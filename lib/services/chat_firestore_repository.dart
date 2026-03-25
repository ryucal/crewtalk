import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/message_model.dart';
import '../models/room_model.dart';
import 'auth_repository.dart';
import 'message_firestore_codec.dart';

/// 채팅방·메시지 Firestore 경로: `rooms/{roomId}`, `rooms/{roomId}/messages/{msgId}`
///
/// **중요:** 상위 문서에 필드가 하나도 없으면 콘솔에는 보이지만 `rooms` 컬렉션 쿼리/스냅샷에
/// 포함되지 않습니다. 각 방 문서에 최소 `name` 필드를 넣어 주세요.
class ChatFirestoreRepository {
  ChatFirestoreRepository._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _rooms =>
      _db.collection('rooms');

  static bool get _ok => AuthRepository.firebaseAvailable;

  static Map<String, Object?> roomToFirestoreFields(RoomModel r) {
    return {
      'name': r.name,
      'lastMsg': r.lastMsg,
      'time': r.time,
      'companies': r.companies,
      'subRoutes': r.subRoutes,
      'timetableImages': r.timetableImages,
      'pinned': r.pinned,
      'adminOnly': r.adminOnly,
      'roomType': r.roomType == RoomType.vendor ? 'vendor' : 'normal',
      'unread': r.unread,
    };
  }

  static String roomDocPathId(RoomModel room) {
    if (room.id == 998 || room.id == 999) {
      throw StateError('가상 방은 Firestore와 연결되지 않습니다');
    }
    return room.id.toString();
  }

  static RoomModel roomFromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final id = int.tryParse(doc.id) ?? doc.id.hashCode.abs();
    final rt = (d['roomType'] as String?) == 'vendor' ? RoomType.vendor : RoomType.normal;
    final companies = (d['companies'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final subRoutes = (d['subRoutes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final timetableImages =
        (d['timetableImages'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    return RoomModel(
      id: id,
      name: (d['name'] as String?)?.trim().isNotEmpty == true ? d['name'] as String : '채팅방 ${doc.id}',
      lastMsg: d['lastMsg'] as String? ?? '',
      time: d['time'] as String? ?? '',
      unread: (d['unread'] as num?)?.toInt() ?? 0,
      companies: companies,
      subRoutes: subRoutes,
      timetableImages: timetableImages,
      pinned: d['pinned'] as bool? ?? false,
      adminOnly: d['adminOnly'] as bool? ?? false,
      roomType: rt,
    );
  }

  static Stream<List<RoomModel>> watchRooms() {
    if (!_ok) {
      return const Stream.empty();
    }
    return _rooms.snapshots().map((snap) {
      final sortByDocId = <String, double>{};
      for (final d in snap.docs) {
        sortByDocId[d.id] = (d.data()['sortOrder'] as num?)?.toDouble() ?? 0;
      }
      final list = snap.docs.map(roomFromSnapshot).toList();
      list.sort((a, b) {
        final ao = sortByDocId[a.id.toString()] ?? 0;
        final bo = sortByDocId[b.id.toString()] ?? 0;
        if (ao != bo) return ao.compareTo(bo);
        return a.name.compareTo(b.name);
      });
      return list;
    });
  }

  static Stream<List<MessageModel>> watchRoomMessages(
    String roomDocId,
    String? myFirebaseUid,
  ) {
    if (!_ok) {
      return const Stream.empty();
    }
    final q = _rooms.doc(roomDocId).collection('messages').orderBy('createdAt', descending: false);
    return q.snapshots().map(
          (snap) => snap.docs.map((d) => MessageFirestoreCodec.fromDocument(d, myFirebaseUid)).toList(),
        );
  }

  /// 오늘 날짜의 메시지 중 인원보고(`report`)만 (collectionGroup)
  static Stream<List<MessageModel>> watchTodayReports(String todayDate, String? myFirebaseUid) {
    if (!_ok) {
      return const Stream.empty();
    }
    return _db
        .collectionGroup('messages')
        .where('date', isEqualTo: todayDate)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => MessageFirestoreCodec.fromDocument(d, myFirebaseUid))
              .where((m) => m.type == MessageType.report)
              .toList(),
        );
  }

  static Future<void> createRoom({
    required String name,
    required List<String> companies,
    required List<String> subRoutes,
    required RoomType roomType,
    required String timeLabel,
  }) async {
    if (!_ok) return;
    final docId = DateTime.now().millisecondsSinceEpoch.toString();
    await _rooms.doc(docId).set({
      'name': name.trim(),
      'lastMsg': '새 채팅방이 생성됐습니다',
      'time': timeLabel,
      'companies': companies,
      'subRoutes': subRoutes,
      'timetableImages': <String>[],
      'pinned': false,
      'adminOnly': false,
      'roomType': roomType == RoomType.vendor ? 'vendor' : 'normal',
      'unread': 0,
      'sortOrder': DateTime.now().millisecondsSinceEpoch,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> patchRoom(String roomDocId, Map<String, Object?> data) async {
    if (!_ok) return;
    await _rooms.doc(roomDocId).set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> setRoomPinned(String roomDocId, bool pinned) async {
    await patchRoom(roomDocId, {'pinned': pinned});
  }

  /// `roomProvider`에서의 순서(가상 방 제외)를 `sortOrder`로 저장합니다.
  static Future<void> persistRoomOrder(List<RoomModel> orderedAllRooms) async {
    if (!_ok) return;
    var batch = _db.batch();
    var n = 0;
    var order = 0;
    for (final r in orderedAllRooms) {
      if (r.id == 998 || r.id == 999) continue;
      batch.set(
        _rooms.doc(r.id.toString()),
        {'sortOrder': order, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      order++;
      n++;
      if (n >= 400) {
        await batch.commit();
        batch = _db.batch();
        n = 0;
      }
    }
    if (n > 0) await batch.commit();
  }

  static Future<void> deleteRoom(String roomDocId) async {
    if (!_ok) return;
    final col = _rooms.doc(roomDocId).collection('messages');
    while (true) {
      final snap = await col.limit(400).get();
      if (snap.docs.isEmpty) break;
      var batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
    await _rooms.doc(roomDocId).delete();
  }

  static Future<String?> uploadChatImage(String roomDocId, String localPath) async {
    if (!_ok || kIsWeb) return null;
    final file = File(localPath);
    if (!await file.exists()) return null;
    try {
      final id = const Uuid().v4();
      final ref = FirebaseStorage.instance.ref('rooms/$roomDocId/images/$id.jpg');
      await ref.putFile(file);
      return ref.getDownloadURL();
    } catch (e, st) {
      debugPrint('uploadChatImage failed: $e\n$st');
      return null;
    }
  }

  static Future<void> sendMessage({
    required String roomDocId,
    required MessageModel msg,
    required String? myFirebaseUid,
    required String lastPreview,
  }) async {
    if (!_ok) return;
    final msgRef = _rooms.doc(roomDocId).collection('messages').doc();
    final fields = MessageFirestoreCodec.toDocumentFields(msg);
    await _db.runTransaction((tx) async {
      tx.set(msgRef, {
        ...fields,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(
        _rooms.doc(roomDocId),
        {
          'lastMsg': lastPreview,
          'time': msg.time,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  static Future<void> updateMessageText({
    required String roomDocId,
    required String messageDocId,
    required String newText,
  }) async {
    if (!_ok) return;
    await _rooms.doc(roomDocId).collection('messages').doc(messageDocId).update({'text': newText});
  }

  static Future<void> deleteMessage(String roomDocId, String messageDocId) async {
    if (!_ok) return;
    await _rooms.doc(roomDocId).collection('messages').doc(messageDocId).delete();
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
      batch.set(
        _rooms.doc(pathId),
        {
          'lastMsg': lastPreview,
          'time': msg.time,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      ops += 2;
      if (ops >= 450) await flush();
    }
    await flush();
  }
}
