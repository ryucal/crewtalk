import 'dart:async' show StreamSubscription, Timer, unawaited;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../database/database_provider.dart';
import '../database/message_dao.dart';
import '../models/message_model.dart';
import '../services/auth_repository.dart';
import '../services/chat_firestore_repository.dart';
import 'app_provider.dart';

// ─── 페이지네이션 기반 메시지 Provider ──────────────────────────────

class ChatMessagesState {
  final List<MessageModel> messages;
  final bool isInitializing;
  final bool isLoadingMore;
  final bool hasMore;
  final bool hasError;
  /// Drift 캐시에서 복원된 직후 true — Firestore 결과가 다를 때
  /// UI 측에서 2차 스크롤 복원을 수행할 수 있도록 힌트 제공.
  final bool restoredFromCache;

  const ChatMessagesState({
    this.messages = const [],
    this.isInitializing = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.hasError = false,
    this.restoredFromCache = false,
  });

  ChatMessagesState copyWith({
    List<MessageModel>? messages,
    bool? isInitializing,
    bool? isLoadingMore,
    bool? hasMore,
    bool? hasError,
    bool? restoredFromCache,
  }) {
    return ChatMessagesState(
      messages: messages ?? this.messages,
      isInitializing: isInitializing ?? this.isInitializing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      hasError: hasError ?? this.hasError,
      restoredFromCache: restoredFromCache ?? this.restoredFromCache,
    );
  }
}

class ChatMessagesNotifier extends StateNotifier<ChatMessagesState> {
  final int roomId;
  final String? myUid;
  final AppDatabase _db;

  StreamSubscription<List<MessageModel>>? _streamSub;
  DocumentSnapshot<Map<String, dynamic>>? _oldestDoc;

  ChatMessagesNotifier({
    required this.roomId,
    required this.myUid,
    required AppDatabase db,
  })  : _db = db,
        super(const ChatMessagesState()) {
    _init();
  }

  static bool _messagesEqual(List<MessageModel> a, List<MessageModel> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].firestoreDocId != b[i].firestoreDocId) return false;
    }
    return true;
  }

  Future<void> _init() async {
    // 1) drift 캐시에서 즉시 로드 → 점프 없이 UI 표시
    try {
      final cached = await _db.getCachedMessages(roomId, currentUid: myUid);
      if (!mounted) return;
      if (cached.isNotEmpty) {
        state = ChatMessagesState(
          messages: cached,
          isInitializing: false,
          hasMore: cached.length >= 50,
          restoredFromCache: true,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('drift cache load($roomId) error: $e');
    }

    if (!AuthRepository.firebaseAvailable) {
      if (mounted) {
        state = state.copyWith(isInitializing: false, hasMore: false, restoredFromCache: false);
      }
      return;
    }

    // 2) Firestore에서 최신 메시지 fetch + drift 동기화
    try {
      final result = await ChatFirestoreRepository.fetchInitialMessages(
        roomId.toString(),
        myUid,
      );
      if (!mounted) return;

      _oldestDoc = result.oldestDoc;

      // drift에 캐싱
      unawaited(_db.upsertMessagesForRoom(roomId, result.messages));

      if (_messagesEqual(state.messages, result.messages)) {
        state = state.copyWith(
          isInitializing: false,
          hasMore: result.messages.length >= 50,
          restoredFromCache: false,
        );
      } else {
        state = ChatMessagesState(
          messages: result.messages,
          isInitializing: false,
          hasMore: result.messages.length >= 50,
        );
      }

      // 3) 실시간 스트림 구독 — 신규 메시지 → drift + state
      _streamSub = ChatFirestoreRepository.watchMessagesAfter(
        roomId.toString(),
        myUid,
        result.newestDoc,
      ).listen(
        _onNewMessages,
        onError: (e) { if (kDebugMode) debugPrint('watchMessagesAfter($roomId) error: $e'); },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('ChatMessagesNotifier._init($roomId) error: $e');
      if (mounted && state.messages.isEmpty) {
        state = const ChatMessagesState(
          isInitializing: false,
          hasMore: false,
          hasError: true,
        );
      } else if (mounted) {
        state = state.copyWith(isInitializing: false, restoredFromCache: false);
      }
    }
  }

  void _onNewMessages(List<MessageModel> newMsgs) {
    if (newMsgs.isEmpty || !mounted) return;

    final existingById = {
      for (final m in state.messages)
        if (m.firestoreDocId != null) m.firestoreDocId!: m,
    };

    bool changed = false;
    final fresh = <MessageModel>[];

    for (final m in newMsgs) {
      if (existingById.containsKey(m.firestoreDocId)) {
        existingById[m.firestoreDocId!] = m;
        changed = true;
      } else {
        fresh.add(m);
        changed = true;
      }
    }

    if (!changed) return;

    final updated = state.messages.map((old) {
      if (old.firestoreDocId != null && existingById.containsKey(old.firestoreDocId)) {
        return existingById[old.firestoreDocId!]!;
      }
      return old;
    }).toList();

    final merged = [...updated, ...fresh];
    state = state.copyWith(messages: merged);

    // drift 캐싱 (비동기, fire-and-forget)
    unawaited(_db.upsertMessagesForRoom(roomId, newMsgs));
  }

  void updateMessageLocally(String docId, MessageModel Function(MessageModel) updater) {
    state = state.copyWith(
      messages: state.messages.map((m) {
        if (m.firestoreDocId == docId) return updater(m);
        return m;
      }).toList(),
    );
  }

  /// 이전 메시지 50건 추가 로드: drift 우선, 부족하면 Firestore 폴백
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);

    final oldestMs = state.messages.isNotEmpty
        ? (state.messages.first.createdAtMs ?? 0)
        : 0;

    try {
      // drift에서 먼저 조회
      final fromCache = await _db.getOlderMessages(
        roomId,
        oldestMs,
        currentUid: myUid,
      );

      if (fromCache.isNotEmpty) {
        if (!mounted) return;
        if (fromCache.length >= 50 || !AuthRepository.firebaseAvailable) {
          state = state.copyWith(
            messages: [...fromCache, ...state.messages],
            isLoadingMore: false,
            hasMore: fromCache.length >= 50,
          );
          return;
        }
      }

      if (!AuthRepository.firebaseAvailable) {
        if (mounted) state = state.copyWith(isLoadingMore: false, hasMore: false);
        return;
      }

      // drift에 부족하면 Firestore에서 fetch
      if (_oldestDoc == null) {
        if (mounted) state = state.copyWith(isLoadingMore: false, hasMore: false);
        return;
      }
      final result = await ChatFirestoreRepository.fetchOlderMessages(
        roomId.toString(),
        myUid,
        _oldestDoc!,
      );
      if (!mounted) return;
      if (result.oldestDoc != null) _oldestDoc = result.oldestDoc;

      unawaited(_db.upsertMessagesForRoom(roomId, result.messages));

      state = state.copyWith(
        messages: [...result.messages, ...state.messages],
        isLoadingMore: false,
        hasMore: result.messages.length >= 50,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('loadMore($roomId) error: $e');
      if (mounted) state = state.copyWith(isLoadingMore: false);
    }
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }
}

final chatMessagesProvider = StateNotifierProvider.autoDispose
    .family<ChatMessagesNotifier, ChatMessagesState, int>((ref, roomId) {
  final link = ref.keepAlive();
  Timer? disposeTimer;

  ref.onCancel(() {
    disposeTimer = Timer(const Duration(minutes: 5), link.close);
  });
  ref.onResume(() {
    disposeTimer?.cancel();
  });
  ref.onDispose(() {
    disposeTimer?.cancel();
  });

  final myUid = ref.watch(userProvider.select((u) => u?.firebaseUid));
  final db = ref.watch(appDatabaseProvider);
  return ChatMessagesNotifier(roomId: roomId, myUid: myUid, db: db);
});

