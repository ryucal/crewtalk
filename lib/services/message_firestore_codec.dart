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
    case 'text':
    default:
      return MessageType.text;
  }
}

RoomType? roomTypeFromWire(String? s) {
  switch (s) {
    case 'vendor':
      return RoomType.vendor;
    case 'normal':
      return RoomType.normal;
    default:
      return null;
  }
}

String? roomTypeToWire(RoomType? t) {
  if (t == null) return null;
  return t == RoomType.vendor ? 'vendor' : 'normal';
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
  final m = Map<String, dynamic>.from(raw as Map);
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

  static Map<String, dynamic> toDocumentFields(MessageModel m) {
    return {
      'clientId': m.id,
      'userId': m.userId,
      'name': m.name,
      'avatar': m.avatar,
      'car': m.car,
      'route': m.route,
      'subRoute': m.subRoute,
      'text': m.text,
      'time': m.time,
      'date': m.date,
      'type': messageTypeToWire(m.type),
      'reportData': m.reportData != null ? _reportToMap(m.reportData!) : null,
      'reactions': reactionsToFirestore(m.reactions),
      'vendorData': m.vendorData != null ? _vendorToMap(m.vendorData!) : null,
      'imageUrl': m.imageUrl,
      'phone': m.phone,
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

    return MessageModel(
      id: clientId,
      firestoreDocId: doc.id,
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
      imageUrl: d['imageUrl'] as String?,
      phone: d['phone'] as String?,
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
