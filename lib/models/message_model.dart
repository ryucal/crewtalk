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

  // image 전용
  final String? imageUrl;

  // emergency 전용
  final String? phone;
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
    this.imageUrl,
    this.phone,
    this.emergencyType,
    this.resultCard,
    this.morningLines,
    this.eveningLines,
    this.morningTotal,
    this.eveningTotal,
    this.unreported,
    this.emoji,
    this.noticeForRoomType,
  });

  MessageModel copyWith({
    String? text,
    Map<String, List<String>>? reactions,
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
      imageUrl: imageUrl,
      phone: phone,
      emergencyType: emergencyType,
      resultCard: resultCard,
      morningLines: morningLines,
      eveningLines: eveningLines,
      morningTotal: morningTotal,
      eveningTotal: eveningTotal,
      unreported: unreported,
      emoji: emoji,
      noticeForRoomType: noticeForRoomType,
    );
  }
}
