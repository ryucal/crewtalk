import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_provider.dart';
import '../database/message_dao.dart';
import '../database/room_dao.dart';
import '../models/room_model.dart';
import '../models/room_kakao_nav_link.dart';
import '../models/user_model.dart';
import '../providers/app_provider.dart';
import '../services/auth_repository.dart';
import '../services/fcm_push_service.dart';
import '../services/chat_firestore_repository.dart';
import '../services/foreground_notify_sound.dart';
import '../services/user_session_storage.dart';

/// 로그인 상태에서 `rooms` 컬렉션을 구독해 [roomProvider]와 동기화합니다.
class FirestoreRoomSync extends ConsumerStatefulWidget {
  final Widget child;

  const FirestoreRoomSync({super.key, required this.child});

  @override
  ConsumerState<FirestoreRoomSync> createState() => _FirestoreRoomSyncState();
}

class _FirestoreRoomSyncState extends ConsumerState<FirestoreRoomSync> {
  StreamSubscription<List<RoomModel>>? _roomsSub;
  StreamSubscription<Map<int, List<RoomKakaoNavLink>>>? _kakaoNavSub;
  final _msgSubs = <int, StreamSubscription<Map<String, dynamic>?>>{};
  /// 앱 시작 후 방별 초기 미읽음 수를 1회 Firestore 조회한 방 ID 집합
  final _initialCountLoaded = <int>{};
  /// 방별 최신 메시지 문서 ID — 첫 스냅샷·동일 문서 재전송 시 알림음 생략
  final _latestMessageDocIdByRoom = <int, String>{};

  void _attach(UserModel? user) {
    _roomsSub?.cancel();
    _roomsSub = null;
    _kakaoNavSub?.cancel();
    _kakaoNavSub = null;
    _cancelMsgSubs();
    if (user == null || !AuthRepository.firebaseAvailable) {
      Future(() {
        if (mounted) ref.read(roomProvider.notifier).mergeFromFirestore([]);
      });
      return;
    }
    if (!kIsWeb && user.firebaseUid != null && user.firebaseUid!.isNotEmpty) {
      FcmPushService.syncForLoggedInUser(user.firebaseUid);
    }

    // drift 캐시에서 방 목록 즉시 로드 (Firestore 응답 전까지 표시)
    final db = ref.read(appDatabaseProvider);
    db.getCachedRooms().then((cached) {
      if (!mounted || cached.isEmpty) return;
      ref.read(roomProvider.notifier).mergeFromFirestore(cached);
    }).catchError((e) {
      if (kDebugMode) debugPrint('drift room cache load error: $e');
    });

    _roomsSub = ChatFirestoreRepository.watchRooms().listen(
      (rooms) {
        Future(() {
          if (!mounted) return;
          ref.read(roomProvider.notifier).mergeFromFirestore(rooms);
          _syncLatestMessageSubs(rooms);
          // drift에 캐싱 + stale 방 정리
          final activeIds = rooms.map((r) => r.id).toSet();
          db.upsertRooms(rooms).then((_) {
            return db.removeStaleCachedRooms(activeIds);
          }).catchError((e) {
            if (kDebugMode) debugPrint('drift room upsert/clean error: $e');
          });
        });
      },
      onError: (e, st) {
        if (kDebugMode) debugPrint('FirestoreRoomSync watchRooms error: $e\n$st');
      },
    );

    _kakaoNavSub = ChatFirestoreRepository.watchKakaoNavLinks().listen(
      (byRoom) {
        Future(() {
          if (!mounted) return;
          ref.read(roomProvider.notifier).applyKakaoNavLinks(byRoom);
          // currentRoomProvider 는 입장 시점 스냅샷이므로 링크가 비어 있을 수 있음.
          // applyKakaoNavLinks 가 roomProvider 를 갱신했으므로 roomProvider 에서
          // 최신 링크를 읽어 currentRoomProvider 도 동기화합니다.
          final cur = ref.read(currentRoomProvider);
          if (cur == null) return;
          final updated = ref.read(roomProvider)
              .firstWhere((r) => r.id == cur.id, orElse: () => cur);
          if (updated.kakaoNavLinks.length != cur.kakaoNavLinks.length) {
            ref.read(currentRoomProvider.notifier).state =
                cur.copyWith(kakaoNavLinks: updated.kakaoNavLinks);
          }
        });
      },
      onError: (e, st) {
        if (kDebugMode) debugPrint('FirestoreRoomSync watchKakaoNavLinks error: $e\n$st');
      },
    );
  }

  /// 각 방의 최신 메시지 1건을 실시간 구독해 lastMsg·time·unread를 갱신합니다.
  void _syncLatestMessageSubs(List<RoomModel> rooms) {
    final activeIds = <int>{};
    for (final room in rooms) {
      if (room.id == 998 || room.id == 999) continue;
      activeIds.add(room.id);
      if (_msgSubs.containsKey(room.id)) continue;
      final roomId = room.id;
      _msgSubs[roomId] = ChatFirestoreRepository.watchLatestMessage(
        roomId.toString(),
      ).listen(
        (data) {
          if (data == null || !mounted) return;
          final docId = data['_docId'] as String? ?? '';
          final prevDocId = _latestMessageDocIdByRoom[roomId] ?? '';
          _latestMessageDocIdByRoom[roomId] = docId;

          final text = data['text'] as String? ?? '';
          final type = data['type'] as String? ?? 'text';
          var time = data['time'] as String? ?? '';
          // HH:mm:ss → HH:mm
          if (time.length >= 8 && time.split(':').length == 3) {
            time = time.substring(0, 5);
          }
          String preview;
          switch (type) {
            case 'image':
              final urls = data['imageUrls'];
              if (urls is List && urls.length > 1) {
                preview = '📷 사진 ${urls.length}장';
              } else {
                preview = '📷 사진';
              }
            case 'report':
              final name = data['name'] as String? ?? '';
              final rd = data['reportData'] as Map<String, dynamic>?;
              final shift = rd?['type'] as String? ?? '';
              final count = rd?['count'] ?? '';
              preview = '$name, $shift, $count명';
            case 'notice':
              preview = '📢 공지';
            case 'emergency':
              preview = '🚨 긴급';
            case 'maintenance':
              final md = data['maintenanceData'] as Map<String, dynamic>?;
              final mCar = md?['car'] as String? ?? '';
              final mSym = md?['symptom'] as String? ?? '';
              preview = '🔧 $mCar · $mSym';
            default:
              preview = text;
          }
          if (preview.isEmpty) return;

          Future(() async {
            if (!mounted) return;
            final currentRoom = ref.read(currentRoomProvider);
            final inThisRoom = currentRoom?.id == roomId;
            final isNewLatest = prevDocId.isNotEmpty && docId.isNotEmpty && prevDocId != docId;

            if (inThisRoom) {
              // 현재 열람 중: 미읽음 0
              ref.read(roomProvider.notifier).updateRoomLocally(
                    roomId,
                    (r) => r.copyWith(lastMsg: preview, time: time, unread: 0),
                  );
            } else if (!_initialCountLoaded.contains(roomId)) {
              // 앱 시작 후 방별 최초 이벤트: drift 로컬 → Firestore 폴백
              _initialCountLoaded.add(roomId);
              final localDb = ref.read(appDatabaseProvider);
              final lastRead = await localDb.getLocalReadState(roomId);
              int count;
              if (lastRead > 0) {
                count = await localDb.countUnread(roomId, lastRead);
              } else {
                final spLastRead = await UserSessionStorage.getLastReadAt(roomId);
                count = await ChatFirestoreRepository.getUnreadCount(
                  roomId.toString(),
                  spLastRead,
                );
              }
              if (!mounted) return;
              ref.read(roomProvider.notifier).updateRoomLocally(
                    roomId,
                    (r) => r.copyWith(lastMsg: preview, time: time, unread: count),
                  );
            } else if (isNewLatest) {
              // 새 메시지: 클라이언트 카운터 +1 (Firestore 읽기 없음)
              ref.read(roomProvider.notifier).updateRoomLocally(
                    roomId,
                    (r) => r.copyWith(lastMsg: preview, time: time, unread: r.unread + 1),
                  );
            } else {
              // 기존 메시지 변경(리액션 등): 미읽음 수 유지, 프리뷰만 갱신
              ref.read(roomProvider.notifier).updateRoomLocally(
                    roomId,
                    (r) => r.copyWith(lastMsg: preview, time: time),
                  );
            }

            if (!isNewLatest) return;

            final senderUid = data['userId'] as String? ?? '';
            final myUid = ref.read(userProvider)?.firebaseUid;
            if (myUid != null && myUid.isNotEmpty && senderUid == myUid) return;
            if (senderUid.isEmpty) {
              final senderName = data['name'] as String? ?? '';
              final myName = ref.read(userProvider)?.name ?? '';
              if (senderName.isNotEmpty && myName.isNotEmpty && senderName == myName) return;
            }

            final user = ref.read(userProvider);
            if (user == null) return;

            // 매니저·슈퍼 — 타인 긴급: 전용 소리만 (알림은 FCM 상단)
            if (type == 'emergency' && user.isStaffElevated) {
              final soundOn = await UserSessionStorage.getMessageNotifSoundEnabled();
              final vibOn = await UserSessionStorage.getMessageNotifVibrateEnabled();
              await ForegroundNotifySound.playEmergency(soundEnabled: soundOn, vibrateEnabled: vibOn);
              return;
            }

            // 일반 메시지 알림음 — 현재 그 방을 보고 있거나 음소거면 생략
            if (inThisRoom) return;
            if (user.isRoomMuted(roomId)) return;

            final soundOn = await UserSessionStorage.getMessageNotifSoundEnabled();
            final vibOn = await UserSessionStorage.getMessageNotifVibrateEnabled();
            await ForegroundNotifySound.play(soundEnabled: soundOn, vibrateEnabled: vibOn);
          });
        },
        onError: (e, st) {
          if (kDebugMode) debugPrint('watchLatestMessage($roomId) error: $e\n$st');
        },
      );
    }
    // 삭제된 방의 구독 해제
    final removed = _msgSubs.keys.where((id) => !activeIds.contains(id)).toList();
    for (final id in removed) {
      _msgSubs.remove(id)?.cancel();
      _latestMessageDocIdByRoom.remove(id);
    }
  }

  void _cancelMsgSubs() {
    for (final s in _msgSubs.values) {
      s.cancel();
    }
    _msgSubs.clear();
    _latestMessageDocIdByRoom.clear();
    _initialCountLoaded.clear();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attach(ref.read(userProvider));
    });
  }

  @override
  void dispose() {
    _roomsSub?.cancel();
    _kakaoNavSub?.cancel();
    _cancelMsgSubs();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<UserModel?>(userProvider, (_, next) => _attach(next));
    return widget.child;
  }
}
