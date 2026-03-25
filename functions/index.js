const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();

/**
 * 로그인 2차: 소속 공용 비밀번호 검증 (클라이언트는 company_private 읽기 불가)
 */
exports.verifyCompanyPassword = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', '로그인이 필요해요');
  }
  const companyName = (data.companyName || '').trim();
  const password = (data.password || '').toString();
  if (!companyName || !password) {
    throw new functions.https.HttpsError('invalid-argument', '소속과 비밀번호를 입력해주세요');
  }
  const snap = await db.collection('company_private').doc(companyName).get();
  if (!snap.exists || snap.data().password !== password) {
    throw new functions.https.HttpsError(
      'permission-denied',
      '소속 비밀번호가 올바르지 않아요',
    );
  }
  return { ok: true };
});

/**
 * Firestore users/{uid}.isAdmin == true 인 계정만 호출 가능
 */
exports.adminUpsertCompany = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', '로그인이 필요해요');
  }
  const uid = context.auth.uid;
  const userSnap = await db.collection('users').doc(uid).get();
  if (!userSnap.exists || userSnap.data().isAdmin !== true) {
    throw new functions.https.HttpsError('permission-denied', '관리자만 등록할 수 있어요');
  }
  const name = (data.name || '').trim();
  const password = (data.password || '').toString();
  if (!name || !password) {
    throw new functions.https.HttpsError('invalid-argument', '소속명과 비밀번호가 필요해요');
  }
  const batch = db.batch();
  const profileRef = db.collection('company_profiles').doc(name);
  const privRef = db.collection('company_private').doc(name);
  batch.set(
    profileRef,
    {
      name,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  batch.set(
    privRef,
    {
      password,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  await batch.commit();
  return { ok: true };
});

exports.adminDeleteCompany = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', '로그인이 필요해요');
  }
  const uid = context.auth.uid;
  const userSnap = await db.collection('users').doc(uid).get();
  if (!userSnap.exists || userSnap.data().isAdmin !== true) {
    throw new functions.https.HttpsError('permission-denied', '관리자만 삭제할 수 있어요');
  }
  const name = (data.name || '').trim();
  if (!name) {
    throw new functions.https.HttpsError('invalid-argument', '소속명이 필요해요');
  }
  const batch = db.batch();
  batch.delete(db.collection('company_profiles').doc(name));
  batch.delete(db.collection('company_private').doc(name));
  await batch.commit();
  return { ok: true };
});
