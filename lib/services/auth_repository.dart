import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/user_model.dart';
import '../utils/phone_auth_utils.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

/// Firebase Auth + Firestore + Callable(소속 검증)
class AuthRepository {
  AuthRepository._();

  static bool get firebaseAvailable => Firebase.apps.isNotEmpty;

  static String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return '이미 가입된 전화번호예요. 로그인해 주세요.';
      case 'invalid-email':
        return '전화번호 형식을 확인해주세요.';
      case 'weak-password':
        return '비밀번호가 너무 짧아요. 6자 이상으로 설정해주세요.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return '전화번호 또는 개인 비밀번호가 올바르지 않아요.';
      case 'too-many-requests':
        return '잠시 후 다시 시도해주세요.';
      default:
        return e.message ?? '로그인에 실패했어요 (${e.code})';
    }
  }

  static Future<UserModel> signUpDriver({
    required String name,
    required String phoneFormatted,
    required String company,
    required String personalPassword,
  }) async {
    final digits = PhoneAuthUtils.digitsOnly(phoneFormatted);
    if (!PhoneAuthUtils.isValidKoreanMobileDigits(digits)) {
      throw AuthException('전화번호를 올바르게 입력해주세요');
    }
    final email = PhoneAuthUtils.syntheticEmailFromDigits(digits);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: personalPassword,
      );
      final uid = cred.user!.uid;
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'name': name.trim(),
          'phoneDigits': digits,
          'company': company,
          'car': '',
          'isAdmin': false,
          'role': 'driver',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        await cred.user?.delete();
        rethrow;
      }
      return UserModel(
        name: name.trim(),
        phone: PhoneAuthUtils.formatDisplay(digits),
        company: company,
        role: UserModel.roleDriver,
        firebaseUid: uid,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_authErrorMessage(e));
    }
  }

  /// 1) 이메일/비번 로그인 2) Callable로 소속 비번 검증 3) 프로필 소속 일치 확인
  static Future<UserModel> signInDriver({
    required String phoneFormatted,
    required String personalPassword,
    required String company,
    required String companyPassword,
  }) async {
    final digits = PhoneAuthUtils.digitsOnly(phoneFormatted);
    if (!PhoneAuthUtils.isValidKoreanMobileDigits(digits)) {
      throw AuthException('전화번호를 올바르게 입력해주세요');
    }
    final email = PhoneAuthUtils.syntheticEmailFromDigits(digits);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: personalPassword,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_authErrorMessage(e));
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw AuthException('로그인에 실패했어요');
    }

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('verifyCompanyPassword');
      await callable.call<Map<String, dynamic>>({
        'companyName': company,
        'password': companyPassword,
      });
    } on FirebaseFunctionsException catch (e) {
      await FirebaseAuth.instance.signOut();
      if (e.code == 'permission-denied' || e.code == 'failed-precondition') {
        throw AuthException(e.message ?? '소속 정보가 올바르지 않아요');
      }
      throw AuthException(e.message ?? '소속 확인에 실패했어요');
    } catch (e) {
      await FirebaseAuth.instance.signOut();
      if (e is AuthException) rethrow;
      throw AuthException('소속 확인에 실패했어요');
    }

    final snap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!snap.exists) {
      await FirebaseAuth.instance.signOut();
      throw AuthException('프로필을 찾을 수 없어요. 회원가입을 진행해주세요.');
    }
    final d = snap.data()!;
    if ((d['company'] as String? ?? '') != company) {
      await FirebaseAuth.instance.signOut();
      throw AuthException('가입 시 등록한 소속과 일치하지 않아요.');
    }

    final roleResolved = UserModel.normalizeRoleFromDoc(d);
    return UserModel(
      name: (d['name'] as String?) ?? '',
      phone: PhoneAuthUtils.formatDisplay(
        (d['phoneDigits'] as String?) ?? digits,
      ),
      company: company,
      car: (d['car'] as String?) ?? '',
      role: roleResolved,
      firebaseUid: uid,
      mutedRooms: UserModel.parseIdList(d['mutedRooms']),
      pinnedRoomIds: UserModel.parseIdList(d['pinnedRoomIds']),
    );
  }

  static Future<void> signOutFirebase() async {
    if (!firebaseAvailable) return;
    await FirebaseAuth.instance.signOut();
  }

  /// Firestore `users/{uid}` 기준으로 [UserModel] 복원 (앱 cold start).
  /// Firebase Auth 세션이 유효하지 않으면 sign out 후 null 반환.
  static Future<UserModel?> loadSessionUser() async {
    if (!firebaseAvailable) return null;
    final cu = FirebaseAuth.instance.currentUser;
    if (cu == null) return null;

    try {
      await cu.reload();
    } catch (_) {
      await FirebaseAuth.instance.signOut();
      return null;
    }

    final refreshed = FirebaseAuth.instance.currentUser;
    if (refreshed == null) return null;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(refreshed.uid)
        .get();
    if (!snap.exists) return null;
    final d = snap.data()!;
    final digits = (d['phoneDigits'] as String?) ?? '';
    final roleResolved = UserModel.normalizeRoleFromDoc(d);
    return UserModel(
      name: (d['name'] as String?) ?? '',
      phone: PhoneAuthUtils.formatDisplay(digits),
      company: (d['company'] as String?) ?? '',
      car: (d['car'] as String?) ?? '',
      role: roleResolved,
      firebaseUid: refreshed.uid,
      mutedRooms: UserModel.parseIdList(d['mutedRooms']),
      pinnedRoomIds: UserModel.parseIdList(d['pinnedRoomIds']),
    );
  }

  /// 관리자 전용: 소속 프로필 + 비밀번호 저장 (Cloud Function)
  static Future<void> adminUpsertCompany({
    required String name,
    required String password,
  }) async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('adminUpsertCompany');
    await callable.call<Map<String, dynamic>>({
      'name': name.trim(),
      'password': password,
    });
  }

  /// 관리자 전용: 소속 삭제
  static Future<void> adminDeleteCompany({required String name}) async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('adminDeleteCompany');
    await callable.call<Map<String, dynamic>>({'name': name.trim()});
  }

  /// 관리자 전용: config/companies.items → company_profiles 동기화 (로그인·가입 드롭다운용)
  static Future<int> adminSyncCompanyProfiles() async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('adminSyncCompanyProfiles');
    final res = await callable.call<Map<String, dynamic>>({});
    final data = res.data;
    final n = data['syncedCount'];
    if (n is int) return n;
    if (n is num) return n.toInt();
    return 0;
  }
}
