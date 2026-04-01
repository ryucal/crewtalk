import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/calendar_item.dart';
import '../models/emergency_contact.dart';
import '../models/user_model.dart';
import '../models/room_model.dart';
import '../models/room_kakao_nav_link.dart';
import '../models/message_model.dart';
import '../services/auth_repository.dart';
import '../services/fcm_push_service.dart';
import '../services/chat_firestore_repository.dart';
import '../services/user_session_storage.dart';
import '../utils/sample_data.dart';
import '../utils/helpers.dart';

/// Firestore에 없고 앱에만 있는 관리용 채팅방 (998·999)
const List<RoomModel> kVirtualChatRooms = [
  RoomModel(id: 999, name: 'Work Hub', lastMsg: '', time: '', unread: 0, adminOnly: true),
  RoomModel(id: 998, name: '기사·차량 관리', lastMsg: '이름 또는 차량번호로 검색하세요', time: '', unread: 0, adminOnly: true),
];

// ─── 유저 ─────────────────────────────────────────────────────
class UserNotifier extends StateNotifier<UserModel?> {
  UserNotifier([super.state]) {
    _syncMutedRooms(state);
  }

  Future<void> login(UserModel user) async {
    state = user;
    _syncMutedRooms(user);
    await UserSessionStorage.saveUser(user);
  }

  Future<void> logout() async {
    final uid = state?.firebaseUid;
    try {
      await FcmPushService.unregisterCurrentDevice(uid);
    } catch (_) {}
    try {
      await AuthRepository.signOutFirebase();
    } catch (_) {}
    state = null;
    FcmPushService.mutedRoomIds = {};
    try {
      await UserSessionStorage.clear();
    } catch (_) {}
  }

  Future<void> update(UserModel user) async {
    state = user;
    _syncMutedRooms(user);
    await UserSessionStorage.saveUser(user);
  }

  /// mutedRooms를 FCM static 필드에 동기화
  void _syncMutedRooms(UserModel? user) {
    FcmPushService.mutedRoomIds = user != null ? Set.of(user.mutedRooms) : {};
  }

  void _persistPinnedRooms(UserModel user) {
    final uid = user.firebaseUid;
    if (uid != null && uid.isNotEmpty && AuthRepository.firebaseAvailable) {
      unawaited(ChatFirestoreRepository.setUserPinnedRoomIds(uid, user.pinnedRoomIds));
    }
  }

  /// 기사·매니저 등: 내 계정에만 상단 고정 (rooms 문서 쓰기 불필요)
  void setPersonalPinnedRooms(List<int> ids) {
    final u = state;
    if (u == null) return;
    final updated = u.copyWith(pinnedRoomIds: ids);
    state = updated;
    unawaited(UserSessionStorage.saveUser(updated));
    _persistPinnedRooms(updated);
  }

  void addPinnedRoom(int roomId) {
    if (roomId == 998 || roomId == 999) return;
    final u = state;
    if (u == null || u.pinnedRoomIds.contains(roomId)) return;
    setPersonalPinnedRooms([...u.pinnedRoomIds, roomId]);
  }

  void removePinnedRoom(int roomId) {
    final u = state;
    if (u == null || !u.pinnedRoomIds.contains(roomId)) return;
    setPersonalPinnedRooms(u.pinnedRoomIds.where((id) => id != roomId).toList());
  }

  /// 방 알림 음소거 토글
  Future<void> toggleRoomMute(int roomId) async {
    final user = state;
    if (user == null) return;
    final isMuted = user.isRoomMuted(roomId);
    final newList = isMuted
        ? user.mutedRooms.where((id) => id != roomId).toList()
        : [...user.mutedRooms, roomId];
    final updated = user.copyWith(mutedRooms: newList);
    state = updated;
    _syncMutedRooms(updated);
    await UserSessionStorage.saveUser(updated);
    final uid = user.firebaseUid;
    if (uid != null && uid.isNotEmpty && AuthRepository.firebaseAvailable) {
      await ChatFirestoreRepository.toggleMuteRoom(uid, roomId, mute: !isMuted);
    }
  }
}

final userProvider = StateNotifierProvider<UserNotifier, UserModel?>(
  (ref) => UserNotifier(),
);

// ─── 채팅방 ───────────────────────────────────────────────────
class RoomNotifier extends StateNotifier<List<RoomModel>> {
  RoomNotifier() : super(kVirtualChatRooms);

  /// Firestore `rooms` 스냅샷으로 일반 방 목록을 갱신합니다 (998·999는 유지).
  /// Firestore items에 lastMsg가 비어있으면 로컬에 이미 채워진 값을 유지합니다.
  void mergeFromFirestore(List<RoomModel> firestoreRooms) {
    final localMap = <int, RoomModel>{};
    for (final r in state) {
      localMap[r.id] = r;
    }
    final merged = firestoreRooms.map((r) {
      final local = localMap[r.id];
      if (local == null) return r;
      var result = r.copyWith(kakaoNavLinks: local.kakaoNavLinks);
      if (r.lastMsg.isEmpty && local.lastMsg.isNotEmpty) {
        result = result.copyWith(lastMsg: local.lastMsg, time: local.time);
      }
      if (local.unread > 0) {
        result = result.copyWith(unread: local.unread);
      }
      return result;
    }).toList();
    state = [...kVirtualChatRooms, ...merged];
  }

  /// `config/kakao_nav_links` 스냅샷으로 방별 카카오맵 링크 갱신
  void applyKakaoNavLinks(Map<int, List<RoomKakaoNavLink>> byRoomId) {
    state = state.map((r) {
      if (r.id == 998 || r.id == 999) return r;
      final links = byRoomId[r.id];
      if (links == null) return r;
      return r.copyWith(kakaoNavLinks: links);
    }).toList();
  }

  /// lastMsg·time 등 로컬 UI 갱신 전용 (Firestore 쓰기 없음)
  void updateRoomLocally(int id, RoomModel Function(RoomModel) updater) {
    state = state.map((r) => r.id == id ? updater(r) : r).toList();
  }

  /// Firebase 미초기화 등 오프라인 모드에서만 방 추가에 사용합니다.
  void addLocal(RoomModel room) => state = [...state, room];

  void remove(int id) {
    if (id == 998 || id == 999) return;
    state = state.where((r) => r.id != id).toList();
    if (AuthRepository.firebaseAvailable) {
      unawaited(ChatFirestoreRepository.deleteRoom(id.toString()));
    }
  }

  void reorder(List<RoomModel> rooms) {
    state = rooms;
    if (AuthRepository.firebaseAvailable) {
      unawaited(ChatFirestoreRepository.persistRoomOrder(rooms));
    }
  }

  void pin(int id, bool pinned) {
    if (id == 998 || id == 999) return;
    state = state.map((r) => r.id == id ? r.copyWith(pinned: pinned) : r).toList();
    if (AuthRepository.firebaseAvailable) {
      unawaited(ChatFirestoreRepository.setRoomPinned(id.toString(), pinned));
    }
  }

  void updateRoom(int id, RoomModel Function(RoomModel) updater) {
    RoomModel? updated;
    state = state.map((r) {
      if (r.id != id) return r;
      final n = updater(r);
      updated = n;
      return n;
    }).toList();
    final u = updated;
    if (u != null && AuthRepository.firebaseAvailable && id != 998 && id != 999) {
      unawaited(ChatFirestoreRepository.patchRoom(id.toString(), ChatFirestoreRepository.roomToFirestoreFields(u)));
    }
  }
}

final roomProvider = StateNotifierProvider<RoomNotifier, List<RoomModel>>(
  (ref) => RoomNotifier(),
);

// ─── 일반 메시지 (Firebase 미사용 로컬 모드 전용) ─────────────────
class MessageNotifier extends StateNotifier<List<MessageModel>> {
  MessageNotifier() : super([]);

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

// ─── Work Hub 메시지 (id:999) ────────────────────────────────
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

// ─── Work Hub 캘린더 일정 ────────────────────────────────────
final calendarItemsProvider = StreamProvider<List<CalendarItem>>((ref) {
  if (!AuthRepository.firebaseAvailable) return const Stream.empty();
  return ChatFirestoreRepository.watchCalendarItems();
});

// ─── 인원보고 재전송 쿨다운 (종료 시각 저장) ──────────────────
// 앱 어디서든 패널/방 이동과 무관하게 유지됨
final reportCooldownEndProvider = StateProvider<DateTime?>((ref) => null);

// ─── 비상연락망 ──────────────────────────────────────────────
final emergencyContactsProvider = StreamProvider<List<EmergencyContact>>((ref) {
  if (!AuthRepository.firebaseAvailable) return const Stream.empty();
  return ChatFirestoreRepository.watchEmergencyContacts();
});
