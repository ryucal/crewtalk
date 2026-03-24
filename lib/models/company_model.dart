class CompanyModel {
  final String name;
  final String password;

  const CompanyModel({required this.name, required this.password});

  CompanyModel copyWith({String? name, String? password}) {
    return CompanyModel(
      name: name ?? this.name,
      password: password ?? this.password,
    );
  }
}
