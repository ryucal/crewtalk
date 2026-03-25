import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/message_model.dart';
import '../services/auth_repository.dart';
import '../services/chat_firestore_repository.dart';
import '../utils/helpers.dart';
import 'app_provider.dart';

/// 일반 채팅방(998·999 제외) 메시지 스트림
final roomMessagesStreamProvider =
    StreamProvider.autoDispose.family<List<MessageModel>, int>((ref, roomId) {
  if (roomId == 998 || roomId == 999) {
    return Stream.value(const []);
  }
  if (!AuthRepository.firebaseAvailable) {
    return Stream.value(const []);
  }
  final uid = ref.watch(userProvider)?.firebaseUid;
  return ChatFirestoreRepository.watchRoomMessages(roomId.toString(), uid);
});

/// 모든 방의 오늘자 인원보고 (collectionGroup) — 집계·DB방 검색용
final todayReportsStreamProvider = StreamProvider.autoDispose<List<MessageModel>>((ref) {
  if (!AuthRepository.firebaseAvailable) {
    return Stream.value(const []);
  }
  final today = dateToday();
  final uid = ref.watch(userProvider)?.firebaseUid;
  return ChatFirestoreRepository.watchTodayReports(today, uid);
});
