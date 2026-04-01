import 'package:drift/drift.dart';

import '../models/message_model.dart';
import 'app_database.dart';

extension MessageDao on AppDatabase {
  /// 방의 캐시된 메시지를 최신순 [limit]건 조회 (오래된 순으로 반환).
  Future<List<MessageModel>> getCachedMessages(
    int roomId, {
    int limit = 50,
    String? currentUid,
  }) async {
    final rows = await (select(cachedMessages)
          ..where((t) => t.roomId.equals(roomId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAtMs)])
          ..limit(limit))
        .get();
    return rows.reversed
        .map((r) => MessageModel.fromJsonString(r.jsonData, currentUid: currentUid))
        .toList();
  }

  /// 특정 시각 이전 메시지를 [limit]건 조회 (loadMore용).
  Future<List<MessageModel>> getOlderMessages(
    int roomId,
    int beforeMs, {
    int limit = 50,
    String? currentUid,
  }) async {
    final rows = await (select(cachedMessages)
          ..where((t) =>
              t.roomId.equals(roomId) & t.createdAtMs.isSmallerThanValue(beforeMs))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAtMs)])
          ..limit(limit))
        .get();
    return rows.reversed
        .map((r) => MessageModel.fromJsonString(r.jsonData, currentUid: currentUid))
        .toList();
  }

  /// 방의 캐시된 메시지 중 가장 최신 createdAtMs 반환 (없으면 0).
  Future<int> getNewestCachedMs(int roomId) async {
    final row = await (select(cachedMessages)
          ..where((t) => t.roomId.equals(roomId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAtMs)])
          ..limit(1))
        .getSingleOrNull();
    return row?.createdAtMs ?? 0;
  }

  /// 방 ID를 포함하여 메시지를 upsert.
  Future<void> upsertMessagesForRoom(int roomId, List<MessageModel> messages) async {
    if (messages.isEmpty) return;
    await batch((b) {
      for (final m in messages) {
        final docId = m.firestoreDocId;
        if (docId == null || docId.isEmpty) continue;
        b.insert(
          cachedMessages,
          CachedMessagesCompanion.insert(
            firestoreDocId: docId,
            roomId: roomId,
            jsonData: m.toJsonString(),
            createdAtMs: Value(m.createdAtMs ?? 0),
            type: Value(m.type.name),
            senderName: Value(m.name),
            textPreview: Value((m.text ?? '').length > 200
                ? (m.text ?? '').substring(0, 200)
                : m.text ?? ''),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// 단일 메시지 삭제.
  Future<void> deleteMessageByDocId(String docId) async {
    await (delete(cachedMessages)..where((t) => t.firestoreDocId.equals(docId))).go();
  }

  /// 방의 모든 캐시 메시지 삭제.
  Future<void> deleteMessagesForRoom(int roomId) async {
    await (delete(cachedMessages)..where((t) => t.roomId.equals(roomId))).go();
  }

  /// 특정 일수보다 오래된 메시지 삭제 (캐시 정리).
  Future<int> deleteOldMessages(int maxAgeDays) async {
    final cutoff = DateTime.now()
        .subtract(Duration(days: maxAgeDays))
        .millisecondsSinceEpoch;
    return (delete(cachedMessages)
          ..where((t) => t.createdAtMs.isSmallerThanValue(cutoff)))
        .go();
  }

  /// lastReadAtMs 이후 메시지 수 (로컬 unread 계산).
  Future<int> countUnread(int roomId, int lastReadAtMs) async {
    final query = select(cachedMessages)
      ..where((t) =>
          t.roomId.equals(roomId) &
          t.createdAtMs.isBiggerThanValue(lastReadAtMs));
    final rows = await query.get();
    return rows.length;
  }
}
