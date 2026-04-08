import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../models/calendar_item.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../models/room_model.dart';
import '../models/room_kakao_nav_link.dart';
import '../models/global_timetable_visibility.dart';
import '../providers/app_provider.dart';
import '../providers/chat_streams_provider.dart';
import '../database/database_provider.dart';
import '../database/outbox_dao.dart';
import '../database/room_dao.dart';
import '../services/auth_repository.dart';
import '../services/chat_firestore_repository.dart';
import '../services/fcm_push_service.dart';
import '../services/user_session_storage.dart';
import '../providers/gps_provider.dart';
import '../services/gps_service.dart';
import '../utils/app_colors.dart';
import '../utils/helpers.dart';
import '../utils/kst_date.dart';
import '../utils/kakao_kko_url_input_formatter.dart';
import '../widgets/message_bubbles.dart';
import '../widgets/timetable_image.dart';
import '../widgets/chat_gallery_photo.dart';

/// 채팅방 목록 미리보기 문자열 (텍스트 외 타입은 한 줄 요약)
String _roomListLastPreview(MessageModel msg) {
  switch (msg.type) {
    case MessageType.text:
      return msg.text ?? '';
    case MessageType.report:
      final rd = msg.reportData;
      if (rd == null) return '${msg.name} 인원보고';
      final routePart = (msg.subRoute != null && msg.subRoute!.isNotEmpty)
          ? '${msg.route} · ${msg.subRoute}'
          : (msg.route ?? '');
      final car = msg.car ?? '';
      return '${msg.name}  $car  $routePart  ${rd.type} ${rd.count}명';
    case MessageType.vendorReport:
      final v = msg.vendorData;
      if (v == null) return '${msg.name} 솔라티 보고';
      final tail = v.passengerCount.trim().isEmpty ? '' : ' ${v.passengerCount}명';
      return '${msg.name}  ${v.company}  ${v.departure}→${v.destination}$tail';
    case MessageType.image:
      final n = msg.imageSources.length;
      if (n > 1) return '📷 사진 $n장';
      return '📷 사진';
    case MessageType.emergency:
      return '🚨 ${msg.emergencyType ?? '긴급 호출'}';
    case MessageType.notice:
      return '📢 ${msg.text ?? ''}';
    case MessageType.dbResult:
      return '🔍 검색 결과';
    case MessageType.summary:
      return '📊 ${msg.date} 운행 집계';
    case MessageType.maintenance:
      final md = msg.maintenanceData;
      if (md == null) return '🔧 정비 접수';
      if (md.consumableOnly && md.consumableItems.isNotEmpty) {
        return '🧴 ${md.consumableRequestDisplayLine}';
      }
      return '🔧 ${md.car} · ${md.symptom}';
  }
}

/// HH:mm:ss → HH:mm 로 변환 (이미 HH:mm 이면 그대로)
String _roomListTime(String t) {
  if (t.length >= 8 && t.split(':').length == 3) return t.substring(0, 5);
  return t;
}

/// `lastReadAt`(ms) 이후에 온 메시지 판별용 정렬 시각
int _messageOrderMs(MessageModel m) {
  if (m.createdAtMs != null) return m.createdAtMs!;
  if (m.id >= 1000000000000) return m.id;
  try {
    final t = m.time;
    final timePart = t.length >= 8 ? t.substring(0, 8) : (t.length >= 5 ? '$t:00' : '00:00:00');
    return DateTime.parse('${m.date} $timePart').millisecondsSinceEpoch;
  } catch (_) {
    return m.id;
  }
}

DateTime? _parseChatDateKey(String dateStr) {
  final parts = dateStr.split(RegExp(r'[-/.]'));
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0].trim());
  final mo = int.tryParse(parts[1].trim());
  final da = int.tryParse(parts[2].trim());
  if (y == null || mo == null || da == null) return null;
  return DateTime(y, mo, da);
}

String _weekdayLabelKo(DateTime d) {
  const w = ['월', '화', '수', '목', '금', '토', '일'];
  return w[d.weekday - 1];
}

/// [lastReadMs] 보다 뒤에 온 첫 메시지 인덱스 (없으면 null)
int? _firstIndexAfterLastRead(List<MessageModel> messages, int lastReadMs) {
  if (lastReadMs <= 0) return null;
  for (var i = 0; i < messages.length; i++) {
    if (_messageOrderMs(messages[i]) > lastReadMs) return i;
  }
  return null;
}

/// 한 번에 고른 여러 장을 한 말풍선으로 올릴 때 업로드 중 UI
class _PendingOutgoingAlbum {
  final String batchId;
  final int roomId;
  final List<String> localPaths;
  final String timeStr;

  _PendingOutgoingAlbum({
    required this.batchId,
    required this.roomId,
    required this.localPaths,
    required this.timeStr,
  });
}

/// 카카오톡 스타일 "여기까지 읽었습니다" 구분선
class _ReadUpToHereDivider extends StatelessWidget {
  const _ReadUpToHereDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Row(
        children: [
          const Expanded(child: Divider(height: 1, thickness: 1, color: Color(0xFFE5E5E5))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFEBEBEB),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '여기까지 읽었습니다',
                style: TextStyle(fontSize: 12, color: Color(0xFF777777), fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const Expanded(child: Divider(height: 1, thickness: 1, color: Color(0xFFE5E5E5))),
        ],
      ),
    );
  }
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  bool _showSideMenu = false;
  /// 정비방 사이드 메뉴 소모품 집계 — 선택 날짜(로컬 달력 기준, 당일 기본)
  DateTime _consumableSideMenuPickDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  bool _showEmergencyConfirm = false;
  DateTime? _lastEmergencySentAt; // 긴급 알림 쿨다운 (5분)
  static const _emergencyCooldown = Duration(minutes: 5);
  static const _maxMessageLength = 1000; // 메시지 최대 글자 수
  bool _showDeleteRoomPopup = false;
  /// null: 닫힘, 1·2: 해당 슬롯 배차표 오버레이
  int? _timetableSlot;
  int _timetableViewIndex = 0;
  bool _showReportPanel = false;
  /// 입력창 쪽(최신 메시지)에 가려진 메시지가 있을 때 표시 — 카카오톡 스타일 아래보기
  bool _showJumpToBottomFab = false;
  final List<_PendingOutgoingAlbum> _pendingOutgoingAlbums = [];
  String? _emergencyType;

  /// 사이드 메뉴 — 슈퍼관리자 카카오맵 링크 편집 초안
  List<String> _kakaoNavDraftIds = [];
  final Map<String, TextEditingController> _navUrlCtrls = {};
  final Map<String, TextEditingController> _navLabelCtrls = {};
  bool _kakaoNavSaving = false;
  bool _kakaoNavPanelExpanded = false;

  void _disposeNavCtrls() {
    for (final c in _navUrlCtrls.values) { c.dispose(); }
    for (final c in _navLabelCtrls.values) { c.dispose(); }
    _navUrlCtrls.clear();
    _navLabelCtrls.clear();
    _kakaoNavDraftIds.clear();
  }

  String _inputText = '';

  /// 방별 스크롤 offset (메모리 + SharedPreferences 백업)
  static const _scrollPrefPrefix = 'chat_scroll_offset_';
  static const _nearBottomPx = 120.0;
  /// 저장값이 이 값이면 "맨 아래" 를 의미 — 렌더링 픽셀 오차나 신규 메시지로
  /// maxScrollExtent 가 달라져도 항상 최신 바닥으로 이동
  static const _atBottomSentinel = -1.0;
  /// ChatScreen 이 dispose 되어도 살아남는 정적 캐시
  /// — 방 목록 ↔ 채팅 이동 시 SharedPreferences 비동기 없이 즉시 복원
  static final Map<int, double> _globalScrollCache = {};

  final Map<int, double> _scrollOffsetMemory = {};
  final Map<int, int> _messageLenByRoom = {};
  int? _activeChatRoomId;
  int? _pendingRestoreRoomId;
  bool _suppressNextAutoFollow = false;
  int _scrollMaintenanceGeneration = 0;

  /// [UserSessionStorage] 기준 읽음 시각 — 구분선·안읽음 경계 (null: 방 전환 직후 아직 로드 전)
  int? _lastReadAtForDivider;
  Timer? _markReadDebounce;
  Timer? _scrollSaveDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScrollPositionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final room = ref.read(currentRoomProvider);
      if (room != null && room.id != 998 && room.id != 999) {
        unawaited(_flushOutbox(room.id.toString()));
      }
    });
  }

  /// 아웃박스에 남아 있는 미전송 메시지를 재전송한다.
  Future<void> _flushOutbox(String roomDocId) async {
    if (!AuthRepository.firebaseAvailable) return;
    final db = ref.read(appDatabaseProvider);
    final pending = await db.getPendingOutboxMessages(roomDocId);
    if (pending.isEmpty) return;
    final uid = ref.read(userProvider)?.firebaseUid;
    for (final item in pending) {
      try {
        final msg = MessageModel.fromJsonString(item.jsonData);
        await ChatFirestoreRepository.sendMessage(
          roomDocId: item.roomDocId,
          msg: msg,
          myFirebaseUid: uid,
          lastPreview: '',
        );
        await db.dequeueOutboxMessage(item.id);
      } on FormatException {
        await db.dequeueOutboxMessage(item.id);
      } catch (e) {
        if (kDebugMode) debugPrint('outbox flush 실패 (row ${item.id}): $e');
      }
    }
  }

  /// 아웃박스에 저장 후 Firestore 전송 — 성공 시 아웃박스에서 삭제.
  Future<void> _sendWithOutbox(RoomModel room, MessageModel msg, String? uid) async {
    final db = ref.read(appDatabaseProvider);
    final rowId = await db.enqueueOutboxMessage(
      roomDocId: room.id.toString(),
      msg: msg,
    );
    try {
      await ChatFirestoreRepository.sendMessage(
        roomDocId: room.id.toString(),
        msg: msg,
        myFirebaseUid: uid,
        lastPreview: _roomListLastPreview(msg),
      );
      await db.dequeueOutboxMessage(rowId);
    } catch (e, st) {
      if (kDebugMode) debugPrint('sendMessage 실패 (아웃박스 보관 중): $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('전송 실패. 채팅방 재진입 시 자동으로 다시 시도합니다.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _onScrollPositionChanged() {
    final id = _activeChatRoomId;
    if (id == null || !_scrollController.hasClients) return;
    final p = _scrollController.position;
    final atBottom = p.hasContentDimensions && (p.maxScrollExtent - p.pixels <= _nearBottomPx);
    final toCache = atBottom ? _atBottomSentinel : _scrollController.offset;
    _scrollOffsetMemory[id] = toCache;
    // 복원 대기 중(_pendingRestoreRoomId == id)인 방은 초기 attach offset=0 이벤트가
    // 올바른 캐시값을 덮어쓰지 않도록 갱신을 보류합니다.
    if (_pendingRestoreRoomId != id) {
      _globalScrollCache[id] = toCache;
      // 디바운스로 로컬스토리지에도 저장 — dispose 시 controller 분리 상황 대비
      _scrollSaveDebounce?.cancel();
      _scrollSaveDebounce = Timer(const Duration(milliseconds: 600), () {
        SharedPreferences.getInstance()
            .then((sp) => sp.setDouble('$_scrollPrefPrefix$id', toCache));
      });
    }
    _syncJumpToBottomFabIfNeeded();
    if (id != 998 && id != 999 && _isNearBottom()) {
      _markReadDebounce?.cancel();
      _markReadDebounce = Timer(const Duration(milliseconds: 450), () {
        if (!mounted || _activeChatRoomId != id || !_scrollController.hasClients) return;
        if (_isNearBottom()) _markRoomAsRead(id, syncDividerState: true);
      });
    }
  }

  void _scheduleJumpToBottomFabSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncJumpToBottomFabIfNeeded();
    });
  }

  void _syncJumpToBottomFabIfNeeded() {
    final show = _shouldShowJumpToBottomFab();
    if (show != _showJumpToBottomFab) {
      setState(() => _showJumpToBottomFab = show);
    }
  }

  bool _shouldShowJumpToBottomFab() {
    if (_activeChatRoomId == null) return false;
    if (!_scrollController.hasClients) return false;
    final p = _scrollController.position;
    if (!p.hasContentDimensions) return false;
    if (p.maxScrollExtent <= 0) return false;
    return !_isNearBottom();
  }

  void _openSideMenu(RoomModel room) {
    // roomProvider 에는 watchKakaoNavLinks 가 항상 최신 링크를 적용해 둠.
    // currentRoomProvider 가 입장 시점 스냅샷이라 링크가 비어 있는 경우
    // (스트림 첫 스냅샷이 입장 전에 도착했지만 currentRoomProvider 는 아직 미갱신)
    // 사이드 메뉴를 열기 전에 roomProvider 에서 최신 링크를 가져와 동기화합니다.
    final freshRoom = ref.read(roomProvider)
        .firstWhere((r) => r.id == room.id, orElse: () => room);
    if (freshRoom.kakaoNavLinks.isNotEmpty && room.kakaoNavLinks.isEmpty) {
      ref.read(currentRoomProvider.notifier).state =
          room.copyWith(kakaoNavLinks: freshRoom.kakaoNavLinks);
    }
    final cur = ref.read(currentRoomProvider);
    final links = cur != null && cur.id == room.id
        ? cur.kakaoNavLinks
        : room.kakaoNavLinks;
    _disposeNavCtrls();
    for (final link in links) {
      _kakaoNavDraftIds.add(link.id);
      _navUrlCtrls[link.id] = TextEditingController(text: link.kakaoShareUrl);
      _navLabelCtrls[link.id] = TextEditingController(text: link.label);
    }
    setState(() {
      _showSideMenu = true;
      _kakaoNavPanelExpanded = false;
      if (freshRoom.isMaintenanceRoom) {
        final n = DateTime.now();
        _consumableSideMenuPickDate = DateTime(n.year, n.month, n.day);
      }
    });
  }

  Future<void> _launchKakaoNavUrl(String raw) async {
    final s = raw.trim();
    if (s.isEmpty) return;
    final uri = Uri.tryParse(s);
    if (uri == null || !uri.hasScheme) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('열 수 없는 링크예요.')),
        );
      }
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카카오맵 또는 브라우저를 열 수 없어요.')),
      );
    }
  }

  Future<void> _confirmDeleteNavLink(RoomModel room, RoomKakaoNavLink link) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('내비 링크 삭제'),
        content: Text('"${link.label}" 링크를 삭제하시겠어요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final remaining = room.kakaoNavLinks.where((l) => l.id != link.id).toList();
    try {
      await ChatFirestoreRepository.saveKakaoNavLinksForRoom(room.id, remaining);
      if (!mounted) return;
      ref.read(roomProvider.notifier).updateRoomLocally(
        room.id, (r) => r.copyWith(kakaoNavLinks: remaining),
      );
      final cur = ref.read(currentRoomProvider);
      if (cur != null && cur.id == room.id) {
        ref.read(currentRoomProvider.notifier).state =
            cur.copyWith(kakaoNavLinks: remaining);
      }
      _navUrlCtrls.remove(link.id)?.dispose();
      _navLabelCtrls.remove(link.id)?.dispose();
      _kakaoNavDraftIds.remove(link.id);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('링크를 삭제했어요.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제에 실패했어요')),
        );
      }
    }
  }

  void _addKakaoNavDraftRow() {
    final id = const Uuid().v4();
    _navUrlCtrls[id] = TextEditingController();
    _navLabelCtrls[id] = TextEditingController();
    setState(() => _kakaoNavDraftIds.add(id));
  }

  bool _canEditKakaoNavLinks(UserModel user) =>
      user.isSuperAdmin && (user.firebaseUid?.isNotEmpty ?? false);

  Future<void> _saveKakaoNavDraft(RoomModel room) async {
    final u = ref.read(userProvider);
    if (u == null || !_canEditKakaoNavLinks(u)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Firebase로 로그인한 슈퍼관리자만 저장할 수 있어요. '
              '관리자 개인비밀번호만으로 로그인한 경우 Firestore 권한이 없습니다. '
              '또는 users 문서의 role이 superadmin 인지 확인하세요.',
            ),
          ),
        );
      }
      return;
    }
    if (!AuthRepository.firebaseAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오프라인 모드에서는 저장할 수 없어요.')),
        );
      }
      return;
    }
    final cleaned = <RoomKakaoNavLink>[];
    if (kDebugMode) debugPrint('[KakaoNav] pre-save: draftIds=${_kakaoNavDraftIds.length}, urlCtrls=${_navUrlCtrls.length}, labelCtrls=${_navLabelCtrls.length}');
    for (final id in List<String>.from(_kakaoNavDraftIds)) {
      if (kDebugMode) debugPrint('[KakaoNav]  checking id=${id.substring(0, 8)}: urlCtrl=${_navUrlCtrls[id] != null}, labelCtrl=${_navLabelCtrls[id] != null}');
      var url = (_navUrlCtrls[id]?.text ?? '').trim();
      final kkoOnly = KakaoKkoUrlExtractingFormatter.extractKkoUrl(url);
      if (kkoOnly != null) url = kkoOnly;
      final label = (_navLabelCtrls[id]?.text ?? '').trim();
      if (url.isEmpty && label.isEmpty) continue;
      if (url.isEmpty || label.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('라벨과 카카오맵 공유 URL을 모두 입력해 주세요.')),
          );
        }
        return;
      }
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('올바른 URL 형식이 아니에요.')),
          );
        }
        return;
      }
      cleaned.add(RoomKakaoNavLink(id: id, label: label, kakaoShareUrl: url));
    }
    if (kDebugMode) debugPrint('[KakaoNav] _kakaoNavDraftIds=${_kakaoNavDraftIds.length}, cleaned=${cleaned.length}');
    for (final c in cleaned) {
      if (kDebugMode) debugPrint('[KakaoNav]  -> id=${c.id.substring(0, 8)}, label=${c.label}, url=${c.kakaoShareUrl}');
    }
    setState(() => _kakaoNavSaving = true);
    try {
      await ChatFirestoreRepository.saveKakaoNavLinksForRoom(room.id, cleaned);
      if (mounted) {
        ref.read(roomProvider.notifier).updateRoomLocally(
          room.id,
          (r) => r.copyWith(kakaoNavLinks: cleaned),
        );
        final cur = ref.read(currentRoomProvider);
        if (cur != null && cur.id == room.id) {
          ref.read(currentRoomProvider.notifier).state =
              cur.copyWith(kakaoNavLinks: cleaned);
        }
        for (final link in cleaned) {
          _navUrlCtrls[link.id]?.text = link.kakaoShareUrl;
          _navLabelCtrls[link.id]?.text = link.label;
        }
        setState(() => _kakaoNavSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('내비 링크 ${cleaned.length}개를 저장했어요.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장에 실패했어요')),
        );
        setState(() => _kakaoNavSaving = false);
      }
    }
  }

  void _markRoomAsRead(int roomId, {bool syncDividerState = true}) {
    if (roomId == 998 || roomId == 999) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    UserSessionStorage.setLastReadAt(roomId, now);

    // drift + Firestore readState 동기화
    final db = ref.read(appDatabaseProvider);
    db.setLocalReadState(roomId, now);
    final uid = ref.read(userProvider)?.firebaseUid;
    if (uid != null && uid.isNotEmpty && AuthRepository.firebaseAvailable) {
      ChatFirestoreRepository.setReadState(roomId.toString(), uid, now);
    }

    if (syncDividerState && mounted && _activeChatRoomId == roomId) {
      setState(() => _lastReadAtForDivider = now);
    }
    Future(() {
      if (mounted) {
        ref.read(roomProvider.notifier).updateRoomLocally(roomId, (r) => r.copyWith(unread: 0));
      }
    });
  }

  void _persistScrollForRoom(int roomId) {
    double? toSave;
    if (_scrollController.hasClients) {
      final p = _scrollController.position;
      if (p.hasContentDimensions) {
        final max = p.maxScrollExtent;
        final o = _scrollController.offset.clamp(0.0, max);
        final atBottom = max - o <= _nearBottomPx;
        toSave = atBottom ? _atBottomSentinel : o;
      }
    }
    // dispose() 시점에는 controller 가 clients 를 이미 잃을 수 있음.
    // 리스너가 마지막으로 기록한 _scrollOffsetMemory 를 fallback 으로 사용합니다.
    toSave ??= _scrollOffsetMemory[roomId];
    if (toSave == null) return;
    _scrollOffsetMemory[roomId] = toSave;
    _globalScrollCache[roomId] = toSave;
    _scrollSaveDebounce?.cancel();
    _scrollSaveDebounce = null;
    SharedPreferences.getInstance().then((sp) => sp.setDouble('$_scrollPrefPrefix$roomId', toSave!));
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final p = _scrollController.position;
    if (!p.hasContentDimensions) return true;
    return p.maxScrollExtent - p.pixels <= _nearBottomPx;
  }

  /// saved 값을 즉시(또는 한 프레임 후) ListView에 적용합니다.
  /// _atBottomSentinel 이거나 null 이면 maxScrollExtent(바닥)으로 이동합니다.
  void _applyScrollRestore(int roomId, int messageCount, double? saved) {
    void apply([int attempt = 0]) {
      if (!mounted || !_scrollController.hasClients) return;
      if (_activeChatRoomId != roomId) return;
      final p = _scrollController.position;
      if (!p.hasContentDimensions) {
        if (attempt < 10) {
          WidgetsBinding.instance.addPostFrameCallback((_) => apply(attempt + 1));
        } else {
          _messageLenByRoom[roomId] = messageCount;
          _suppressNextAutoFollow = true;
          _scheduleJumpToBottomFabSync();
        }
        return;
      }
      final max = p.maxScrollExtent;
      final isAtBottom = saved == null || saved == _atBottomSentinel;
      final offset = isAtBottom ? max : saved.clamp(0.0, max);
      _scrollController.jumpTo(offset);
      _messageLenByRoom[roomId] = messageCount;
      _suppressNextAutoFollow = true;
      _scheduleJumpToBottomFabSync();
      if (roomId != 998 && roomId != 999 && max - offset <= _nearBottomPx) {
        _markRoomAsRead(roomId, syncDividerState: true);
      }
    }

    // postFrameCallback 안에서 호출된 경우 ListView 가 이미 렌더됐을 수 있음 →
    // 즉시 적용 시도 후 dimension 미준비 시 다음 프레임으로 1회 재시도
    if (_scrollController.hasClients &&
        _scrollController.position.hasContentDimensions) {
      apply();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
    }
  }

  Future<void> _restoreScrollForRoom(int roomId, int messageCount) async {
    // Fast path: 정적 캐시에 값이 있으면 SharedPreferences 비동기 없이 즉시 복원
    final cached = _globalScrollCache[roomId];
    if (cached != null) {
      _applyScrollRestore(roomId, messageCount, cached);
      return;
    }
    // Slow path: 디스크에서 읽어야 하는 첫 방문
    final sp = await SharedPreferences.getInstance();
    if (!mounted) return;
    final disk = sp.getDouble('$_scrollPrefPrefix$roomId');
    // await 중 캐시에 값이 생겼을 수 있음
    _applyScrollRestore(roomId, messageCount, _globalScrollCache[roomId] ?? disk);
  }

  void _queueScrollMaintenance(int roomId, int messageLength) {
    final gen = ++_scrollMaintenanceGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || gen != _scrollMaintenanceGeneration) return;
      _runScrollMaintenance(roomId, messageLength);
    });
  }

  void _runScrollMaintenance(int roomId, int messageLength) {
    if (_pendingRestoreRoomId == roomId) {
      if (messageLength == 0) {
        if (AuthRepository.firebaseAvailable && roomId != 998 && roomId != 999) {
          final chatState = ref.read(chatMessagesProvider(roomId));
          if (chatState.isInitializing) return;
        }
        _pendingRestoreRoomId = null;
        return;
      }
      _pendingRestoreRoomId = null;
      _restoreScrollForRoom(roomId, messageLength);
      return;
    }
    if (_suppressNextAutoFollow) {
      _suppressNextAutoFollow = false;
      _messageLenByRoom[roomId] = messageLength;
      _scheduleJumpToBottomFabSync();
      return;
    }
    final prev = _messageLenByRoom[roomId];
    _messageLenByRoom[roomId] = messageLength;
    if (prev != null && messageLength != prev) {
      if (messageLength > prev && _isNearBottom()) {
        _scrollToBottom(animated: true);
        if (roomId != 998 && roomId != 999) {
          _markRoomAsRead(roomId, syncDividerState: true);
        }
      } else if (_scrollController.hasClients) {
        // 2단계(Firestore) 결과로 메시지 목록이 교체된 경우
        // 현재 스크롤 위치에서 재복원하여 튐 방지
        _applyScrollRestore(roomId, messageLength, _scrollController.offset);
      }
    }
    _scheduleJumpToBottomFabSync();
  }

  @override
  void dispose() {
    FcmPushService.activeRoomId = null;
    _markReadDebounce?.cancel();
    _scrollSaveDebounce?.cancel();
    if (_activeChatRoomId != null) {
      final id = _activeChatRoomId!;
      if (_scrollController.hasClients && _isNearBottom() && id != 998 && id != 999) {
        final now = DateTime.now().millisecondsSinceEpoch;
        UserSessionStorage.setLastReadAt(id, now);
        Future(() {
          if (!mounted) return;
          ref.read(roomProvider.notifier).updateRoomLocally(id, (r) => r.copyWith(unread: 0));
        });
      }
      _persistScrollForRoom(id);
    }
    _scrollController.removeListener(_onScrollPositionChanged);
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    _disposeNavCtrls();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (animated) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }
    });
  }

  /// 인원보고 전송 직후: 리스트 길이·Firestore 스트림 반영 전에 스크롤이 어긋나므로 여러 타이밍에 맞춤
  void _scheduleScrollAfterOutgoingReport() {
    void tick() {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      tick();
      Future.delayed(const Duration(milliseconds: 80), tick);
      Future.delayed(const Duration(milliseconds: 280), tick);
    });
  }

  /// 텍스트 전송 직후: 키보드·스트림 반영 전에 maxExtent가 짧게 잡히므로 여러 타이밍에 맞춤 스크롤
  void _scheduleScrollAfterOutgoingText() {
    void tick() {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      tick();
      Future.delayed(const Duration(milliseconds: 40), tick);
      Future.delayed(const Duration(milliseconds: 120), tick);
      Future.delayed(const Duration(milliseconds: 320), tick);
      Future.delayed(const Duration(milliseconds: 600), tick);
    });
  }

  void _exitChatToRoomList(RoomModel room) {
    _persistScrollForRoom(room.id);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/rooms');
    }
  }

  List<MessageModel> _getMessages(RoomModel room) {
    if (room.id == 999) return ref.watch(adminMessageProvider);
    if (room.id == 998) return ref.watch(dbMessageProvider);
    if (!AuthRepository.firebaseAvailable) {
      return ref.watch(messageProvider).where((m) {
        if (m.type != MessageType.notice) return true;
        if (m.noticeForRoomType == null) return true;
        return m.noticeForRoomType == room.roomType;
      }).toList();
    }
    final chatState = ref.watch(chatMessagesProvider(room.id));
    return chatState.messages.where((m) {
      if (m.type != MessageType.notice) return true;
      if (m.noticeForRoomType == null) return true;
      return m.noticeForRoomType == room.roomType;
    }).toList();
  }

  void _addMessage(RoomModel room, MessageModel msg) {
    if (room.id == 999) {
      ref.read(adminMessageProvider.notifier).upsertSummary(msg);
    } else if (room.id == 998) {
      ref.read(dbMessageProvider.notifier).add(msg);
    } else if (AuthRepository.firebaseAvailable) {
      final uid = ref.read(userProvider)?.firebaseUid;
      final preview = _roomListLastPreview(msg);
      unawaited(_sendWithOutbox(room, msg, uid));
      ref.read(roomProvider.notifier).updateRoomLocally(room.id, (r) => r.copyWith(
            lastMsg: preview,
            time: _roomListTime(msg.time),
          ));
    } else {
      ref.read(messageProvider.notifier).add(msg);
      ref.read(roomProvider.notifier).updateRoomLocally(room.id, (r) => r.copyWith(
            lastMsg: _roomListLastPreview(msg),
            time: _roomListTime(msg.time),
          ));
    }
    if (room.id != 998 &&
        room.id != 999 &&
        (msg.type == MessageType.report || msg.type == MessageType.vendorReport)) {
      _scheduleScrollAfterOutgoingReport();
    }
  }

  void _editMessage(RoomModel room, int id, String newText) {
    if (room.id == 999) return;
    if (room.id == 998) return;
    if (AuthRepository.firebaseAvailable) {
      final list = ref.read(chatMessagesProvider(room.id)).messages;
      MessageModel? found;
      for (final m in list) {
        if (m.id == id) found = m;
      }
      final docId = found?.firestoreDocId;
      if (docId != null) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        ref.read(chatMessagesProvider(room.id).notifier)
            .updateMessageLocally(docId, (m) => m.copyWith(text: newText, editedAtMs: nowMs));
        unawaited(
          ChatFirestoreRepository.updateMessageText(
            roomDocId: room.id.toString(),
            messageDocId: docId,
            newText: newText,
          ).catchError((Object e, StackTrace st) {
            if (kDebugMode) debugPrint('updateMessageText: $e\n$st');
          }),
        );
      }
      return;
    }
    ref.read(messageProvider.notifier).editText(id, newText);
  }

  void _editReportMessage(
    RoomModel room,
    MessageModel msg, {
    required String car,
    required String route,
    String? subRoute,
    required String reportType,
    required int count,
    required int maxCount,
  }) {
    if (room.id == 999 || room.id == 998) return;
    if (!AuthRepository.firebaseAvailable) return;
    final docId = msg.firestoreDocId;
    if (docId == null) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    ref.read(chatMessagesProvider(room.id).notifier)
        .updateMessageLocally(docId, (m) => m.copyWith(
          car: car,
          route: route,
          subRoute: subRoute,
          reportData: ReportData(
            type: reportType,
            count: count,
            maxCount: maxCount,
            isOverCapacity: count >= maxCount,
          ),
          editedAtMs: nowMs,
        ));
    unawaited(
      ChatFirestoreRepository.updateReportData(
        roomDocId: room.id.toString(),
        messageDocId: docId,
        car: car,
        route: route,
        subRoute: subRoute,
        reportType: reportType,
        count: count,
        maxCount: maxCount,
      ).catchError((Object e, StackTrace st) {
        if (kDebugMode) debugPrint('updateReportData: $e\n$st');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('보고 수정에 실패했어요')),
          );
        }
      }),
    );
  }

  void _deleteMessage(RoomModel room, int id) {
    if (room.id == 999 || room.id == 998) return;
    if (AuthRepository.firebaseAvailable) {
      final list = ref.read(chatMessagesProvider(room.id)).messages;
      MessageModel? found;
      for (final m in list) {
        if (m.id == id) found = m;
      }
      final docId = found?.firestoreDocId;
      if (docId != null) {
        ref.read(chatMessagesProvider(room.id).notifier)
            .updateMessageLocally(docId, (m) => m.copyWith(isDeleted: true));
        unawaited(
          ChatFirestoreRepository.softDeleteMessage(room.id.toString(), docId)
              .catchError((Object e, StackTrace st) {
                if (kDebugMode) debugPrint('softDeleteMessage: $e\n$st');
              }),
        );
      }
      return;
    }
    ref.read(messageProvider.notifier).remove(id);
  }

  void _sendText(RoomModel room, bool isDbRoom) {
    final text = _inputText.trim();
    if (text.isEmpty) return;
    if (text.length > _maxMessageLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('메시지는 $_maxMessageLength자 이하로 입력해주세요.')),
      );
      return;
    }
    final user = ref.read(userProvider)!;
    final t = timeNow();
    final today = dateToday();

    _addMessage(room, MessageModel(
      id: DateTime.now().millisecondsSinceEpoch,
      userId: outgoingMessageUserId(user),
      name: user.name,
      avatar: user.avatar,
      car: user.car,
      text: text,
      time: t,
      date: today,
      type: MessageType.text,
      isMe: true,
    ));

    ref.read(roomProvider.notifier).updateRoomLocally(room.id, (r) => r.copyWith(lastMsg: text, time: t));
    _textController.clear();
    setState(() => _inputText = '');
    _scheduleScrollAfterOutgoingText();

    if (isDbRoom) _handleDbQuery(room, text, t, today, user.name);
  }

  Future<void> _pickChatImages(RoomModel room) async {
    if (room.id == 999 || room.id == 998) return;
    final user = ref.read(userProvider);
    if (user == null) return;

    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty || !mounted) return;

    final t = timeNow();
    final today = dateToday();
    final baseId = DateTime.now().millisecondsSinceEpoch;

    // Firebase 모바일: 한 묶음 썸네일 그리드 + 병렬 업로드 → 메시지 1개(또는 장수 1이면 단일)
    if (AuthRepository.firebaseAvailable && !kIsWeb) {
      final batchId = 'b$baseId';
      setState(() {
        _pendingOutgoingAlbums.add(_PendingOutgoingAlbum(
          batchId: batchId,
          roomId: room.id,
          localPaths: files.map((f) => f.path).toList(),
          timeStr: t,
        ));
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animated: true));

      final results = await Future.wait<String?>(
        List.generate(files.length, (i) async {
          return ChatFirestoreRepository.uploadChatImage(room.id.toString(), files[i].path);
        }),
      );

      if (!mounted) return;
      setState(() => _pendingOutgoingAlbums.removeWhere((a) => a.batchId == batchId));

      final urls = <String>[];
      for (final u in results) {
        if (u != null && u.isNotEmpty) urls.add(u);
      }
      final failedCount = results.length - urls.length;
      if (urls.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진을 업로드하지 못했어요. 로그인 상태와 네트워크를 확인해 주세요.')),
        );
        return;
      }
      if (failedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('일부 사진만 전송됐어요. ($failedCount장 실패)')),
        );
      }

      _addMessage(
        room,
        MessageModel(
          id: baseId,
          userId: outgoingMessageUserId(user),
          name: user.name,
          avatar: user.avatar,
          car: user.car,
          time: t,
          date: today,
          type: MessageType.image,
          isMe: true,
          imageUrl: urls.first,
          imageUrls: urls.length > 1 ? urls : const [],
        ),
      );
      final lastLabel = urls.length == 1 ? '📷 사진' : '📷 사진 ${urls.length}장';
      ref.read(roomProvider.notifier).updateRoomLocally(room.id, (r) => r.copyWith(lastMsg: lastLabel, time: t));
      setState(() {});
      _scrollToBottom(animated: true);
      return;
    }

    // 로컬 / 웹: 업로드 없음 — 2장 이상이면 한 메시지로 묶음
    final paths = files.map((f) => f.path).toList();
    if (paths.length == 1) {
      _addMessage(
        room,
        MessageModel(
          id: baseId,
          userId: outgoingMessageUserId(user),
          name: user.name,
          avatar: user.avatar,
          car: user.car,
          time: t,
          date: today,
          type: MessageType.image,
          isMe: true,
          imageUrl: paths.first,
        ),
      );
    } else {
      _addMessage(
        room,
        MessageModel(
          id: baseId,
          userId: outgoingMessageUserId(user),
          name: user.name,
          avatar: user.avatar,
          car: user.car,
          time: t,
          date: today,
          type: MessageType.image,
          isMe: true,
          imageUrl: paths.first,
          imageUrls: paths,
        ),
      );
    }
    final lastLabel = paths.length == 1 ? '📷 사진' : '📷 사진 ${paths.length}장';
    ref.read(roomProvider.notifier).updateRoomLocally(room.id, (r) => r.copyWith(lastMsg: lastLabel, time: t));
    setState(() {});
    _scrollToBottom();
  }

  void _handleDbQuery(RoomModel room, String query, String t, String today, String userName) {
    final isCarQuery = RegExp(r'\d{4}').hasMatch(query);
    final isNameQuery = RegExp(r'^[가-힣]{2,4}$').hasMatch(query.trim());

    if (!isNameQuery && !isCarQuery) {
      _addMessage(room, MessageModel(
        id: DateTime.now().millisecondsSinceEpoch + 1,
        userId: 'system', name: '시스템',
        text: '이름(한글 2~4자) 또는 차량번호(숫자 4자리)를 입력해주세요.',
        time: timeNow(), date: today, type: MessageType.text, isMe: false,
      ));
      _scrollToBottom();
      return;
    }

    if (AuthRepository.firebaseAvailable) {
      _handleDbQueryFirestore(room, query, today, isNameQuery: isNameQuery, isCarQuery: isCarQuery);
    } else {
      _handleDbQueryLocal(room, query, today, isNameQuery: isNameQuery, isCarQuery: isCarQuery);
    }
  }

  Future<void> _handleDbQueryFirestore(
    RoomModel room, String query, String today,
    {required bool isNameQuery, required bool isCarQuery}
  ) async {
    final roomIds = ref.read(roomProvider)
        .where((r) => r.id != 998 && r.id != 999 && !r.adminOnly)
        .map((r) => r.id)
        .toList();

    MessageModel? report;

    if (isNameQuery) {
      report = await ChatFirestoreRepository.getLatestReportByName(query.trim(), roomIds);
    } else if (isCarQuery) {
      final digits = query.replaceAll(RegExp(r'[^0-9]'), '');
      final last4 = digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
      report = await ChatFirestoreRepository.getLatestReportByCarLast4(last4, roomIds);
    }

    if (!mounted) return;

    if (report != null) {
      final resultCard = DbResultCard(
        searchType: isNameQuery ? 'name' : 'car',
        name: report.name,
        phone: report.phone ?? '미등록',
        company: report.company ?? '미등록',
        car: report.car,
        route: report.route,
        subRoute: report.subRoute,
        reportData: report.reportData,
        reportDateTime: '${report.date} ${report.time}',
      );
      _addMessage(room, MessageModel(
        id: DateTime.now().millisecondsSinceEpoch + 1,
        userId: 'system', name: '시스템',
        time: timeNow(), date: today, type: MessageType.dbResult, isMe: false,
        resultCard: resultCard,
      ));
    } else {
      _addMessage(room, MessageModel(
        id: DateTime.now().millisecondsSinceEpoch + 1,
        userId: 'system', name: '시스템',
        text: '\'$query\'에 해당하는 보고 내역을 찾을 수 없어요.',
        time: timeNow(), date: today, type: MessageType.text, isMe: false,
      ));
    }
    ref.read(roomProvider.notifier).updateRoomLocally(room.id, (r) => r.copyWith(lastMsg: '🔍 $query 검색', time: timeNow()));
    _scrollToBottom();
  }

  void _handleDbQueryLocal(
    RoomModel room, String query, String today,
    {required bool isNameQuery, required bool isCarQuery}
  ) {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final reportMsgs = [...ref.read(messageProvider).where((m) => m.type == MessageType.report)].reversed.toList();
      DbResultCard? resultCard;

      if (isNameQuery) {
        final name = query.trim();
        final lastReport = reportMsgs.where((m) => m.name == name).firstOrNull;
        if (lastReport != null) {
          resultCard = DbResultCard(
            searchType: 'name',
            name: lastReport.name,
            phone: lastReport.phone ?? '미등록',
            company: lastReport.company ?? '미등록',
            route: lastReport.route,
            subRoute: lastReport.subRoute,
            car: lastReport.car,
            reportData: lastReport.reportData,
            reportDateTime: '${lastReport.date} ${lastReport.time}',
          );
        }
      } else if (isCarQuery) {
        final digits = query.replaceAll(RegExp(r'[^0-9]'), '');
        final lastReport = reportMsgs.where((m) => m.car != null && m.car!.replaceAll(RegExp(r'\D'), '').contains(digits)).firstOrNull;
        if (lastReport != null) {
          resultCard = DbResultCard(
            searchType: 'car',
            name: lastReport.name,
            phone: lastReport.phone ?? '미등록',
            company: lastReport.company ?? '미등록',
            car: lastReport.car,
            route: lastReport.route,
            subRoute: lastReport.subRoute,
            reportData: lastReport.reportData,
            reportDateTime: '${lastReport.date} ${lastReport.time}',
          );
        }
      }

      if (resultCard != null) {
        _addMessage(room, MessageModel(
          id: DateTime.now().millisecondsSinceEpoch + 1,
          userId: 'system', name: '시스템',
          time: timeNow(), date: today, type: MessageType.dbResult, isMe: false,
          resultCard: resultCard,
        ));
      } else {
        _addMessage(room, MessageModel(
          id: DateTime.now().millisecondsSinceEpoch + 1,
          userId: 'system', name: '시스템',
          text: '\'$query\'에 해당하는 보고 내역을 찾을 수 없어요.',
          time: timeNow(), date: today, type: MessageType.text, isMe: false,
        ));
      }
      ref.read(roomProvider.notifier).updateRoomLocally(room.id, (r) => r.copyWith(lastMsg: '🔍 $query 검색', time: timeNow()));
      _scrollToBottom();
    });
  }


  void _sendEmergency(RoomModel room) {
    if (_emergencyType == null) return;
    final now = DateTime.now();
    if (_lastEmergencySentAt != null &&
        now.difference(_lastEmergencySentAt!) < _emergencyCooldown) {
      final remaining = _emergencyCooldown - now.difference(_lastEmergencySentAt!);
      final mins = remaining.inMinutes;
      final secs = remaining.inSeconds % 60;
      final label = mins > 0 ? '$mins분 $secs초' : '$secs초';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('긴급 알림은 $label 후 다시 보낼 수 있어요.')),
      );
      setState(() {
        _showEmergencyConfirm = false;
        _emergencyType = null;
      });
      return;
    }
    final user = ref.read(userProvider)!;
    final t = timeNow();
    final today = dateToday();
    final msg = MessageModel(
      id: DateTime.now().millisecondsSinceEpoch,
      userId: outgoingMessageUserId(user),
      name: user.name,
      phone: user.phone,
      car: user.car,
      route: room.name,
      emergencyType: _emergencyType,
      time: t,
      date: today,
      type: MessageType.emergency,
      isMe: true,
    );
    _addMessage(room, msg);
    setState(() {
      _showEmergencyConfirm = false;
      _emergencyType = null;
      _lastEmergencySentAt = DateTime.now();
    });
    _scrollToBottom();
  }

  void _handleReact(RoomModel room, int msgId, String emoji, String userName) {
    if (room.id == 998 || room.id == 999) return;
    if (!AuthRepository.firebaseAvailable) {
      ref.read(messageProvider.notifier).react(msgId, emoji, userName);
      return;
    }
    final list = ref.read(chatMessagesProvider(room.id)).messages;
    MessageModel? m;
    for (final x in list) {
      if (x.id == msgId) m = x;
    }
    final docId = m?.firestoreDocId;
    if (docId == null || m == null) return;
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
    unawaited(
      ChatFirestoreRepository.updateReactions(
        roomDocId: room.id.toString(),
        messageDocId: docId,
        reactions: reactions,
      ).catchError((Object e, StackTrace st) {
        if (kDebugMode) debugPrint('updateReactions: $e\n$st');
      }),
    );
  }

  void _updateMaintenanceStatus(RoomModel room, MessageModel msg, String newStatus) {
    if (!AuthRepository.firebaseAvailable) return;
    final docId = msg.firestoreDocId;
    if (docId == null) return;
    final oldStatus = msg.maintenanceData?.status ?? '접수';
    final notifier = ref.read(chatMessagesProvider(room.id).notifier);
    notifier.updateMessageLocally(docId, (m) =>
        m.copyWith(maintenanceData: m.maintenanceData?.copyWith(status: newStatus)));
    ChatFirestoreRepository.updateMaintenanceStatus(
      roomDocId: room.id.toString(),
      messageDocId: docId,
      newStatus: newStatus,
    ).catchError((Object e) {
      notifier.updateMessageLocally(docId, (m) =>
          m.copyWith(maintenanceData: m.maintenanceData?.copyWith(status: oldStatus)));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('상태 변경에 실패했어요')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 사이드메뉴가 열려 있는 동안 Firestore에서 kakaoNavLinks가 뒤늦게 로드되면
    // draft 편집 행(_kakaoNavDraftIds)에 누락된 링크를 자동으로 추가합니다.
    ref.listen<RoomModel?>(currentRoomProvider, (prev, next) {
      if (!mounted || !_showSideMenu || next == null) return;
      final nextLinks = next.kakaoNavLinks;
      final existingIds = _kakaoNavDraftIds.toSet();
      var changed = false;
      for (final link in nextLinks.reversed) {
        if (!existingIds.contains(link.id)) {
          _kakaoNavDraftIds.insert(0, link.id);
          _navUrlCtrls[link.id] = TextEditingController(text: link.kakaoShareUrl);
          _navLabelCtrls[link.id] = TextEditingController(text: link.label);
          changed = true;
        }
      }
      if (changed) setState(() {});
    });

    final room = ref.watch(currentRoomProvider);
    if (room == null) {
      if (_activeChatRoomId != null) {
        _persistScrollForRoom(_activeChatRoomId!);
        _activeChatRoomId = null;
        FcmPushService.activeRoomId = null;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/rooms'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = ref.watch(userProvider);
    if (user == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final isAdmin = user.isAdmin;
    final isAdminRoom = room.id == 999;
    final isDbRoom = room.id == 998;
    final isVendorRoom = room.isVendorRoom;
    final isMaintenanceRoom = room.isMaintenanceRoom;

    // 일반 방에서 메시지 로드 실패(네트워크 오류 등) 시 재시도 화면
    if (!isAdminRoom && !isDbRoom && AuthRepository.firebaseAvailable) {
      final chatState = ref.watch(chatMessagesProvider(room.id));
      if (chatState.hasError) {
        return Scaffold(
          appBar: AppBar(title: Text(room.name)),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('메시지를 불러오지 못했어요', style: TextStyle(fontSize: 15)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(chatMessagesProvider(room.id)),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        );
      }
    }

    final messages = _getMessages(room);

    if (_activeChatRoomId != room.id) {
      if (_activeChatRoomId != null) {
        _persistScrollForRoom(_activeChatRoomId!);
      }
      _showJumpToBottomFab = false;
      _lastReadAtForDivider = null;
      _activeChatRoomId = room.id;
      FcmPushService.activeRoomId = room.id.toString();
      _pendingRestoreRoomId = room.id;
      final rid = room.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        UserSessionStorage.getLastReadAt(rid).then((v) {
          if (!mounted || _activeChatRoomId != rid) return;
          setState(() => _lastReadAtForDivider = v);
        });
      });
    }
    _queueScrollMaintenance(room.id, messages.length);

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _exitChatToRoomList(room);
      },
      child: Scaffold(
        backgroundColor: room.id == 999 ? Colors.white : const Color(0xFFF5F5F5),
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            Column(
              children: [
                _buildHeader(
                  room,
                  isAdmin,
                  isAdminRoom,
                  isDbRoom,
                  isVendorRoom,
                  isMaintenanceRoom,
                  ref.watch(globalTimetableVisibilityProvider),
                  kstDateKeyNow(),
                ),
                if (isAdminRoom)
                  Expanded(child: _buildWorkHubBody(room, messages, user))
                else ...[
                  Expanded(
                    child: GestureDetector(
                      onTap: () { if (_showReportPanel) setState(() => _showReportPanel = false); },
                      behavior: HitTestBehavior.translucent,
                      child: _buildMessageArea(
                        room,
                        messages,
                        user,
                        user.isSuperAdmin,
                        extraBottomPadding: !isDbRoom && _showReportPanel,
                      ),
                    ),
                  ),
                  _buildInputArea(room, isDbRoom, isVendorRoom, isMaintenanceRoom),
                ],
              ],
            ),

            // 사이드 메뉴
            if (_showSideMenu) _buildSideMenu(room, messages, user, isAdminRoom, isDbRoom, isVendorRoom, isMaintenanceRoom),

            // 긴급 호출 확인 팝업
            if (_showEmergencyConfirm) _buildEmergencyConfirm(room),


            // 채팅방 삭제 확인
            if (_showDeleteRoomPopup) _buildDeleteRoomPopup(room),

            // 배차 시간표 (슬롯 1·2)
            if (_timetableSlot != null) _buildTimetable(room),
          ],
        ),
      ),
    );
  }

  // ─── 헤더 ───────────────────────────────────────────────────
  Widget _buildHeader(
    RoomModel room,
    bool isAdmin,
    bool isAdminRoom,
    bool isDbRoom,
    bool isVendorRoom,
    bool isMaintenanceRoom,
    GlobalTimetableByDate timetableByDate,
    String kstTodayKey,
  ) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 6, bottom: 6, left: 4, right: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
        boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Text('‹', style: TextStyle(fontSize: 28, color: Color(0xFF333333), fontWeight: FontWeight.w300, height: 1)),
            onPressed: () => _exitChatToRoomList(room),
          ),
          Expanded(
            child: Text(room.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          ),
          if (!isAdminRoom &&
              !isDbRoom &&
              globalTimetableHeaderSlotVisible(
                byDate: timetableByDate,
                kstTodayKey: kstTodayKey,
                slot: 1,
                roomHasTimetableImages: room.hasTimetable1,
              ))
            _buildTimetableHeaderButton(slot: 1, label: '배차표1'),
          if (!isAdminRoom &&
              !isDbRoom &&
              globalTimetableHeaderSlotVisible(
                byDate: timetableByDate,
                kstTodayKey: kstTodayKey,
                slot: 2,
                roomHasTimetableImages: room.hasTimetable2,
              ))
            _buildTimetableHeaderButton(slot: 2, label: '배차표2'),
          if (!isAdminRoom && !isDbRoom)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Tooltip(
                message: '사진 보내기',
                child: _IconHeaderBtn(
                  icon: Icons.image_outlined,
                  onTap: () => _pickChatImages(room),
                ),
              ),
            ),
          if (!isAdminRoom && !isDbRoom && !isMaintenanceRoom)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Tooltip(
                message: '긴급 호출',
                child: _IconHeaderBtn(
                  icon: Icons.sos_outlined,
                  iconColor: AppColors.emergencyRed,
                  backgroundColor: AppColors.emergencyRedLight,
                  borderColor: AppColors.emergencyBorder,
                  onTap: () => setState(() => _showEmergencyConfirm = true),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Tooltip(
              message: '메뉴',
              child: _IconHeaderBtn(
                icon: Icons.menu_rounded,
                onTap: () => _openSideMenu(room),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimetableHeaderButton({required int slot, required String label}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Tooltip(
        message: '배차 시간표 $slot',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() {
              _timetableViewIndex = 0;
              _timetableSlot = slot;
            }),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.morningBlueBg,
                border: Border.all(color: AppColors.morningBlue.withValues(alpha: 0.28)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.morningBlue,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 업로드 중 묶음 사진 (그리드 썸네일 + 통합 로딩)
  Widget _buildPendingOutgoingAlbumRow(_PendingOutgoingAlbum p) {
    const maxW = 220.0;
    const gap = 3.0;
    final n = p.localPaths.length;
    final useGrid = n > 1;
    final cellW = useGrid ? (maxW - gap) / 2 : maxW;
    final cellH = useGrid ? (maxW - gap) / 2 : 280.0;
    final rowCount = useGrid ? (n / 2).ceil() : 1;
    final gridH = useGrid ? rowCount * cellH + (rowCount > 1 ? (rowCount - 1) * gap : 0) : 280.0;

    Widget thumbGrid() {
      if (!useGrid) {
        return TimetableImage(source: p.localPaths.first, width: maxW, height: gridH, fit: BoxFit.cover);
      }
      final rows = <Widget>[];
      for (var r = 0; r < rowCount; r++) {
        final i0 = r * 2;
        final cells = <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TimetableImage(
              source: p.localPaths[i0],
              width: cellW,
              height: cellH,
              fit: BoxFit.cover,
            ),
          ),
        ];
        if (i0 + 1 < n) {
          cells.add(SizedBox(width: gap));
          cells.add(
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TimetableImage(
                source: p.localPaths[i0 + 1],
                width: cellW,
                height: cellH,
                fit: BoxFit.cover,
              ),
            ),
          );
        }
        rows.add(Row(mainAxisSize: MainAxisSize.min, children: cells));
        if (r < rowCount - 1) rows.add(SizedBox(height: gap));
      }
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: rows);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_roomListTime(p.timeStr), style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
                    const SizedBox(width: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: maxW,
                        height: gridH,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Positioned.fill(
                              child: Align(
                                alignment: Alignment.topRight,
                                child: thumbGrid(),
                              ),
                            ),
                            Container(color: Colors.black.withValues(alpha: 0.38)),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: CircularProgressIndicator(strokeWidth: 3.2, color: Colors.white),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '전송 중',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white.withValues(alpha: 0.95),
                                      shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  // ─── 메시지 영역 ─────────────────────────────────────────────
  Widget _buildLoadMoreHeader(int roomId, ChatMessagesState chatState) {
    if (chatState.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: TextButton(
          onPressed: () => ref.read(chatMessagesProvider(roomId).notifier).loadMore(),
          child: const Text('이전 메시지 더 보기', style: TextStyle(fontSize: 13)),
        ),
      ),
    );
  }

  Widget _buildMessageArea(
    RoomModel room,
    List<MessageModel> messages,
    UserModel user,
    bool canModerateMessages, {
    bool extraBottomPadding = false,
  }) {
    final pendingForRoom = _pendingOutgoingAlbums.where((p) => p.roomId == room.id).toList();
    if (messages.isEmpty && pendingForRoom.isEmpty) {
      return const Center(child: Text('메시지가 없어요', style: TextStyle(color: AppColors.textHint, fontSize: 14)));
    }

    final allImages = <String>[];
    for (final m in messages) {
      if (m.type == MessageType.image) allImages.addAll(m.imageSources);
      if (m.type == MessageType.maintenance && m.maintenanceData != null) {
        allImages.addAll(m.maintenanceData!.photoUrls);
      }
    }

    // Scaffold resizeToAvoidBottomInset 이 이미 키보드 높이만큼 body를 줄임 —
    // viewInsets 를 ListView padding 에 또 더하면 입력창·키보드 사이 빈 공간이 생기고 스크롤이 어긋남
    final adminSummarySafe =
        room.id == 999 ? MediaQuery.of(context).viewPadding.bottom : 0.0;
    final listBottom =
        16.0 + adminSummarySafe + (extraBottomPadding ? 28.0 : 0.0);
    final fabBottom = 8.0 + (extraBottomPadding ? 28.0 : 0.0);

    final lastRead = _lastReadAtForDivider;
    final unreadStartIndex = room.id != 998 &&
            room.id != 999 &&
            lastRead != null &&
            !_isNearBottom()
        ? _firstIndexAfterLastRead(messages, lastRead)
        : null;

    final isRealRoom = room.id != 998 && room.id != 999 && AuthRepository.firebaseAvailable;
    final chatState = isRealRoom ? ref.read(chatMessagesProvider(room.id)) : null;
    final showLoadMoreHeader = isRealRoom && (chatState!.hasMore || chatState.isLoadingMore);
    final headerCount = showLoadMoreHeader ? 1 : 0;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomRight,
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(12, 16, 12, listBottom),
          itemCount: messages.length + pendingForRoom.length + headerCount,
          itemBuilder: (context, i) {
            // "이전 메시지 더 보기" 헤더
            if (showLoadMoreHeader && i == 0) {
              return _buildLoadMoreHeader(room.id, chatState!);
            }
            final msgIndex = i - headerCount;
            if (msgIndex < messages.length) {
              final msg = messages[msgIndex];
              final prevMsg = msgIndex > 0 ? messages[msgIndex - 1] : null;
              final showDate = prevMsg == null || prevMsg.date != msg.date;
              final showUnreadLine = unreadStartIndex != null && msgIndex == unreadStartIndex;
              return Column(
                key: ValueKey(msg.firestoreDocId ?? msg.id),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showUnreadLine) const _ReadUpToHereDivider(),
                  if (showDate) DateDivider(date: msg.date),
                  MessageBubble(
                    msg: msg,
                    isAdmin: canModerateMessages,
                    currentUser: user.name,
                    onEdit: (id, newText) => _editMessage(room, id, newText),
                    onDelete: (id) => _deleteMessage(room, id),
                    onReact: (id, emoji, userName) => _handleReact(room, id, emoji, userName),
                    onOpenGallery: (imageUrl) {
                      if (allImages.isEmpty) return;
                      showDialog(
                        context: context,
                        barrierColor: Colors.black.withValues(alpha: 0.96),
                        barrierDismissible: true,
                        useSafeArea: false,
                        builder: (ctx) => _ChatImageGalleryDialog(
                          urls: allImages,
                          initialUrl: imageUrl,
                        ),
                      );
                    },
                    onMaintenanceStatusChanged: room.isMaintenanceRoom && (user?.isStaffElevated ?? false)
                        ? (m, newStatus) => _updateMaintenanceStatus(room, m, newStatus)
                        : null,
                    onEditReport: canModerateMessages
                        ? (m, {required car, required route, subRoute, required reportType, required count, required maxCount}) =>
                            _editReportMessage(room, m, car: car, route: route, subRoute: subRoute, reportType: reportType, count: count, maxCount: maxCount)
                        : null,
                  ),
                  const SizedBox(height: 4),
                ],
              );
            }
            final pend = pendingForRoom[msgIndex - messages.length];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPendingOutgoingAlbumRow(pend),
                const SizedBox(height: 4),
              ],
            );
          },
        ),
        if (_showJumpToBottomFab)
          Positioned(
            right: 8,
            bottom: fabBottom,
            child: Material(
              color: Colors.white,
              elevation: 4,
              shadowColor: Colors.black26,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  if (room.id != 998 && room.id != 999) {
                    _markRoomAsRead(room.id);
                  }
                  _scrollToBottom(animated: true);
                },
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.keyboard_arrow_down_rounded, size: 30, color: Color(0xFF555555)),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ─── 입력창 ──────────────────────────────────────────────────
  Widget _buildInputArea(RoomModel room, bool isDbRoom, bool isVendorRoom, bool isMaintenanceRoom) {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 인원 보고 / 정비 예약 패널
          if (_showReportPanel)
            isMaintenanceRoom
                ? _MaintenanceReportPanel(
                    room: room,
                    onSend: (msg) => _addMessage(room, msg),
                  )
                : isVendorRoom
                    ? _VendorReportPanel(
                        room: room,
                        onSend: (msg) => _addMessage(room, msg),
                      )
                    : _NormalReportPanel(
                        room: room,
                        onSend: (msg) => _addMessage(room, msg),
                      ),

          // 입력바
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFEEEEEE)))),
            child: Row(
              children: [
                if (!isDbRoom)
                  GestureDetector(
                    onTap: () => setState(() => _showReportPanel = !_showReportPanel),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: _showReportPanel ? AppColors.kakaoYellow : const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(isMaintenanceRoom ? '정비접수' : '인원보고', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black)),
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    onChanged: (v) => setState(() => _inputText = v),
                    onSubmitted: (_) => _sendText(room, isDbRoom),
                    maxLength: _maxMessageLength,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    style: const TextStyle(fontSize: 15, color: Colors.black),
                    decoration: InputDecoration(
                      hintText: isDbRoom ? '이름 또는 차량번호 입력...' : '메시지 입력...',
                      hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 15),
                      filled: true,
                      fillColor: const Color(0xFFFAFAFA),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Colors.black, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _sendText(room, isDbRoom),
                  child: Opacity(
                    opacity: _inputText.trim().isNotEmpty ? 1.0 : 0.4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(color: AppColors.kakaoYellow, borderRadius: BorderRadius.circular(12)),
                      child: const Text('전송', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.kakaoBrown)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 키보드가 열리면 Scaffold가 이미 inset 만큼 줄어듦 — 여기서 viewPadding 을 또 주면 키보드 위에 빈 공간이 생김
          SizedBox(
            height: MediaQuery.of(context).viewInsets.bottom > 0
                ? 0
                : MediaQuery.of(context).viewPadding.bottom,
          ),
        ],
      ),
    );
  }

  // ─── Work Hub (999) 본문 ─────────────────────────────────────
  Widget _buildWorkHubBody(RoomModel room, List<MessageModel> messages, UserModel user) {
    final calendarAsync = ref.watch(calendarItemsProvider);
    final items = calendarAsync.valueOrNull ?? <CalendarItem>[];
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final isSuperAdmin = user.role == 'superadmin';

    final upcoming = items.where((e) {
      if (e.isRangeSchedule) return e.endDate!.compareTo(todayStr) >= 0;
      return e.date.compareTo(todayStr) >= 0;
    }).toList();
    final past = items.where((e) {
      if (e.isRangeSchedule) return e.endDate!.compareTo(todayStr) < 0;
      return e.date.compareTo(todayStr) < 0;
    }).toList();

    String dateLabel(String dateStr) {
      if (dateStr == todayStr) return '오늘';
      final tm = DateTime.tryParse(dateStr);
      if (tm == null) return dateStr;
      final diff = DateTime(tm.year, tm.month, tm.day).difference(DateTime(now.year, now.month, now.day)).inDays;
      if (diff == 1) return '내일';
      if (diff == 2) return '모레';
      const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
      final wd = weekdays[tm.weekday - 1];
      return '${tm.month}월 ${tm.day}일 ($wd)';
    }

    Map<String, List<CalendarItem>> groupByDate(List<CalendarItem> list) {
      final map = <String, List<CalendarItem>>{};
      for (final e in list) {
        map.putIfAbsent(e.date, () => []).add(e);
      }
      return map;
    }

    void confirmDelete(CalendarItem item) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('일정 삭제'),
          content: Text('"${item.title}"을(를) 삭제하시겠습니까?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                ChatFirestoreRepository.deleteCalendarItem(item.id);
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    }

    const workHubTitleColor = Color(0xFF111111);
    const workHubMutedColor = Color(0xFF8E8E93);
    const workHubLineColor = Color(0xFFF2F2F7);

    Widget buildItemRow(CalendarItem item, {bool dimmed = false, bool showDividerBelow = false}) {
      final hasTime = item.startTime != null && item.startTime!.isNotEmpty;
      final accentColor = _calendarItemColor(item);
      final kindLabel = item.isTodo ? '할 일' : '일정';

      String subtitle = '';
      if (item.isRangeSchedule) {
        subtitle = '${dateLabel(item.date)} → ${dateLabel(item.endDate!)}';
      } else if (hasTime) {
        subtitle = item.startTime!;
      }

      final titleColor = dimmed ? const Color(0xFFAEAEB2) : workHubTitleColor;
      final subColor = dimmed ? const Color(0xFFC7C7CC) : workHubMutedColor;
      final creator = item.createdByName?.trim();
      final kindAndCreator = (creator != null && creator.isNotEmpty)
          ? '$kindLabel · $creator'
          : kindLabel;

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dimmed ? const Color(0xFFD1D1D6) : accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          letterSpacing: -0.4,
                          color: titleColor,
                          decoration: dimmed ? TextDecoration.lineThrough : null,
                          decorationColor: titleColor.withValues(alpha: 0.4),
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.3,
                            color: subColor,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        kindAndCreator,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                          color: dimmed ? const Color(0xFFC7C7CC) : workHubMutedColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSuperAdmin)
                  IconButton(
                    onPressed: () => confirmDelete(item),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 22,
                      color: dimmed ? const Color(0xFFD1D1D6) : const Color(0xFFC7C7CC),
                    ),
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
              ],
            ),
          ),
          if (showDividerBelow)
            Divider(height: 1, thickness: 1, color: workHubLineColor, indent: 22),
        ],
      );
    }

    Widget buildDateSection(
      String dateStr,
      List<CalendarItem> dateItems, {
      bool dimmed = false,
      bool compactTop = false,
    }) {
      final isToday = dateStr == todayStr;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: compactTop ? 6 : 22, bottom: 4),
            child: Row(
              children: [
                if (isToday && !dimmed) ...[
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF007AFF),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
                Text(
                  dateLabel(dateStr),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: dimmed ? const Color(0xFFAEAEB2) : workHubTitleColor,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < dateItems.length; i++)
            buildItemRow(
              dateItems[i],
              dimmed: dimmed,
              showDividerBelow: i < dateItems.length - 1,
            ),
        ],
      );
    }

    final upcomingGroups = groupByDate(upcoming);
    final pastGroups = groupByDate(past);
    final sortedUpcomingDates = upcomingGroups.keys.toList()..sort();
    final sortedPastDates = pastGroups.keys.toList()..sort((a, b) => b.compareTo(a));

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(22, 8, 22, MediaQuery.of(context).viewPadding.bottom + 88),
          children: [
            const SizedBox(height: 8),
            Text(
              '업무 일정',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.9,
                height: 1.15,
                color: workHubTitleColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              upcoming.isEmpty ? '예정된 일정이 없어요' : '예정 ${upcoming.length}건',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.3,
                color: workHubMutedColor,
              ),
            ),
            const SizedBox(height: 8),
            Divider(height: 32, thickness: 1, color: workHubLineColor),

            if (items.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 72),
                  child: Column(
                    children: [
                      Icon(Icons.event_available_outlined, size: 40, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        '등록된 일정이 없습니다',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              for (var i = 0; i < sortedUpcomingDates.length; i++)
                buildDateSection(
                  sortedUpcomingDates[i],
                  upcomingGroups[sortedUpcomingDates[i]]!,
                  compactTop: i == 0,
                ),

              if (sortedPastDates.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 28, bottom: 4),
                  child: Row(
                    children: [
                      Expanded(child: Divider(height: 1, thickness: 1, color: workHubLineColor)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          '지난 일정',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                            color: workHubMutedColor,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(height: 1, thickness: 1, color: workHubLineColor)),
                    ],
                  ),
                ),
                for (final date in sortedPastDates)
                  buildDateSection(date, pastGroups[date]!, dimmed: true),
              ],
            ],
          ],
        ),

        if (isSuperAdmin)
          Positioned(
            right: 22,
            bottom: MediaQuery.of(context).viewPadding.bottom + 22,
            child: FloatingActionButton(
              elevation: 1,
              highlightElevation: 2,
              backgroundColor: const Color(0xFF1C1C1E),
              foregroundColor: Colors.white,
              onPressed: () => _showAddCalendarSheet(context),
              child: const Icon(Icons.add_rounded, size: 28),
            ),
          ),
      ],
    );
  }

  Color _calendarItemColor(CalendarItem item) {
    if (item.color != null && item.color!.isNotEmpty) {
      final hex = item.color!.replaceFirst('#', '');
      final v = int.tryParse(hex, radix: 16);
      if (v != null) {
        return Color(hex.length == 6 ? (0xFF000000 | v) : v);
      }
    }
    return item.isTodo ? const Color(0xFF10B981) : const Color(0xFF6366F1);
  }

  void _showAddCalendarSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddCalendarBottomSheet(),
    );
  }

  bool _messageOnConsumablePickDate(MessageModel m, DateTime pick) {
    final d = _parseChatDateKey(m.date);
    if (d == null) return false;
    return d.year == pick.year && d.month == pick.month && d.day == pick.day;
  }

  Future<void> _pickConsumableSideMenuDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _consumableSideMenuPickDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: '소모품 요청 내역 날짜',
    );
    if (picked != null && mounted) {
      setState(() {
        _consumableSideMenuPickDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  /// 정비방 사이드 메뉴 — 달력으로 날짜 선택, 선택일 소모품 요청만 표시 (채팅에 로드된 메시지 기준)
  List<Widget> _buildMaintenanceConsumableSideSection(BuildContext context, List<MessageModel> messages) {
    final pick = _consumableSideMenuPickDate;
    final consumableMsgs = messages.where((m) {
      if (m.isDeleted) return false;
      if (m.type != MessageType.maintenance) return false;
      final md = m.maintenanceData;
      return md != null && md.consumableOnly && md.consumableItems.isNotEmpty;
    }).toList();

    final dayList = consumableMsgs.where((m) => _messageOnConsumablePickDate(m, pick)).toList()
      ..sort((a, b) => _messageOrderMs(b).compareTo(_messageOrderMs(a)));

    const sectionDeco = BoxDecoration(
      color: Color(0xFFF0F7FF),
      borderRadius: BorderRadius.all(Radius.circular(12)),
      border: Border.fromBorderSide(BorderSide(color: Color(0xFFBFDBFE), width: 1.2)),
    );

    final wd = _weekdayLabelKo(pick);
    final dateTitle =
        '${pick.year}-${pick.month.toString().padLeft(2, '0')}-${pick.day.toString().padLeft(2, '0')} ($wd)';
    final today = DateTime.now();
    final isToday = pick.year == today.year && pick.month == today.month && pick.day == today.day;

    var urea = 0, coolant = 0, washer = 0;
    for (final m in dayList) {
      for (final c in m.maintenanceData!.consumableItems) {
        switch (c) {
          case 'urea':
            urea++;
            break;
          case 'coolant':
            coolant++;
            break;
          case 'washer':
            washer++;
            break;
        }
      }
    }
    final countParts = <String>[];
    if (urea > 0) countParts.add('요소수 $urea');
    if (coolant > 0) countParts.add('부동액 $coolant');
    if (washer > 0) countParts.add('워셔액 $washer');
    final countLine = countParts.join(' · ');

    final detailBlock = dayList.isEmpty
        ? Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Text(
              '선택한 날짜에 소모품 요청이 없어요.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.35),
            ),
          )
        : Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (countLine.isNotEmpty) ...[
                  Text(
                    countLine,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade800, height: 1.3),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 6),
                ],
                ...dayList.map((m) {
                  final line = m.maintenanceData?.consumableRequestDisplayLine ?? '';
                  final tt = _roomListTime(m.time);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 44,
                          child: Text(
                            tt,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            line,
                            style: const TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF334155)),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );

    return [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: sectionDeco,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2_outlined, size: 20, color: Colors.blue.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '소모품 요청',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.blue.shade900),
                  ),
                ),
                Text(
                  '${dayList.length}건',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _pickConsumableSideMenuDate(context),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF93C5FD)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_rounded, size: 22, color: Colors.blue.shade800),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dateTitle,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              '탭하여 날짜 선택',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      if (isToday)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '오늘',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                          ),
                        ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, color: Colors.grey.shade500),
                    ],
                  ),
                ),
              ),
            ),
            detailBlock,
          ],
        ),
      ),
      const SizedBox(height: 18),
    ];
  }

  // ─── 사이드 메뉴 ─────────────────────────────────────────────
  Widget _buildSideMenu(RoomModel room, List<MessageModel> messages, UserModel user, bool isAdminRoom, bool isDbRoom, bool isVendorRoom, bool isMaintenanceRoom) {
    return SizedBox.expand(
      child: Material(
        color: Colors.white,
        child: Column(
          children: [
                  // 헤더
                  SafeArea(
                    bottom: false,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(room.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          GestureDetector(
                            onTap: () => setState(() => _showSideMenu = false),
                            child: const Text('✕', style: TextStyle(fontSize: 18, color: Color(0xFF888888))),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 본문
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isMaintenanceRoom) ..._buildMaintenanceConsumableSideSection(context, messages),
                          if (!isAdminRoom && !isDbRoom && !isMaintenanceRoom) ...[
                            // ─── 카카오맵 내비 ───────────────────────────
                            const SizedBox(height: 8),
                            const Text('카카오맵 내비', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF333333))),
                            const SizedBox(height: 10),
                            if (user.isSuperAdmin && !_canEditKakaoNavLinks(user))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF8E1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFFFE082)),
                                  ),
                                  child: Text(
                                    '이 로그인 방식으로는 링크를 서버에 저장할 수 없어요. '
                                    '전화번호·소속으로 Firebase 로그인한 슈퍼관리자 계정을 사용하거나, '
                                    'Firestore users 문서의 role을 superadmin 으로 맞춰 주세요.',
                                    style: TextStyle(fontSize: 11, color: Colors.brown.shade800, height: 1.4),
                                  ),
                                ),
                              ),
                            if (_canEditKakaoNavLinks(user)) ...[
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F7FA),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE3E8EF)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 헤더 (항상 표시 — 탭하면 펼치기/접기)
                                    InkWell(
                                      borderRadius: _kakaoNavPanelExpanded
                                          ? const BorderRadius.vertical(top: Radius.circular(12))
                                          : BorderRadius.circular(12),
                                      onTap: () => setState(() => _kakaoNavPanelExpanded = !_kakaoNavPanelExpanded),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        child: Row(
                                          children: [
                                            const Text(
                                              '슈퍼관리자 · 링크 관리',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.adminIndigo),
                                            ),
                                            const Spacer(),
                                            Icon(
                                              _kakaoNavPanelExpanded
                                                  ? Icons.keyboard_arrow_up_rounded
                                                  : Icons.keyboard_arrow_down_rounded,
                                              size: 18,
                                              color: AppColors.adminIndigo,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // 펼쳐진 내용
                                    if (_kakaoNavPanelExpanded) ...[
                                      const Divider(height: 1, color: Color(0xFFE3E8EF)),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '카카오맵에서 복사한 공유 URL을 붙여 넣고, 버튼에 쓸 라벨을 입력한 뒤 저장하세요.',
                                              style: TextStyle(fontSize: 11, color: AppColors.textHint.withValues(alpha: 0.95), height: 1.4),
                                            ),
                                            const SizedBox(height: 12),
                                            ..._kakaoNavDraftIds.map((id) {
                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 10),
                                                child: _KakaoNavLinkDraftTile(
                                                  key: ValueKey(id),
                                                  urlController: _navUrlCtrls[id]!,
                                                  labelController: _navLabelCtrls[id]!,
                                                  onDelete: () {
                                                    _navUrlCtrls.remove(id)?.dispose();
                                                    _navLabelCtrls.remove(id)?.dispose();
                                                    setState(() => _kakaoNavDraftIds.remove(id));
                                                  },
                                                ),
                                              );
                                            }),
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: TextButton.icon(
                                                onPressed: _addKakaoNavDraftRow,
                                                icon: const Icon(Icons.add_rounded, size: 20),
                                                label: const Text('항목 추가'),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            SizedBox(
                                              width: double.infinity,
                                              child: FilledButton(
                                                onPressed: _kakaoNavSaving ? null : () => _saveKakaoNavDraft(room),
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: AppColors.adminIndigo,
                                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                                ),
                                                child: _kakaoNavSaving
                                                    ? const SizedBox(
                                                        height: 20,
                                                        width: 20,
                                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                      )
                                                    : const Text('저장'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            if (room.kakaoNavLinks.isEmpty && !user.isSuperAdmin)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '등록된 내비 링크가 없어요.',
                                  style: TextStyle(fontSize: 12, color: AppColors.textHint.withValues(alpha: 0.9)),
                                ),
                              ),
                            ...room.kakaoNavLinks.map((link) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => _launchKakaoNavUrl(link.kakaoShareUrl),
                                    onLongPress: _canEditKakaoNavLinks(user) ? () => _confirmDeleteNavLink(room, link) : null,
                                    child: Ink(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [Color(0xFFFEE500), Color(0xFFF5D000)],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.06),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.navigation_rounded, color: AppColors.kakaoBrown, size: 22),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                link.label,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.kakaoBrown,
                                                ),
                                              ),
                                            ),
                                            Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.kakaoBrown.withValues(alpha: 0.85)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],

                        ],
                      ),
                    ),
                  ),
                  // 하단 버튼
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
                    child: Column(
                      children: [
                        if (!isAdminRoom && !isDbRoom)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(
                                  user.isRoomMuted(room.id) ? Icons.notifications_off_rounded : Icons.notifications_active_rounded,
                                  size: 18,
                                  color: user.isRoomMuted(room.id) ? const Color(0xFF999999) : const Color(0xFF333333),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '이 채팅방 알림',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: user.isRoomMuted(room.id) ? const Color(0xFF999999) : const Color(0xFF333333),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 28,
                                  child: Switch.adaptive(
                                    value: !user.isRoomMuted(room.id),
                                    activeColor: const Color(0xFF4CAF50),
                                    onChanged: (_) {
                                      ref.read(userProvider.notifier).toggleRoomMute(room.id);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (user.canManageRoomsAndConfig && !isAdminRoom)
                          GestureDetector(
                            onTap: () => setState(() { _showSideMenu = false; _showDeleteRoomPopup = true; }),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(color: const Color(0x0FC62828), borderRadius: BorderRadius.circular(10)),
                              child: const Text('🗑 채팅방 삭제', style: TextStyle(color: AppColors.eveningRed, fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        GestureDetector(
                          onTap: () {
                            setState(() => _showSideMenu = false);
                            _exitChatToRoomList(room);
                          },
                          child: const Text('← 채팅방 나가기', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).viewPadding.bottom),
                ],
              ),
            ),
    );
  }

  // ─── 긴급 호출 확인 팝업 ─────────────────────────────────────
  Widget _buildEmergencyConfirm(RoomModel room) {
    final items = <(IconData, String, Color)>[
      (Icons.directions_car_filled_rounded, '차량 고장', const Color(0xFF3949AB)),
      (Icons.medical_services_rounded, '응급 환자', const Color(0xFF00897B)),
      (Icons.warning_amber_rounded, '사고 발생', const Color(0xFFE65100)),
      (Icons.groups_rounded, '승객 난동', const Color(0xFF6D4C41)),
    ];
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF5C1018), Color(0xFFC62828), Color(0xFFEF5350)],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                              ),
                              child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 26),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '긴급 호출',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white.withValues(alpha: 0.95),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '상황 유형을 선택한 뒤 전송하세요',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.78), height: 1.35),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFF8F9FA),
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...items.map((item) {
                          final selected = _emergencyType == item.$2;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => setState(() => _emergencyType = item.$2),
                                borderRadius: BorderRadius.circular(16),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOutCubic,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: selected ? AppColors.emergencyRed : const Color(0xFFE8EAED),
                                      width: selected ? 2 : 1,
                                    ),
                                    boxShadow: selected
                                        ? [
                                            BoxShadow(
                                              color: AppColors.emergencyRed.withValues(alpha: 0.12),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.03),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: item.$3.withValues(alpha: selected ? 0.14 : 0.1),
                                          borderRadius: BorderRadius.circular(13),
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(item.$1, color: item.$3, size: 24),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          item.$2,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                                            color: selected ? const Color(0xFF1A1A1A) : const Color(0xFF3C4043),
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ),
                                      if (selected)
                                        Icon(Icons.check_circle_rounded, color: AppColors.emergencyRed.withValues(alpha: 0.95), size: 24),
                                      if (!selected)
                                        Icon(Icons.chevron_right_rounded, color: AppColors.textHint.withValues(alpha: 0.5), size: 22),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => setState(() {
                                    _showEmergencyConfirm = false;
                                    _emergencyType = null;
                                  }),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFDADCE0)),
                                    ),
                                    child: const Text('취소', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF5F6368))),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _emergencyType != null ? () => _sendEmergency(room) : null,
                                  borderRadius: BorderRadius.circular(14),
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      gradient: _emergencyType != null
                                          ? const LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [Color(0xFFD32F2F), Color(0xFFC62828)],
                                            )
                                          : null,
                                      color: _emergencyType == null ? const Color(0xFFBDBDBD) : null,
                                      boxShadow: _emergencyType != null
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFFC62828).withValues(alpha: 0.35),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      alignment: Alignment.center,
                                      child: const Text('전송', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.2)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── 채팅방 삭제 팝업 ────────────────────────────────────────
  Widget _buildDeleteRoomPopup(RoomModel room) {
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Container(
        width: 260,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('채팅방 삭제', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('"${room.name}" 채팅방을 삭제하시겠습니까?\n삭제 후 복구할 수 없습니다.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF666666)), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => setState(() => _showDeleteRoomPopup = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFDDDDDD)), borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: const Text('취소', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF555555))),
                ),
              )),
              const SizedBox(width: 8),
              Expanded(child: GestureDetector(
                onTap: () {
                  ref.read(roomProvider.notifier).remove(room.id);
                  context.go('/rooms');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(color: AppColors.eveningRed, borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: const Text('삭제', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              )),
            ]),
          ],
        ),
      ),
    );
  }

  // ─── 배차 시간표 (여러 장, photo_view 갤러리) ──────────────────
  Widget _buildTimetable(RoomModel room) {
    final slot = _timetableSlot;
    if (slot == null || (slot != 1 && slot != 2)) return const SizedBox.shrink();
    final images = slot == 1 ? room.timetable1Images : room.timetable2Images;
    if (images.isEmpty) return const SizedBox.shrink();
    return _TimetablePhotoViewOverlay(
      room: room,
      slot: slot,
      images: images,
      initialIndex: _timetableViewIndex,
      onClose: () => setState(() => _timetableSlot = null),
    );
  }
}

/// 배차 시간표 모달: 채팅 이미지와 동일하게 PhotoViewGallery로 스와이프·줌
class _TimetablePhotoViewOverlay extends StatefulWidget {
  final RoomModel room;
  final int slot;
  final List<String> images;
  final int initialIndex;
  final VoidCallback onClose;

  const _TimetablePhotoViewOverlay({
    required this.room,
    required this.slot,
    required this.images,
    required this.initialIndex,
    required this.onClose,
  });

  @override
  State<_TimetablePhotoViewOverlay> createState() => _TimetablePhotoViewOverlayState();
}

class _TimetablePhotoViewOverlayState extends State<_TimetablePhotoViewOverlay> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    final n = widget.images.length;
    final i = widget.initialIndex.clamp(0, n - 1);
    _currentIndex = i;
    _pageController = PageController(initialPage: i);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.images.length;
    final mq = MediaQuery.sizeOf(context);
    final w = mq.width * 0.92;
    final h = mq.height * 0.55;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.black.withValues(alpha: 0.88)),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.room.name} 배차 시간표 ${widget.slot}',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                ),
                if (n > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${_currentIndex + 1} / $n',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                const SizedBox(height: 14),
                SizedBox(
                  width: w,
                  height: h,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: PhotoViewGallery.builder(
                      pageController: _pageController,
                      itemCount: n,
                      onPageChanged: (i) => setState(() => _currentIndex = i),
                      scrollPhysics: const BouncingScrollPhysics(),
                      backgroundDecoration: const BoxDecoration(color: Color(0xFF101010)),
                      builder: (context, index) {
                        return PhotoViewGalleryPageOptions.customChild(
                          minScale: PhotoViewComputedScale.contained * 0.85,
                          maxScale: PhotoViewComputedScale.covered * 4,
                          initialScale: PhotoViewComputedScale.contained,
                          basePosition: Alignment.center,
                          child: TimetableImage(
                            source: widget.images[index],
                            fit: BoxFit.contain,
                            width: w,
                            height: h,
                            fullQuality: true,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onClose,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Text('닫기', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 일반 기사용 인원 보고 패널 ───────────────────────────────
class _NormalReportPanel extends ConsumerStatefulWidget {
  final RoomModel room;
  final void Function(MessageModel) onSend;
  const _NormalReportPanel({required this.room, required this.onSend});

  @override
  ConsumerState<_NormalReportPanel> createState() => _NormalReportPanelState();
}

class _NormalReportPanelState extends ConsumerState<_NormalReportPanel> {
  String _shiftType = '출근';
  int _count = 0;
  int _maxCount = 45;
  String _selectedSubRoute = '';
  bool _subRouteWarning = false;
  bool _carWarning = false;
  bool _isTimeEdited = false;
  // 화면 갱신용 틱 (쿨다운 표시) — 쿨다운 상태는 Provider에서 관리
  Timer? _cooldownTicker;
  late String _nowTime;
  Timer? _ticker;

  // SharedPreferences 키
  String get _subRouteKey => 'subRoute_${widget.room.id}';

  @override
  void initState() {
    super.initState();
    _nowTime = _currentTime();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isTimeEdited) setState(() => _nowTime = _currentTime());
    });
    _loadSavedSubRoute();
    _startCooldownTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _cooldownTicker?.cancel();
    super.dispose();
  }

  // 쿨다운 남은 초 계산 (Provider의 종료시각 기준)
  int get _cooldownSec {
    final end = ref.read(reportCooldownEndProvider);
    if (end == null) return 0;
    final remaining = end.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  // 쿨다운이 활성화된 동안 1초마다 UI를 갱신하는 타이머
  void _startCooldownTicker() {
    _cooldownTicker?.cancel();
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = _cooldownSec;
      setState(() {}); // 남은 시간 표시 갱신
      if (remaining <= 0) {
        _cooldownTicker?.cancel();
        _cooldownTicker = null;
      }
    });
  }

  String _currentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  Future<void> _loadSavedSubRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_subRouteKey) ?? '';
    if (mounted && widget.room.subRoutes.contains(saved)) {
      setState(() => _selectedSubRoute = saved);
    }
  }

  Future<void> _saveSubRoute(String value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value.isEmpty) {
      await prefs.remove(_subRouteKey);
    } else {
      await prefs.setString(_subRouteKey, value);
    }
  }

  void _send() {
    if (_cooldownSec > 0) return;
    final user = ref.read(userProvider);
    if (user == null) return;
    if (user.car.trim().isEmpty) {
      setState(() => _carWarning = true);
      Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _carWarning = false); });
      return;
    }
    if (widget.room.subRoutes.isNotEmpty && _selectedSubRoute.isEmpty) {
      setState(() => _subRouteWarning = true);
      Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _subRouteWarning = false); });
      return;
    }
    final today = dateToday();
    final carDigits = user.car.replaceAll(RegExp(r'[^0-9]'), '');
    final msg = MessageModel(
      id: DateTime.now().millisecondsSinceEpoch,
      userId: outgoingMessageUserId(user),
      name: user.name,
      phone: user.phone,
      company: user.company,
      car: user.car,
      carLast4: carDigits.length >= 4 ? carDigits.substring(carDigits.length - 4) : carDigits,
      route: widget.room.name,
      subRoute: _selectedSubRoute.isEmpty ? null : _selectedSubRoute,
      time: _isTimeEdited ? _nowTime : _currentTime(),
      date: today,
      type: MessageType.report,
      isMe: true,
      reportData: ReportData(type: _shiftType, count: _count, maxCount: _maxCount, isOverCapacity: _count >= _maxCount),
    );
    widget.onSend(msg);
    // 전송 후 시간만 실시간으로 복귀 (나머지 상태는 유지)
    setState(() => _isTimeEdited = false);
    // 쿨다운 종료 시각을 Provider에 저장 (앱 전역 유지)
    ref.read(reportCooldownEndProvider.notifier).state =
        DateTime.now().add(const Duration(seconds: 30));
    _startCooldownTicker();

    // GPS 시작/재시작 (웹 제외)
    if (!kIsWeb) _triggerGps(user, msg, _selectedSubRoute);
  }

  Future<void> _triggerGps(UserModel user, MessageModel msg, String panelSelectedSubRoute) async {
    final gps = GpsService.instance;

    // 이미 활성화 중이면 자동 종료 타이머만 리셋 후 새 운행 정보로 재시작
    final hasPermission = await gps.requestPermissions();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('위치 권한이 필요합니다. 설정에서 허용해 주세요.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    var subRoute = (msg.subRoute ?? '').trim();
    if (subRoute.isEmpty) subRoute = panelSelectedSubRoute.trim();
    if (subRoute.isEmpty && widget.room.subRoutes.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_subRouteKey) ?? '';
      if (widget.room.subRoutes.contains(saved)) subRoute = saved;
    }

    final started = await gps.start(
      name: user.name,
      car: user.car,
      route: widget.room.name,
      subRoute: subRoute,
      count: msg.reportData?.count ?? 0,
      roomId: widget.room.id,
      company: user.company,
      phone: user.phone,
    );
    if (!started) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('포그라운드 서비스 시작에 실패했습니다. 알림 권한을 확인해 주세요.'),
          ),
        );
      }
      return;
    }

    gps.onAutoStopped = () {
      if (mounted) {
        ref.read(gpsActiveProvider.notifier).state = false;
        ref.read(gpsRunInfoProvider.notifier).state = null;
      }
    };

    ref.read(gpsActiveProvider.notifier).state = true;
    ref.read(gpsRunInfoProvider.notifier).state = GpsRunInfo(
      name: user.name,
      car: user.car,
      route: widget.room.name,
      subRoute: subRoute,
      count: msg.reportData?.count ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final subRoutes = widget.room.subRoutes;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── 시간 표시 ───────────────────────────────────────
          GestureDetector(
            onTap: () => _showTimeInputDialog(),
            child: Column(
              children: [
                Text(_nowTime, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 2, color: Color(0xFF1A1A1A))),
                if (_isTimeEdited) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('⚠️ 시간 수동 변경됨', style: TextStyle(fontSize: 11, color: Color(0xFFE65100), fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() { _isTimeEdited = false; _nowTime = _currentTime(); }),
                        child: const Text('현재 시간으로 되돌리기', style: TextStyle(fontSize: 11, color: Color(0xFF1565C0), fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          // ─── 세부 노선 선택 ──────────────────────────────────
          if (subRoutes.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: subRoutes.map((r) {
                final active = _selectedSubRoute == r;
                return GestureDetector(
                  onTap: () {
                    final next = active ? '' : r;
                    setState(() => _selectedSubRoute = next);
                    _saveSubRoute(next);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFF1A237E) : Colors.white,
                      border: Border.all(color: active ? const Color(0xFF1A237E) : const Color(0xFFDDDDDD)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${active ? '✓ ' : ''}$r', style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.w400, color: active ? Colors.white : const Color(0xFF555555))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],
          // ─── 출근/퇴근 선택 ──────────────────────────────────
          Row(
            children: ['출근', '퇴근'].map((t) {
              final active = _shiftType == t;
              final color = t == '출근' ? const Color(0xFF1565C0) : const Color(0xFFC62828);
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _shiftType = t),
                  child: Container(
                    margin: EdgeInsets.only(left: t == '퇴근' ? 6 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? color.withValues(alpha: 0.1) : Colors.white,
                      border: Border.all(color: active ? color : const Color(0xFFDDDDDD), width: 1.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(t, style: TextStyle(fontSize: 14, fontWeight: active ? FontWeight.w800 : FontWeight.w400, color: active ? color : const Color(0xFFAAAAAA))),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // ─── 최대 인원 프리셋 ─────────────────────────────────
          Row(
            children: [
              Expanded(child: _presetBtn(label: '0', active: _count <= 40, onTap: () => setState(() { _maxCount = 41; _count = 0; }))),
              ...[41, 44, 45].map((n) {
                final active = n == 41 ? (_count >= 41 && _count <= 43) : _count == n;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _presetBtn(label: '$n', active: active, onTap: () => setState(() { _maxCount = n; _count = n; })),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
          // ─── 인원 카운터 ──────────────────────────────────────
          Row(
            children: [
              _counterBtn(icon: '－', color: const Color(0xFFC62828), bg: const Color(0x14C62828), onTap: () => setState(() => _count = (_count - 1).clamp(0, 45))),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showCountInputDialog(),
                  child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFEEEEEE)), borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: Text(
                    '$_count',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _count >= _maxCount ? const Color(0xFFFF5252) : const Color(0xFF1A1A1A)),
                  ),
                ),
                ),
              ),
              _counterBtn(icon: '＋', color: const Color(0xFF1565C0), bg: const Color(0x141565C0), onTap: () => setState(() => _count = (_count + 1).clamp(0, 45))),
            ],
          ),
          // ─── 경고 메시지 ──────────────────────────────────────
          if (_carWarning) ...[
            const SizedBox(height: 8),
            _warningBox('⚠️ 차량번호를 먼저 설정해주세요. (프로필 설정)'),
          ],
          if (_subRouteWarning) ...[
            const SizedBox(height: 8),
            _warningBox('⚠️ 세부 노선을 먼저 선택해주세요.'),
          ],
          const SizedBox(height: 12),
          // ─── 전송 버튼 ────────────────────────────────────────
          GestureDetector(
            onTap: _send,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: _cooldownSec > 0 ? const Color(0xFFAAAAAA) : Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                _cooldownSec > 0 ? '재전송 대기 ${_cooldownSec}초' : '보고 전송',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 시간 숫자패드 다이얼로그 ─────────────────────────────
  void _showTimeInputDialog() {
    final ctrl = TextEditingController();
    String preview = '';

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlg) => Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 280,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, 8))]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('시간 입력', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, decoration: TextDecoration.none, color: Colors.black)),
                  const SizedBox(height: 4),
                  const Text('숫자 4자리 입력 (예: 0930 → 09:30)', style: TextStyle(fontSize: 11, color: Color(0xFF999999), decoration: TextDecoration.none)),
                  const SizedBox(height: 12),
                  // 미리보기
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)),
                    alignment: Alignment.center,
                    child: Text(
                      preview.isEmpty ? '--:--:--' : preview,
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 2,
                        color: preview.isEmpty ? const Color(0xFFCCCCCC) : const Color(0xFF1A1A1A),
                        decoration: TextDecoration.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 4),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '0000',
                      hintStyle: const TextStyle(color: Color(0xFFCCCCCC)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5)),
                    ),
                    onChanged: (val) {
                      final digits = val.replaceAll(RegExp(r'\D'), '');
                      String p = '';
                      if (digits.length >= 4) {
                        final h = int.tryParse(digits.substring(0, 2)) ?? 0;
                        final m = int.tryParse(digits.substring(2, 4)) ?? 0;
                        if (h <= 23 && m <= 59) {
                          p = '${digits.substring(0,2)}:${digits.substring(2,4)}:00';
                        }
                      }
                      setDlg(() => preview = p);
                    },
                    onSubmitted: (_) {
                      if (preview.isNotEmpty) {
                        setState(() { _nowTime = preview; _isTimeEdited = true; });
                        Navigator.pop(ctx);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFDDDDDD)), borderRadius: BorderRadius.circular(10)),
                        alignment: Alignment.center,
                        child: const Text('취소', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF555555), decoration: TextDecoration.none)),
                      ),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: GestureDetector(
                      onTap: () {
                        if (preview.isNotEmpty) {
                          setState(() { _nowTime = preview; _isTimeEdited = true; });
                          Navigator.pop(ctx);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(color: const Color(0xFF1565C0), borderRadius: BorderRadius.circular(10)),
                        alignment: Alignment.center,
                        child: const Text('확인', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white, decoration: TextDecoration.none)),
                      ),
                    )),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── 인원 숫자 직접 입력 다이얼로그 ──────────────────────────
  void _showCountInputDialog() {
    final ctrl = TextEditingController(text: _count > 0 ? '$_count' : '');

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 240,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, 8))]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('인원 직접 입력', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, decoration: TextDecoration.none, color: Colors.black)),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '0',
                    hintStyle: const TextStyle(color: Color(0xFFCCCCCC)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5)),
                    suffixText: '명',
                    suffixStyle: const TextStyle(fontSize: 16, color: Color(0xFF888888)),
                  ),
                  onSubmitted: (val) {
                    final v = (int.tryParse(val) ?? 0).clamp(0, 45);
                    setState(() => _count = v);
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 4),
                const Text('최대 45명 (초과 시 자동 보정)', style: TextStyle(fontSize: 11, color: Color(0xFF999999), decoration: TextDecoration.none)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFDDDDDD)), borderRadius: BorderRadius.circular(10)),
                      alignment: Alignment.center,
                      child: const Text('취소', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF555555), decoration: TextDecoration.none)),
                    ),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: GestureDetector(
                    onTap: () {
                      final v = (int.tryParse(ctrl.text) ?? 0).clamp(0, 45);
                      setState(() => _count = v);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(color: const Color(0xFF1565C0), borderRadius: BorderRadius.circular(10)),
                      alignment: Alignment.center,
                      child: const Text('확인', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white, decoration: TextDecoration.none)),
                    ),
                  )),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _presetBtn({required String label, required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active ? const Color(0x14E65100) : Colors.white,
          border: Border.all(color: active ? const Color(0xFFE65100) : const Color(0xFFDDDDDD), width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.w400, color: active ? const Color(0xFFE65100) : const Color(0xFFAAAAAA))),
      ),
    );
  }

  Widget _counterBtn({required String icon, required Color color, required Color bg, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: bg, border: Border.all(color: color, width: 1.5), borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.center,
        child: Text(icon, style: TextStyle(fontSize: 22, color: color, height: 1)),
      ),
    );
  }

  Widget _warningBox(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: const Color(0x14C62828), border: Border.all(color: const Color(0xFFC62828)), borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFFC62828), fontWeight: FontWeight.w600), textAlign: TextAlign.center),
  );
}

// ─── 차량 정비 접수 패널 ──────────────────────────────────────
class _MaintenanceReportPanel extends ConsumerStatefulWidget {
  final RoomModel room;
  final void Function(MessageModel) onSend;
  const _MaintenanceReportPanel({required this.room, required this.onSend});

  @override
  ConsumerState<_MaintenanceReportPanel> createState() => _MaintenanceReportPanelState();
}

class _MaintenanceReportPanelState extends ConsumerState<_MaintenanceReportPanel> {
  late final TextEditingController _symptomCtl;
  String _driveability = '';
  late String _dateStr;
  late String _timeStr;
  List<String> _pickedPhotoPaths = [];
  bool _uploading = false;
  final Set<String> _consumableCodes = {};

  static const _driveOptions = ['정상 운행 가능', '조심 운행 가능', '즉시 점검 필요'];
  static const _consumableOptions = <(String code, String label)>[
    ('urea', '요소수'),
    ('coolant', '부동액'),
    ('washer', '워셔액'),
  ];

  static const _labelStyle = TextStyle(fontSize: 13, color: Color(0xFF999999), fontWeight: FontWeight.w700);
  static const _fieldDeco = BoxDecoration(
    color: Color(0xFFFAFAFA),
    border: Border.fromBorderSide(BorderSide(color: Color(0xFFE0E0E0), width: 1.5)),
    borderRadius: BorderRadius.all(Radius.circular(10)),
  );

  @override
  void initState() {
    super.initState();
    _symptomCtl = TextEditingController();
    final now = DateTime.now();
    _dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _symptomCtl.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 80);
    if (files.isEmpty || !mounted) return;
    setState(() {
      _pickedPhotoPaths = [..._pickedPhotoPaths, ...files.map((f) => f.path)];
    });
  }

  Future<void> _send() async {
    final user = ref.read(userProvider);
    if (user == null) return;

    final t = timeNow();
    final today = dateToday();

    if (_consumableCodes.isNotEmpty) {
      final sortedItems = MaintenanceData.consumableItemCodesOrdered
          .where(_consumableCodes.contains)
          .toList();
      if (sortedItems.isEmpty) return;

      final msg = MessageModel(
        id: DateTime.now().millisecondsSinceEpoch,
        userId: outgoingMessageUserId(user),
        name: user.name,
        phone: user.phone,
        company: user.company,
        car: user.car,
        time: t,
        date: today,
        type: MessageType.maintenance,
        isMe: true,
        maintenanceData: MaintenanceData(
          car: user.car,
          driverName: user.name,
          phone: user.phone,
          occurredAt: '$_dateStr $_timeStr',
          symptom: '',
          driveability: '소모품 요청',
          photoUrls: const [],
          consumableOnly: true,
          consumableItems: sortedItems,
        ),
      );
      widget.onSend(msg);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('소모품 요청을 보냈습니다.')),
        );
      }
      setState(() {
        _consumableCodes.clear();
        _pickedPhotoPaths = [];
      });
      return;
    }

    if (_symptomCtl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('고장 증상을 입력해 주세요.')),
      );
      return;
    }
    if (_driveability.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('운행 가능 여부를 선택해 주세요.')),
      );
      return;
    }

    setState(() => _uploading = true);

    // 사진 업로드
    final photoUrls = <String>[];
    if (_pickedPhotoPaths.isNotEmpty && AuthRepository.firebaseAvailable) {
      for (final path in _pickedPhotoPaths) {
        final url = await ChatFirestoreRepository.uploadChatImage(
          widget.room.id.toString(), path,
        );
        if (url != null) photoUrls.add(url);
      }
    }

    if (!mounted) return;
    setState(() => _uploading = false);

    final msg = MessageModel(
      id: DateTime.now().millisecondsSinceEpoch,
      userId: outgoingMessageUserId(user),
      name: user.name,
      phone: user.phone,
      company: user.company,
      car: user.car,
      time: t,
      date: today,
      type: MessageType.maintenance,
      isMe: true,
      maintenanceData: MaintenanceData(
        car: user.car,
        driverName: user.name,
        phone: user.phone,
        occurredAt: '$_dateStr $_timeStr',
        symptom: _symptomCtl.text.trim(),
        driveability: _driveability,
        photoUrls: photoUrls,
      ),
    );
    widget.onSend(msg);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('정비 예약이 접수됐습니다.')),
      );
    }

    // 전송 후 입력 초기화
    setState(() {
      _symptomCtl.clear();
      _driveability = '';
      _pickedPhotoPaths = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final consumableMode = _consumableCodes.isNotEmpty;
    final canSelectConsumable =
        _symptomCtl.text.trim().isEmpty && _driveability.isEmpty;
    return Container(
      constraints: const BoxConstraints(maxHeight: 480),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로필에서 불러온 정보
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD0DBFF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('프로필 정보', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF3F51B5))),
                  const SizedBox(height: 6),
                  Text('${user?.name ?? ''} · ${user?.car ?? ''} · ${user?.phone ?? ''}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // 발생 날짜·시간
            const Text('발생 날짜·시간', style: _labelStyle),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null && mounted) {
                        setState(() => _dateStr = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: _fieldDeco,
                      child: Text(_dateStr, style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final parts = _timeStr.split(':');
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0),
                      );
                      if (picked != null && mounted) {
                        setState(() => _timeStr = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: _fieldDeco,
                      child: Text(_timeStr, style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // 고장 증상
            const Text('고장 증상 *', style: _labelStyle),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: _fieldDeco,
              child: TextField(
                controller: _symptomCtl,
                enabled: !consumableMode,
                onChanged: (_) => setState(() {}),
                maxLines: 2,
                style: TextStyle(
                  fontSize: 16,
                  color: consumableMode ? const Color(0xFFBBBBBB) : Colors.black,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '증상을 상세히 입력해 주세요',
                  hintStyle: TextStyle(fontSize: 16, color: Color(0xFFBBBBBB)),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // 운행 가능 여부
            const Text('운행 가능 여부 *', style: _labelStyle),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _driveOptions.map((opt) {
                final active = _driveability == opt;
                final Color color;
                if (opt == '정상 운행 가능') {
                  color = const Color(0xFF2E7D32);
                } else if (opt == '조심 운행 가능') {
                  color = const Color(0xFFE65100);
                } else {
                  color = const Color(0xFFC62828);
                }
                return GestureDetector(
                  onTap: consumableMode
                      ? null
                      : () => setState(() {
                            _driveability = active ? '' : opt;
                            if (_driveability.isNotEmpty) _consumableCodes.clear();
                          }),
                  child: Opacity(
                    opacity: consumableMode ? 0.45 : 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? color.withValues(alpha: 0.1) : Colors.white,
                        border: Border.all(color: active ? color : const Color(0xFFDDDDDD), width: 1.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(opt, style: TextStyle(fontSize: 14, fontWeight: active ? FontWeight.w700 : FontWeight.w400, color: active ? color : const Color(0xFF888888))),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            const Text('소모품 (중복 선택)', style: _labelStyle),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _consumableOptions.map((e) {
                final code = e.$1;
                final label = e.$2;
                final active = _consumableCodes.contains(code);
                const color = Color(0xFF1565C0);
                return GestureDetector(
                  onTap: canSelectConsumable
                      ? () => setState(() {
                            if (active) {
                              _consumableCodes.remove(code);
                            } else {
                              _consumableCodes.add(code);
                              _driveability = '';
                              _symptomCtl.clear();
                              _pickedPhotoPaths = [];
                            }
                          })
                      : null,
                  child: Opacity(
                    opacity: canSelectConsumable ? 1 : 0.45,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? color.withValues(alpha: 0.1) : Colors.white,
                        border: Border.all(color: active ? color : const Color(0xFFDDDDDD), width: 1.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                          color: active ? color : const Color(0xFF888888),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (consumableMode)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '소모품을 선택한 경우 고장 증상·운행 여부·사진은 보내지 않습니다.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.35),
                ),
              ),
            const SizedBox(height: 14),
            // 사진 첨부
            const Text('사진 첨부', style: _labelStyle),
            const SizedBox(height: 6),
            Row(
              children: [
                GestureDetector(
                  onTap: (_uploading || consumableMode) ? null : _pickPhotos,
                  child: Opacity(
                    opacity: consumableMode ? 0.45 : 1,
                    child: Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        border: Border.all(color: const Color(0xFFDDDDDD)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.camera_alt_outlined, size: 22, color: Color(0xFF888888)),
                          Text('${_pickedPhotoPaths.length}', style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_pickedPhotoPaths.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _pickedPhotoPaths.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (_, i) {
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(_pickedPhotoPaths[i]),
                                  width: 60, height: 60, fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 2, right: 2,
                                child: GestureDetector(
                                  onTap: () => setState(() => _pickedPhotoPaths.removeAt(i)),
                                  child: Container(
                                    width: 18, height: 18,
                                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, size: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            // 전송 버튼
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _uploading ? null : _send,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE65100),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _uploading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('정비 접수 전송', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 솔라티(구 하청업체) 인원 보고 패널 ───────────────────────
class _VendorReportPanel extends ConsumerStatefulWidget {
  final RoomModel room;
  final void Function(MessageModel) onSend;
  const _VendorReportPanel({required this.room, required this.onSend});

  @override
  ConsumerState<_VendorReportPanel> createState() => _VendorReportPanelState();
}

class _VendorReportPanelState extends ConsumerState<_VendorReportPanel> {
  late String _dateStr;
  late final TextEditingController _timeCtl;
  late final TextEditingController _departureCtl;
  late final TextEditingController _destinationCtl;
  late final TextEditingController _passengerCtl;
  late final TextEditingController _distanceCtl;
  late final TextEditingController _reserverCtl;
  late final TextEditingController _specialNoteCtl;

  static const _labelStyle = TextStyle(fontSize: 11, color: Color(0xFF999999), fontWeight: FontWeight.w700);
  static const _fieldDeco = BoxDecoration(
    color: Color(0xFFFAFAFA),
    border: Border.fromBorderSide(BorderSide(color: Color(0xFFE0E0E0), width: 1.5)),
    borderRadius: BorderRadius.all(Radius.circular(10)),
  );

  /// 연속 4자리 숫자 → HH:mm (범위 밖이면 00:00)
  static String _timeFromFourDigits(String four) {
    if (four.length != 4) return four;
    final h = int.tryParse(four.substring(0, 2)) ?? 0;
    final m = int.tryParse(four.substring(2, 4)) ?? 0;
    if (h <= 23 && m <= 59) {
      return '${four.substring(0, 2)}:${four.substring(2, 4)}';
    }
    return '00:00';
  }

  void _onVendorTimeChanged(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      if (_timeCtl.text.isNotEmpty) _timeCtl.clear();
      return;
    }
    if (digits.length < 4) {
      if (_timeCtl.text != digits) {
        _timeCtl.value = TextEditingValue(
          text: digits,
          selection: TextSelection.collapsed(offset: digits.length),
        );
      }
      return;
    }
    final formatted = _timeFromFourDigits(digits.substring(0, 4));
    if (_timeCtl.text != formatted) {
      _timeCtl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    _timeCtl = TextEditingController(text: '$hh$mm');
    _onVendorTimeChanged(_timeCtl.text);
    _departureCtl = TextEditingController();
    _destinationCtl = TextEditingController();
    _passengerCtl = TextEditingController();
    _distanceCtl = TextEditingController();
    _reserverCtl = TextEditingController();
    _specialNoteCtl = TextEditingController();
  }

  @override
  void dispose() {
    _timeCtl.dispose();
    _departureCtl.dispose();
    _destinationCtl.dispose();
    _passengerCtl.dispose();
    _distanceCtl.dispose();
    _reserverCtl.dispose();
    _specialNoteCtl.dispose();
    super.dispose();
  }

  String get _operationDateTimeCombined {
    final raw = _timeCtl.text.trim();
    String timePart;
    if (raw.contains(':')) {
      timePart = raw;
    } else {
      final digits = raw.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 4) {
        timePart = _timeFromFourDigits(digits.substring(0, 4));
      } else if (digits.isEmpty) {
        timePart = '00:00';
      } else {
        timePart = '00:00';
      }
    }
    return '$_dateStr $timePart';
  }

  void _send() {
    final user = ref.read(userProvider);
    if (user == null) return;
    final t = timeNow();
    final today = dateToday();
    final msg = MessageModel(
      id: DateTime.now().millisecondsSinceEpoch,
      userId: outgoingMessageUserId(user),
      name: user.name,
      car: user.car,
      time: t,
      date: today,
      type: MessageType.vendorReport,
      isMe: true,
      vendorData: VendorData(
        company: user.company,
        operationDateTime: _operationDateTimeCombined,
        departure: _departureCtl.text.trim(),
        destination: _destinationCtl.text.trim(),
        passengerCount: _passengerCtl.text.trim(),
        distanceKm: _distanceCtl.text.trim(),
        reserver: _reserverCtl.text.trim(),
        specialNote: _specialNoteCtl.text.trim(),
      ),
    );
    widget.onSend(msg);
  }

  Widget _labeledField(String label, TextEditingController c, {String? hint, TextInputType? keyboardType, int? maxLines}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: _fieldDeco,
          child: TextField(
            controller: c,
            keyboardType: keyboardType,
            maxLines: maxLines ?? 1,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFBBBBBB)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  /// 솔라티 패널: 한 줄에 두 칸 (간격 10)
  Widget _vendorTwoColumnRow(Widget left, Widget right) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 10),
        Expanded(child: right),
      ],
    );
  }

  Widget _distanceFieldCell() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('이동거리', style: _labelStyle),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: _fieldDeco,
                child: TextField(
                  controller: _distanceCtl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '0',
                    hintStyle: TextStyle(fontSize: 14, color: Color(0xFFBBBBBB)),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Text('km', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF555555))),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 580),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFEEEEEE)))),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('운행일자', style: _labelStyle),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.tryParse(_dateStr) ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) {
                  setState(() {
                    _dateStr = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                  });
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: _fieldDeco,
                child: Text(_dateStr, style: const TextStyle(fontSize: 14)),
              ),
            ),
            const SizedBox(height: 12),
            const Text('운행시간', style: _labelStyle),
            const SizedBox(height: 4),
            const Text('숫자 4자리 (예: 0730 → 07:30, 범위 초과 시 00:00)', style: TextStyle(fontSize: 10, color: Color(0xFFAAAAAA))),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: _fieldDeco,
              child: TextField(
                controller: _timeCtl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '0000',
                  hintStyle: TextStyle(fontSize: 14, color: Color(0xFFBBBBBB)),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: _onVendorTimeChanged,
              ),
            ),
            const SizedBox(height: 12),
            _vendorTwoColumnRow(
              _labeledField('출발지', _departureCtl, hint: '출발지 입력'),
              _labeledField('도착지', _destinationCtl, hint: '도착지 입력'),
            ),
            const SizedBox(height: 12),
            _vendorTwoColumnRow(
              _labeledField('탑승인원', _passengerCtl, hint: '예: 12', keyboardType: TextInputType.number),
              _distanceFieldCell(),
            ),
            const SizedBox(height: 12),
            _vendorTwoColumnRow(
              _labeledField('예약자', _reserverCtl, hint: '예약자 이름'),
              _labeledField('특이사항', _specialNoteCtl, hint: '내용 입력', maxLines: 3),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _send,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(color: const Color(0xFF1A237E), borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: const Text('보고 전송', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 공용 위젯 ────────────────────────────────────────────────
/// 채팅 이미지 메시지 풀스크린: 좌우 스와이프로 같은 방의 사진만 순서대로 탐색
class _ChatImageGalleryDialog extends StatefulWidget {
  final List<String> urls;
  final String initialUrl;

  const _ChatImageGalleryDialog({
    required this.urls,
    required this.initialUrl,
  });

  @override
  State<_ChatImageGalleryDialog> createState() => _ChatImageGalleryDialogState();
}

class _ChatImageGalleryDialogState extends State<_ChatImageGalleryDialog> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    final urls = widget.urls;
    var initial = 0;
    if (urls.isNotEmpty) {
      final hit = urls.indexOf(widget.initialUrl);
      initial = hit >= 0 ? hit : 0;
    }
    _currentIndex = initial;
    _pageController = PageController(initialPage: initial);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    if (urls.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    final size = MediaQuery.sizeOf(context);

    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PhotoViewGallery.builder(
              pageController: _pageController,
              itemCount: urls.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              scrollPhysics: const BouncingScrollPhysics(),
              backgroundDecoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.98)),
              builder: (context, index) {
                return PhotoViewGalleryPageOptions.customChild(
                  minScale: PhotoViewComputedScale.contained * 0.85,
                  maxScale: PhotoViewComputedScale.covered * 4,
                  initialScale: PhotoViewComputedScale.contained,
                  basePosition: Alignment.center,
                  child: ChatGalleryPhoto(
                    url: urls[index],
                    width: size.width,
                    height: size.height,
                  ),
                );
              },
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            if (urls.length > 1)
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        child: Text(
                          '${_currentIndex + 1} / ${urls.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 슈퍼관리자 — 카카오맵 URL·라벨 한 줄 편집 (컨트롤러는 부모가 관리)
class _KakaoNavLinkDraftTile extends StatelessWidget {
  final TextEditingController urlController;
  final TextEditingController labelController;
  final VoidCallback onDelete;

  const _KakaoNavLinkDraftTile({
    super.key,
    required this.urlController,
    required this.labelController,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: urlController,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 2,
                  inputFormatters: [KakaoKkoUrlExtractingFormatter()],
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: '카카오맵 공유 URL',
                    hintText: 'https://kko.to/... (붙여넣기 시 링크만 자동 추출)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                tooltip: '삭제',
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: labelController,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              isDense: true,
              labelText: '버튼 라벨',
              hintText: '예: 양지출근',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconHeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? backgroundColor;
  final Color? borderColor;

  const _IconHeaderBtn({
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white,
            border: Border.all(color: borderColor ?? const Color(0xFFDDDDDD)),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 19, color: iconColor ?? const Color(0xFF555555)),
        ),
      ),
    );
  }
}

class _AddCalendarBottomSheet extends ConsumerStatefulWidget {
  const _AddCalendarBottomSheet();

  @override
  ConsumerState<_AddCalendarBottomSheet> createState() => _AddCalendarBottomSheetState();
}

class _AddCalendarBottomSheetState extends ConsumerState<_AddCalendarBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _titleCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  DateTime? _endDate;
  TimeOfDay? _selectedTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() {
          _endDate = null;
          _selectedTime = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  bool get _isTodo => _tabCtrl.index == 0;

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate({bool isEnd = false}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isEnd ? (_endDate ?? _selectedDate) : _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF6366F1)),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isEnd) {
        _endDate = picked;
      } else {
        _selectedDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
      }
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF6366F1)),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => _selectedTime = picked);
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    final creator = ref.read(userProvider)?.name.trim() ?? '';
    final item = CalendarItem(
      id: const Uuid().v4(),
      date: _fmt(_selectedDate),
      kind: _isTodo ? 'todo' : 'schedule',
      title: title,
      startTime: (!_isTodo && _selectedTime != null) ? _fmtTime(_selectedTime!) : null,
      endDate: (!_isTodo && _endDate != null) ? _fmt(_endDate!) : null,
      createdByName: creator.isEmpty ? null : creator,
    );
    await ChatFirestoreRepository.addCalendarItem(item);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '일정 추가',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
              ),
              const SizedBox(height: 16),

              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  indicator: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xFF666666),
                  labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  tabs: const [
                    Tab(text: '할 일'),
                    Tab(text: '일정'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _titleCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: _isTodo ? '할 일을 입력하세요' : '일정 제목을 입력하세요',
                  hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 14),

              _buildDateRow(
                icon: Icons.calendar_today_rounded,
                label: '날짜',
                value: _fmt(_selectedDate),
                onTap: () => _pickDate(),
              ),

              if (!_isTodo) ...[
                const SizedBox(height: 10),
                _buildDateRow(
                  icon: Icons.access_time_rounded,
                  label: '시간',
                  value: _selectedTime != null ? _fmtTime(_selectedTime!) : '선택 안 함',
                  onTap: _pickTime,
                  onClear: _selectedTime != null ? () => setState(() => _selectedTime = null) : null,
                ),
                const SizedBox(height: 10),
                _buildDateRow(
                  icon: Icons.date_range_rounded,
                  label: '종료일',
                  value: _endDate != null ? _fmt(_endDate!) : '선택 안 함',
                  onTap: () => _pickDate(isEnd: true),
                  onClear: _endDate != null ? () => setState(() => _endDate = null) : null,
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  child: _saving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('추가'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF6366F1)),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
            const Spacer(),
            Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
            if (onClear != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFAAAAAA)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
