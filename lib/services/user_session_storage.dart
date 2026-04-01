import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';

/// 로그인 세션을 기기에 저장·복원 (로그아웃 시 삭제)
class UserSessionStorage {
  UserSessionStorage._();

  static const _key = 'crewtalk_user_session_v1';

  static Future<UserModel?> loadUser() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_key);
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;
      return UserModel.fromJson(map);
    } catch (_) {
      await clear();
      return null;
    }
  }

  static Future<void> saveUser(UserModel user) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, jsonEncode(user.toJson()));
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_key);
  }

  // ─── 방별 읽음 상태 (안읽음 뱃지용) ────────────────────────────

  static const _readPrefix = 'room_last_read_';

  static Future<int> getLastReadAt(int roomId) async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt('$_readPrefix$roomId') ?? 0;
  }

  static Future<void> setLastReadAt(int roomId, int epochMs) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('$_readPrefix$roomId', epochMs);
  }

  static Future<Map<int, int>> getAllLastReadAt(List<int> roomIds) async {
    final sp = await SharedPreferences.getInstance();
    final result = <int, int>{};
    for (final id in roomIds) {
      result[id] = sp.getInt('$_readPrefix$id') ?? 0;
    }
    return result;
  }

  // ─── 포그라운드 메시지 알림 (채팅 목록 동기화용) ─────────────────

  static const _keyMessageNotifSound = 'settings_message_notif_sound_v1';
  static const _keyMessageNotifVibrate = 'settings_message_notif_vibrate_v1';

  static Future<bool> getMessageNotifSoundEnabled() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_keyMessageNotifSound) ?? true;
  }

  static Future<void> setMessageNotifSoundEnabled(bool value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_keyMessageNotifSound, value);
  }

  static Future<bool> getMessageNotifVibrateEnabled() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_keyMessageNotifVibrate) ?? true;
  }

  static Future<void> setMessageNotifVibrateEnabled(bool value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_keyMessageNotifVibrate, value);
  }

}
