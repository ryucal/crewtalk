// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CachedMessagesTable extends CachedMessages
    with TableInfo<$CachedMessagesTable, CachedMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _firestoreDocIdMeta = const VerificationMeta(
    'firestoreDocId',
  );
  @override
  late final GeneratedColumn<String> firestoreDocId = GeneratedColumn<String>(
    'firestore_doc_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roomIdMeta = const VerificationMeta('roomId');
  @override
  late final GeneratedColumn<int> roomId = GeneratedColumn<int>(
    'room_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('text'),
  );
  static const VerificationMeta _senderNameMeta = const VerificationMeta(
    'senderName',
  );
  @override
  late final GeneratedColumn<String> senderName = GeneratedColumn<String>(
    'sender_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _textPreviewMeta = const VerificationMeta(
    'textPreview',
  );
  @override
  late final GeneratedColumn<String> textPreview = GeneratedColumn<String>(
    'text_preview',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _jsonDataMeta = const VerificationMeta(
    'jsonData',
  );
  @override
  late final GeneratedColumn<String> jsonData = GeneratedColumn<String>(
    'json_data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    firestoreDocId,
    roomId,
    createdAtMs,
    type,
    senderName,
    textPreview,
    jsonData,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('firestore_doc_id')) {
      context.handle(
        _firestoreDocIdMeta,
        firestoreDocId.isAcceptableOrUnknown(
          data['firestore_doc_id']!,
          _firestoreDocIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firestoreDocIdMeta);
    }
    if (data.containsKey('room_id')) {
      context.handle(
        _roomIdMeta,
        roomId.isAcceptableOrUnknown(data['room_id']!, _roomIdMeta),
      );
    } else if (isInserting) {
      context.missing(_roomIdMeta);
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('sender_name')) {
      context.handle(
        _senderNameMeta,
        senderName.isAcceptableOrUnknown(data['sender_name']!, _senderNameMeta),
      );
    }
    if (data.containsKey('text_preview')) {
      context.handle(
        _textPreviewMeta,
        textPreview.isAcceptableOrUnknown(
          data['text_preview']!,
          _textPreviewMeta,
        ),
      );
    }
    if (data.containsKey('json_data')) {
      context.handle(
        _jsonDataMeta,
        jsonData.isAcceptableOrUnknown(data['json_data']!, _jsonDataMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonDataMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {firestoreDocId};
  @override
  CachedMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedMessage(
      firestoreDocId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}firestore_doc_id'],
      )!,
      roomId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}room_id'],
      )!,
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      senderName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_name'],
      )!,
      textPreview: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_preview'],
      )!,
      jsonData: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json_data'],
      )!,
    );
  }

  @override
  $CachedMessagesTable createAlias(String alias) {
    return $CachedMessagesTable(attachedDatabase, alias);
  }
}

class CachedMessage extends DataClass implements Insertable<CachedMessage> {
  final String firestoreDocId;
  final int roomId;
  final int createdAtMs;
  final String type;
  final String senderName;
  final String textPreview;
  final String jsonData;
  const CachedMessage({
    required this.firestoreDocId,
    required this.roomId,
    required this.createdAtMs,
    required this.type,
    required this.senderName,
    required this.textPreview,
    required this.jsonData,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['firestore_doc_id'] = Variable<String>(firestoreDocId);
    map['room_id'] = Variable<int>(roomId);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    map['type'] = Variable<String>(type);
    map['sender_name'] = Variable<String>(senderName);
    map['text_preview'] = Variable<String>(textPreview);
    map['json_data'] = Variable<String>(jsonData);
    return map;
  }

  CachedMessagesCompanion toCompanion(bool nullToAbsent) {
    return CachedMessagesCompanion(
      firestoreDocId: Value(firestoreDocId),
      roomId: Value(roomId),
      createdAtMs: Value(createdAtMs),
      type: Value(type),
      senderName: Value(senderName),
      textPreview: Value(textPreview),
      jsonData: Value(jsonData),
    );
  }

  factory CachedMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedMessage(
      firestoreDocId: serializer.fromJson<String>(json['firestoreDocId']),
      roomId: serializer.fromJson<int>(json['roomId']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
      type: serializer.fromJson<String>(json['type']),
      senderName: serializer.fromJson<String>(json['senderName']),
      textPreview: serializer.fromJson<String>(json['textPreview']),
      jsonData: serializer.fromJson<String>(json['jsonData']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'firestoreDocId': serializer.toJson<String>(firestoreDocId),
      'roomId': serializer.toJson<int>(roomId),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
      'type': serializer.toJson<String>(type),
      'senderName': serializer.toJson<String>(senderName),
      'textPreview': serializer.toJson<String>(textPreview),
      'jsonData': serializer.toJson<String>(jsonData),
    };
  }

  CachedMessage copyWith({
    String? firestoreDocId,
    int? roomId,
    int? createdAtMs,
    String? type,
    String? senderName,
    String? textPreview,
    String? jsonData,
  }) => CachedMessage(
    firestoreDocId: firestoreDocId ?? this.firestoreDocId,
    roomId: roomId ?? this.roomId,
    createdAtMs: createdAtMs ?? this.createdAtMs,
    type: type ?? this.type,
    senderName: senderName ?? this.senderName,
    textPreview: textPreview ?? this.textPreview,
    jsonData: jsonData ?? this.jsonData,
  );
  CachedMessage copyWithCompanion(CachedMessagesCompanion data) {
    return CachedMessage(
      firestoreDocId: data.firestoreDocId.present
          ? data.firestoreDocId.value
          : this.firestoreDocId,
      roomId: data.roomId.present ? data.roomId.value : this.roomId,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
      type: data.type.present ? data.type.value : this.type,
      senderName: data.senderName.present
          ? data.senderName.value
          : this.senderName,
      textPreview: data.textPreview.present
          ? data.textPreview.value
          : this.textPreview,
      jsonData: data.jsonData.present ? data.jsonData.value : this.jsonData,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedMessage(')
          ..write('firestoreDocId: $firestoreDocId, ')
          ..write('roomId: $roomId, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('type: $type, ')
          ..write('senderName: $senderName, ')
          ..write('textPreview: $textPreview, ')
          ..write('jsonData: $jsonData')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    firestoreDocId,
    roomId,
    createdAtMs,
    type,
    senderName,
    textPreview,
    jsonData,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedMessage &&
          other.firestoreDocId == this.firestoreDocId &&
          other.roomId == this.roomId &&
          other.createdAtMs == this.createdAtMs &&
          other.type == this.type &&
          other.senderName == this.senderName &&
          other.textPreview == this.textPreview &&
          other.jsonData == this.jsonData);
}

class CachedMessagesCompanion extends UpdateCompanion<CachedMessage> {
  final Value<String> firestoreDocId;
  final Value<int> roomId;
  final Value<int> createdAtMs;
  final Value<String> type;
  final Value<String> senderName;
  final Value<String> textPreview;
  final Value<String> jsonData;
  final Value<int> rowid;
  const CachedMessagesCompanion({
    this.firestoreDocId = const Value.absent(),
    this.roomId = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.type = const Value.absent(),
    this.senderName = const Value.absent(),
    this.textPreview = const Value.absent(),
    this.jsonData = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedMessagesCompanion.insert({
    required String firestoreDocId,
    required int roomId,
    this.createdAtMs = const Value.absent(),
    this.type = const Value.absent(),
    this.senderName = const Value.absent(),
    this.textPreview = const Value.absent(),
    required String jsonData,
    this.rowid = const Value.absent(),
  }) : firestoreDocId = Value(firestoreDocId),
       roomId = Value(roomId),
       jsonData = Value(jsonData);
  static Insertable<CachedMessage> custom({
    Expression<String>? firestoreDocId,
    Expression<int>? roomId,
    Expression<int>? createdAtMs,
    Expression<String>? type,
    Expression<String>? senderName,
    Expression<String>? textPreview,
    Expression<String>? jsonData,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (firestoreDocId != null) 'firestore_doc_id': firestoreDocId,
      if (roomId != null) 'room_id': roomId,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (type != null) 'type': type,
      if (senderName != null) 'sender_name': senderName,
      if (textPreview != null) 'text_preview': textPreview,
      if (jsonData != null) 'json_data': jsonData,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedMessagesCompanion copyWith({
    Value<String>? firestoreDocId,
    Value<int>? roomId,
    Value<int>? createdAtMs,
    Value<String>? type,
    Value<String>? senderName,
    Value<String>? textPreview,
    Value<String>? jsonData,
    Value<int>? rowid,
  }) {
    return CachedMessagesCompanion(
      firestoreDocId: firestoreDocId ?? this.firestoreDocId,
      roomId: roomId ?? this.roomId,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      type: type ?? this.type,
      senderName: senderName ?? this.senderName,
      textPreview: textPreview ?? this.textPreview,
      jsonData: jsonData ?? this.jsonData,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (firestoreDocId.present) {
      map['firestore_doc_id'] = Variable<String>(firestoreDocId.value);
    }
    if (roomId.present) {
      map['room_id'] = Variable<int>(roomId.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (senderName.present) {
      map['sender_name'] = Variable<String>(senderName.value);
    }
    if (textPreview.present) {
      map['text_preview'] = Variable<String>(textPreview.value);
    }
    if (jsonData.present) {
      map['json_data'] = Variable<String>(jsonData.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedMessagesCompanion(')
          ..write('firestoreDocId: $firestoreDocId, ')
          ..write('roomId: $roomId, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('type: $type, ')
          ..write('senderName: $senderName, ')
          ..write('textPreview: $textPreview, ')
          ..write('jsonData: $jsonData, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedRoomsTable extends CachedRooms
    with TableInfo<$CachedRoomsTable, CachedRoom> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedRoomsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _jsonDataMeta = const VerificationMeta(
    'jsonData',
  );
  @override
  late final GeneratedColumn<String> jsonData = GeneratedColumn<String>(
    'json_data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, sortOrder, jsonData];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_rooms';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedRoom> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('json_data')) {
      context.handle(
        _jsonDataMeta,
        jsonData.isAcceptableOrUnknown(data['json_data']!, _jsonDataMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonDataMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedRoom map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedRoom(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      jsonData: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json_data'],
      )!,
    );
  }

  @override
  $CachedRoomsTable createAlias(String alias) {
    return $CachedRoomsTable(attachedDatabase, alias);
  }
}

class CachedRoom extends DataClass implements Insertable<CachedRoom> {
  final int id;
  final String name;
  final int sortOrder;
  final String jsonData;
  const CachedRoom({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.jsonData,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['sort_order'] = Variable<int>(sortOrder);
    map['json_data'] = Variable<String>(jsonData);
    return map;
  }

  CachedRoomsCompanion toCompanion(bool nullToAbsent) {
    return CachedRoomsCompanion(
      id: Value(id),
      name: Value(name),
      sortOrder: Value(sortOrder),
      jsonData: Value(jsonData),
    );
  }

  factory CachedRoom.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedRoom(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      jsonData: serializer.fromJson<String>(json['jsonData']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'jsonData': serializer.toJson<String>(jsonData),
    };
  }

  CachedRoom copyWith({
    int? id,
    String? name,
    int? sortOrder,
    String? jsonData,
  }) => CachedRoom(
    id: id ?? this.id,
    name: name ?? this.name,
    sortOrder: sortOrder ?? this.sortOrder,
    jsonData: jsonData ?? this.jsonData,
  );
  CachedRoom copyWithCompanion(CachedRoomsCompanion data) {
    return CachedRoom(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      jsonData: data.jsonData.present ? data.jsonData.value : this.jsonData,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedRoom(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('jsonData: $jsonData')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, sortOrder, jsonData);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedRoom &&
          other.id == this.id &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder &&
          other.jsonData == this.jsonData);
}

class CachedRoomsCompanion extends UpdateCompanion<CachedRoom> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> sortOrder;
  final Value<String> jsonData;
  const CachedRoomsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.jsonData = const Value.absent(),
  });
  CachedRoomsCompanion.insert({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required String jsonData,
  }) : jsonData = Value(jsonData);
  static Insertable<CachedRoom> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? sortOrder,
    Expression<String>? jsonData,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (jsonData != null) 'json_data': jsonData,
    });
  }

  CachedRoomsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? sortOrder,
    Value<String>? jsonData,
  }) {
    return CachedRoomsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      jsonData: jsonData ?? this.jsonData,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (jsonData.present) {
      map['json_data'] = Variable<String>(jsonData.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedRoomsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('jsonData: $jsonData')
          ..write(')'))
        .toString();
  }
}

class $LocalReadStateTable extends LocalReadState
    with TableInfo<$LocalReadStateTable, LocalReadStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalReadStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _roomIdMeta = const VerificationMeta('roomId');
  @override
  late final GeneratedColumn<int> roomId = GeneratedColumn<int>(
    'room_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastReadAtMsMeta = const VerificationMeta(
    'lastReadAtMs',
  );
  @override
  late final GeneratedColumn<int> lastReadAtMs = GeneratedColumn<int>(
    'last_read_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [roomId, lastReadAtMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_read_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalReadStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('room_id')) {
      context.handle(
        _roomIdMeta,
        roomId.isAcceptableOrUnknown(data['room_id']!, _roomIdMeta),
      );
    }
    if (data.containsKey('last_read_at_ms')) {
      context.handle(
        _lastReadAtMsMeta,
        lastReadAtMs.isAcceptableOrUnknown(
          data['last_read_at_ms']!,
          _lastReadAtMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {roomId};
  @override
  LocalReadStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalReadStateData(
      roomId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}room_id'],
      )!,
      lastReadAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_read_at_ms'],
      )!,
    );
  }

  @override
  $LocalReadStateTable createAlias(String alias) {
    return $LocalReadStateTable(attachedDatabase, alias);
  }
}

class LocalReadStateData extends DataClass
    implements Insertable<LocalReadStateData> {
  final int roomId;
  final int lastReadAtMs;
  const LocalReadStateData({required this.roomId, required this.lastReadAtMs});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['room_id'] = Variable<int>(roomId);
    map['last_read_at_ms'] = Variable<int>(lastReadAtMs);
    return map;
  }

  LocalReadStateCompanion toCompanion(bool nullToAbsent) {
    return LocalReadStateCompanion(
      roomId: Value(roomId),
      lastReadAtMs: Value(lastReadAtMs),
    );
  }

  factory LocalReadStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalReadStateData(
      roomId: serializer.fromJson<int>(json['roomId']),
      lastReadAtMs: serializer.fromJson<int>(json['lastReadAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'roomId': serializer.toJson<int>(roomId),
      'lastReadAtMs': serializer.toJson<int>(lastReadAtMs),
    };
  }

  LocalReadStateData copyWith({int? roomId, int? lastReadAtMs}) =>
      LocalReadStateData(
        roomId: roomId ?? this.roomId,
        lastReadAtMs: lastReadAtMs ?? this.lastReadAtMs,
      );
  LocalReadStateData copyWithCompanion(LocalReadStateCompanion data) {
    return LocalReadStateData(
      roomId: data.roomId.present ? data.roomId.value : this.roomId,
      lastReadAtMs: data.lastReadAtMs.present
          ? data.lastReadAtMs.value
          : this.lastReadAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalReadStateData(')
          ..write('roomId: $roomId, ')
          ..write('lastReadAtMs: $lastReadAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(roomId, lastReadAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalReadStateData &&
          other.roomId == this.roomId &&
          other.lastReadAtMs == this.lastReadAtMs);
}

class LocalReadStateCompanion extends UpdateCompanion<LocalReadStateData> {
  final Value<int> roomId;
  final Value<int> lastReadAtMs;
  const LocalReadStateCompanion({
    this.roomId = const Value.absent(),
    this.lastReadAtMs = const Value.absent(),
  });
  LocalReadStateCompanion.insert({
    this.roomId = const Value.absent(),
    this.lastReadAtMs = const Value.absent(),
  });
  static Insertable<LocalReadStateData> custom({
    Expression<int>? roomId,
    Expression<int>? lastReadAtMs,
  }) {
    return RawValuesInsertable({
      if (roomId != null) 'room_id': roomId,
      if (lastReadAtMs != null) 'last_read_at_ms': lastReadAtMs,
    });
  }

  LocalReadStateCompanion copyWith({
    Value<int>? roomId,
    Value<int>? lastReadAtMs,
  }) {
    return LocalReadStateCompanion(
      roomId: roomId ?? this.roomId,
      lastReadAtMs: lastReadAtMs ?? this.lastReadAtMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (roomId.present) {
      map['room_id'] = Variable<int>(roomId.value);
    }
    if (lastReadAtMs.present) {
      map['last_read_at_ms'] = Variable<int>(lastReadAtMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalReadStateCompanion(')
          ..write('roomId: $roomId, ')
          ..write('lastReadAtMs: $lastReadAtMs')
          ..write(')'))
        .toString();
  }
}

class $OutboxMessagesTable extends OutboxMessages
    with TableInfo<$OutboxMessagesTable, OutboxMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _roomDocIdMeta = const VerificationMeta(
    'roomDocId',
  );
  @override
  late final GeneratedColumn<String> roomDocId = GeneratedColumn<String>(
    'room_doc_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonDataMeta = const VerificationMeta(
    'jsonData',
  );
  @override
  late final GeneratedColumn<String> jsonData = GeneratedColumn<String>(
    'json_data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, roomDocId, jsonData, createdAtMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('room_doc_id')) {
      context.handle(
        _roomDocIdMeta,
        roomDocId.isAcceptableOrUnknown(data['room_doc_id']!, _roomDocIdMeta),
      );
    } else if (isInserting) {
      context.missing(_roomDocIdMeta);
    }
    if (data.containsKey('json_data')) {
      context.handle(
        _jsonDataMeta,
        jsonData.isAcceptableOrUnknown(data['json_data']!, _jsonDataMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonDataMeta);
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxMessage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      roomDocId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}room_doc_id'],
      )!,
      jsonData: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json_data'],
      )!,
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
    );
  }

  @override
  $OutboxMessagesTable createAlias(String alias) {
    return $OutboxMessagesTable(attachedDatabase, alias);
  }
}

class OutboxMessage extends DataClass implements Insertable<OutboxMessage> {
  final int id;
  final String roomDocId;
  final String jsonData;
  final int createdAtMs;
  const OutboxMessage({
    required this.id,
    required this.roomDocId,
    required this.jsonData,
    required this.createdAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['room_doc_id'] = Variable<String>(roomDocId);
    map['json_data'] = Variable<String>(jsonData);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    return map;
  }

  OutboxMessagesCompanion toCompanion(bool nullToAbsent) {
    return OutboxMessagesCompanion(
      id: Value(id),
      roomDocId: Value(roomDocId),
      jsonData: Value(jsonData),
      createdAtMs: Value(createdAtMs),
    );
  }

  factory OutboxMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxMessage(
      id: serializer.fromJson<int>(json['id']),
      roomDocId: serializer.fromJson<String>(json['roomDocId']),
      jsonData: serializer.fromJson<String>(json['jsonData']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'roomDocId': serializer.toJson<String>(roomDocId),
      'jsonData': serializer.toJson<String>(jsonData),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
    };
  }

  OutboxMessage copyWith({
    int? id,
    String? roomDocId,
    String? jsonData,
    int? createdAtMs,
  }) => OutboxMessage(
    id: id ?? this.id,
    roomDocId: roomDocId ?? this.roomDocId,
    jsonData: jsonData ?? this.jsonData,
    createdAtMs: createdAtMs ?? this.createdAtMs,
  );
  OutboxMessage copyWithCompanion(OutboxMessagesCompanion data) {
    return OutboxMessage(
      id: data.id.present ? data.id.value : this.id,
      roomDocId: data.roomDocId.present ? data.roomDocId.value : this.roomDocId,
      jsonData: data.jsonData.present ? data.jsonData.value : this.jsonData,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxMessage(')
          ..write('id: $id, ')
          ..write('roomDocId: $roomDocId, ')
          ..write('jsonData: $jsonData, ')
          ..write('createdAtMs: $createdAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, roomDocId, jsonData, createdAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxMessage &&
          other.id == this.id &&
          other.roomDocId == this.roomDocId &&
          other.jsonData == this.jsonData &&
          other.createdAtMs == this.createdAtMs);
}

class OutboxMessagesCompanion extends UpdateCompanion<OutboxMessage> {
  final Value<int> id;
  final Value<String> roomDocId;
  final Value<String> jsonData;
  final Value<int> createdAtMs;
  const OutboxMessagesCompanion({
    this.id = const Value.absent(),
    this.roomDocId = const Value.absent(),
    this.jsonData = const Value.absent(),
    this.createdAtMs = const Value.absent(),
  });
  OutboxMessagesCompanion.insert({
    this.id = const Value.absent(),
    required String roomDocId,
    required String jsonData,
    this.createdAtMs = const Value.absent(),
  }) : roomDocId = Value(roomDocId),
       jsonData = Value(jsonData);
  static Insertable<OutboxMessage> custom({
    Expression<int>? id,
    Expression<String>? roomDocId,
    Expression<String>? jsonData,
    Expression<int>? createdAtMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (roomDocId != null) 'room_doc_id': roomDocId,
      if (jsonData != null) 'json_data': jsonData,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
    });
  }

  OutboxMessagesCompanion copyWith({
    Value<int>? id,
    Value<String>? roomDocId,
    Value<String>? jsonData,
    Value<int>? createdAtMs,
  }) {
    return OutboxMessagesCompanion(
      id: id ?? this.id,
      roomDocId: roomDocId ?? this.roomDocId,
      jsonData: jsonData ?? this.jsonData,
      createdAtMs: createdAtMs ?? this.createdAtMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (roomDocId.present) {
      map['room_doc_id'] = Variable<String>(roomDocId.value);
    }
    if (jsonData.present) {
      map['json_data'] = Variable<String>(jsonData.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxMessagesCompanion(')
          ..write('id: $id, ')
          ..write('roomDocId: $roomDocId, ')
          ..write('jsonData: $jsonData, ')
          ..write('createdAtMs: $createdAtMs')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedMessagesTable cachedMessages = $CachedMessagesTable(this);
  late final $CachedRoomsTable cachedRooms = $CachedRoomsTable(this);
  late final $LocalReadStateTable localReadState = $LocalReadStateTable(this);
  late final $OutboxMessagesTable outboxMessages = $OutboxMessagesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedMessages,
    cachedRooms,
    localReadState,
    outboxMessages,
  ];
}

typedef $$CachedMessagesTableCreateCompanionBuilder =
    CachedMessagesCompanion Function({
      required String firestoreDocId,
      required int roomId,
      Value<int> createdAtMs,
      Value<String> type,
      Value<String> senderName,
      Value<String> textPreview,
      required String jsonData,
      Value<int> rowid,
    });
typedef $$CachedMessagesTableUpdateCompanionBuilder =
    CachedMessagesCompanion Function({
      Value<String> firestoreDocId,
      Value<int> roomId,
      Value<int> createdAtMs,
      Value<String> type,
      Value<String> senderName,
      Value<String> textPreview,
      Value<String> jsonData,
      Value<int> rowid,
    });

class $$CachedMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedMessagesTable> {
  $$CachedMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get firestoreDocId => $composableBuilder(
    column: $table.firestoreDocId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get roomId => $composableBuilder(
    column: $table.roomId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderName => $composableBuilder(
    column: $table.senderName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textPreview => $composableBuilder(
    column: $table.textPreview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jsonData => $composableBuilder(
    column: $table.jsonData,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedMessagesTable> {
  $$CachedMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get firestoreDocId => $composableBuilder(
    column: $table.firestoreDocId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get roomId => $composableBuilder(
    column: $table.roomId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderName => $composableBuilder(
    column: $table.senderName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textPreview => $composableBuilder(
    column: $table.textPreview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jsonData => $composableBuilder(
    column: $table.jsonData,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedMessagesTable> {
  $$CachedMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get firestoreDocId => $composableBuilder(
    column: $table.firestoreDocId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get roomId =>
      $composableBuilder(column: $table.roomId, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get senderName => $composableBuilder(
    column: $table.senderName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get textPreview => $composableBuilder(
    column: $table.textPreview,
    builder: (column) => column,
  );

  GeneratedColumn<String> get jsonData =>
      $composableBuilder(column: $table.jsonData, builder: (column) => column);
}

class $$CachedMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedMessagesTable,
          CachedMessage,
          $$CachedMessagesTableFilterComposer,
          $$CachedMessagesTableOrderingComposer,
          $$CachedMessagesTableAnnotationComposer,
          $$CachedMessagesTableCreateCompanionBuilder,
          $$CachedMessagesTableUpdateCompanionBuilder,
          (
            CachedMessage,
            BaseReferences<_$AppDatabase, $CachedMessagesTable, CachedMessage>,
          ),
          CachedMessage,
          PrefetchHooks Function()
        > {
  $$CachedMessagesTableTableManager(
    _$AppDatabase db,
    $CachedMessagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> firestoreDocId = const Value.absent(),
                Value<int> roomId = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> senderName = const Value.absent(),
                Value<String> textPreview = const Value.absent(),
                Value<String> jsonData = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedMessagesCompanion(
                firestoreDocId: firestoreDocId,
                roomId: roomId,
                createdAtMs: createdAtMs,
                type: type,
                senderName: senderName,
                textPreview: textPreview,
                jsonData: jsonData,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String firestoreDocId,
                required int roomId,
                Value<int> createdAtMs = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> senderName = const Value.absent(),
                Value<String> textPreview = const Value.absent(),
                required String jsonData,
                Value<int> rowid = const Value.absent(),
              }) => CachedMessagesCompanion.insert(
                firestoreDocId: firestoreDocId,
                roomId: roomId,
                createdAtMs: createdAtMs,
                type: type,
                senderName: senderName,
                textPreview: textPreview,
                jsonData: jsonData,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedMessagesTable,
      CachedMessage,
      $$CachedMessagesTableFilterComposer,
      $$CachedMessagesTableOrderingComposer,
      $$CachedMessagesTableAnnotationComposer,
      $$CachedMessagesTableCreateCompanionBuilder,
      $$CachedMessagesTableUpdateCompanionBuilder,
      (
        CachedMessage,
        BaseReferences<_$AppDatabase, $CachedMessagesTable, CachedMessage>,
      ),
      CachedMessage,
      PrefetchHooks Function()
    >;
typedef $$CachedRoomsTableCreateCompanionBuilder =
    CachedRoomsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> sortOrder,
      required String jsonData,
    });
typedef $$CachedRoomsTableUpdateCompanionBuilder =
    CachedRoomsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> sortOrder,
      Value<String> jsonData,
    });

class $$CachedRoomsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedRoomsTable> {
  $$CachedRoomsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jsonData => $composableBuilder(
    column: $table.jsonData,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedRoomsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedRoomsTable> {
  $$CachedRoomsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jsonData => $composableBuilder(
    column: $table.jsonData,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedRoomsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedRoomsTable> {
  $$CachedRoomsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get jsonData =>
      $composableBuilder(column: $table.jsonData, builder: (column) => column);
}

class $$CachedRoomsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedRoomsTable,
          CachedRoom,
          $$CachedRoomsTableFilterComposer,
          $$CachedRoomsTableOrderingComposer,
          $$CachedRoomsTableAnnotationComposer,
          $$CachedRoomsTableCreateCompanionBuilder,
          $$CachedRoomsTableUpdateCompanionBuilder,
          (
            CachedRoom,
            BaseReferences<_$AppDatabase, $CachedRoomsTable, CachedRoom>,
          ),
          CachedRoom,
          PrefetchHooks Function()
        > {
  $$CachedRoomsTableTableManager(_$AppDatabase db, $CachedRoomsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedRoomsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedRoomsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedRoomsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> jsonData = const Value.absent(),
              }) => CachedRoomsCompanion(
                id: id,
                name: name,
                sortOrder: sortOrder,
                jsonData: jsonData,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required String jsonData,
              }) => CachedRoomsCompanion.insert(
                id: id,
                name: name,
                sortOrder: sortOrder,
                jsonData: jsonData,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedRoomsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedRoomsTable,
      CachedRoom,
      $$CachedRoomsTableFilterComposer,
      $$CachedRoomsTableOrderingComposer,
      $$CachedRoomsTableAnnotationComposer,
      $$CachedRoomsTableCreateCompanionBuilder,
      $$CachedRoomsTableUpdateCompanionBuilder,
      (
        CachedRoom,
        BaseReferences<_$AppDatabase, $CachedRoomsTable, CachedRoom>,
      ),
      CachedRoom,
      PrefetchHooks Function()
    >;
typedef $$LocalReadStateTableCreateCompanionBuilder =
    LocalReadStateCompanion Function({
      Value<int> roomId,
      Value<int> lastReadAtMs,
    });
typedef $$LocalReadStateTableUpdateCompanionBuilder =
    LocalReadStateCompanion Function({
      Value<int> roomId,
      Value<int> lastReadAtMs,
    });

class $$LocalReadStateTableFilterComposer
    extends Composer<_$AppDatabase, $LocalReadStateTable> {
  $$LocalReadStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get roomId => $composableBuilder(
    column: $table.roomId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastReadAtMs => $composableBuilder(
    column: $table.lastReadAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalReadStateTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalReadStateTable> {
  $$LocalReadStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get roomId => $composableBuilder(
    column: $table.roomId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastReadAtMs => $composableBuilder(
    column: $table.lastReadAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalReadStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalReadStateTable> {
  $$LocalReadStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get roomId =>
      $composableBuilder(column: $table.roomId, builder: (column) => column);

  GeneratedColumn<int> get lastReadAtMs => $composableBuilder(
    column: $table.lastReadAtMs,
    builder: (column) => column,
  );
}

class $$LocalReadStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalReadStateTable,
          LocalReadStateData,
          $$LocalReadStateTableFilterComposer,
          $$LocalReadStateTableOrderingComposer,
          $$LocalReadStateTableAnnotationComposer,
          $$LocalReadStateTableCreateCompanionBuilder,
          $$LocalReadStateTableUpdateCompanionBuilder,
          (
            LocalReadStateData,
            BaseReferences<
              _$AppDatabase,
              $LocalReadStateTable,
              LocalReadStateData
            >,
          ),
          LocalReadStateData,
          PrefetchHooks Function()
        > {
  $$LocalReadStateTableTableManager(
    _$AppDatabase db,
    $LocalReadStateTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalReadStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalReadStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalReadStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> roomId = const Value.absent(),
                Value<int> lastReadAtMs = const Value.absent(),
              }) => LocalReadStateCompanion(
                roomId: roomId,
                lastReadAtMs: lastReadAtMs,
              ),
          createCompanionCallback:
              ({
                Value<int> roomId = const Value.absent(),
                Value<int> lastReadAtMs = const Value.absent(),
              }) => LocalReadStateCompanion.insert(
                roomId: roomId,
                lastReadAtMs: lastReadAtMs,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalReadStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalReadStateTable,
      LocalReadStateData,
      $$LocalReadStateTableFilterComposer,
      $$LocalReadStateTableOrderingComposer,
      $$LocalReadStateTableAnnotationComposer,
      $$LocalReadStateTableCreateCompanionBuilder,
      $$LocalReadStateTableUpdateCompanionBuilder,
      (
        LocalReadStateData,
        BaseReferences<_$AppDatabase, $LocalReadStateTable, LocalReadStateData>,
      ),
      LocalReadStateData,
      PrefetchHooks Function()
    >;
typedef $$OutboxMessagesTableCreateCompanionBuilder =
    OutboxMessagesCompanion Function({
      Value<int> id,
      required String roomDocId,
      required String jsonData,
      Value<int> createdAtMs,
    });
typedef $$OutboxMessagesTableUpdateCompanionBuilder =
    OutboxMessagesCompanion Function({
      Value<int> id,
      Value<String> roomDocId,
      Value<String> jsonData,
      Value<int> createdAtMs,
    });

class $$OutboxMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxMessagesTable> {
  $$OutboxMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get roomDocId => $composableBuilder(
    column: $table.roomDocId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jsonData => $composableBuilder(
    column: $table.jsonData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxMessagesTable> {
  $$OutboxMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roomDocId => $composableBuilder(
    column: $table.roomDocId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jsonData => $composableBuilder(
    column: $table.jsonData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxMessagesTable> {
  $$OutboxMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get roomDocId =>
      $composableBuilder(column: $table.roomDocId, builder: (column) => column);

  GeneratedColumn<String> get jsonData =>
      $composableBuilder(column: $table.jsonData, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );
}

class $$OutboxMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxMessagesTable,
          OutboxMessage,
          $$OutboxMessagesTableFilterComposer,
          $$OutboxMessagesTableOrderingComposer,
          $$OutboxMessagesTableAnnotationComposer,
          $$OutboxMessagesTableCreateCompanionBuilder,
          $$OutboxMessagesTableUpdateCompanionBuilder,
          (
            OutboxMessage,
            BaseReferences<_$AppDatabase, $OutboxMessagesTable, OutboxMessage>,
          ),
          OutboxMessage,
          PrefetchHooks Function()
        > {
  $$OutboxMessagesTableTableManager(
    _$AppDatabase db,
    $OutboxMessagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> roomDocId = const Value.absent(),
                Value<String> jsonData = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
              }) => OutboxMessagesCompanion(
                id: id,
                roomDocId: roomDocId,
                jsonData: jsonData,
                createdAtMs: createdAtMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String roomDocId,
                required String jsonData,
                Value<int> createdAtMs = const Value.absent(),
              }) => OutboxMessagesCompanion.insert(
                id: id,
                roomDocId: roomDocId,
                jsonData: jsonData,
                createdAtMs: createdAtMs,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxMessagesTable,
      OutboxMessage,
      $$OutboxMessagesTableFilterComposer,
      $$OutboxMessagesTableOrderingComposer,
      $$OutboxMessagesTableAnnotationComposer,
      $$OutboxMessagesTableCreateCompanionBuilder,
      $$OutboxMessagesTableUpdateCompanionBuilder,
      (
        OutboxMessage,
        BaseReferences<_$AppDatabase, $OutboxMessagesTable, OutboxMessage>,
      ),
      OutboxMessage,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedMessagesTableTableManager get cachedMessages =>
      $$CachedMessagesTableTableManager(_db, _db.cachedMessages);
  $$CachedRoomsTableTableManager get cachedRooms =>
      $$CachedRoomsTableTableManager(_db, _db.cachedRooms);
  $$LocalReadStateTableTableManager get localReadState =>
      $$LocalReadStateTableTableManager(_db, _db.localReadState);
  $$OutboxMessagesTableTableManager get outboxMessages =>
      $$OutboxMessagesTableTableManager(_db, _db.outboxMessages);
}
