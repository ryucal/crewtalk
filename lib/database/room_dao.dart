import 'package:drift/drift.dart';

import '../models/room_model.dart';
import 'app_database.dart';

extension RoomDao on AppDatabase {
  /// 캐시된 방 목록을 sortOrder 순으로 조회.
  Future<List<RoomModel>> getCachedRooms() async {
    final rows = await (select(cachedRooms)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return rows.map((r) => RoomModel.fromJsonString(r.jsonData)).toList();
  }

  /// 방 목록을 upsert (Firestore watchRooms 스냅샷 수신 시 호출).
  Future<void> upsertRooms(List<RoomModel> rooms) async {
    if (rooms.isEmpty) return;
    await batch((b) {
      for (var i = 0; i < rooms.length; i++) {
        final r = rooms[i];
        if (r.id == 998 || r.id == 999) continue;
        b.insert(
          cachedRooms,
          CachedRoomsCompanion.insert(
            id: Value(r.id),
            jsonData: r.toJsonString(),
            name: Value(r.name),
            sortOrder: Value(i),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// 캐시에서 삭제된 방 제거 (Firestore에 없는 방 정리).
  Future<void> removeStaleCachedRooms(Set<int> activeIds) async {
    final all = await select(cachedRooms).get();
    final stale = all.where((r) => !activeIds.contains(r.id)).toList();
    if (stale.isEmpty) return;
    await batch((b) {
      for (final r in stale) {
        b.deleteWhere(cachedRooms, (t) => t.id.equals(r.id));
      }
    });
  }

  // ─── 읽음 상태 ──────────────────────────────────────────────

  /// 방의 마지막 읽은 시각을 조회 (없으면 0).
  Future<int> getLocalReadState(int roomId) async {
    final row = await (select(localReadState)
          ..where((t) => t.roomId.equals(roomId)))
        .getSingleOrNull();
    return row?.lastReadAtMs ?? 0;
  }

  /// 모든 방의 읽음 상태를 맵으로 조회.
  Future<Map<int, int>> getAllLocalReadStates() async {
    final rows = await select(localReadState).get();
    return {for (final r in rows) r.roomId: r.lastReadAtMs};
  }

  /// 마지막 읽은 시각 upsert.
  Future<void> setLocalReadState(int roomId, int epochMs) async {
    await into(localReadState).insertOnConflictUpdate(
      LocalReadStateCompanion.insert(
        roomId: Value(roomId),
        lastReadAtMs: Value(epochMs),
      ),
    );
  }
}
