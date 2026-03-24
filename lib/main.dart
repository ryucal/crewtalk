import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router/app_router.dart';
import 'services/gps_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // GPS Foreground Service 초기화 (웹 제외)
  GpsService.init();
  if (!kIsWeb) {
    FlutterForegroundTask.initCommunicationPort();
  }

  runApp(const ProviderScope(child: CrewTalkApp()));
}

class CrewTalkApp extends ConsumerWidget {
  const CrewTalkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
