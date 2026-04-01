import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 포그라운드(앱 실행 중) 알림음 — 일반 메시지 / 긴급 메시지 MP3 + 선택적 진동
///
/// [audioplayers]는 `flutter pub add` 직후 **핫 리로드만으로는 네이티브가 안 붙습니다.**
/// 한 번 **앱 완전 종료 후 `flutter run`으로 다시 빌드**해야 합니다.
/// 그 전에는 [MissingPluginException] 시 시스템 알림음으로 대체합니다.
class ForegroundNotifySound {
  ForegroundNotifySound._();

  static AudioPlayer? _player;
  /// 이번 프로세스에서 네이티브 오디오 실패 시 시스템음만 씀 (재실행 시 초기화됨)
  static bool _nativeAudioUnavailable = false;

  static const String _assetChat = 'sounds/chat_notify.mp3';
  static const String _assetEmergency = 'sounds/emergency_notify.mp3';

  /// 일반 새 메시지 알림
  static Future<void> play({
    required bool soundEnabled,
    required bool vibrateEnabled,
  }) =>
      _playAsset(
        assetPath: _assetChat,
        soundEnabled: soundEnabled,
        vibrateEnabled: vibrateEnabled,
        heavyVibrate: false,
      );

  /// 매니저·슈퍼 — 타인이 보낸 긴급 전용 (진동 강함)
  static Future<void> playEmergency({
    required bool soundEnabled,
    required bool vibrateEnabled,
  }) =>
      _playAsset(
        assetPath: _assetEmergency,
        soundEnabled: soundEnabled,
        vibrateEnabled: vibrateEnabled,
        heavyVibrate: true,
      );

  static Future<void> _playAsset({
    required String assetPath,
    required bool soundEnabled,
    required bool vibrateEnabled,
    required bool heavyVibrate,
  }) async {
    if (vibrateEnabled) {
      if (heavyVibrate) {
        await HapticFeedback.heavyImpact();
        await Future<void>.delayed(const Duration(milliseconds: 80));
        await HapticFeedback.mediumImpact();
      } else {
        await HapticFeedback.mediumImpact();
      }
    }
    if (!soundEnabled) return;
    if (kIsWeb) {
      return;
    }

    if (_nativeAudioUnavailable) {
      SystemSound.play(SystemSoundType.alert);
      return;
    }

    try {
      _player ??= AudioPlayer();
      await _player!.setReleaseMode(ReleaseMode.stop);
      await _player!.stop();
      await _player!.play(AssetSource(assetPath));
    } on MissingPluginException catch (e, st) {
      _nativeAudioUnavailable = true;
      await _disposePlayerQuietly();
      if (kDebugMode) debugPrint(
        'ForegroundNotifySound: audioplayers 플러그인 미연결 ($e). '
        '앱을 완전히 종료한 뒤 flutter run으로 다시 빌드하세요. 임시로 시스템음 사용.\n$st',
      );
      SystemSound.play(SystemSoundType.alert);
    } catch (e, st) {
      if (kDebugMode) debugPrint('ForegroundNotifySound.play error: $e\n$st');
      SystemSound.play(SystemSoundType.alert);
    }
  }

  static Future<void> _disposePlayerQuietly() async {
    try {
      await _player?.dispose();
    } catch (_) {}
    _player = null;
  }
}
