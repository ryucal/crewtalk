import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database/app_database.dart';
import 'database/message_dao.dart';
import 'firebase_options.dart';
import 'models/room_model.dart';
import 'models/user_model.dart';
import 'providers/app_provider.dart';
import 'router/app_router.dart';
import 'services/auth_repository.dart';
import 'services/fcm_push_service.dart';
import 'widgets/firestore_room_sync.dart';
import 'services/gps_service.dart';
import 'services/user_session_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // GPS Foreground Service 초기화 (웹 제외)
  GpsService.init();
  if (!kIsWeb) {
    FlutterForegroundTask.initCommunicationPort();
  }

  UserModel? initialUser;

  // 1단계: Firebase 초기화
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await FcmPushService.init();
    }
  } catch (e, st) {
    if (kDebugMode) debugPrint('Firebase 초기화 실패 — 로컬 모드로 동작합니다.\n$e\n$st');
  }

  // 2단계: 세션 복원 (Firebase 가용 여부에 따라 분기)
  if (AuthRepository.firebaseAvailable) {
    try {
      initialUser = await AuthRepository.loadSessionUser();
      if (!kIsWeb) {
        await FcmPushService.syncForLoggedInUser(initialUser?.firebaseUid);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('세션 복원 실패 — 로그인 화면으로 이동합니다.\n$e');
      try { await AuthRepository.signOutFirebase(); } catch (_) {}
      try { await UserSessionStorage.clear(); } catch (_) {}
    }
  } else {
    initialUser = await UserSessionStorage.loadUser();
  }

  // 30일 이상 된 캐시 메시지 정리 (fire-and-forget)
  AppDatabase().deleteOldMessages(30).then((count) {
    if (kDebugMode && count > 0) debugPrint('drift: purged $count old cached messages');
  }).catchError((_) {});

  runApp(
    ProviderScope(
      overrides: [
        userProvider.overrideWith((ref) => UserNotifier(initialUser)),
      ],
      child: FirestoreRoomSync(
        child: const CrewTalkApp(),
      ),
    ),
  );
}

class CrewTalkApp extends ConsumerStatefulWidget {
  const CrewTalkApp({super.key});

  @override
  ConsumerState<CrewTalkApp> createState() => _CrewTalkAppState();
}

class _CrewTalkAppState extends ConsumerState<CrewTalkApp> {
  StreamSubscription<RemoteMessage>? _fcmOpenedSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bindPushNavigation());
  }

  void _bindPushNavigation() {
    if (kIsWeb || !AuthRepository.firebaseAvailable) return;

    FcmPushService.onLocalNotificationTapped = _openFromPayloadString;

    _fcmOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen(_openFromRemoteMessage);
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? msg) {
      if (msg == null || !mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _navigateFromNotificationData(msg.data);
      });
    });
  }

  @override
  void dispose() {
    _fcmOpenedSub?.cancel();
    FcmPushService.onLocalNotificationTapped = null;
    super.dispose();
  }

  void _openFromPayloadString(String? payload) {
    if (payload == null || payload.isEmpty) {
      _navigateFromNotificationData(const {});
      return;
    }
    _navigateFromNotificationData({'roomId': payload});
  }

  void _openFromRemoteMessage(RemoteMessage msg) {
    _navigateFromNotificationData(msg.data);
  }

  /// 긴급/일반 푸시 data 의 `roomId` 로 채팅방 이동, 없거나 목록에 없으면 목록으로
  void _navigateFromNotificationData(Map<String, dynamic> data) {
    if (!mounted) return;
    final router = ref.read(routerProvider);
    final user = ref.read(userProvider);
    if (user == null) {
      router.go('/login');
      return;
    }

    final roomIdStr = data['roomId'] as String?;
    final id = int.tryParse(roomIdStr ?? '');
    if (id == null) {
      router.go('/rooms');
      return;
    }

    final rooms = ref.read(roomProvider);
    RoomModel? room;
    for (final r in rooms) {
      if (r.id == id) {
        room = r;
        break;
      }
    }

    if (room != null) {
      ref.read(currentRoomProvider.notifier).state = room;
      router.push('/chat');
    } else {
      router.go('/rooms');
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'CREW TALK',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'AppleSDGothicNeo',
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
