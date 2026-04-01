class EmergencyContact {
  final String id;
  final String category;
  final String name;
  final String phone;
  final int order;

  const EmergencyContact({
    required this.id,
    required this.category,
    required this.name,
    required this.phone,
    this.order = 0,
  });

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      id: '${map['id'] ?? ''}',
      category: '${map['category'] ?? ''}',
      name: '${map['name'] ?? ''}',
      phone: '${map['phone'] ?? ''}',
      order: (map['order'] is int) ? map['order'] as int : 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'category': category,
        'name': name,
        'phone': phone,
        'order': order,
      };

  EmergencyContact copyWith({
    String? id,
    String? category,
    String? name,
    String? phone,
    int? order,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      category: category ?? this.category,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      order: order ?? this.order,
    );
  }
}
