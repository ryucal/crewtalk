import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/sample_data.dart';

/// 회원가입·로그인 소속 드롭다운용 이름 목록.
/// Firebase + `company_profiles`가 있으면 그걸 쓰고, 비어 있거나 미초기화면 샘플 소속 이름을 씁니다.
final companyNamesForAuthProvider = StreamProvider<List<String>>((ref) async* {
  if (Firebase.apps.isEmpty) {
    yield sampleCompanies.map((c) => c.name).toList();
    return;
  }

  await for (final snap
      in FirebaseFirestore.instance.collection('company_profiles').snapshots()) {
    final names = snap.docs.map((d) => d.id).toList()..sort();
    if (names.isEmpty) {
      yield sampleCompanies.map((c) => c.name).toList();
    } else {
      yield names;
    }
  }
});
