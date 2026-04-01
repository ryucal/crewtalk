import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/message_model.dart';
import '../models/room_model.dart';

String messageTypeToWire(MessageType t) {
  switch (t) {
    case MessageType.text:
      return 'text';
    case MessageType.report:
      return 'report';
    case MessageType.vendorReport:
      return 'vendorReport';
    case MessageType.notice:
      return 'notice';
    case MessageType.image:
      return 'image';
    case MessageType.emergency:
      return 'emergency';
    case MessageType.dbResult:
      return 'dbResult';
    case MessageType.summary:
      return 'summary';
    case MessageType.maintenance:
      return 'maintenance';
  }
}

MessageType messageTypeFromWire(String? s) {
  switch (s) {
    case 'report':
      return MessageType.report;
    case 'vendorReport':
      return MessageType.vendorReport;
    case 'notice':
      return MessageType.notice;
    case 'image':
      return MessageType.image;
    case 'emergency':
      return MessageType.emergency;
    case 'dbResult':
      return MessageType.dbResult;
    case 'summary':
      return MessageType.summary;
    case 'maintenance':
      return MessageType.maintenance;
    case 'text':
    default:
      return MessageType.text;
  }
}

RoomType? roomTypeFromWire(String? s) {
  switch (s) {
    case 'vendor':
      return RoomType.vendor;
    case 'maintenance':
      return RoomType.maintenance;
    case 'normal':
      return RoomType.normal;
    default:
      return null;
  }
}

String? roomTypeToWire(RoomType? t) {
  if (t == null) return null;
  switch (t) {
    case RoomType.vendor:
      return 'vendor';
    case RoomType.maintenance:
      return 'maintenance';
    case RoomType.normal:
      return 'normal';
  }
}

Map<String, dynamic> _reportToMap(ReportData r) => {
      'type': r.type,
      'count': r.count,
      'maxCount': r.maxCount,
      'isOverCapacity': r.isOverCapacity,
    };

ReportData? _reportFromMap(dynamic raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  return ReportData(
    type: m['type'] as String? ?? '출근',
    count: (m['count'] as num?)?.toInt() ?? 0,
    maxCount: (m['maxCount'] as num?)?.toInt() ?? 0,
    isOverCapacity: m['isOverCapacity'] as bool? ?? false,
  );
}

Map<String, dynamic> _vendorToMap(VendorData v) => {
      'company': v.company,
      'operationDateTime': v.operationDateTime,
      'departure': v.departure,
      'destination': v.destination,
      'passengerCount': v.passengerCount,
      'distanceKm': v.distanceKm,
      'reserver': v.reserver,
      'specialNote': v.specialNote,
    };

VendorData? _vendorFromMap(dynamic raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  return VendorData(
    company: m['company'] as String? ?? '',
    operationDateTime: m['operationDateTime'] as String? ?? '',
    departure: m['departure'] as String? ?? '',
    destination: m['destination'] as String? ?? '',
    passengerCount: m['passengerCount'] as String? ?? '',
    distanceKm: m['distanceKm'] as String? ?? '',
    reserver: m['reserver'] as String? ?? '',
    specialNote: m['specialNote'] as String? ?? '',
  );
}

Map<String, dynamic> _summaryLineToMap(SummaryLine l) => {
      'name': l.name,
      'total': l.total,
      'reported': l.reported,
      'subLines': l.subLines.map(_summaryLineToMap).toList(),
    };

SummaryLine _summaryLineFromMap(dynamic raw) {
  if (raw is! Map) {
    return const SummaryLine(name: '', total: 0, reported: false);
  }
  final m = Map<String, dynamic>.from(raw);
  final subs = (m['subLines'] as List<dynamic>?) ?? [];
  return SummaryLine(
    name: m['name'] as String? ?? '',
    total: (m['total'] as num?)?.toInt() ?? 0,
    reported: m['reported'] as bool? ?? false,
    subLines: subs.map(_summaryLineFromMap).toList(),
  );
}

Map<String, dynamic>? _dbResultToMap(DbResultCard? c) {
  if (c == null) return null;
  return {
    'searchType': c.searchType,
    'name': c.name,
    'phone': c.phone,
    'company': c.company,
    'car': c.car,
    'route': c.route,
    'subRoute': c.subRoute,
    'reportData': c.reportData != null ? _reportToMap(c.reportData!) : null,
    'reportDateTime': c.reportDateTime,
    'specialNote': c.specialNote,
  };
}

DbResultCard? _dbResultFromMap(dynamic raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  return DbResultCard(
    searchType: m['searchType'] as String? ?? 'name',
    name: m['name'] as String?,
    phone: m['phone'] as String?,
    company: m['company'] as String?,
    car: m['car'] as String?,
    route: m['route'] as String?,
    subRoute: m['subRoute'] as String?,
    reportData: _reportFromMap(m['reportData']),
    reportDateTime: m['reportDateTime'] as String?,
    specialNote: m['specialNote'] as String?,
  );
}

Map<String, dynamic> _maintenanceToMap(MaintenanceData m) => {
      'car': m.car,
      'driverName': m.driverName,
      'phone': m.phone,
      'occurredAt': m.occurredAt,
      'symptom': m.symptom,
      'driveability': m.driveability,
      'photoUrls': m.photoUrls,
      'specialNote': m.specialNote,
      'status': m.status,
    };

MaintenanceData? _maintenanceFromMap(dynamic raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  final photos = <String>[];
  final rawPhotos = m['photoUrls'];
  if (rawPhotos is List) {
    for (final e in rawPhotos) {
      if (e is String && e.trim().isNotEmpty) photos.add(e);
    }
  }
  return MaintenanceData(
    car: m['car'] as String? ?? '',
    driverName: m['driverName'] as String? ?? '',
    phone: m['phone'] as String? ?? '',
    occurredAt: m['occurredAt'] as String? ?? '',
    symptom: m['symptom'] as String? ?? '',
    driveability: m['driveability'] as String? ?? '',
    photoUrls: photos,
    specialNote: m['specialNote'] as String? ?? '',
    status: m['status'] as String? ?? '접수',
  );
}

Map<String, dynamic> reactionsToFirestore(Map<String, List<String>> r) {
  final out = <String, dynamic>{};
  for (final e in r.entries) {
    out[e.key] = e.value;
  }
  return out;
}

Map<String, List<String>> reactionsFromFirestore(dynamic raw) {
  if (raw is! Map) return {};
  final m = Map<String, dynamic>.from(raw);
  final out = <String, List<String>>{};
  for (final e in m.entries) {
    final v = e.value;
    if (v is List) {
      out[e.key] = v.map((x) => x.toString()).toList();
    }
  }
  return out;
}

/// Firestore 메시지 문서 필드 (루트에 펼쳐서 저장 — collectionGroup 필터용)
class MessageFirestoreCodec {
  MessageFirestoreCodec._();

  static Map<String, dynamic> _imageWireFields(MessageModel m) {
    final src = m.imageSources;
    if (src.isEmpty) {
      return {'imageUrl': null, 'imageUrls': null};
    }
    return {
      'imageUrl': src.first,
      'imageUrls': src.length > 1 ? src : null,
    };
  }

  static Map<String, dynamic> toDocumentFields(MessageModel m) {
    return {
      'clientId': m.id,
      'userId': m.userId,
      'name': m.name,
      'avatar': m.avatar,
      'car': m.car,
      'route': m.route,
      'subRoute': m.subRoute,
      'text': m.text ?? '',
      'time': m.time,
      'date': m.date,
      'type': messageTypeToWire(m.type),
      'reportData': m.reportData != null ? _reportToMap(m.reportData!) : null,
      'reactions': reactionsToFirestore(m.reactions),
      'vendorData': m.vendorData != null ? _vendorToMap(m.vendorData!) : null,
      'maintenanceData': m.maintenanceData != null ? _maintenanceToMap(m.maintenanceData!) : null,
      ..._imageWireFields(m),
      'phone': m.phone,
      'company': m.company,
      'carLast4': m.carLast4,
      'emergencyType': m.emergencyType,
      'resultCard': _dbResultToMap(m.resultCard),
      'morningLines': m.morningLines?.map(_summaryLineToMap).toList(),
      'eveningLines': m.eveningLines?.map(_summaryLineToMap).toList(),
      'morningTotal': m.morningTotal,
      'eveningTotal': m.eveningTotal,
      'unreported': m.unreported,
      'emoji': m.emoji,
      'noticeForRoomType': roomTypeToWire(m.noticeForRoomType),
    };
  }

  static MessageModel fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String? myFirebaseUid,
  ) {
    final d = doc.data() ?? {};
    final type = messageTypeFromWire(d['type'] as String?);
    final uid = d['userId'] as String? ?? '';
    final isMe = myFirebaseUid != null && myFirebaseUid.isNotEmpty && uid == myFirebaseUid;
    final clientId = (d['clientId'] as num?)?.toInt() ?? doc.id.hashCode.abs();
    int? createdAtMs;
    final ca = d['createdAt'];
    if (ca is Timestamp) {
      createdAtMs = ca.millisecondsSinceEpoch;
    }

    List<String> parsedImgUrls = [];
    final rawUrls = d['imageUrls'];
    if (rawUrls is List) {
      for (final e in rawUrls) {
        if (e is String && e.trim().isNotEmpty) parsedImgUrls.add(e);
      }
    }
    if (parsedImgUrls.isEmpty) {
      final one = d['imageUrl'] as String?;
      if (one != null && one.trim().isNotEmpty) parsedImgUrls = [one];
    }
    final parsedImageUrl = parsedImgUrls.isNotEmpty ? parsedImgUrls.first : null;
    final parsedImageUrlsMulti =
        parsedImgUrls.length > 1 ? List<String>.from(parsedImgUrls) : const <String>[];

    return MessageModel(
      id: clientId,
      firestoreDocId: doc.id,
      createdAtMs: createdAtMs,
      userId: uid,
      name: d['name'] as String? ?? '',
      avatar: d['avatar'] as String?,
      car: d['car'] as String?,
      route: d['route'] as String?,
      subRoute: d['subRoute'] as String?,
      text: d['text'] as String?,
      time: d['time'] as String? ?? '',
      date: d['date'] as String? ?? '',
      type: type,
      isMe: isMe,
      reportData: _reportFromMap(d['reportData']),
      reactions: reactionsFromFirestore(d['reactions']),
      vendorData: _vendorFromMap(d['vendorData']),
      maintenanceData: _maintenanceFromMap(d['maintenanceData']),
      imageUrl: parsedImageUrl,
      imageUrls: parsedImageUrlsMulti,
      phone: d['phone'] as String?,
      company: d['company'] as String?,
      carLast4: d['carLast4'] as String?,
      emergencyType: d['emergencyType'] as String?,
      resultCard: _dbResultFromMap(d['resultCard']),
      morningLines: (d['morningLines'] as List<dynamic>?)?.map(_summaryLineFromMap).toList(),
      eveningLines: (d['eveningLines'] as List<dynamic>?)?.map(_summaryLineFromMap).toList(),
      morningTotal: (d['morningTotal'] as num?)?.toInt(),
      eveningTotal: (d['eveningTotal'] as num?)?.toInt(),
      unreported: (d['unreported'] as num?)?.toInt(),
      emoji: d['emoji'] as String?,
      noticeForRoomType: roomTypeFromWire(d['noticeForRoomType'] as String?),
    );
  }
}
