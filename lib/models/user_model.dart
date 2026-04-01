/// 앱·Firestore 공통 역할. Firestore `users.role` 문자열과 맞출 것.
class UserModel {
  /// 일반 기사
  static const String roleDriver = 'driver';

  /// 기사 + 998·999·전체 공지
  static const String roleManager = 'manager';

  /// 방/소속/config·타인 메시지 관리 등 전 권한
  static const String roleSuperAdmin = 'superadmin';

  final String name;
  final String phone;
  final String company;
  final String car;
  /// Firestore `users.role` (정규화된 canonical 값)
  final String role;
  /// Firebase Auth UID (레거시 관리자 로그인 등에는 null)
  final String? firebaseUid;
  /// 알림 음소거한 방 ID 목록
  final List<int> mutedRooms;

  /// 사용자별 상단 고정 방 ID (순서 유지). `rooms.pinned` 글로벌 고정과 별개.
  final List<int> pinnedRoomIds;

  const UserModel({
    required this.name,
    required this.phone,
    required this.company,
    this.car = '',
    this.role = roleDriver,
    this.firebaseUid,
    this.mutedRooms = const [],
    this.pinnedRoomIds = const [],
  });

  String get avatar => name.isNotEmpty ? name[0] : '?';

  /// 문서의 `role` / 레거시 `isAdmin` 기준으로 canonical role 결정
  static String normalizeRoleFromDoc(Map<String, dynamic> d) {
    var r = (d['role'] as String?)?.trim() ?? '';
    if (r.isEmpty && d['isAdmin'] == true) {
      r = roleManager;
    }
    if (r.isEmpty) return roleDriver;
    final lower = r.toLowerCase();
    if (lower == 'superadmin') return roleSuperAdmin;
    if (lower == 'manager') return roleManager;
    if (lower == 'driver') return roleDriver;
    return roleDriver;
  }

  String get normalizedRole {
    final lower = role.trim().toLowerCase();
    if (lower == 'superadmin') return roleSuperAdmin;
    if (lower == 'manager') return roleManager;
    return roleDriver;
  }

  bool get isSuperAdmin => normalizedRole == roleSuperAdmin;
  bool get isManagerOnly => normalizedRole == roleManager;

  /// 매니저 또는 슈퍼 (998·999·공지 등)
  bool get isStaffElevated => isSuperAdmin || isManagerOnly;

  /// 하위 호환: 예전 `isAdmin` 의미 ≈ 매니저 이상
  bool get isAdmin => isStaffElevated;

  /// 채팅방 추가·삭제·순서·소속 관리·config 쓰기 등
  bool get canManageRoomsAndConfig => isSuperAdmin;

  /// Firestore `rooms/{id}` 메타 쓰기 허용(규칙상 isElevatedAdmin) — 슈퍼 + 소속명 「관리자」
  bool get canWriteRoomMetaOnFirestore =>
      canManageRoomsAndConfig || company.trim() == '관리자';

  /// 전체 공지
  bool get canBroadcast => isStaffElevated;

  /// 타인 메시지 수정/삭제 UI
  bool get canModerateChatMessages => isStaffElevated;

  bool isRoomMuted(int roomId) => mutedRooms.contains(roomId);

  /// 글로벌 고정(`rooms.pinned`) 또는 내 고정 목록에 포함되면 상단 고정으로 표시
  bool isRoomPinnedForMe(int roomId, {required bool globalPinned}) =>
      globalPinned || pinnedRoomIds.contains(roomId);

  UserModel copyWith({
    String? name,
    String? phone,
    String? company,
    String? car,
    String? role,
    String? firebaseUid,
    List<int>? mutedRooms,
    List<int>? pinnedRoomIds,
  }) {
    return UserModel(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      company: company ?? this.company,
      car: car ?? this.car,
      role: role ?? this.role,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      mutedRooms: mutedRooms ?? this.mutedRooms,
      pinnedRoomIds: pinnedRoomIds ?? this.pinnedRoomIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'company': company,
        'car': car,
        'role': role,
        'isAdmin': isAdmin,
        'firebaseUid': firebaseUid,
        'mutedRooms': mutedRooms,
        'pinnedRoomIds': pinnedRoomIds,
      };

  /// Firestore·JSON 배열 필드 → 방 ID 리스트
  static List<int> parseIdList(dynamic v) {
    if (v is! List) return const [];
    return v.map((e) => e is num ? e.toInt() : int.tryParse('$e')).whereType<int>().toList();
  }

  static UserModel? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final name = json['name'] as String? ?? '';
    if (name.trim().isEmpty) return null;
    final roleResolved = normalizeRoleFromDoc(json);
    return UserModel(
      name: name.trim(),
      phone: json['phone'] as String? ?? '',
      company: json['company'] as String? ?? '',
      car: json['car'] as String? ?? '',
      role: roleResolved,
      firebaseUid: json['firebaseUid'] as String?,
      mutedRooms: parseIdList(json['mutedRooms']),
      pinnedRoomIds: parseIdList(json['pinnedRoomIds']),
    );
  }
}
