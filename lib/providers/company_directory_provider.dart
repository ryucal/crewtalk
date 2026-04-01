import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/company_model.dart';
import '../services/auth_repository.dart';
import '../utils/sample_data.dart';

const String kHiddenCompanyPasswordLabel = '••••••••';

/// 로그인·회원가입 소속 이름 드롭다운용.
/// `config/companies.items[]` 배열에서 직접 소속 이름만 추출한다.
/// Firestore rules에서 `config/companies` 문서는 인증 없이 읽기 허용되어 있다.
final companyNamesForAuthProvider = StreamProvider<List<String>>((ref) async* {
  if (!AuthRepository.firebaseAvailable) {
    yield sampleCompanies.map((c) => c.name).toList();
    return;
  }

  await for (final snap in FirebaseFirestore.instance
      .collection('config')
      .doc('companies')
      .snapshots()) {
    final items = snap.data()?['items'];
    if (items is! List || items.isEmpty) {
      yield <String>[];
      continue;
    }
    final names = <String>[];
    for (final e in items) {
      if (e is! Map) continue;
      final name = '${e['name'] ?? ''}'.trim();
      if (name.isNotEmpty) names.add(name);
    }
    names.sort();
    yield names;
  }
});

List<CompanyModel> _parseConfigItems(dynamic raw) {
  if (raw is! List || raw.isEmpty) return [];
  final out = <CompanyModel>[];
  for (final e in raw) {
    if (e is! Map) continue;
    final name = '${e['name'] ?? ''}'.trim();
    if (name.isEmpty) continue;
    final stored = '${e['password'] ?? ''}';
    final display = stored.startsWith('sha256:')
        ? kHiddenCompanyPasswordLabel
        : (stored.isEmpty ? kHiddenCompanyPasswordLabel : stored);
    out.add(CompanyModel(name: name, password: display));
  }
  out.sort((a, b) => a.name.compareTo(b.name));
  return out;
}

/// 소속 관리 화면용 (인증 후에만 사용).
/// `config/companies.items` 를 실시간 구독. 비어 있으면 `company_profiles` 폴백.
final companyListProvider = StreamProvider<List<CompanyModel>>((ref) async* {
  if (!AuthRepository.firebaseAvailable) {
    yield sampleCompanies;
    return;
  }

  await for (final snap in FirebaseFirestore.instance
      .collection('config')
      .doc('companies')
      .snapshots()) {
    final list = _parseConfigItems(snap.data()?['items']);
    if (list.isNotEmpty) {
      yield list;
    } else {
      final profileSnap = await FirebaseFirestore.instance
          .collection('company_profiles')
          .get();
      if (profileSnap.docs.isNotEmpty) {
        final fromProfiles = profileSnap.docs
            .map((d) =>
                CompanyModel(name: d.id, password: kHiddenCompanyPasswordLabel))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        yield fromProfiles;
      } else {
        yield sampleCompanies;
      }
    }
  }
});
