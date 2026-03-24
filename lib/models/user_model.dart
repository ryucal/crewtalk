class UserModel {
  final String name;
  final String phone;
  final String company;
  final String car;
  final bool isAdmin;

  const UserModel({
    required this.name,
    required this.phone,
    required this.company,
    this.car = '',
    this.isAdmin = false,
  });

  String get avatar => name.isNotEmpty ? name[0] : '?';

  UserModel copyWith({
    String? name,
    String? phone,
    String? company,
    String? car,
    bool? isAdmin,
  }) {
    return UserModel(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      company: company ?? this.company,
      car: car ?? this.car,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
}
