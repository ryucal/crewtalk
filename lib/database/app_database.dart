import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class CachedMessages extends Table {
  TextColumn get firestoreDocId => text()();
  IntColumn get roomId => integer()();
  IntColumn get createdAtMs => integer().withDefault(const Constant(0))();
  TextColumn get type => text().withDefault(const Constant('text'))();
  TextColumn get senderName => text().withDefault(const Constant(''))();
  TextColumn get textPreview => text().withDefault(const Constant(''))();
  TextColumn get jsonData => text()();

  @override
  Set<Column> get primaryKey => {firestoreDocId};

  @override
  List<Set<Column>> get uniqueKeys => [];
}

class CachedRooms extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get jsonData => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalReadState extends Table {
  IntColumn get roomId => integer()();
  IntColumn get lastReadAtMs => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {roomId};
}

/// 전송 보류 중인 메시지 — 네트워크 복구 후 재전송.
class OutboxMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get roomDocId => text()();
  TextColumn get jsonData => text()();
  IntColumn get createdAtMs => integer().withDefault(const Constant(0))();
}

@DriftDatabase(tables: [CachedMessages, CachedRooms, LocalReadState, OutboxMessages])
class AppDatabase extends _$AppDatabase {
  AppDatabase._() : super(_openConnection());

  static final AppDatabase instance = AppDatabase._();

  factory AppDatabase() => instance;

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(outboxMessages);
      }
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'crewtalk_cache');
  }
}
