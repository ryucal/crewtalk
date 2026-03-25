import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/room_model.dart';
import '../models/user_model.dart';
import '../providers/app_provider.dart';
import '../services/auth_repository.dart';
import '../services/chat_firestore_repository.dart';

/// 로그인 상태에서 `rooms` 컬렉션을 구독해 [roomProvider]와 동기화합니다.
class FirestoreRoomSync extends ConsumerStatefulWidget {
  final Widget child;

  const FirestoreRoomSync({super.key, required this.child});

  @override
  ConsumerState<FirestoreRoomSync> createState() => _FirestoreRoomSyncState();
}

class _FirestoreRoomSyncState extends ConsumerState<FirestoreRoomSync> {
  StreamSubscription<List<RoomModel>>? _sub;

  void _attach(UserModel? user) {
    _sub?.cancel();
    _sub = null;
    if (user == null || !AuthRepository.firebaseAvailable) {
      ref.read(roomProvider.notifier).mergeFromFirestore([]);
      return;
    }
    _sub = ChatFirestoreRepository.watchRooms().listen(
      ref.read(roomProvider.notifier).mergeFromFirestore,
      onError: (e, st) {
        debugPrint('FirestoreRoomSync watchRooms error: $e\n$st');
      },
    );
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
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<UserModel?>(userProvider, (_, next) => _attach(next));
    return widget.child;
  }
}
