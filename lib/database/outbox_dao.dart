import 'package:drift/drift.dart';

import '../models/message_model.dart';
import 'app_database.dart';

extension OutboxDao on AppDatabase {
  /// 전송 대기 메시지를 아웃박스에 삽입하고 행 ID를 반환한다.
  Future<int> enqueueOutboxMessage({
    required String roomDocId,
    required MessageModel msg,
  }) {
    return into(outboxMessages).insert(
      OutboxMessagesCompanion.insert(
        roomDocId: roomDocId,
        jsonData: msg.toJsonString(),
        createdAtMs: Value(msg.createdAtMs ?? DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// 특정 방의 전송 대기 메시지를 오래된 순으로 반환한다.
  Future<List<OutboxMessage>> getPendingOutboxMessages(String roomDocId) {
    return (select(outboxMessages)
          ..where((t) => t.roomDocId.equals(roomDocId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAtMs)]))
        .get();
  }

  /// 아웃박스에서 해당 행을 삭제한다 (전송 성공 후 호출).
  Future<void> dequeueOutboxMessage(int rowId) {
    return (delete(outboxMessages)..where((t) => t.id.equals(rowId))).go();
  }
}
