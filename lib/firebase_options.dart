// ignore_for_file: lines_longer_than_80_chars
//
// flutterfire configure 로 갱신 가능 (프로젝트: crewtalk8).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase 미설정 시 init이 실패하면 앱은 로컬(레거시) 로그인만 사용합니다.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions: 이 플랫폼은 Firebase 설정이 필요합니다.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCdSYBQ1RxPjKHDmhb85WxTEQHZsakDG-k',
    appId: '1:297756278549:web:48b63705da933b4d94b31c',
    messagingSenderId: '297756278549',
    projectId: 'crewtalk8',
    authDomain: 'crewtalk8.firebaseapp.com',
    storageBucket: 'crewtalk8.firebasestorage.app',
    measurementId: 'G-TVZKQ8ZY1H',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBWDcZYAKDa2rL8vsmF1hMEyUklD7KDVeU',
    appId: '1:297756278549:android:7c0460958819744b94b31c',
    messagingSenderId: '297756278549',
    projectId: 'crewtalk8',
    storageBucket: 'crewtalk8.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBMT8eidRYOsWz2uCEb_lHZGJQt8SEfFFA',
    appId: '1:297756278549:ios:ac7b68038fefeec694b31c',
    messagingSenderId: '297756278549',
    projectId: 'crewtalk8',
    storageBucket: 'crewtalk8.firebasestorage.app',
    iosBundleId: 'com.crewtalk.crewtalk',
    iosClientId:
        '297756278549-e4qug2hpi4vfk6unfi38qufr6iht3dot.apps.googleusercontent.com',
  );

  static const FirebaseOptions macos = ios;
}