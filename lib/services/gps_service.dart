import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

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

  /// 30초 단위 로컬 버퍼 (Firestore 업로드 전 임시 저장)
  final List<Map<String, dynamic>> _buffer = [];

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
        channelId: 'crewtalk_gps_channel',
        channelName: '운행 중',
        channelDescription: '인원 보고가 전송된 후 운행 경로를 추적 중입니다.',
        channelImportance: NotificationChannelImportance.DEFAULT,
        priority: NotificationPriority.DEFAULT,
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

  /// 위치 권한 요청. true = 사용 가능, false = 거부됨
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

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

  Future<void> start({
    required String name,
    required String car,
    required String route,
    String subRoute = '',
    int count = 0,
  }) async {
    if (kIsWeb) return;

    // 재보고 시: 이전 GPS 중지 → 새 운행으로 재시작
    if (_active) await _stopInternal(keepService: true);

    _name = name;
    _car = car;
    _route = route;
    _subRoute = subRoute;
    _count = count;
    _active = true;
    _buffer.clear();

    await _startForegroundService();
    _startPositionStream();
    _startUploadTimer();
    _startAutoStopTimer();

    debugPrint('[GpsService] 운행 시작 — $name / $car / $route $_subRoute / ${count}명');
  }

  // ─── 운행 종료 ─────────────────────────────────────────────────────────────

  Future<void> stop() async {
    if (!_active) return;
    await _stopInternal(keepService: false);
    debugPrint('[GpsService] 운행 종료');
  }

  Future<void> _stopInternal({required bool keepService}) async {
    _active = false;

    await _positionSub?.cancel();
    _positionSub = null;

    _uploadTimer?.cancel();
    _uploadTimer = null;

    _autoStopTimer?.cancel();
    _autoStopTimer = null;

    _flushBuffer();

    if (!keepService && !kIsWeb) {
      await FlutterForegroundTask.stopService();
    }
  }

  // ─── GPS 스트림 (5초 간격) ──────────────────────────────────────────────────

  void _startPositionStream() {
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    ).listen(
      _onPosition,
      onError: (e) => debugPrint('[GpsService] 스트림 오류: $e'),
    );

    // geolocator 스트림 자체에 interval 옵션이 없으므로
    // 5초마다 단발 위치를 추가로 수집
    Timer.periodic(const Duration(seconds: 5), (t) async {
      if (!_active) {
        t.cancel();
        return;
      }
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
          ),
        );
        _onPosition(pos);
      } catch (_) {}
    });
  }

  void _onPosition(Position pos) {
    if (!_active) return;
    final point = {
      'date': _fmtDate(DateTime.now()),
      'time': _fmtTime(DateTime.now()),
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
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    _buffer.add(point);
    debugPrint(
      '[GpsService] 수집 (${_buffer.length}/${_buffer.length}) '
      '— lat:${pos.latitude.toStringAsFixed(5)}, '
      'lng:${pos.longitude.toStringAsFixed(5)}',
    );
  }

  // ─── 30초 버퍼 업로드 ──────────────────────────────────────────────────────

  void _startUploadTimer() {
    _uploadTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _flushBuffer();
    });
  }

  void _flushBuffer() {
    if (_buffer.isEmpty) return;
    final batch = List<Map<String, dynamic>>.from(_buffer);
    _buffer.clear();

    // TODO: Firebase 연동 후 Firestore 서브컬렉션에 업로드
    // tracks/{date}_{name}_{route}/points/{ts} 형태로 저장 예정
    debugPrint('[GpsService] 버퍼 플러시 — ${batch.length}개 포인트 (DB 연결 전 로컬 보관)');
  }

  // ─── 1시간 자동 종료 ───────────────────────────────────────────────────────

  void _startAutoStopTimer() {
    _autoStopTimer = Timer(const Duration(hours: 1), () async {
      debugPrint('[GpsService] 1시간 미보고로 자동 종료');
      await stop();
      onAutoStopped?.call();
    });
  }

  /// 보고 전송 시 자동 종료 타이머를 1시간으로 재설정
  void resetAutoStopTimer() {
    _autoStopTimer?.cancel();
    _startAutoStopTimer();
  }

  // ─── Foreground Service 알림 ───────────────────────────────────────────────

  Future<void> _startForegroundService() async {
    final title = '운행 중 · $_name';
    final body =
        '$_route${_subRoute.isNotEmpty ? ' · $_subRoute' : ''} · ${_count}명';

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: body,
      );
    } else {
      await FlutterForegroundTask.startService(
        serviceId: 1001,
        notificationTitle: title,
        notificationText: body,
        callback: startCallback,
      );
    }
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
