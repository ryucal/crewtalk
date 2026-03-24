enum RoomType { normal, vendor }

class RoomModel {
  final int id;
  final String name;
  final String lastMsg;
  final String time;
  final int unread;
  final List<String> companies;
  final List<String> subRoutes;
  /// 배차 시간표 (URL, 로컬 경로, 또는 web data URL)
  final List<String> timetableImages;
  final bool pinned;
  final bool adminOnly;
  final RoomType roomType;

  const RoomModel({
    required this.id,
    required this.name,
    this.lastMsg = '',
    this.time = '',
    this.unread = 0,
    this.companies = const [],
    this.subRoutes = const [],
    this.timetableImages = const [],
    this.pinned = false,
    this.adminOnly = false,
    this.roomType = RoomType.normal,
  });

  bool get isVendorRoom => roomType == RoomType.vendor;

  bool get hasTimetable => timetableImages.isNotEmpty;

  RoomModel copyWith({
    int? id,
    String? name,
    String? lastMsg,
    String? time,
    int? unread,
    List<String>? companies,
    List<String>? subRoutes,
    List<String>? timetableImages,
    bool clearTimetableImages = false,
    bool? pinned,
    bool? adminOnly,
    RoomType? roomType,
  }) {
    return RoomModel(
      id: id ?? this.id,
      name: name ?? this.name,
      lastMsg: lastMsg ?? this.lastMsg,
      time: time ?? this.time,
      unread: unread ?? this.unread,
      companies: companies ?? this.companies,
      subRoutes: subRoutes ?? this.subRoutes,
      timetableImages: clearTimetableImages ? [] : (timetableImages ?? this.timetableImages),
      pinned: pinned ?? this.pinned,
      adminOnly: adminOnly ?? this.adminOnly,
      roomType: roomType ?? this.roomType,
    );
  }
}
