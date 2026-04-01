import 'dart:convert';

import 'room_kakao_nav_link.dart';

enum RoomType { normal, vendor, maintenance }

class RoomModel {
  final int id;
  final String name;
  final String lastMsg;
  final String time;
  final int unread;
  final List<String> companies;
  final List<String> subRoutes;
  /// 배차 시간표 1 (URL, 로컬 경로, 또는 web data URL)
  final List<String> timetable1Images;
  /// 배차 시간표 2
  final List<String> timetable2Images;
  final bool pinned;
  final bool adminOnly;
  final RoomType roomType;
  /// `config/kakao_nav_links`에서 병합 (채팅방 사이드 메뉴 내비 버튼)
  final List<RoomKakaoNavLink> kakaoNavLinks;

  const RoomModel({
    required this.id,
    required this.name,
    this.lastMsg = '',
    this.time = '',
    this.unread = 0,
    this.companies = const [],
    this.subRoutes = const [],
    this.timetable1Images = const [],
    this.timetable2Images = const [],
    this.pinned = false,
    this.adminOnly = false,
    this.roomType = RoomType.normal,
    this.kakaoNavLinks = const [],
  });

  bool get isVendorRoom => roomType == RoomType.vendor;
  bool get isMaintenanceRoom => roomType == RoomType.maintenance;

  bool get hasTimetable1 => timetable1Images.isNotEmpty;
  bool get hasTimetable2 => timetable2Images.isNotEmpty;
  bool get hasAnyTimetable => hasTimetable1 || hasTimetable2;

  // ─── drift 캐시 직렬화 ─────────────────────────────────────────

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'lastMsg': lastMsg,
      'time': time,
      'unread': unread,
      'companies': companies,
      'subRoutes': subRoutes,
      'timetable1Images': timetable1Images,
      'timetable2Images': timetable2Images,
      'pinned': pinned,
      'adminOnly': adminOnly,
      'roomType': roomType.name,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  static RoomModel fromJson(Map<String, dynamic> j) {
    final rtStr = j['roomType'] as String? ?? 'normal';
    final rt = RoomType.values.firstWhere(
      (e) => e.name == rtStr,
      orElse: () => RoomType.normal,
    );
    return RoomModel(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: j['name'] as String? ?? '',
      lastMsg: j['lastMsg'] as String? ?? '',
      time: j['time'] as String? ?? '',
      unread: (j['unread'] as num?)?.toInt() ?? 0,
      companies: (j['companies'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      subRoutes: (j['subRoutes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      timetable1Images: (j['timetable1Images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      timetable2Images: (j['timetable2Images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      pinned: j['pinned'] as bool? ?? false,
      adminOnly: j['adminOnly'] as bool? ?? false,
      roomType: rt,
    );
  }

  static RoomModel fromJsonString(String s) =>
      fromJson(jsonDecode(s) as Map<String, dynamic>);

  RoomModel copyWith({
    int? id,
    String? name,
    String? lastMsg,
    String? time,
    int? unread,
    List<String>? companies,
    List<String>? subRoutes,
    List<String>? timetable1Images,
    List<String>? timetable2Images,
    bool clearTimetable1Images = false,
    bool clearTimetable2Images = false,
    bool? pinned,
    bool? adminOnly,
    RoomType? roomType,
    List<RoomKakaoNavLink>? kakaoNavLinks,
  }) {
    return RoomModel(
      id: id ?? this.id,
      name: name ?? this.name,
      lastMsg: lastMsg ?? this.lastMsg,
      time: time ?? this.time,
      unread: unread ?? this.unread,
      companies: companies ?? this.companies,
      subRoutes: subRoutes ?? this.subRoutes,
      timetable1Images: clearTimetable1Images ? const [] : (timetable1Images ?? this.timetable1Images),
      timetable2Images: clearTimetable2Images ? const [] : (timetable2Images ?? this.timetable2Images),
      pinned: pinned ?? this.pinned,
      adminOnly: adminOnly ?? this.adminOnly,
      roomType: roomType ?? this.roomType,
      kakaoNavLinks: kakaoNavLinks ?? this.kakaoNavLinks,
    );
  }
}
