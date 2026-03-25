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
}
