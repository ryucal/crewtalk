import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../firebase_options.dart';
import 'auth_repository.dart';
import 'user_session_storage.dart';

/// 백그라운드 isolate — 반드시 최상위 함수, 등록은 [main]에서 `runApp` 전
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode) debugPrint('FCM background: ${message.messageId} ${message.notification?.title}');
}

/// FCM 토큰을 `users/{uid}.fcmTokens` 배열에 저장 · 긴급 등 푸시 수신
class FcmPushService {
  FcmPushService._();

  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static String? _lastRegisteredUid;

  /// 현재 사용자가 보고 있는 채팅방 ID (포그라운드 알림 억제용)
  static String? activeRoomId;

  /// 음소거된 방 ID 목록 (로그인 시 UserModel.mutedRooms에서 동기화)
  static Set<int> mutedRoomIds = {};

  /// 포그라운드 로컬 알림 탭 시 [payload]는 `roomId` 문자열 (앱 루트에서 네비게이션 연결)
  static void Function(String? payload)? onLocalNotificationTapped;

  static const _androidChannelDefault = AndroidNotificationChannel(
    'crewtalk_messages',
    '채팅 알림',
    description: '새 메시지 및 안내',
    importance: Importance.defaultImportance,
  );

  static const _androidChannelEmergency = AndroidNotificationChannel(
    'crewtalk_emergency',
    '긴급 알림',
    description: '긴급 호출 전용',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static Future<void> init() async {
    if (kIsWeb || !AuthRepository.firebaseAvailable) return;
    if (_initialized) return;
    _initialized = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: darwinInit),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    final androidPlugin = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_androidChannelDefault);
    await androidPlugin?.createNotificationChannel(_androidChannelEmergency);

    if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.request();
      if (kDebugMode) debugPrint('FCM Android notification permission: $status');
    }

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final uid = _lastRegisteredUid;
      if (uid != null) {
        await _saveToken(uid, newToken);
      }
      if (kDebugMode) debugPrint('FCM token refreshed');
    });

    if (kDebugMode) debugPrint('FcmPushService initialized');
  }

  /// iOS/macOS는 APNs 토큰이 늦게 도착할 수 있어, [waitForApns]가 true면 준비될 때까지 대기 후 [getToken].
  static Future<String?> _obtainFcmToken({required bool waitForApns}) async {
    final isAppleOs = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);
    if (!isAppleOs) {
      return FirebaseMessaging.instance.getToken();
    }

    if (waitForApns) {
      const step = Duration(milliseconds: 250);
      const maxWait = Duration(seconds: 20);
      final deadline = DateTime.now().add(maxWait);

      while (DateTime.now().isBefore(deadline)) {
        final apns = await FirebaseMessaging.instance.getAPNSToken();
        if (apns != null && apns.isNotEmpty) {
          break;
        }
        await Future<void>.delayed(step);
      }
    }

    final maxAttempts = waitForApns ? 8 : 3;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final t = await FirebaseMessaging.instance.getToken();
        if (t != null && t.isNotEmpty) return t;
      } on FirebaseException catch (e) {
        final code = e.code.toLowerCase();
        if (code.contains('apns') && attempt < maxAttempts - 1) {
          await Future<void>.delayed(Duration(milliseconds: waitForApns ? 400 : 150));
          continue;
        }
        if (!waitForApns) return null;
        rethrow;
      }
    }
    return null;
  }

  static void _onNotificationTap(NotificationResponse response) {
    if (kDebugMode) debugPrint('FCM local notification tap: ${response.payload}');
    onLocalNotificationTapped?.call(response.payload);
  }

  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    final n = message.notification;
    final data = message.data;
    final isEmergency = data['type'] == 'emergency' || (n?.title?.contains('긴급') ?? false);

    if (n == null && data.isEmpty) return;

    final msgRoomId = data['roomId'] as String?;
    if (!isEmergency && msgRoomId != null && msgRoomId == activeRoomId) {
      if (kDebugMode) debugPrint('FCM: 현재 보고 있는 방($msgRoomId) — 알림 억제');
      return;
    }

    if (!isEmergency && msgRoomId != null) {
      final roomNum = int.tryParse(msgRoomId);
      if (roomNum != null && mutedRoomIds.contains(roomNum)) {
        if (kDebugMode) debugPrint('FCM: 음소거된 방($msgRoomId) — 알림 억제');
        return;
      }
    }

    final soundOn = isEmergency || await UserSessionStorage.getMessageNotifSoundEnabled();
    final vibOn = isEmergency || await UserSessionStorage.getMessageNotifVibrateEnabled();

    final title = n?.title ?? (isEmergency ? '🚨 긴급' : 'CREW TALK');
    final body = n?.body ?? data['body'] ?? '';

    final androidDetails = AndroidNotificationDetails(
      isEmergency ? _androidChannelEmergency.id : _androidChannelDefault.id,
      isEmergency ? _androidChannelEmergency.name : _androidChannelDefault.name,
      channelDescription: isEmergency ? _androidChannelEmergency.description : _androidChannelDefault.description,
      importance: isEmergency ? Importance.max : Importance.defaultImportance,
      priority: isEmergency ? Priority.high : Priority.defaultPriority,
      playSound: soundOn,
      enableVibration: vibOn,
      silent: !soundOn && !vibOn,
    );
    final darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: soundOn,
    );

    await _local.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: darwinDetails),
      payload: data['roomId'],
    );
  }

  /// 로그인 세션이 있을 때 호출 — 토큰을 Firestore에 등록
  static Future<void> syncForLoggedInUser(String? firebaseUid) async {
    if (kIsWeb || !AuthRepository.firebaseAvailable) return;
    await init();

    if (firebaseUid == null || firebaseUid.isEmpty) {
      _lastRegisteredUid = null;
      return;
    }

    _lastRegisteredUid = firebaseUid;

    try {
      final token = await _obtainFcmToken(waitForApns: true);
      if (token == null || token.isEmpty) {
        if (kDebugMode) debugPrint('FCM: 토큰 없음 — iOS는 APNs·푸시 capability·Firebase APNs 키·실기기 여부 확인');
        return;
      }
      await _saveToken(firebaseUid, token);
      if (kDebugMode) debugPrint('FCM token saved for uid=$firebaseUid');
    } catch (e, st) {
      if (kDebugMode) debugPrint('FCM sync error: $e\n$st');
    }
  }

  static Future<void> _saveToken(String uid, String token) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  /// 로그아웃 직전 호출 (Auth 세션 유지 중에만 Firestore 업데이트 가능)
  static Future<void> unregisterCurrentDevice(String? firebaseUid) async {
    if (kIsWeb || !AuthRepository.firebaseAvailable) return;
    if (firebaseUid == null || firebaseUid.isEmpty) return;

    try {
      final token = await _obtainFcmToken(waitForApns: false);
      if (token != null && token.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(firebaseUid).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
      }
      await FirebaseMessaging.instance.deleteToken();
      if (kDebugMode) debugPrint('FCM token removed for uid=$firebaseUid');
    } catch (e, st) {
      if (kDebugMode) debugPrint('FCM unregister error: $e\n$st');
    }
    _lastRegisteredUid = null;
  }
}
