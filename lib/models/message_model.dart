import 'dart:convert';

import 'room_model.dart';

enum MessageType {
  text,
  report,
  vendorReport,
  notice,
  image,
  emergency,
  dbResult,
  summary,
  maintenance,
}

class ReportData {
  final String type; // '출근' | '퇴근'
  final int count;
  final int maxCount;
  final bool isOverCapacity;

  const ReportData({
    required this.type,
    required this.count,
    required this.maxCount,
    this.isOverCapacity = false,
  });
}

/// 솔라티(구 하청업체) 인원보고 데이터
class VendorData {
  final String company;
  final String operationDateTime;
  final String departure;
  final String destination;
  final String passengerCount;
  final String distanceKm;
  final String reserver;
  final String specialNote;

  const VendorData({
    required this.company,
    required this.operationDateTime,
    required this.departure,
    required this.destination,
    required this.passengerCount,
    required this.distanceKm,
    required this.reserver,
    this.specialNote = '',
  });
}

/// 차량 정비 접수 데이터
class MaintenanceData {
  final String car;
  final String driverName;
  final String phone;
  final String occurredAt;
  final String symptom;
  /// '정상 운행 가능' | '조심 운행 가능' | '즉시 점검 필요'
  final String driveability;
  final List<String> photoUrls;
  final String specialNote;
  /// '접수' | '정비예정' | '정비완료'
  final String status;

  const MaintenanceData({
    required this.car,
    required this.driverName,
    required this.phone,
    required this.occurredAt,
    required this.symptom,
    required this.driveability,
    this.photoUrls = const [],
    this.specialNote = '',
    this.status = '접수',
  });

  MaintenanceData copyWith({String? status}) {
    return MaintenanceData(
      car: car,
      driverName: driverName,
      phone: phone,
      occurredAt: occurredAt,
      symptom: symptom,
      driveability: driveability,
      photoUrls: photoUrls,
      specialNote: specialNote,
      status: status ?? this.status,
    );
  }
}

class SummaryLine {
  final String name;
  final int total;
  final bool reported;
  final List<SummaryLine> subLines;

  const SummaryLine({
    required this.name,
    required this.total,
    required this.reported,
    this.subLines = const [],
  });
}

class DbResultCard {
  final String searchType; // 'name' | 'car'
  final String? name;
  final String? phone;
  final String? company;
  final String? car;
  final String? route;
  final String? subRoute;
  final ReportData? reportData;
  final String? reportDateTime;
  final String? specialNote;

  const DbResultCard({
    required this.searchType,
    this.name,
    this.phone,
    this.company,
    this.car,
    this.route,
    this.subRoute,
    this.reportData,
    this.reportDateTime,
    this.specialNote,
  });
}

class MessageModel {
  final int id;
  final String userId;
  final String name;
  final String? avatar;
  final String? car;
  final String? route;
  final String? subRoute;
  final String? text;
  final String time;
  final String date;
  final MessageType type;
  final bool isMe;
  final ReportData? reportData;
  final Map<String, List<String>> reactions;

  // report 전용
  final VendorData? vendorData;

  // maintenance 전용
  final MaintenanceData? maintenanceData;

  // image 전용 — 단일은 imageUrl, 2장 이상 묶음은 imageUrls(첫 장은 imageUrl에도 저장해 구버전 호환)
  final String? imageUrl;
  final List<String> imageUrls;

  // report/emergency 공용
  final String? phone;
  final String? company;
  final String? carLast4;

  // emergency 전용
  final String? emergencyType;

  // dbResult 전용
  final DbResultCard? resultCard;

  // summary 전용
  final List<SummaryLine>? morningLines;
  final List<SummaryLine>? eveningLines;
  final int? morningTotal;
  final int? eveningTotal;
  final int? unreported;
  final String? emoji;

  /// 전체 공지(`notice`)만 사용. null이면 일반·솔라티 모든 채팅방에 표시, 값이 있으면 해당 `RoomType` 채팅방에만 표시.
  final RoomType? noticeForRoomType;

  /// `rooms/{roomId}/messages/{docId}` 문서 ID (Firestore 연동 시)
  final String? firestoreDocId;

  /// Firestore `createdAt` (읽음 구분선 등 정렬·비교용). 로컬 전용 메시지는 null일 수 있음.
  final int? createdAtMs;

  const MessageModel({
    required this.id,
    required this.userId,
    required this.name,
    this.avatar,
    this.car,
    this.route,
    this.subRoute,
    this.text,
    required this.time,
    required this.date,
    required this.type,
    this.isMe = false,
    this.reportData,
    this.reactions = const {},
    this.vendorData,
    this.maintenanceData,
    this.imageUrl,
    this.imageUrls = const [],
    this.phone,
    this.company,
    this.carLast4,
    this.emergencyType,
    this.resultCard,
    this.morningLines,
    this.eveningLines,
    this.morningTotal,
    this.eveningTotal,
    this.unreported,
    this.emoji,
    this.noticeForRoomType,
    this.firestoreDocId,
    this.createdAtMs,
  });

  /// 말풍선·업로드용 URL 목록 (묶음 또는 단일)
  List<String> get imageSources {
    if (imageUrls.isNotEmpty) return List<String>.unmodifiable(imageUrls);
    if (imageUrl != null && imageUrl!.isNotEmpty) return [imageUrl!];
    return const [];
  }

  // ─── drift 캐시 직렬화 ─────────────────────────────────────────

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'avatar': avatar,
      'car': car,
      'route': route,
      'subRoute': subRoute,
      'text': text,
      'time': time,
      'date': date,
      'type': type.name,
      'isMe': isMe,
      'phone': phone,
      'company': company,
      'carLast4': carLast4,
      'emergencyType': emergencyType,
      'firestoreDocId': firestoreDocId,
      'createdAtMs': createdAtMs,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'noticeForRoomType': noticeForRoomType?.name,
      'reactions': reactions.map((k, v) => MapEntry(k, v)),
      if (reportData != null) 'reportData': {
        'type': reportData!.type,
        'count': reportData!.count,
        'maxCount': reportData!.maxCount,
        'isOverCapacity': reportData!.isOverCapacity,
      },
      if (vendorData != null) 'vendorData': {
        'company': vendorData!.company,
        'operationDateTime': vendorData!.operationDateTime,
        'departure': vendorData!.departure,
        'destination': vendorData!.destination,
        'passengerCount': vendorData!.passengerCount,
        'distanceKm': vendorData!.distanceKm,
        'reserver': vendorData!.reserver,
        'specialNote': vendorData!.specialNote,
      },
      if (maintenanceData != null) 'maintenanceData': {
        'car': maintenanceData!.car,
        'driverName': maintenanceData!.driverName,
        'phone': maintenanceData!.phone,
        'occurredAt': maintenanceData!.occurredAt,
        'symptom': maintenanceData!.symptom,
        'driveability': maintenanceData!.driveability,
        'photoUrls': maintenanceData!.photoUrls,
        'specialNote': maintenanceData!.specialNote,
        'status': maintenanceData!.status,
      },
      if (resultCard != null) 'resultCard': {
        'searchType': resultCard!.searchType,
        'name': resultCard!.name,
        'phone': resultCard!.phone,
        'company': resultCard!.company,
        'car': resultCard!.car,
        'route': resultCard!.route,
        'subRoute': resultCard!.subRoute,
        'reportDateTime': resultCard!.reportDateTime,
        'specialNote': resultCard!.specialNote,
        if (resultCard!.reportData != null) 'reportData': {
          'type': resultCard!.reportData!.type,
          'count': resultCard!.reportData!.count,
          'maxCount': resultCard!.reportData!.maxCount,
          'isOverCapacity': resultCard!.reportData!.isOverCapacity,
        },
      },
      if (morningLines != null) 'morningLines': morningLines!.map((l) => {
        'name': l.name, 'total': l.total, 'reported': l.reported,
        'subLines': l.subLines.map((s) => {'name': s.name, 'total': s.total, 'reported': s.reported}).toList(),
      }).toList(),
      if (eveningLines != null) 'eveningLines': eveningLines!.map((l) => {
        'name': l.name, 'total': l.total, 'reported': l.reported,
        'subLines': l.subLines.map((s) => {'name': s.name, 'total': s.total, 'reported': s.reported}).toList(),
      }).toList(),
      'morningTotal': morningTotal,
      'eveningTotal': eveningTotal,
      'unreported': unreported,
      'emoji': emoji,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  static MessageModel fromJson(Map<String, dynamic> j, {String? currentUid}) {
    final typeStr = j['type'] as String? ?? 'text';
    final type = MessageType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => MessageType.text,
    );
    final userId = j['userId'] as String? ?? '';
    final isMe = currentUid != null && currentUid.isNotEmpty && userId == currentUid;

    ReportData? reportData;
    if (j['reportData'] is Map) {
      final rd = j['reportData'] as Map<String, dynamic>;
      reportData = ReportData(
        type: rd['type'] as String? ?? '',
        count: (rd['count'] as num?)?.toInt() ?? 0,
        maxCount: (rd['maxCount'] as num?)?.toInt() ?? 0,
        isOverCapacity: rd['isOverCapacity'] as bool? ?? false,
      );
    }

    VendorData? vendorData;
    if (j['vendorData'] is Map) {
      final vd = j['vendorData'] as Map<String, dynamic>;
      vendorData = VendorData(
        company: vd['company'] as String? ?? '',
        operationDateTime: vd['operationDateTime'] as String? ?? '',
        departure: vd['departure'] as String? ?? '',
        destination: vd['destination'] as String? ?? '',
        passengerCount: vd['passengerCount'] as String? ?? '',
        distanceKm: vd['distanceKm'] as String? ?? '',
        reserver: vd['reserver'] as String? ?? '',
        specialNote: vd['specialNote'] as String? ?? '',
      );
    }

    MaintenanceData? maintenanceData;
    if (j['maintenanceData'] is Map) {
      final md = j['maintenanceData'] as Map<String, dynamic>;
      maintenanceData = MaintenanceData(
        car: md['car'] as String? ?? '',
        driverName: md['driverName'] as String? ?? '',
        phone: md['phone'] as String? ?? '',
        occurredAt: md['occurredAt'] as String? ?? '',
        symptom: md['symptom'] as String? ?? '',
        driveability: md['driveability'] as String? ?? '',
        photoUrls: (md['photoUrls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
        specialNote: md['specialNote'] as String? ?? '',
        status: md['status'] as String? ?? '접수',
      );
    }

    final noticeRtStr = j['noticeForRoomType'] as String?;
    RoomType? noticeForRoomType;
    if (noticeRtStr != null) {
      noticeForRoomType = RoomType.values.firstWhere(
        (e) => e.name == noticeRtStr,
        orElse: () => RoomType.normal,
      );
    }

    final rawReactions = j['reactions'];
    final reactions = <String, List<String>>{};
    if (rawReactions is Map) {
      for (final e in rawReactions.entries) {
        reactions[e.key.toString()] =
            (e.value as List<dynamic>?)?.map((v) => v.toString()).toList() ?? [];
      }
    }

    DbResultCard? resultCard;
    if (j['resultCard'] is Map) {
      final rc = j['resultCard'] as Map<String, dynamic>;
      ReportData? rcReport;
      if (rc['reportData'] is Map) {
        final rrd = rc['reportData'] as Map<String, dynamic>;
        rcReport = ReportData(
          type: rrd['type'] as String? ?? '',
          count: (rrd['count'] as num?)?.toInt() ?? 0,
          maxCount: (rrd['maxCount'] as num?)?.toInt() ?? 0,
          isOverCapacity: rrd['isOverCapacity'] as bool? ?? false,
        );
      }
      resultCard = DbResultCard(
        searchType: rc['searchType'] as String? ?? 'name',
        name: rc['name'] as String?,
        phone: rc['phone'] as String?,
        company: rc['company'] as String?,
        car: rc['car'] as String?,
        route: rc['route'] as String?,
        subRoute: rc['subRoute'] as String?,
        reportData: rcReport,
        reportDateTime: rc['reportDateTime'] as String?,
        specialNote: rc['specialNote'] as String?,
      );
    }

    List<SummaryLine>? parseSummaryLines(dynamic raw) {
      if (raw is! List) return null;
      return raw.whereType<Map>().map<SummaryLine>((e) {
        final m = Map<String, dynamic>.from(e);
        return SummaryLine(
          name: m['name'] as String? ?? '',
          total: (m['total'] as num?)?.toInt() ?? 0,
          reported: m['reported'] as bool? ?? false,
          subLines: ((m['subLines'] as List<dynamic>?) ?? [])
              .whereType<Map>()
              .map<SummaryLine>((s) {
            final sm = Map<String, dynamic>.from(s);
            return SummaryLine(
              name: sm['name'] as String? ?? '',
              total: (sm['total'] as num?)?.toInt() ?? 0,
              reported: sm['reported'] as bool? ?? false,
            );
          }).toList(),
        );
      }).toList();
    }

    return MessageModel(
      id: (j['id'] as num?)?.toInt() ?? 0,
      userId: userId,
      name: j['name'] as String? ?? '',
      avatar: j['avatar'] as String?,
      car: j['car'] as String?,
      route: j['route'] as String?,
      subRoute: j['subRoute'] as String?,
      text: j['text'] as String?,
      time: j['time'] as String? ?? '',
      date: j['date'] as String? ?? '',
      type: type,
      isMe: isMe,
      reportData: reportData,
      reactions: reactions,
      vendorData: vendorData,
      maintenanceData: maintenanceData,
      imageUrl: j['imageUrl'] as String?,
      imageUrls: (j['imageUrls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      phone: j['phone'] as String?,
      company: j['company'] as String?,
      carLast4: j['carLast4'] as String?,
      emergencyType: j['emergencyType'] as String?,
      resultCard: resultCard,
      morningLines: parseSummaryLines(j['morningLines']),
      eveningLines: parseSummaryLines(j['eveningLines']),
      morningTotal: (j['morningTotal'] as num?)?.toInt(),
      eveningTotal: (j['eveningTotal'] as num?)?.toInt(),
      unreported: (j['unreported'] as num?)?.toInt(),
      emoji: j['emoji'] as String?,
      noticeForRoomType: noticeForRoomType,
      firestoreDocId: j['firestoreDocId'] as String?,
      createdAtMs: (j['createdAtMs'] as num?)?.toInt(),
    );
  }

  static MessageModel fromJsonString(String s, {String? currentUid}) =>
      fromJson(jsonDecode(s) as Map<String, dynamic>, currentUid: currentUid);

  MessageModel copyWith({
    String? text,
    Map<String, List<String>>? reactions,
    String? firestoreDocId,
    int? createdAtMs,
    String? imageUrl,
    List<String>? imageUrls,
    MaintenanceData? maintenanceData,
  }) {
    return MessageModel(
      id: id,
      userId: userId,
      name: name,
      avatar: avatar,
      car: car,
      route: route,
      subRoute: subRoute,
      text: text ?? this.text,
      time: time,
      date: date,
      type: type,
      isMe: isMe,
      reportData: reportData,
      reactions: reactions ?? this.reactions,
      vendorData: vendorData,
      maintenanceData: maintenanceData ?? this.maintenanceData,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      phone: phone,
      company: company,
      carLast4: carLast4,
      emergencyType: emergencyType,
      resultCard: resultCard,
      morningLines: morningLines,
      eveningLines: eveningLines,
      morningTotal: morningTotal,
      eveningTotal: eveningTotal,
      unreported: unreported,
      emoji: emoji,
      noticeForRoomType: noticeForRoomType,
      firestoreDocId: firestoreDocId ?? this.firestoreDocId,
      createdAtMs: createdAtMs ?? this.createdAtMs,
    );
  }
}
