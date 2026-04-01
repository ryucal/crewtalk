import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show
        kDebugMode,
        kIsWeb,
        debugPrint,
        defaultTargetPlatform,
        TargetPlatform,
        VoidCallback;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import 'auth_repository.dart';
import 'track_firestore_repository.dart';

/// Foreground Task 진입점 — 반드시 최상위에 위치해야 함
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(_GpsTaskHandler());
}

/// Foreground Task 핸들러 (백그라운드 실행 유지 역할)
class _GpsTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

/// GPS 추적 서비스 — 싱글턴
class GpsService {
  GpsService._();
  static final GpsService instance = GpsService._();

  bool _active = false;
  bool get isActive => _active;

  StreamSubscription<Position>? _positionSub;
  Timer? _uploadTimer;
  Timer? _autoStopTimer;
  Timer? _firstFlushTimer;
  Timer? _fallbackTimer;

  bool _flushInProgress = false;

  /// 30초 단위 버퍼 → Firestore `tracks/{id}/points` 배치 업로드
  final List<Map<String, dynamic>> _buffer = [];

  String? _currentTrackId;
  bool _firestoreTrack = false;

  // 디버그 카운터 — finalizeTrack 시 트랙 문서에 함께 기록
  int _pointsCollected = 0;
  int _pointsFlushed = 0;
  int _flushErrors = 0;

  // 현재 운행 메타데이터
  String _name = '';
  String _car = '';
  String _route = '';
  String _subRoute = '';
  int _count = 0;

  /// 1시간 자동 종료 후 UI에 알릴 콜백
  VoidCallback? onAutoStopped;

  // ─── 초기화 ────────────────────────────────────────────────────────────────

  static void init() {
    if (kIsWeb) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'crewtalk_gps_channel_v2',
        channelName: '운행 중',
        channelDescription: '인원 보고가 전송된 후 운행 경로를 추적 중입니다.',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
        playSound: false,
        enableVibration: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  // ─── 권한 요청 ─────────────────────────────────────────────────────────────

  /// 위치 + 알림 권한을 한 번에 요청. true = 모두 허용, false = 하나라도 거부
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    // ① 알림 권한 (Android 13+ 필수 — FGS 알림 표시에 필요)
    var notifPerm =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notifPerm != NotificationPermission.granted) {
      notifPerm =
          await FlutterForegroundTask.requestNotificationPermission();
      if (notifPerm != NotificationPermission.granted) {
        if (kDebugMode) debugPrint('[GpsService] 알림 권한 거부됨');
        return false;
      }
    }

    // ② 위치 서비스 활성화 확인
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    // ③ 위치 권한
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) {
      return false;
    }
    return true;
  }

  // ─── 운행 시작 ─────────────────────────────────────────────────────────────

  /// 운행 시작. 포그라운드 서비스 시작에 성공하면 true, 실패하면 false.
  Future<bool> start({
    required String name,
    required String car,
    required String route,
    String subRoute = '',
    int count = 0,
    int? roomId,
    String company = '',
    String phone = '',
  }) async {
    if (kIsWeb) return false;

    if (_active) {
      await _stopInternal(keepService: true, stopReason: 'replaced_by_report');
    }

    _name = name;
    _car = car;
    _route = route;
    _subRoute = subRoute;
    _count = count;
    _buffer.clear();
    _currentTrackId = null;
    _firestoreTrack = false;
    _pointsCollected = 0;
    _pointsFlushed = 0;
    _flushErrors = 0;

    // FGS 먼저 시작 — 실패하면 위치 스트림 시작하지 않음
    final fgsOk = await _startForegroundService();
    if (!fgsOk) {
      if (kDebugMode) debugPrint('[GpsService] FGS 실패 → 운행 시작 중단');
      return false;
    }

    if (AuthRepository.firebaseAvailable) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final rid = roomId;
      if (uid != null && rid != null && rid != 998 && rid != 999) {
        final digits = phone.replaceAll(RegExp(r'\D'), '');
        final driverId = '$company|$digits';
        final tid = await TrackFirestoreRepository.createActiveTrack(
          ownerUid: uid,
          name: name,
          car: car,
          company: company,
          driverId: driverId,
          roomId: rid,
          route: route,
          subRoute: subRoute,
          count: count,
        );
        if (tid != null) {
          _currentTrackId = tid;
          _firestoreTrack = true;
          if (kDebugMode) debugPrint('[GpsService] Firestore 트랙 생성: $tid');
        }
      }
    }

    _active = true;

    _startPositionStream();
    _startUploadTimer();
    _startAutoStopTimer();

    if (kDebugMode) {
      debugPrint('[GpsService] 운행 시작 — $name / $car / $route $subRoute / $count명');
    }
    return true;
  }

  // ─── 운행 종료 ─────────────────────────────────────────────────────────────

  Future<void> stop({String stopReason = 'user_stop'}) async {
    if (!_active) return;
    await _stopInternal(keepService: false, stopReason: stopReason);
    if (kDebugMode) debugPrint('[GpsService] 운행 종료');
  }

  Future<void> _stopInternal({
    required bool keepService,
    required String stopReason,
  }) async {
    _active = false;

    await _positionSub?.cancel();
    _positionSub = null;

    _uploadTimer?.cancel();
    _uploadTimer = null;

    _firstFlushTimer?.cancel();
    _firstFlushTimer = null;

    _fallbackTimer?.cancel();
    _fallbackTimer = null;

    _autoStopTimer?.cancel();
    _autoStopTimer = null;

    await _flushBufferToFirestore();

    if (_firestoreTrack && _currentTrackId != null) {
      await TrackFirestoreRepository.finalizeTrack(
        _currentTrackId!,
        stopReason: stopReason,
        pointsCollected: _pointsCollected,
        pointsFlushed: _pointsFlushed,
        flushErrors: _flushErrors,
      );
      if (kDebugMode) {
        debugPrint(
          '[GpsService] 트랙 종료 $_currentTrackId — $stopReason '
          '(collected=$_pointsCollected flushed=$_pointsFlushed errors=$_flushErrors)',
        );
      }
    }
    _currentTrackId = null;
    _firestoreTrack = false;

    if (!keepService && !kIsWeb) {
      await FlutterForegroundTask.stopService();
    }
  }

  // ─── GPS 스트림 ────────────────────────────────────────────────────────────
  /// Activity 기반 위치 스트림 + FlutterForegroundTask FGS 로 프로세스 보호.
  /// ForegroundNotificationConfig 는 사용하지 않음 — geolocator_android 의
  /// GeolocatorLocationService 바인딩이 안 됐을 때 스트림이 조용히 멈추는 문제 방지.
  LocationSettings _positionStreamSettings() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          intervalDuration: const Duration(seconds: 5),
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          pauseLocationUpdatesAutomatically: false,
        );
      default:
        return const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
        );
    }
  }

  bool _streamEverFired = false;

  void _startPositionStream() {
    _streamEverFired = false;
    final settings = _positionStreamSettings();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      _onPosition,
      onError: (e) {
        if (kDebugMode) debugPrint('[GpsService] 스트림 오류: $e');
        _startFallbackPolling();
      },
      onDone: () {
        if (kDebugMode) debugPrint('[GpsService] 스트림 완료 (onDone)');
        if (_active) _startFallbackPolling();
      },
    );

    // 15초 안에 스트림 이벤트가 안 오면 폴백 전환
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(const Duration(seconds: 15), () {
      if (_active && !_streamEverFired) {
        if (kDebugMode) debugPrint('[GpsService] 스트림 15초 무응답 — 폴백 전환');
        _startFallbackPolling();
      }
    });
  }

  /// 스트림이 안 올 때 5초마다 getCurrentPosition 으로 수동 수집
  void _startFallbackPolling() {
    if (_fallbackTimer != null &&
        _fallbackTimer!.isActive &&
        _streamEverFired) {
      return;
    }
    _positionSub?.cancel();
    _positionSub = null;
    _fallbackTimer?.cancel();
    if (kDebugMode) {
      debugPrint('[GpsService] 폴백 폴링 시작 (5초 간격 getCurrentPosition)');
    }
    _fallbackTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!_active) {
        _fallbackTimer?.cancel();
        return;
      }
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        _onPosition(pos);
      } catch (e) {
        if (kDebugMode) debugPrint('[GpsService] 폴백 위치 조회 실패: $e');
      }
    });
  }

  void _onPosition(Position pos) {
    if (!_active) return;
    _streamEverFired = true;
    _pointsCollected++;
    final dt = pos.timestamp ?? DateTime.now();
    final point = {
      'date': _fmtDate(dt),
      'time': _fmtTime(dt),
      'name': _name,
      'car': _car,
      'route': _route,
      'subRoute': _subRoute,
      'count': _count,
      'lat': pos.latitude,
      'lng': pos.longitude,
      'accuracy': pos.accuracy,
      'heading': pos.heading,
      'speed': pos.speed,
      'ts': dt.millisecondsSinceEpoch,
    };
    _buffer.add(point);
    if (kDebugMode) {
      debugPrint(
        '[GpsService] 수집 #$_pointsCollected — '
        'lat:${pos.latitude.toStringAsFixed(5)}, '
        'lng:${pos.longitude.toStringAsFixed(5)} '
        '(buf=${_buffer.length})',
      );
    }
  }

  // ─── 30초 버퍼 → Firestore ─────────────────────────────────────────────────

  void _startUploadTimer() {
    _uploadTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_flushBufferToFirestore());
    });
    _firstFlushTimer?.cancel();
    _firstFlushTimer = Timer(const Duration(seconds: 8), () {
      unawaited(_flushBufferToFirestore());
    });
  }

  Future<void> _flushBufferToFirestore() async {
    if (_flushInProgress || _buffer.isEmpty) return;
    _flushInProgress = true;
    try {
      final batch = List<Map<String, dynamic>>.from(_buffer);
      _buffer.clear();

      if (!_firestoreTrack || _currentTrackId == null) {
        if (kDebugMode) {
          debugPrint('[GpsService] 버퍼 폐기 ${batch.length}건 (Firestore 트랙 없음)');
        }
        return;
      }

      final ok =
          await TrackFirestoreRepository.appendPoints(_currentTrackId!, batch);
      if (!ok) {
        _flushErrors++;
        _buffer.insertAll(0, batch);
        if (kDebugMode) {
          debugPrint(
            '[GpsService] Firestore 포인트 쓰기 실패 (err=$_flushErrors) — '
            '${batch.length}건 버퍼 복원',
          );
        }
      } else {
        _pointsFlushed += batch.length;
        if (kDebugMode) {
          debugPrint(
            '[GpsService] Firestore 업로드 ${batch.length}건 '
            '(총 flushed=$_pointsFlushed)',
          );
        }
      }
    } finally {
      _flushInProgress = false;
    }
  }

  // ─── 1시간 자동 종료 ───────────────────────────────────────────────────────

  void _startAutoStopTimer() {
    _autoStopTimer = Timer(const Duration(hours: 1), () async {
      if (kDebugMode) debugPrint('[GpsService] 1시간 미보고로 자동 종료');
      if (_active) {
        await stop(stopReason: 'auto_timeout');
        onAutoStopped?.call();
      }
    });
  }

  void resetAutoStopTimer() {
    _autoStopTimer?.cancel();
    _startAutoStopTimer();
  }

  // ─── Foreground Service 알림 ───────────────────────────────────────────────

  Future<bool> _startForegroundService() async {
    final notifPerm =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notifPerm != NotificationPermission.granted) {
      final result =
          await FlutterForegroundTask.requestNotificationPermission();
      if (result != NotificationPermission.granted) {
        if (kDebugMode) debugPrint('[GpsService] FGS 시작 실패 — 알림 권한 거부');
        return false;
      }
    }

    final title = '운행 중 · $_name';
    final body =
        '$_route${_subRoute.isNotEmpty ? ' · $_subRoute' : ''} · $_count명';

    final ServiceRequestResult result;
    if (await FlutterForegroundTask.isRunningService) {
      result = await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: body,
      );
    } else {
      result = await FlutterForegroundTask.startService(
        serviceId: 1001,
        notificationTitle: title,
        notificationText: body,
        callback: startCallback,
      );
    }

    if (result case ServiceRequestFailure(:final error)) {
      if (kDebugMode) debugPrint('[GpsService] FGS 시작/업데이트 실패: $error');
      return false;
    }
    return true;
  }

  // ─── 유틸 ──────────────────────────────────────────────────────────────────

  String _fmtDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';
}
