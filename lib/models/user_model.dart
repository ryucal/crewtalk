class UserModel {
  final String name;
  final String phone;
  final String company;
  final String car;
  final bool isAdmin;
  /// Firebase Auth UID (레거시 관리자 로그인 등에는 null)
  final String? firebaseUid;

  const UserModel({
    required this.name,
    required this.phone,
    required this.company,
    this.car = '',
    this.isAdmin = false,
    this.firebaseUid,
  });

  String get avatar => name.isNotEmpty ? name[0] : '?';

  UserModel copyWith({
    String? name,
    String? phone,
    String? company,
    String? car,
    bool? isAdmin,
    String? firebaseUid,
  }) {
    return UserModel(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      company: company ?? this.company,
      car: car ?? this.car,
      isAdmin: isAdmin ?? this.isAdmin,
      firebaseUid: firebaseUid ?? this.firebaseUid,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'company': company,
        'car': car,
        'isAdmin': isAdmin,
        'firebaseUid': firebaseUid,
      };

  static UserModel? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final name = json['name'] as String? ?? '';
    if (name.trim().isEmpty) return null;
    return UserModel(
      name: name.trim(),
      phone: json['phone'] as String? ?? '',
      company: json['company'] as String? ?? '',
      car: json['car'] as String? ?? '',
      isAdmin: json['isAdmin'] as bool? ?? false,
      firebaseUid: json['firebaseUid'] as String?,
    );
  }
}
