import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/calendar_item.dart';
import '../models/emergency_contact.dart';
import '../models/message_model.dart';
import '../models/room_model.dart';
import '../models/room_kakao_nav_link.dart';
import '../models/global_timetable_visibility.dart';
import 'auth_repository.dart';
import 'message_firestore_codec.dart';

/// 채팅방 메타: `rooms/{roomId}` 개별 문서.
/// 메시지: `rooms/{roomId}/messages/{msgId}` 서브컬렉션.
/// 읽음 상태: `rooms/{roomId}/readState/{uid}` 서브컬렉션.
class ChatFirestoreRepository {
  ChatFirestoreRepository._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _rooms =>
      _db.collection('rooms');

  /// 방별 카카오맵 공유 링크: `config/kakao_nav_links` → `rooms.{roomId}` 배열 (쓰기: 슈퍼만 rules)
  static DocumentReference<Map<String, dynamic>> get _kakaoNavConfig =>
      _db.collection('config').doc('kakao_nav_links');

  /// 전체 방 공통 배차표 슬롯 노출 예약: `config/timetable_visibility` (쓰기: isElevatedAdmin)
  static DocumentReference<Map<String, dynamic>> get _timetableVisibilityConfig =>
      _db.collection('config').doc('timetable_visibility');

  static bool get _ok => AuthRepository.firebaseAvailable;

  /// 관리자가 수정 가능한 방 설정 필드만 반환 (lastMessage는 Cloud Function이 관리).
  static Map<String, Object?> roomToFirestoreFields(RoomModel r) {
    return {
      'name': r.name,
      'companies': r.companies,
      'subRoutes': r.subRoutes,
      'timetable1Images': r.timetable1Images,
      'timetable2Images': r.timetable2Images,
      'pinned': r.pinned,
      'adminOnly': r.adminOnly,
      'roomType': roomTypeToWire(r.roomType) ?? 'normal',
    };
  }

  static List<String> _stringListFromFirestore(dynamic v) {
    if (v is! List) return [];
    return v.map((e) => e.toString()).toList();
  }

  static String roomDocPathId(RoomModel room) {
    if (room.id == 998 || room.id == 999) {
      throw StateError('가상 방은 Firestore와 연결되지 않습니다');
    }
    return room.id.toString();
  }

  /// 방 문서 데이터를 [RoomModel]로 변환. [docId]는 문서 ID (정수 문자열).
  static RoomModel roomFromDoc(String docId, Map<String, dynamic> m) {
    final id = int.tryParse(docId) ?? (m['id'] as num?)?.toInt() ?? 0;
    final rtStr = m['roomType'] as String?;
    final rt = rtStr == 'vendor'
        ? RoomType.vendor
        : rtStr == 'maintenance'
            ? RoomType.maintenance
            : RoomType.normal;
    final companies =
        (m['companies'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final subRoutes =
        (m['subRoutes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final List<String> timetable1Images;
    final List<String> timetable2Images;
    if (m.containsKey('timetable1Images') || m.containsKey('timetable2Images')) {
      timetable1Images = _stringListFromFirestore(m['timetable1Images']);
      timetable2Images = _stringListFromFirestore(m['timetable2Images']);
    } else {
      final legacy = _stringListFromFirestore(m['timetableImages']);
      timetable1Images = legacy;
      timetable2Images = const [];
    }

    // lastMessage: Cloud Function이 갱신하는 denormalized 필드
    final lm = m['lastMessage'] as Map<String, dynamic>?;
    final lastMsg = lm?['text'] as String? ?? '';
    var lastTime = lm?['time'] as String? ?? '';
    if (lastTime.length >= 8 && lastTime.split(':').length == 3) {
      lastTime = lastTime.substring(0, 5);
    }

    return RoomModel(
      id: id,
      name: (m['name'] as String?)?.trim().isNotEmpty == true
          ? m['name'] as String
          : '채팅방 $id',
      lastMsg: lastMsg,
      time: lastTime,
      unread: 0,
      companies: companies,
      subRoutes: subRoutes,
      timetable1Images: timetable1Images,
      timetable2Images: timetable2Images,
      pinned: m['pinned'] as bool? ?? false,
      adminOnly: m['adminOnly'] as bool? ?? false,
      roomType: rt,
    );
  }

  /// `rooms` 컬렉션을 실시간 구독 (sortOrder 순 정렬)
  /// sortOrder 필드가 없는 문서도 포함하기 위해 클라이언트에서 정렬합니다.
  static Stream<List<RoomModel>> watchRooms() {
    if (!_ok) return const Stream.empty();
    return _rooms.snapshots().map((snap) {
      final withOrder = snap.docs.map((doc) {
        final data = doc.data();
        final order = (data['sortOrder'] as num?)?.toInt();
        return (room: roomFromDoc(doc.id, data), order: order);
      }).toList();
      withOrder.sort((a, b) {
        final ao = a.order ?? a.room.id;
        final bo = b.order ?? b.room.id;
        return ao.compareTo(bo);
      });
      return withOrder.map((e) => e.room).toList();
    });
  }

  static Map<int, List<RoomKakaoNavLink>> _kakaoNavMapFromData(Map<String, dynamic>? data) {
    if (data == null) return {};
    final raw = data['rooms'];
    if (raw is! Map) return {};
    final out = <int, List<RoomKakaoNavLink>>{};
    for (final e in raw.entries) {
      final id = int.tryParse(e.key.toString());
      if (id == null) continue;
      final list = e.value;
      if (list is! List) {
        out[id] = [];
        continue;
      }
      final links = <RoomKakaoNavLink>[];
      for (final item in list) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        final link = RoomKakaoNavLink.tryFromMap(m);
        if (link != null) links.add(link);
      }
      out[id] = links;
    }
    return out;
  }

  /// `config/kakao_nav_links` 실시간 구독 — 문서에 있는 방 id만 맵에 포함
  static Stream<Map<int, List<RoomKakaoNavLink>>> watchKakaoNavLinks() {
    if (!_ok) return const Stream.empty();
    return _kakaoNavConfig.snapshots().map((s) => _kakaoNavMapFromData(s.data()));
  }

  /// `config/timetable_visibility` 실시간 구독 — 날짜별 슬롯 노출 규칙
  static Stream<GlobalTimetableByDate> watchGlobalTimetableVisibility() {
    if (!_ok) return Stream.value({});
    return _timetableVisibilityConfig.snapshots().map(
          (s) => globalTimetableFromFirestore(s.data()),
        );
  }

  static final RegExp _timetableDateKeyRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// 한 날짜(KST `YYYY-MM-DD`)에 슬롯 노출 예약. 전체 채팅방에 적용됩니다.
  /// `update()`는 점 표기법을 중첩 필드 경로로 해석하므로 `byDate.{dateKey}`가 올바르게 갱신됩니다.
  /// 문서가 아직 없으면 `set()`으로 올바른 중첩 구조를 생성합니다.
  static Future<void> setGlobalTimetableDay(
    String dateKey, {
    required bool slot1Visible,
    required bool slot2Visible,
  }) async {
    if (!_ok) return;
    final payload = <String, dynamic>{
      'byDate.$dateKey': {
        'slot1': slot1Visible,
        'slot2': slot2Visible,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    };
    try {
      await _timetableVisibilityConfig.update(payload);
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        await _timetableVisibilityConfig.set({
          'byDate': {
            dateKey: {'slot1': slot1Visible, 'slot2': slot2Visible},
          },
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        rethrow;
      }
    }
  }

  /// 해당 날짜 규칙 삭제 → 그날은 기본(이미지 있으면 노출) 동작
  static Future<void> removeGlobalTimetableDay(String dateKey) async {
    if (!_ok) return;
    try {
      await _timetableVisibilityConfig.update({
        'byDate.$dateKey': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') return;
      if (kDebugMode) debugPrint('removeGlobalTimetableDay: ${e.code} ${e.message}');
      rethrow;
    }
  }

  /// [todayKstKey](`YYYY-MM-DD`, KST) **이전** 날짜 키를 `byDate`에서 제거합니다.
  static Future<void> prunePastGlobalTimetableDays(String todayKstKey) async {
    if (!_ok) return;
    try {
      final snap = await _timetableVisibilityConfig.get();
      final data = snap.data();
      if (data == null) return;
      final raw = data['byDate'];
      if (raw is! Map) return;
      final keysToRemove = <String>[];
      for (final e in raw.keys) {
        final ks = e.toString();
        if (_timetableDateKeyRe.hasMatch(ks) && ks.compareTo(todayKstKey) < 0) {
          keysToRemove.add(ks);
        }
      }
      if (keysToRemove.isEmpty) return;
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      for (final k in keysToRemove) {
        updates['byDate.$k'] = FieldValue.delete();
      }
      await _timetableVisibilityConfig.update(updates);
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') return;
      if (kDebugMode) debugPrint('prunePastGlobalTimetableDays: ${e.code} ${e.message}');
    }
  }

  /// 슈퍼관리자 전용 — 해당 방의 링크 목록 전체를 덮어씀
  static Future<void> saveKakaoNavLinksForRoom(int roomId, List<RoomKakaoNavLink> links) async {
    if (!_ok || roomId == 998 || roomId == 999) return;
    final key = roomId.toString();
    final value = links.map((e) => e.toMap()).toList();
    if (kDebugMode) debugPrint('[KakaoNav] saveKakaoNavLinksForRoom: roomId=$roomId, links.length=${links.length}');
    for (var i = 0; i < value.length; i++) {
      if (kDebugMode) debugPrint('[KakaoNav]   [$i] ${value[i]}');
    }
    final snap = await _kakaoNavConfig.get();
    final existing = Map<String, dynamic>.from(snap.data() ?? {});
    final rooms = Map<String, dynamic>.from((existing['rooms'] as Map?) ?? {});
    rooms[key] = value;
    if (kDebugMode) debugPrint('[KakaoNav] full rooms map keys: ${rooms.keys.toList()}, room $key has ${(rooms[key] as List).length} items');
    await _kakaoNavConfig.set({'rooms': rooms});
    if (kDebugMode) debugPrint('[KakaoNav] set() complete');
  }

  static Future<void> _removeKakaoNavRoomKey(int roomId) async {
    if (!_ok) return;
    try {
      await _kakaoNavConfig.update({'rooms.$roomId': FieldValue.delete()});
    } catch (e) {
      if (kDebugMode) debugPrint('removeKakaoNavRoomKey: $e');
    }
  }

  /// `lastReadAt` 이후 메시지 수를 COUNT 집계로 조회합니다 (문서 읽기 없음).
  static Future<int> getUnreadCount(String roomDocId, int lastReadAtMs) async {
    if (!_ok) return 0;
    try {
      final AggregateQuery query;
      if (lastReadAtMs <= 0) {
        query = _rooms.doc(roomDocId).collection('messages').count();
      } else {
        final after = Timestamp.fromMillisecondsSinceEpoch(lastReadAtMs);
        query = _rooms
            .doc(roomDocId)
            .collection('messages')
            .where('createdAt', isGreaterThan: after)
            .count();
      }
      final snap = await query.get();
      return snap.count ?? 0;
    } catch (e) {
      if (kDebugMode) debugPrint('getUnreadCount($roomDocId) error: $e');
      return 0;
    }
  }

  /// 방 1개의 최신 메시지 1건을 실시간 구독 (방 목록 lastMsg 갱신용)
  static Stream<Map<String, dynamic>?> watchLatestMessage(String roomDocId) {
    if (!_ok) return const Stream.empty();
    return _rooms
        .doc(roomDocId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;
          final doc = snap.docs.first;
          final m = Map<String, dynamic>.from(doc.data());
          m['_docId'] = doc.id;
          return m;
        });
  }

  // ─── 페이지네이션 메서드 ──────────────────────────────────────────

  /// 최신 [limit]건을 내림차순으로 가져와 역순(오래된 것 먼저)으로 반환.
  /// [oldestDoc] — 이전 페이지 fetch용 커서, [newestDoc] — 스트림 시작점 커서.
  static Future<({
    List<MessageModel> messages,
    DocumentSnapshot<Map<String, dynamic>>? oldestDoc,
    DocumentSnapshot<Map<String, dynamic>>? newestDoc,
  })> fetchInitialMessages(
    String roomDocId,
    String? myUid, {
    int limit = 50,
  }) async {
    if (!_ok) return (messages: const <MessageModel>[], oldestDoc: null, newestDoc: null);
    final query = _rooms
        .doc(roomDocId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit);
    try {
      final snap = await query.get();
      if (snap.docs.isEmpty) return (messages: const <MessageModel>[], oldestDoc: null, newestDoc: null);
      final messages = snap.docs.reversed
          .map((d) => MessageFirestoreCodec.fromDocument(d, myUid))
          .toList();
      return (
        messages: messages,
        oldestDoc: snap.docs.last,   // 내림차순 마지막 = 가장 오래된 것
        newestDoc: snap.docs.first,  // 내림차순 첫번째 = 가장 최신 것
      );
    } catch (e) {
      if (kDebugMode) debugPrint('fetchInitialMessages($roomDocId) server error: $e — trying cache');
      try {
        final snap = await query.get(const GetOptions(source: Source.cache));
        if (snap.docs.isEmpty) return (messages: const <MessageModel>[], oldestDoc: null, newestDoc: null);
        final messages = snap.docs.reversed
            .map((d) => MessageFirestoreCodec.fromDocument(d, myUid))
            .toList();
        return (messages: messages, oldestDoc: null, newestDoc: null);
      } catch (_) {
        return (messages: const <MessageModel>[], oldestDoc: null, newestDoc: null);
      }
    }
  }

  /// [beforeDoc] 이전 메시지 [limit]건 (이전 페이지 더 보기).
  static Future<({
    List<MessageModel> messages,
    DocumentSnapshot<Map<String, dynamic>>? oldestDoc,
  })> fetchOlderMessages(
    String roomDocId,
    String? myUid,
    DocumentSnapshot<Map<String, dynamic>> beforeDoc, {
    int limit = 50,
  }) async {
    if (!_ok) return (messages: const <MessageModel>[], oldestDoc: null);
    try {
      final snap = await _rooms
          .doc(roomDocId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(beforeDoc)
          .limit(limit)
          .get();
      if (snap.docs.isEmpty) return (messages: const <MessageModel>[], oldestDoc: null);
      final messages = snap.docs.reversed
          .map((d) => MessageFirestoreCodec.fromDocument(d, myUid))
          .toList();
      return (messages: messages, oldestDoc: snap.docs.last);
    } catch (e) {
      if (kDebugMode) debugPrint('fetchOlderMessages($roomDocId) error: $e');
      return (messages: const <MessageModel>[], oldestDoc: null);
    }
  }

  /// [startAfterDoc] 이후 메시지를 실시간 구독 (신규 메시지 전용 스트림).
  static Stream<List<MessageModel>> watchMessagesAfter(
    String roomDocId,
    String? myUid,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDoc,
  ) {
    if (!_ok) return const Stream.empty();
    var query = _rooms
        .doc(roomDocId)
        .collection('messages')
        .orderBy('createdAt', descending: false);
    if (startAfterDoc != null) {
      query = query.startAfterDocument(startAfterDoc);
    }
    return query.snapshots().map(
          (snap) => snap.docs
              .map((d) => MessageFirestoreCodec.fromDocument(d, myUid))
              .toList(),
        );
  }

  /// 오늘 날짜의 인원보고(report)를 일반 방별로 조회하여 합산 (Future 기반)
  static Future<List<MessageModel>> fetchTodayReports(
    String todayDate,
    String? myFirebaseUid,
    List<int> roomIds,
  ) async {
    if (!_ok) return const [];
    final all = <MessageModel>[];
    await Future.wait(roomIds.map((rid) async {
      try {
        final snap = await _rooms
            .doc(rid.toString())
            .collection('messages')
            .where('date', isEqualTo: todayDate)
            .where('type', isEqualTo: 'report')
            .get();
        for (final doc in snap.docs) {
          all.add(MessageFirestoreCodec.fromDocument(doc, myFirebaseUid));
        }
      } catch (e) {
        if (kDebugMode) debugPrint('fetchTodayReports room=$rid error: $e');
      }
    }));
    return all;
  }

  /// 이름으로 최신 인원보고 1건 조회 — 단일 where + 클라이언트 필터
  static Future<MessageModel?> getLatestReportByName(
    String name, List<int> roomIds,
  ) async {
    if (!_ok) return null;
    final all = <MessageModel>[];
    await Future.wait(roomIds.map((rid) async {
      try {
        final snap = await _rooms
            .doc(rid.toString())
            .collection('messages')
            .where('name', isEqualTo: name)
            .get();
        for (final doc in snap.docs) {
          final m = MessageFirestoreCodec.fromDocument(doc, null);
          if (m.type == MessageType.report) all.add(m);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('getLatestReportByName room=$rid error: $e');
      }
    }));
    if (all.isEmpty) return null;
    all.sort((a, b) => '${b.date} ${b.time}'.compareTo('${a.date} ${a.time}'));
    return all.first;
  }

  /// 차량번호 뒤 4자리로 최신 인원보고 1건 조회 — 단일 where + 클라이언트 필터
  static Future<MessageModel?> getLatestReportByCarLast4(
    String last4, List<int> roomIds,
  ) async {
    if (!_ok) return null;
    final all = <MessageModel>[];
    await Future.wait(roomIds.map((rid) async {
      try {
        final snap = await _rooms
            .doc(rid.toString())
            .collection('messages')
            .where('carLast4', isEqualTo: last4)
            .get();
        for (final doc in snap.docs) {
          final m = MessageFirestoreCodec.fromDocument(doc, null);
          if (m.type == MessageType.report) all.add(m);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('getLatestReportByCarLast4 room=$rid error: $e');
      }
    }));
    if (all.isEmpty) return null;
    all.sort((a, b) => '${b.date} ${b.time}'.compareTo('${a.date} ${a.time}'));
    return all.first;
  }

  // ─── 방 CRUD ────────────────────────────────────────────────

  /// 방 ID를 트랜잭션으로 안전하게 채번한 뒤 개별 문서를 생성합니다.
  static Future<void> createRoom({
    required String name,
    required List<String> companies,
    required List<String> subRoutes,
    required RoomType roomType,
    required String timeLabel,
  }) async {
    if (!_ok) return;
    final counterRef = _db.collection('config').doc('room_counter');
    final newId = await _db.runTransaction<int>((tx) async {
      final snap = await tx.get(counterRef);
      final current = (snap.data()?['nextId'] as num?)?.toInt() ?? 1;
      tx.set(counterRef, {'nextId': current + 1}, SetOptions(merge: true));
      return current;
    });

    await _rooms.doc(newId.toString()).set({
      'id': newId,
      'name': name.trim(),
      'companies': companies,
      'subRoutes': subRoutes,
      'timetable1Images': <String>[],
      'timetable2Images': <String>[],
      'pinned': false,
      'adminOnly': false,
      'roomType': roomTypeToWire(roomType) ?? 'normal',
      'sortOrder': newId,
      'lastMessage': {
        'text': '새 채팅방이 생성됐습니다',
        'type': 'text',
        'senderName': '',
        'time': timeLabel,
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 방 문서의 특정 필드만 원자적으로 수정합니다.
  static Future<void> patchRoom(String roomDocId, Map<String, Object?> data) async {
    if (!_ok) return;
    await _rooms.doc(roomDocId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> setRoomPinned(String roomDocId, bool pinned) async {
    await patchRoom(roomDocId, {'pinned': pinned});
  }

  /// 각 방 문서의 sortOrder만 배치 업데이트합니다.
  static Future<void> persistRoomOrder(List<RoomModel> orderedAllRooms) async {
    if (!_ok) return;
    final batch = _db.batch();
    var order = 0;
    for (final r in orderedAllRooms) {
      if (r.id == 998 || r.id == 999) continue;
      batch.update(_rooms.doc(r.id.toString()), {'sortOrder': order});
      order++;
    }
    await batch.commit();
  }

  static Future<void> deleteRoom(String roomDocId) async {
    if (!_ok) return;
    final roomId = int.tryParse(roomDocId);
    if (roomId == null) return;

    await _rooms.doc(roomDocId).delete();
    await _removeKakaoNavRoomKey(roomId);

    // 메시지·readState 서브컬렉션 정리
    for (final sub in ['messages', 'readState']) {
      final col = _rooms.doc(roomDocId).collection(sub);
      while (true) {
        final snap = await col.limit(400).get();
        if (snap.docs.isEmpty) break;
        var batch = _db.batch();
        for (final d in snap.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    }
  }

  /// 사용자의 mutedRooms 토글 (Firestore users/{uid})
  static Future<void> toggleMuteRoom(String uid, int roomId, {required bool mute}) async {
    if (!_ok) return;
    final ref = _db.collection('users').doc(uid);
    await ref.set({
      'mutedRooms': mute
          ? FieldValue.arrayUnion([roomId])
          : FieldValue.arrayRemove([roomId]),
    }, SetOptions(merge: true));
  }

  /// 사용자별 상단 고정 방 ID 전체 교체 (Firestore users/{uid})
  static Future<void> setUserPinnedRoomIds(String uid, List<int> ids) async {
    if (!_ok) return;
    await _db.collection('users').doc(uid).set(
          {'pinnedRoomIds': ids},
          SetOptions(merge: true),
        );
  }

  static const _maxImageBytes = 15 * 1024 * 1024;
  static const _allowedExts = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.heif'};

  static Future<String?> uploadChatImage(String roomDocId, String localPath) async {
    if (!_ok || kIsWeb) return null;
    final file = File(localPath);
    if (!await file.exists()) return null;

    final size = await file.length();
    if (size > _maxImageBytes) {
      if (kDebugMode) debugPrint('uploadChatImage: 파일 크기 초과 (${(size / 1024 / 1024).toStringAsFixed(1)}MB > 15MB)');
      return null;
    }

    final dot = localPath.lastIndexOf('.');
    final ext = dot >= 0 ? localPath.substring(dot).toLowerCase() : '';
    if (ext.isNotEmpty && !_allowedExts.contains(ext)) {
      if (kDebugMode) debugPrint('uploadChatImage: 허용되지 않는 확장자 ($ext)');
      return null;
    }

    final contentType = switch (ext) {
      '.png' => 'image/png',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      '.heic' || '.heif' => 'image/heic',
      _ => 'image/jpeg',
    };

    try {
      final id = const Uuid().v4();
      final ref = FirebaseStorage.instance.ref('rooms/$roomDocId/images/$id${ext.isEmpty ? '.jpg' : ext}');
      await ref.putFile(file, SettableMetadata(contentType: contentType));
      return ref.getDownloadURL();
    } catch (e, st) {
      if (kDebugMode) debugPrint('uploadChatImage failed: $e\n$st');
      return null;
    }
  }

  static Future<String?> uploadTimetableImage(String roomDocId, String localPath) async {
    if (!_ok || kIsWeb) return null;
    final file = File(localPath);
    if (!await file.exists()) return null;

    final size = await file.length();
    if (size > _maxImageBytes) {
      if (kDebugMode) debugPrint('uploadTimetableImage: 파일 크기 초과 (${(size / 1024 / 1024).toStringAsFixed(1)}MB > 15MB)');
      return null;
    }

    final dot = localPath.lastIndexOf('.');
    final ext = dot >= 0 ? localPath.substring(dot).toLowerCase() : '';
    if (ext.isNotEmpty && !_allowedExts.contains(ext)) {
      if (kDebugMode) debugPrint('uploadTimetableImage: 허용되지 않는 확장자 ($ext)');
      return null;
    }

    final contentType = switch (ext) {
      '.png' => 'image/png',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      '.heic' || '.heif' => 'image/heic',
      _ => 'image/jpeg',
    };

    try {
      final id = const Uuid().v4();
      final ref = FirebaseStorage.instance
          .ref('rooms/$roomDocId/timetable/$id${ext.isEmpty ? '.jpg' : ext}');
      await ref.putFile(file, SettableMetadata(contentType: contentType));
      return ref.getDownloadURL();
    } catch (e, st) {
      if (kDebugMode) debugPrint('uploadTimetableImage failed: $e\n$st');
      return null;
    }
  }

  static Future<void> sendMessage({
    required String roomDocId,
    required MessageModel msg,
    required String? myFirebaseUid,
    required String lastPreview,
  }) async {
    if (!_ok) throw StateError('오프라인 모드에서는 메시지를 보낼 수 없습니다.');
    try {
      final msgRef = _rooms.doc(roomDocId).collection('messages').doc();
      final fields = MessageFirestoreCodec.toDocumentFields(msg);
      await msgRef.set({
        ...fields,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      if (kDebugMode) debugPrint('sendMessage Firestore error: $e\n$st');
      rethrow;
    }
  }

  static Future<void> updateMessageText({
    required String roomDocId,
    required String messageDocId,
    required String newText,
  }) async {
    if (!_ok) return;
    await _rooms.doc(roomDocId).collection('messages').doc(messageDocId).update({
      'text': newText,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateReportData({
    required String roomDocId,
    required String messageDocId,
    required String car,
    required String route,
    String? subRoute,
    required String reportType,
    required int count,
    required int maxCount,
  }) async {
    if (!_ok) return;
    await _rooms.doc(roomDocId).collection('messages').doc(messageDocId).update({
      'car': car,
      'route': route,
      'subRoute': subRoute,
      'reportData': {
        'type': reportType,
        'count': count,
        'maxCount': maxCount,
        'isOverCapacity': count >= maxCount,
      },
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteMessage(String roomDocId, String messageDocId) async {
    if (!_ok) return;
    await _rooms.doc(roomDocId).collection('messages').doc(messageDocId).delete();
  }

  static Future<void> softDeleteMessage(String roomDocId, String messageDocId) async {
    if (!_ok) return;
    await _rooms.doc(roomDocId).collection('messages').doc(messageDocId).update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateMaintenanceStatus({
    required String roomDocId,
    required String messageDocId,
    required String newStatus,
  }) async {
    if (!_ok) return;
    await _rooms
        .doc(roomDocId)
        .collection('messages')
        .doc(messageDocId)
        .update({'maintenanceData.status': newStatus});
  }

  static Future<void> updateReactions({
    required String roomDocId,
    required String messageDocId,
    required Map<String, List<String>> reactions,
  }) async {
    if (!_ok) return;
    await _rooms
        .doc(roomDocId)
        .collection('messages')
        .doc(messageDocId)
        .update({'reactions': reactionsToFirestore(reactions)});
  }

  /// 관리자 전체 공지: 대상 방마다 메시지 추가 + 목록 미리보기 갱신
  static Future<void> broadcastNoticeToRooms({
    required List<RoomModel> targetRooms,
    required MessageModel msg,
    required String lastPreview,
  }) async {
    if (!_ok) return;
    var batch = _db.batch();
    var ops = 0;

    Future<void> flush() async {
      if (ops == 0) return;
      await batch.commit();
      batch = _db.batch();
      ops = 0;
    }

    for (final room in targetRooms) {
      if (room.id == 998 || room.id == 999) continue;
      final pathId = room.id.toString();
      final msgRef = _rooms.doc(pathId).collection('messages').doc();
      final fields = MessageFirestoreCodec.toDocumentFields(msg);
      batch.set(msgRef, {
        ...fields,
        'createdAt': FieldValue.serverTimestamp(),
      });
      ops++;
      if (ops >= 450) await flush();
    }
    await flush();
  }

  // ─── 읽음 상태 (readState 서브컬렉션) ─────────────────────────

  /// 사용자의 방별 마지막 읽은 시각을 Firestore에 저장합니다.
  static Future<void> setReadState(String roomDocId, String uid, int epochMs) async {
    if (!_ok || uid.isEmpty) return;
    try {
      await _rooms.doc(roomDocId).collection('readState').doc(uid).set({
        'lastReadAt': Timestamp.fromMillisecondsSinceEpoch(epochMs),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('setReadState($roomDocId) error: $e');
    }
  }

  /// Firestore에서 사용자의 방별 마지막 읽은 시각을 가져옵니다.
  static Future<int> getReadState(String roomDocId, String uid) async {
    if (!_ok || uid.isEmpty) return 0;
    try {
      final snap = await _rooms.doc(roomDocId).collection('readState').doc(uid).get();
      if (!snap.exists) return 0;
      final ts = snap.data()?['lastReadAt'];
      if (ts is Timestamp) return ts.millisecondsSinceEpoch;
      return 0;
    } catch (e) {
      if (kDebugMode) debugPrint('getReadState($roomDocId) error: $e');
      return 0;
    }
  }

  /// `workspace_calendar` 문서에서 일정 맵 목록 추출.
  /// - 정상: `items` 가 **배열** (앱 `arrayUnion` / 권장 스키마)
  /// - 웹/마이그레이션: `items` 가 **맵**(인덱스 문자열 키)인 경우
  /// - 레거시: `items` 없이 문서 **최상위**에 일정 객체만 있는 경우 (메타 키 제외)
  static List<Map<String, dynamic>> _calendarItemMapsFromData(
    Map<String, dynamic> data,
  ) {
    Map<String, dynamic>? asStringKeyedMap(dynamic v) {
      if (v is Map<String, dynamic>) return v;
      if (v is Map) {
        return v.map((k, val) => MapEntry(k.toString(), val));
      }
      return null;
    }

    bool looksLikeItem(Map<String, dynamic> m) {
      final id = m['id'];
      final date = m['date'];
      final idOk = id != null && id.toString().trim().isNotEmpty;
      final dateOk = date != null && date.toString().trim().isNotEmpty;
      return idOk && dateOk;
    }

    const metaKeys = {
      'items',
      'updatedAt',
      'createdAt',
      'updated_at',
      'created_at',
    };

    final dynamic itemsField = data['items'];
    if (itemsField is List<dynamic>) {
      final out = <Map<String, dynamic>>[];
      for (final e in itemsField) {
        final m = asStringKeyedMap(e);
        if (m != null && looksLikeItem(m)) out.add(m);
      }
      if (out.isNotEmpty) return out;
      // `items: []` 만 있고 예전에 루트에만 넣었던 데이터가 남은 경우
    }
    if (itemsField != null) {
      final asMap = asStringKeyedMap(itemsField);
      if (asMap != null) {
        final out = <Map<String, dynamic>>[];
        for (final e in asMap.values) {
          final m = asStringKeyedMap(e);
          if (m != null && looksLikeItem(m)) out.add(m);
        }
        return out;
      }
    }

    final out = <Map<String, dynamic>>[];
    for (final e in data.entries) {
      if (metaKeys.contains(e.key)) continue;
      final m = asStringKeyedMap(e.value);
      if (m != null && looksLikeItem(m)) out.add(m);
    }
    return out;
  }

  /// `config/workspace_calendar` 문서를 실시간 구독 → [CalendarItem] 목록
  static Stream<List<CalendarItem>> watchCalendarItems() {
    if (!_ok) return const Stream.empty();
    return _db
        .collection('config')
        .doc('workspace_calendar')
        .snapshots()
        .map((snap) {
      final data = snap.data();
      if (data == null) return <CalendarItem>[];
      try {
        final maps = _calendarItemMapsFromData(data);
        final items = maps
            .map(CalendarItem.fromMap)
            .where((e) => e.id.isNotEmpty && e.date.isNotEmpty)
            .toList();
        items.sort((a, b) {
          final cmp = a.date.compareTo(b.date);
          if (cmp != 0) return cmp;
          return (a.startTime ?? '').compareTo(b.startTime ?? '');
        });
        return items;
      } catch (e, st) {
        if (kDebugMode) debugPrint('watchCalendarItems parse error: $e\n$st');
        return <CalendarItem>[];
      }
    });
  }

  static final _calendarRef = _db.collection('config').doc('workspace_calendar');

  /// 캘린더 항목 추가
  static Future<void> addCalendarItem(CalendarItem item) async {
    if (!_ok) return;
    await _calendarRef.set({
      'items': FieldValue.arrayUnion([item.toMap()]),
    }, SetOptions(merge: true));
  }

  /// 캘린더 항목 삭제 (id로 필터링 후 배열 전체 교체)
  static Future<void> deleteCalendarItem(String itemId) async {
    if (!_ok) return;
    final snap = await _calendarRef.get();
    final data = snap.data();
    if (data == null) return;
    final maps = _calendarItemMapsFromData(data);
    final filtered = maps.where((m) => '${m['id']}' != itemId).toList();
    await _calendarRef.update({'items': filtered});
  }

  // ─── 비상연락망 ─────────────────────────────────────────────────

  static DocumentReference<Map<String, dynamic>> get _emergencyRef =>
      _db.collection('config').doc('emergency_contacts');

  static Stream<List<EmergencyContact>> watchEmergencyContacts() {
    if (!_ok) return const Stream.empty();
    return _emergencyRef.snapshots().map((snap) {
      final items = snap.data()?['items'];
      if (items is! List) return <EmergencyContact>[];
      final list = <EmergencyContact>[];
      for (final e in items) {
        if (e is! Map) continue;
        list.add(EmergencyContact.fromMap(Map<String, dynamic>.from(e)));
      }
      list.sort((a, b) => a.order.compareTo(b.order));
      return list;
    });
  }

  static Future<void> saveEmergencyContact(EmergencyContact contact) async {
    if (!_ok) return;
    final snap = await _emergencyRef.get();
    final items = <Map<String, dynamic>>[];
    final raw = snap.data()?['items'];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) items.add(Map<String, dynamic>.from(e));
      }
    }
    final idx = items.indexWhere((m) => '${m['id']}' == contact.id);
    if (idx >= 0) {
      items[idx] = contact.toMap();
    } else {
      items.add(contact.toMap());
    }
    await _emergencyRef.set({'items': items}, SetOptions(merge: true));
  }

  static Future<void> deleteEmergencyContact(String contactId) async {
    if (!_ok) return;
    final snap = await _emergencyRef.get();
    final raw = snap.data()?['items'];
    if (raw is! List) return;
    final filtered = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is! Map) continue;
      if ('${e['id']}' == contactId) continue;
      filtered.add(Map<String, dynamic>.from(e));
    }
    await _emergencyRef.update({'items': filtered});
  }
}
