import '../models/company_model.dart';
import '../models/room_model.dart';
import '../models/message_model.dart';

// ─── 샘플 소속 ────────────────────────────────────────────────
const List<CompanyModel> sampleCompanies = [
  CompanyModel(name: '크루', password: '1111'),
  CompanyModel(name: '더크루', password: '2222'),
  CompanyModel(name: '강남', password: '3333'),
  CompanyModel(name: '가자고', password: '4444'),
  CompanyModel(name: '가고파', password: '5555'),
  CompanyModel(name: '리바스', password: '6666'),
  CompanyModel(name: '케이오림', password: '7777'),
];

// ─── 샘플 채팅방 ──────────────────────────────────────────────
const List<RoomModel> sampleRooms = [
  RoomModel(id: 1, name: '독성리', lastMsg: '홍길동  78사 2918  독성리  출근 41명', time: '09:12', unread: 3, companies: ['크루', '더크루']),
  RoomModel(id: 2, name: '가좌리', lastMsg: '김철수  72바 1234  가좌리  퇴근 38명', time: '08:55', unread: 0, companies: ['크루']),
  RoomModel(id: 3, name: '용인 외부셔틀', lastMsg: '박영희  15나 5678  용인 외부셔틀  출근 44명', time: '08:40', unread: 1, companies: ['강남']),
  RoomModel(id: 4, name: '천리', lastMsg: '이민수  33가 9999  천리  출근 45명', time: '08:30', unread: 0, companies: ['더크루', '가자고']),
  RoomModel(id: 5, name: '백암', lastMsg: '최지영  55나 7777  백암  출근 44명', time: '08:10', unread: 2, companies: ['가자고']),
  RoomModel(id: 999, name: '운행 관리 현황', lastMsg: '오전 집계가 업데이트됩니다', time: '', unread: 0, adminOnly: true),
  RoomModel(id: 998, name: '기사·차량 관리', lastMsg: '이름 또는 차량번호로 검색하세요', time: '', unread: 0, adminOnly: true),
];

// ─── 샘플 기사 DB ─────────────────────────────────────────────
class DriverDb {
  final int id;
  final String name;
  final String phone;
  final String company;
  final String car;
  final String note;
  final String specialNote;

  const DriverDb({
    required this.id,
    required this.name,
    required this.phone,
    required this.company,
    required this.car,
    this.note = '',
    this.specialNote = '',
  });
}

const List<DriverDb> driverDb = [
  DriverDb(id: 1, name: '홍길동', phone: '010-1234-5678', company: '크루', car: '경기 78사 2918호'),
  DriverDb(id: 2, name: '김철수', phone: '010-2345-6789', company: '크루', car: '경기 72바 1234호', note: '야간 운행 불가', specialNote: '야간 운행 불가'),
  DriverDb(id: 3, name: '박영희', phone: '010-3456-7890', company: '더크루', car: '경기 15나 5678호'),
  DriverDb(id: 4, name: '이민수', phone: '010-4567-8901', company: '강남', car: '경기 33가 9999호', note: '신규 기사', specialNote: '신규 기사 (2026년 3월 입사)'),
  DriverDb(id: 5, name: '최지영', phone: '010-5678-9012', company: '가자고', car: '경기 55나 7777호'),
];

// ─── 샘플 차량 DB ─────────────────────────────────────────────
class VehicleDb {
  final int id;
  final String carNumber;
  final String model;
  final int capacity;
  final String inspectionExpiry;
  final String driver;
  final String note;

  const VehicleDb({
    required this.id,
    required this.carNumber,
    required this.model,
    required this.capacity,
    required this.inspectionExpiry,
    required this.driver,
    this.note = '',
  });
}

const List<VehicleDb> vehicleDb = [
  VehicleDb(id: 1, carNumber: '경기 78사 2918호', model: '현대 유니버스', capacity: 45, inspectionExpiry: '2026-08-15', driver: '홍길동'),
  VehicleDb(id: 2, carNumber: '경기 72바 1234호', model: '현대 에어로', capacity: 41, inspectionExpiry: '2026-07-01', driver: '김철수'),
  VehicleDb(id: 3, carNumber: '경기 15나 5678호', model: '기아 그랜버드', capacity: 44, inspectionExpiry: '2027-01-20', driver: '박영희', note: '에어컨 점검 필요'),
  VehicleDb(id: 4, carNumber: '경기 33가 9999호', model: '현대 유니버스', capacity: 45, inspectionExpiry: '2026-10-05', driver: '이민수'),
  VehicleDb(id: 5, carNumber: '경기 55나 7777호', model: '기아 그랜버드', capacity: 44, inspectionExpiry: '2027-04-15', driver: '최지영'),
];

// ─── 샘플 메시지 ──────────────────────────────────────────────
final List<MessageModel> sampleMessages = [
  const MessageModel(
    id: 1, userId: 'admin', name: '관리자',
    text: '오늘도 안전 운행 부탁드립니다 🙏',
    time: '07:30', date: '2026-03-10', type: MessageType.text, isMe: false,
  ),
  MessageModel(
    id: 2, userId: 'user2', name: '김철수', avatar: '철',
    car: '경기 72바 1234', route: 'A노선',
    time: '08:10', date: '2026-03-10', type: MessageType.report, isMe: false,
    reportData: const ReportData(type: '출근', count: 38, maxCount: 41),
  ),
  MessageModel(
    id: 3, userId: 'user3', name: '박영희', avatar: '영',
    car: '경기 15나 5678', route: 'B노선',
    time: '08:22', date: '2026-03-11', type: MessageType.report, isMe: false,
    reportData: const ReportData(type: '출근', count: 44, maxCount: 44, isOverCapacity: true),
  ),
  const MessageModel(
    id: 4, userId: 'me', name: '홍길동', avatar: '길',
    car: '경기 33가 9999', route: 'C노선',
    text: '오늘 날씨 좋네요!',
    time: '08:45', date: '2026-03-11', type: MessageType.text, isMe: true,
  ),
];

// DB 채팅방 초기 메시지
List<MessageModel> initialDbMessages(String todayDate) => [
  MessageModel(
    id: 1, userId: 'system', name: '시스템',
    text: '이름 또는 차량번호(숫자 4자리)를 입력하면 기사·차량 정보를 조회할 수 있어요.',
    time: '', date: todayDate, type: MessageType.text, isMe: false,
  ),
];
