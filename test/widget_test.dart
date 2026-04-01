import 'package:flutter_test/flutter_test.dart';

import 'package:crewtalk/models/user_model.dart';

void main() {
  group('UserModel', () {
    test('fromJson/toJson round-trip preserves fields', () {
      final user = UserModel(
        name: '홍길동',
        phone: '010-1234-5678',
        company: '크루',
        firebaseUid: 'uid_123',
      );

      final json = user.toJson();
      final restored = UserModel.fromJson(json);

      expect(restored, isNotNull);
      expect(restored!.name, equals('홍길동'));
      expect(restored.phone, equals('010-1234-5678'));
      expect(restored.company, equals('크루'));
      expect(restored.firebaseUid, equals('uid_123'));
    });

    test('fromJson returns null for empty name', () {
      final result = UserModel.fromJson({'name': '', 'phone': '010', 'company': 'x'});
      expect(result, isNull);
    });

    test('default role is driver', () {
      final user = UserModel(name: '테스트', phone: '010-0000-0000', company: '크루');
      expect(user.normalizedRole, equals(UserModel.roleDriver));
    });

    test('normalizedRole handles case variations', () {
      final superAdmin = UserModel(
        name: '관리자', phone: '010-0000-0000', company: '관리자',
        role: 'SuperAdmin',
      );
      expect(superAdmin.normalizedRole, equals(UserModel.roleSuperAdmin));

      final manager = UserModel(
        name: '매니저', phone: '010-0000-0000', company: '크루',
        role: 'Manager',
      );
      expect(manager.normalizedRole, equals(UserModel.roleManager));
    });
  });
}
