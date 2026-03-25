import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../models/room_model.dart';
import '../models/message_model.dart';
import '../models/company_model.dart';
import '../services/auth_repository.dart';
import '../services/user_session_storage.dart';
import '../utils/sample_data.dart';
import '../utils/helpers.dart';

// ─── 유저 ─────────────────────────────────────────────────────
class UserNotifier extends StateNotifier<UserModel?> {
  UserNotifier([super.state]);

  Future<void> login(UserModel user) async {
    state = user;
    await UserSessionStorage.saveUser(user);
  }

  Future<void> logout() async {
    await AuthRepository.signOutFirebase();
    state = null;
    await UserSessionStorage.clear();
  }

  Future<void> update(UserModel user) async {
    state = user;
    await UserSessionStorage.saveUser(user);
  }
}

final userProvider = StateNotifierProvider<UserNotifier, UserModel?>(
  (ref) => UserNotifier(),
);

// ─── 소속 ─────────────────────────────────────────────────────
class CompanyNotifier extends StateNotifier<List<CompanyModel>> {
  CompanyNotifier() : super(sampleCompanies);

  void add(CompanyModel company) => state = [...state, company];
  void remove(int index) {
    final list = [...state];
    list.removeAt(index);
    state = list;
  }
  void update(List<CompanyModel> companies) => state = companies;
}

final companyProvider = StateNotifierProvider<CompanyNotifier, List<CompanyModel>>(
  (ref) => CompanyNotifier(),
);

// ─── 채팅방 ───────────────────────────────────────────────────
class RoomNotifier extends StateNotifier<List<RoomModel>> {
  RoomNotifier() : super(sampleRooms);

  void add(RoomModel room) => state = [...state, room];
  void remove(int id) => state = state.where((r) => r.id != id).toList();
  void reorder(List<RoomModel> rooms) => state = rooms;
  void pin(int id, bool pinned) {
    state = state.map((r) => r.id == id ? r.copyWith(pinned: pinned) : r).toList();
  }
  void updateRoom(int id, RoomModel Function(RoomModel) updater) {
    state = state.map((r) => r.id == id ? updater(r) : r).toList();
  }
}

final roomProvider = StateNotifierProvider<RoomNotifier, List<RoomModel>>(
  (ref) => RoomNotifier(),
);

// ─── 일반 메시지 ──────────────────────────────────────────────
class MessageNotifier extends StateNotifier<List<MessageModel>> {
  MessageNotifier() : super(sampleMessages);

  void add(MessageModel msg) => state = [...state, msg];
  void addAll(List<MessageModel> msgs) => state = [...state, ...msgs];
  void remove(int id) => state = state.where((m) => m.id != id).toList();
  void editText(int id, String newText) {
    state = state.map((m) => m.id == id ? m.copyWith(text: newText) : m).toList();
  }
  void react(int msgId, String emoji, String userName) {
    state = state.map((m) {
      if (m.id != msgId) return m;
      final reactions = Map<String, List<String>>.from(
        m.reactions.map((k, v) => MapEntry(k, List<String>.from(v))),
      );
      final users = reactions[emoji] ?? [];
      if (users.contains(userName)) {
        users.remove(userName);
      } else {
        users.add(userName);
      }
      reactions[emoji] = users;
      return m.copyWith(reactions: reactions);
    }).toList();
  }
}

final messageProvider = StateNotifierProvider<MessageNotifier, List<MessageModel>>(
  (ref) => MessageNotifier(),
);

// ─── 운행 관리 현황 메시지 (id:999) ──────────────────────────
class AdminMessageNotifier extends StateNotifier<List<MessageModel>> {
  AdminMessageNotifier() : super([]);

  void upsertSummary(MessageModel summary) {
    final exists = state.any((m) => m.date == summary.date && m.type == MessageType.summary);
    if (exists) {
      state = state.map((m) =>
        (m.date == summary.date && m.type == MessageType.summary) ? summary : m
      ).toList();
    } else {
      state = [...state, summary];
    }
  }
}

final adminMessageProvider = StateNotifierProvider<AdminMessageNotifier, List<MessageModel>>(
  (ref) => AdminMessageNotifier(),
);

// ─── 기사·차량 관리 메시지 (id:998) ──────────────────────────
class DbMessageNotifier extends StateNotifier<List<MessageModel>> {
  DbMessageNotifier() : super(initialDbMessages(dateToday()));

  void add(MessageModel msg) => state = [...state, msg];
}

final dbMessageProvider = StateNotifierProvider<DbMessageNotifier, List<MessageModel>>(
  (ref) => DbMessageNotifier(),
);

// ─── 현재 열린 채팅방 ─────────────────────────────────────────
final currentRoomProvider = StateProvider<RoomModel?>((ref) => null);

// ─── 인원보고 재전송 쿨다운 (종료 시각 저장) ──────────────────
// 앱 어디서든 패널/방 이동과 무관하게 유지됨
final reportCooldownEndProvider = StateProvider<DateTime?>((ref) => null);
