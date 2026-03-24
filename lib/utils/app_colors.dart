import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF000000);
  static const Color background = Color(0xFFF5F5F5);
  static const Color white = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFEEEEEE);
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF333333);
  static const Color textHint = Color(0xFFAAAAAA);
  static const Color textLight = Color(0xFFBBBBBB);

  static const Color morningBlue = Color(0xFF1565C0);
  static const Color morningBlueBg = Color(0xFFE3F0FD);
  static const Color eveningRed = Color(0xFFC62828);
  static const Color eveningRedBg = Color(0xFFFDEAEA);
  static const Color nightPurple = Color(0xFF6A1B9A);
  static const Color nightPurpleBg = Color(0xFFF3E8FD);

  static const Color adminIndigo = Color(0xFF1A237E);
  static const Color adminIndigoBg = Color(0xFFE8EAF6);

  static const Color kakaoYellow = Color(0xFFFEE500);
  static const Color kakaoBrown = Color(0xFF3C1E1E);

  static const Color emergencyRed = Color(0xFFE53935);
  static const Color emergencyRedLight = Color(0xFFFFF0F0);
  static const Color emergencyBorder = Color(0xFFFFCDD2);

  static const Color unreadBadge = Color(0xFFFF3B30);
  static const Color overCapacity = Color(0xFFFF5252);
  static const Color warning = Color(0xFFE65100);

  static const Color noticeBackground = Color(0xFFEEEDFE);
  static const Color noticeBorder = Color(0xFFAFA9EC);
  static const Color noticePurple = Color(0xFF534AB7);
  static const Color noticeDeep = Color(0xFF3C3489);

  static const List<AvatarColor> avatarPalette = [
    AvatarColor(bg: Color(0xFFE6F1FB), color: Color(0xFF185FA5)),
    AvatarColor(bg: Color(0xFFE1F5EE), color: Color(0xFF0F6E56)),
    AvatarColor(bg: Color(0xFFFAEEDA), color: Color(0xFF854F0B)),
    AvatarColor(bg: Color(0xFFFBEAF0), color: Color(0xFF993556)),
    AvatarColor(bg: Color(0xFFEEEDFE), color: Color(0xFF534AB7)),
    AvatarColor(bg: Color(0xFFEAF3DE), color: Color(0xFF3B6D11)),
    AvatarColor(bg: Color(0xFFFAECE7), color: Color(0xFF993C1D)),
    AvatarColor(bg: Color(0xFFF1EFE8), color: Color(0xFF5F5E5A)),
  ];

  static AvatarColor avatarColor(String name) {
    if (name.isEmpty) return avatarPalette[0];
    final code = name.codeUnitAt(0);
    return avatarPalette[code % avatarPalette.length];
  }
}

class AvatarColor {
  final Color bg;
  final Color color;

  const AvatarColor({required this.bg, required this.color});
}
