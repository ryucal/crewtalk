const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated, onDocumentWritten } = require('firebase-functions/v2/firestore');
const { logger } = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();

const db = admin.firestore();

const PASSWORD_HASH_PREFIX = 'sha256:';

/**
 * 비밀번호를 SHA-256으로 해시한다.
 * @param {string} plain 평문 비밀번호
 * @returns {string} "sha256:{hex}" 형태의 해시 문자열
 */
function hashPassword(plain) {
  return PASSWORD_HASH_PREFIX + crypto.createHash('sha256').update(plain).digest('hex');
}

/**
 * 입력된 평문 비밀번호가 저장된 값과 일치하는지 검증한다.
 * 저장값이 "sha256:" 접두사를 가지면 해시 비교, 아니면 평문 비교 (하위 호환).
 * @param {string} plain 사용자가 입력한 평문 비밀번호
 * @param {string} stored Firestore에 저장된 값
 * @returns {boolean}
 */
function verifyPassword(plain, stored) {
  if (stored.startsWith(PASSWORD_HASH_PREFIX)) {
    return hashPassword(plain) === stored;
  }
  // 하위 호환: 아직 마이그레이션 전인 평문 비밀번호
  return plain === stored;
}

async function writeAuditLog(action, uid, details) {
  try {
    await db.collection('audit_logs').add({
      action,
      uid,
      details: details || {},
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (e) {
    logger.error('audit log write failed', { action, uid, error: e.message });
  }
}

// 비밀번호 실패 rate limiting 설정
const RATE_LIMIT_MAX_ATTEMPTS = 10;    // 허용 실패 횟수
const RATE_LIMIT_WINDOW_MS = 10 * 60 * 1000; // 10분 윈도우

/**
 * 로그인 2차: 소속 공용 비밀번호 검증 (클라이언트는 company_private 읽기 불가)
 * - UID당 10분 내 10회 이상 실패 시 일시 차단
 */
exports.verifyCompanyPassword = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', '로그인이 필요해요');
  }
  const uid = request.auth.uid;
  const companyName = (request.data.companyName || '').trim();
  const password = (request.data.password || '').toString();
  if (!companyName || !password) {
    throw new HttpsError('invalid-argument', '소속과 비밀번호를 입력해주세요');
  }

  // Rate limiting: auth_attempts/{uid} 문서로 실패 횟수 추적
  const attemptRef = db.collection('auth_attempts').doc(uid);
  const now = Date.now();
  const attemptSnap = await attemptRef.get();
  if (attemptSnap.exists) {
    const d = attemptSnap.data();
    const windowStart = d.windowStart || 0;
    const count = d.count || 0;
    if (now - windowStart < RATE_LIMIT_WINDOW_MS && count >= RATE_LIMIT_MAX_ATTEMPTS) {
      const remainSec = Math.ceil((RATE_LIMIT_WINDOW_MS - (now - windowStart)) / 1000);
      throw new HttpsError(
        'resource-exhausted',
        `시도 횟수를 초과했어요. ${remainSec}초 후 다시 시도해주세요.`,
      );
    }
  }

  // config/companies.items[] 에서 소속 비번 검증
  const companiesSnap = await db.collection('config').doc('companies').get();
  const items = (companiesSnap.exists && Array.isArray(companiesSnap.data().items))
    ? companiesSnap.data().items
    : [];
  const matched = items.find(
    (it) => String(it.name || '').trim() === companyName && verifyPassword(password, String(it.password || '')),
  );

  if (!matched) {
    // 실패: 카운터 증가
    const d = attemptSnap.exists ? attemptSnap.data() : {};
    const windowStart = d.windowStart || 0;
    const isNewWindow = now - windowStart >= RATE_LIMIT_WINDOW_MS;
    await attemptRef.set({
      windowStart: isNewWindow ? now : windowStart,
      count: isNewWindow ? 1 : (d.count || 0) + 1,
      lastFailAt: now,
    });
    throw new HttpsError('permission-denied', '소속 비밀번호가 올바르지 않아요');
  }

  // 성공 시 카운터 초기화
  if (attemptSnap.exists) {
    await attemptRef.delete();
  }
  return { ok: true };
});

/**
 * isAdmin == true 또는 role == 'superadmin' 계정만 호출 가능
 */
function isAdminUser(userData) {
  if (!userData) return false;
  if (userData.isAdmin === true) return true;
  const role = (userData.role || '').toString().toLowerCase().trim();
  return role === 'superadmin';
}

/**
 * config/companies.items[]의 name마다 company_profiles/{name}을 merge.
 * 앱 로그인·회원가입은 인증 전이라 config/companies를 읽지 못하고,
 * 공개 읽기 허용인 company_profiles만 소속 이름 목록으로 사용함.
 * @returns {Promise<number>} 동기화한 소속 개수
 */
async function syncCompanyProfilesFromConfigItems() {
  const companiesSnap = await db.collection('config').doc('companies').get();
  const items = (companiesSnap.exists && Array.isArray(companiesSnap.data().items))
    ? companiesSnap.data().items
    : [];

  const names = [];
  for (const it of items) {
    const name = String(it.name || '').trim();
    if (name) names.push(name);
  }

  for (let i = 0; i < names.length; i += 450) {
    const chunk = names.slice(i, i + 450);
    const batch = db.batch();
    for (const name of chunk) {
      batch.set(
        db.collection('company_profiles').doc(name),
        { name, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
        { merge: true },
      );
    }
    await batch.commit();
  }
  logger.info('syncCompanyProfilesFromConfigItems', { count: names.length });
  return names.length;
}

exports.onConfigCompaniesWritten = onDocumentWritten(
  'config/companies',
  async (event) => {
    if (!event.data.after.exists) return null;
    try {
      await syncCompanyProfilesFromConfigItems();
    } catch (e) {
      logger.error('onConfigCompaniesWritten sync failed', e);
    }
    return null;
  },
);

exports.adminSyncCompanyProfiles = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', '로그인이 필요해요');
  }
  const uid = request.auth.uid;
  const userSnap = await db.collection('users').doc(uid).get();
  if (!userSnap.exists || !isAdminUser(userSnap.data())) {
    throw new HttpsError('permission-denied', '관리자만 동기화할 수 있어요');
  }
  const count = await syncCompanyProfilesFromConfigItems();
  await writeAuditLog('company_profiles_sync', uid, { syncedCount: count });
  return { ok: true, syncedCount: count };
});

exports.adminUpsertCompany = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', '로그인이 필요해요');
  }
  const uid = request.auth.uid;
  const userSnap = await db.collection('users').doc(uid).get();
  if (!userSnap.exists || !isAdminUser(userSnap.data())) {
    throw new HttpsError('permission-denied', '관리자만 등록할 수 있어요');
  }
  const name = (request.data.name || '').trim();
  const password = (request.data.password || '').toString();
  if (!name || !password) {
    throw new HttpsError('invalid-argument', '소속명과 비밀번호가 필요해요');
  }
  const hashedPassword = hashPassword(password);

  // config/companies.items[] 배열 갱신 (verifyCompanyPassword가 읽는 위치)
  const companiesRef = db.collection('config').doc('companies');
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(companiesRef);
    const items = (snap.exists && Array.isArray(snap.data().items))
      ? snap.data().items
      : [];
    const idx = items.findIndex((it) => String(it.name || '').trim() === name);
    if (idx >= 0) {
      items[idx] = { ...items[idx], name, password: hashedPassword };
    } else {
      items.push({ name, password: hashedPassword });
    }
    tx.set(companiesRef, { items }, { merge: true });
  });

  const batch = db.batch();
  const profileRef = db.collection('company_profiles').doc(name);
  const privRef = db.collection('company_private').doc(name);
  batch.set(
    profileRef,
    { name, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true },
  );
  batch.set(
    privRef,
    { password: hashedPassword, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true },
  );
  await batch.commit();
  await writeAuditLog('company_upsert', uid, { companyName: name });
  return { ok: true };
});

exports.adminDeleteCompany = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', '로그인이 필요해요');
  }
  const uid = request.auth.uid;
  const userSnap = await db.collection('users').doc(uid).get();
  if (!userSnap.exists || !isAdminUser(userSnap.data())) {
    throw new HttpsError('permission-denied', '관리자만 삭제할 수 있어요');
  }
  const name = (request.data.name || '').trim();
  if (!name) {
    throw new HttpsError('invalid-argument', '소속명이 필요해요');
  }
  // verifyCompanyPassword / 앱 목록이 읽는 config/companies.items 에서도 제거
  const companiesRef = db.collection('config').doc('companies');
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(companiesRef);
    const items = (snap.exists && Array.isArray(snap.data().items))
      ? snap.data().items
      : [];
    const filtered = items.filter((it) => String(it.name || '').trim() !== name);
    tx.set(companiesRef, { items: filtered }, { merge: true });
  });
  const batch = db.batch();
  batch.delete(db.collection('company_profiles').doc(name));
  batch.delete(db.collection('company_private').doc(name));
  await batch.commit();
  await writeAuditLog('company_delete', uid, { companyName: name });
  return { ok: true };
});

const STAFF_ROLES_FOR_EMERGENCY_PUSH = ['manager', 'superadmin', 'superAdmin'];

const UNREGISTERED_ERROR_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

async function removeStaleTokens(multicastResponse, tokens) {
  const staleByUid = new Map();
  multicastResponse.responses.forEach((resp, idx) => {
    if (!resp.success && resp.error && UNREGISTERED_ERROR_CODES.has(resp.error.code)) {
      const token = tokens[idx];
      if (token) {
        if (!staleByUid.has(token)) staleByUid.set(token, token);
      }
    }
  });
  if (staleByUid.size === 0) return 0;

  const staleTokens = [...staleByUid.values()];
  const usersSnap = await db.collection('users')
    .where('fcmTokens', 'array-contains-any', staleTokens.slice(0, 10))
    .get();

  const batch = db.batch();
  let cleaned = 0;
  usersSnap.forEach((doc) => {
    const arr = doc.data().fcmTokens;
    if (!Array.isArray(arr)) return;
    const toRemove = arr.filter((t) => staleTokens.includes(t));
    if (toRemove.length > 0) {
      batch.update(doc.ref, { fcmTokens: admin.firestore.FieldValue.arrayRemove(...toRemove) });
      cleaned += toRemove.length;
    }
  });
  if (cleaned > 0) {
    try {
      await batch.commit();
      logger.info('FCM stale tokens removed', { count: cleaned });
    } catch (e) {
      logger.error('FCM stale token cleanup failed', e);
    }
  }
  return cleaned;
}

function shouldExcludeSenderFromPush(uid, userData, senderUserId) {
  if (!senderUserId || typeof senderUserId !== 'string') return false;
  if (uid === senderUserId) return true;
  if (senderUserId.startsWith('phone_')) {
    const digits = senderUserId.replace(/^phone_/, '');
    if (userData && userData.phoneDigits === digits) return true;
  }
  return false;
}

function chatMessageBodyPreview(d) {
  const name = (d.name || '알 수 없음').toString();
  const t = (d.type || 'text').toString();
  if (t === 'image') return `${name}: 📷 사진`;
  if (t === 'report') {
    const rd = d.reportData;
    if (rd && rd.type && rd.count != null) {
      return `${name}: ${rd.type} ${rd.count}명`;
    }
    return `${name}: 인원보고`;
  }
  if (t === 'vendorReport') return `${name}: 솔라티 보고`;
  if (t === 'emergency') return `${name}: 긴급 호출`;
  if (t === 'notice') return `${name}: ${(d.text || '공지').toString()}`.slice(0, 180);
  const tx = (d.text || '').toString().trim();
  if (tx) return `${name}: ${tx}`.slice(0, 200);
  return `${name}: 새 메시지`;
}

async function collectFcmTokensForCompanies(companyNames, senderUserId, roomId) {
  const tokenSet = new Set();
  const roomNum = Number(roomId);
  const unique = [...new Set((companyNames || []).map((c) => String(c).trim()).filter(Boolean))];
  for (let i = 0; i < unique.length; i += 10) {
    const chunk = unique.slice(i, i + 10);
    let qs;
    try {
      qs = await db.collection('users').where('company', 'in', chunk).get();
    } catch (e) {
      logger.error('chat FCM: user query failed', e);
      continue;
    }
    qs.forEach((doc) => {
      const data = doc.data();
      if (shouldExcludeSenderFromPush(doc.id, data, senderUserId)) return;
      const muted = data.mutedRooms;
      if (Array.isArray(muted) && muted.includes(roomNum)) return;
      const arr = data.fcmTokens;
      if (!Array.isArray(arr)) return;
      arr.forEach((t) => {
        if (typeof t === 'string' && t.length > 0) tokenSet.add(t);
      });
    });
  }
  return [...tokenSet];
}

/**
 * 메시지 생성 시:
 * 1) rooms/{roomId}.lastMessage 갱신 (denormalization)
 * 2) FCM 발송
 *    - emergency → 매니저·슈퍼
 *    - 그 외 → 해당 방 `companies` 소속 사용자(발신자 제외)
 */
exports.onEmergencyMessageCreated = onDocumentCreated(
  'rooms/{roomId}/messages/{messageId}',
  async (event) => {
    const snap = event.data;
    if (!snap) return null;
    const d = snap.data();
    if (!d) return null;
    const roomId = event.params.roomId;
    const senderUserId = (d.userId || '').toString();

    // ── 1) lastMessage 갱신 ──
    const idStr = String(roomId);
    if (idStr !== '998' && idStr !== '999') {
      const preview = chatMessageBodyPreview(d).replace(/^[^:]+:\s*/, '');
      try {
        await db.collection('rooms').doc(idStr).update({
          lastMessage: {
            text: preview.slice(0, 200),
            type: (d.type || 'text').toString(),
            senderName: (d.name || '').toString(),
            time: (d.time || '').toString(),
            createdAt: d.createdAt || admin.firestore.FieldValue.serverTimestamp(),
          },
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (e) {
        logger.error('lastMessage update failed', { roomId: idStr, error: e.message });
      }
    }

    // ── 2) FCM: 긴급 메시지 ──
    if (d.type === 'emergency') {
      logger.info('emergency message created, sending FCM', {
        roomId,
        messageId: event.params.messageId,
      });
      await writeAuditLog('emergency_message', senderUserId, {
        roomId,
        messageId: event.params.messageId,
        emergencyType: (d.emergencyType || '').toString(),
      });

      let staffSnap;
      try {
        staffSnap = await db
          .collection('users')
          .where('role', 'in', STAFF_ROLES_FOR_EMERGENCY_PUSH)
          .get();
      } catch (e) {
        logger.error('emergency FCM: staff query failed', e);
        return null;
      }

      const tokenSet = new Set();
      staffSnap.forEach((doc) => {
        const data = doc.data();
        if (shouldExcludeSenderFromPush(doc.id, data, senderUserId)) return;
        const arr = data.fcmTokens;
        if (!Array.isArray(arr)) return;
        arr.forEach((t) => {
          if (typeof t === 'string' && t.length > 0) tokenSet.add(t);
        });
      });

      const tokens = [...tokenSet];
      if (tokens.length === 0) {
        logger.info('emergency FCM: no tokens');
        return null;
      }

      const route = (d.route || '').toString();
      const name = (d.name || '').toString();
      const emergencyType = (d.emergencyType || '긴급 호출').toString();
      const body = [route, name, emergencyType].filter(Boolean).join(' · ') || '긴급 호출이 접수되었습니다.';

      const messaging = admin.messaging();
      const batchSize = 500;
      let success = 0;
      let failure = 0;

      for (let i = 0; i < tokens.length; i += batchSize) {
        const chunk = tokens.slice(i, i + batchSize);
        try {
          const res = await messaging.sendEachForMulticast({
            tokens: chunk,
            notification: { title: '🚨 긴급', body },
            // data 키 `route` 는 Android/Flutter 가 앱 초기 경로로 오인할 수 있어 `routeLabel` 사용
            data: {
              type: 'emergency',
              roomId: String(roomId),
              routeLabel: route,
              name,
              emergencyType,
            },
            android: {
              priority: 'high',
              notification: { channelId: 'crewtalk_emergency' },
            },
            apns: {
              payload: { aps: { sound: 'default', badge: 1, 'content-available': 1 } },
              headers: { 'apns-priority': '10' },
            },
          });
          success += res.successCount;
          failure += res.failureCount;
          if (res.failureCount > 0) {
            removeStaleTokens(res, chunk).catch((e) =>
              logger.error('emergency FCM: stale cleanup error', e));
          }
        } catch (e) {
          logger.error('emergency FCM: sendEachForMulticast failed', e);
        }
      }

      logger.info('emergency FCM done', { success, failure, tokenCount: tokens.length });
      return null;
    }

    // ── 3) FCM: 일반 채팅 (998·999 제외) ──
    if (idStr === '998' || idStr === '999') return null;

    let companies = [];
    let roomTitle = 'CREW TALK';
    try {
      const roomSnap = await db.collection('rooms').doc(idStr).get();
      if (roomSnap.exists) {
        const roomData = roomSnap.data();
        companies = Array.isArray(roomData.companies) ? roomData.companies.map((x) => String(x)) : [];
        roomTitle = (roomData.name && String(roomData.name).trim()) || roomTitle;
      }
    } catch (e) {
      logger.error('chat FCM: rooms doc read failed', e);
      return null;
    }

    if (companies.length === 0) {
      logger.info('chat FCM: skip — room has no companies', { roomId: idStr });
      return null;
    }

    const tokens = await collectFcmTokensForCompanies(companies, senderUserId, idStr);
    if (tokens.length === 0) {
      logger.info('chat FCM: no tokens for companies', { roomId: idStr });
      return null;
    }

    const body = chatMessageBodyPreview(d);
    const messaging = admin.messaging();
    const batchSize = 500;
    let success = 0;
    let failure = 0;

    for (let i = 0; i < tokens.length; i += batchSize) {
      const chunk = tokens.slice(i, i + batchSize);
      try {
        const res = await messaging.sendEachForMulticast({
          tokens: chunk,
          notification: { title: roomTitle, body },
          data: { type: 'chat', roomId: idStr, msgType: String(d.type || 'text') },
          android: {
            priority: 'high',
            notification: { channelId: 'crewtalk_messages' },
          },
          apns: {
            payload: { aps: { sound: 'default', badge: 1, 'content-available': 1 } },
            headers: { 'apns-priority': '10' },
          },
        });
        success += res.successCount;
        failure += res.failureCount;
        if (res.failureCount > 0) {
          removeStaleTokens(res, chunk).catch((e) =>
            logger.error('chat FCM: stale cleanup error', e));
        }
      } catch (e) {
        logger.error('chat FCM: sendEachForMulticast failed', e);
      }
    }

    logger.info('chat FCM done', { roomId: idStr, success, failure, tokenCount: tokens.length });
    return null;
  },
);
