import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../models/message_model.dart';
import '../models/room_model.dart';
import '../providers/app_provider.dart';
import '../providers/gps_provider.dart';
import '../services/gps_service.dart';
import '../utils/app_colors.dart';
import '../utils/helpers.dart';
import '../utils/sample_data.dart';
import '../widgets/message_bubbles.dart';
import '../widgets/timetable_image.dart';

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
      return '📷 사진';
    case MessageType.emergency:
      return '🚨 ${msg.emergencyType ?? '긴급 호출'}';
    case MessageType.notice:
      return '📢 ${msg.text ?? ''}';
    case MessageType.dbResult:
      return '🔍 검색 결과';
    case MessageType.summary:
      return '📊 ${msg.date} 운행 집계';
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
  bool _showEmergencyConfirm = false;
  bool _showDeleteRoomPopup = false;
  bool _showTimetable = false;
  int _timetableViewIndex = 0;
  bool _showReportPanel = false;
  int _reportPage = 0;
  String? _emergencyType;
  MessageModel? _emergencyAlert;

  String _inputText = '';

  /// 방별 스크롤 offset (메모리 + SharedPreferences 백업)
  static const _scrollPrefPrefix = 'chat_scroll_offset_';
  static const _nearBottomPx = 120.0;

  final Map<int, double> _scrollOffsetMemory = {};
  final Map<int, int> _messageLenByRoom = {};
  int? _activeChatRoomId;
  int? _pendingRestoreRoomId;
  bool _suppressNextAutoFollow = false;
  int _scrollMaintenanceGeneration = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScrollPositionChanged);
  }

  void _onScrollPositionChanged() {
    final id = _activeChatRoomId;
    if (id == null || !_scrollController.hasClients) return;
    _scrollOffsetMemory[id] = _scrollController.offset;
  }

  void _persistScrollForRoom(int roomId) {
    if (!_scrollController.hasClients) return;
    final p = _scrollController.position;
    if (!p.hasContentDimensions) return;
    final max = p.maxScrollExtent;
    final o = _scrollController.offset.clamp(0.0, max);
    _scrollOffsetMemory[roomId] = o;
    SharedPreferences.getInstance().then((sp) => sp.setDouble('$_scrollPrefPrefix$roomId', o));
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final p = _scrollController.position;
    if (!p.hasContentDimensions) return true;
    return p.maxScrollExtent - p.pixels <= _nearBottomPx;
  }

  Future<void> _restoreScrollForRoom(int roomId, int messageCount) async {
    final sp = await SharedPreferences.getInstance();
    if (!mounted) return;
    final disk = sp.getDouble('$_scrollPrefPrefix$roomId');
    final saved = _scrollOffsetMemory[roomId] ?? disk;

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
        }
        return;
      }
      final max = p.maxScrollExtent;
      if (saved == null) {
        _scrollController.jumpTo(max);
      } else {
        _scrollController.jumpTo(saved.clamp(0.0, max));
      }
      _messageLenByRoom[roomId] = messageCount;
      _suppressNextAutoFollow = true;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
    });
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
      _pendingRestoreRoomId = null;
      _restoreScrollForRoom(roomId, messageLength);
      return;
    }
    if (_suppressNextAutoFollow) {
      _suppressNextAutoFollow = false;
      _messageLenByRoom[roomId] = messageLength;
      return;
    }
    final prev = _messageLenByRoom[roomId];
    _messageLenByRoom[roomId] = messageLength;
    if (prev != null && messageLength > prev && _isNearBottom()) {
      _scrollToBottom(animated: true);
    }
  }

  @override
  void dispose() {
    if (_activeChatRoomId != null) {
      _persistScrollForRoom(_activeChatRoomId!);
    }
    _scrollController.removeListener(_onScrollPositionChanged);
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
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

  List<MessageModel> _getMessages(RoomModel room) {
    if (room.id == 999) return ref.watch(adminMessageProvider);
    if (room.id == 998) return ref.watch(dbMessageProvider);
    return ref.watch(messageProvider).where((m) {
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
    } else {
      ref.read(messageProvider.notifier).add(msg);
      ref.read(roomProvider.notifier).updateRoom(room.id, (r) => r.copyWith(
            lastMsg: _roomListLastPreview(msg),
            time: msg.time,
          ));
    }
  }

  void _editMessage(RoomModel room, int id, String newText) {
    if (room.id == 999) return;
    if (room.id == 998) return;
    ref.read(messageProvider.notifier).editText(id, newText);
  }

  void _sendText(RoomModel room, bool isDbRoom) {
    final text = _inputText.trim();
    if (text.isEmpty) return;
    final user = ref.read(userProvider)!;
    final t = timeNow();
    final today = dateToday();

    _addMessage(room, MessageModel(
      id: DateTime.now().millisecondsSinceEpoch,
      userId: 'me',
      name: user.name,
      avatar: user.avatar,
      car: user.car,
      text: text,
      time: t,
      date: today,
      type: MessageType.text,
      isMe: true,
    ));

    ref.read(roomProvider.notifier).updateRoom(room.id, (r) => r.copyWith(lastMsg: text, time: t));
    _textController.clear();
    setState(() => _inputText = '');
    _scrollToBottom();

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

    for (var i = 0; i < files.length; i++) {
      _addMessage(
        room,
        MessageModel(
          id: baseId + i,
          userId: 'me',
          name: user.name,
          avatar: user.avatar,
          car: user.car,
          time: t,
          date: today,
          type: MessageType.image,
          isMe: true,
          imageUrl: files[i].path,
        ),
      );
    }

    final lastLabel = files.length == 1 ? '📷 사진' : '📷 사진 ${files.length}장';
    ref.read(roomProvider.notifier).updateRoom(room.id, (r) => r.copyWith(lastMsg: lastLabel, time: t));
    setState(() {});
    _scrollToBottom();
  }

  void _handleDbQuery(RoomModel room, String query, String t, String today, String userName) {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final isCarQuery = RegExp(r'\d{4}').hasMatch(query);
      final isNameQuery = RegExp(r'^[가-힣]{2,4}$').hasMatch(query.trim());

      final allMessages = ref.read(messageProvider);
      final reportMsgs = [...allMessages].where((m) => m.type == MessageType.report).toList().reversed.toList();

      DbResultCard? resultCard;

      if (isNameQuery) {
        final name = query.trim();
        final driverInfo = driverDb.where((d) => d.name == name).firstOrNull;
        final lastReport = reportMsgs.where((m) => m.name == name).firstOrNull;
        if (driverInfo != null || lastReport != null) {
          resultCard = DbResultCard(
            searchType: 'name',
            name: driverInfo?.name ?? lastReport?.name ?? name,
            phone: driverInfo?.phone ?? '미등록',
            company: driverInfo?.company ?? '미등록',
            route: lastReport?.route,
            subRoute: lastReport?.subRoute,
            car: lastReport?.car ?? driverInfo?.car,
            reportData: lastReport?.reportData,
            reportDateTime: lastReport != null ? '${lastReport.date} ${lastReport.time}' : null,
            specialNote: driverInfo?.specialNote,
          );
        }
      } else if (isCarQuery) {
        final digits = query.replaceAll(RegExp(r'[^0-9]'), '');
        final lastReport = reportMsgs.where((m) => m.car != null && m.car!.replaceAll(RegExp(r'\D'), '').contains(digits)).firstOrNull;
        final vehicleInfo = vehicleDb.where((v) => v.carNumber.replaceAll(RegExp(r'\D'), '').contains(digits)).firstOrNull;
        final driverInfo = vehicleInfo != null
            ? driverDb.where((d) => d.name == vehicleInfo.driver).firstOrNull
            : (lastReport != null ? driverDb.where((d) => d.name == lastReport.name).firstOrNull : null);
        if (lastReport != null || vehicleInfo != null) {
          resultCard = DbResultCard(
            searchType: 'car',
            car: lastReport?.car ?? vehicleInfo?.carNumber,
            name: lastReport?.name ?? vehicleInfo?.driver,
            phone: driverInfo?.phone ?? '미등록',
            company: driverInfo?.company ?? '미등록',
            route: lastReport?.route,
            subRoute: lastReport?.subRoute,
            reportData: lastReport?.reportData,
            reportDateTime: lastReport != null ? '${lastReport.date} ${lastReport.time}' : null,
            specialNote: driverInfo?.specialNote,
          );
        }
      }

      if (resultCard != null) {
        _addMessage(room, MessageModel(
          id: DateTime.now().millisecondsSinceEpoch + 1,
          userId: 'system',
          name: '시스템',
          time: timeNow(),
          date: today,
          type: MessageType.dbResult,
          isMe: false,
          resultCard: resultCard,
        ));
      } else {
        _addMessage(room, MessageModel(
          id: DateTime.now().millisecondsSinceEpoch + 1,
          userId: 'system',
          name: '시스템',
          text: '\'$query\'에 해당하는 정보를 찾을 수 없어요.',
          time: timeNow(),
          date: today,
          type: MessageType.text,
          isMe: false,
        ));
      }
      ref.read(roomProvider.notifier).updateRoom(room.id, (r) => r.copyWith(lastMsg: '🔍 $query 검색', time: timeNow()));
      _scrollToBottom();
    });
  }


  // ─── 운행 관리 현황 집계 생성 ────────────────────────────────
  void _generateSummary() {
    final allMessages = ref.read(messageProvider);
    final allRooms = ref.read(roomProvider);
    final today = dateToday();
    final t = timeNow();

    final normalRooms = allRooms.where((r) => !r.adminOnly).toList();
    final reportMsgs = allMessages.where((m) => m.type == MessageType.report && m.date == today).toList();

    List<SummaryLine> makeLines(String shiftType) {
      return normalRooms.map((room) {
        final subRoutes = room.subRoutes;
        final roomReports = reportMsgs.where((m) => m.reportData?.type == shiftType && m.route == room.name).toList();
        if (subRoutes.isNotEmpty) {
          final subLines = subRoutes.map((sub) {
            final subReports = roomReports.where((m) => m.subRoute == sub).toList();
            final total = subReports.fold(0, (s, m) => s + (m.reportData?.count ?? 0));
            return SummaryLine(name: sub, total: total, reported: subReports.isNotEmpty);
          }).toList();
          final total = subLines.fold(0, (s, l) => s + l.total);
          return SummaryLine(name: room.name, total: total, reported: subLines.any((l) => l.reported), subLines: subLines);
        }
        final total = roomReports.fold(0, (s, m) => s + (m.reportData?.count ?? 0));
        return SummaryLine(name: room.name, total: total, reported: roomReports.isNotEmpty);
      }).toList();
    }

    final morningLines = makeLines('출근');
    final eveningLines = makeLines('퇴근');
    final morningTotal = morningLines.fold(0, (s, l) => s + l.total);
    final eveningTotal = eveningLines.fold(0, (s, l) => s + l.total);
    final unreported = morningLines.where((l) => !l.reported).length;

    final summaryMsg = MessageModel(
      id: DateTime.now().millisecondsSinceEpoch,
      userId: 'system',
      name: '시스템',
      emoji: '📊',
      time: t,
      date: today,
      type: MessageType.summary,
      isMe: false,
      morningLines: morningLines,
      eveningLines: eveningLines,
      morningTotal: morningTotal,
      eveningTotal: eveningTotal,
      unreported: unreported,
    );

    ref.read(adminMessageProvider.notifier).upsertSummary(summaryMsg);
    ref.read(roomProvider.notifier).updateRoom(999, (r) => r.copyWith(
      lastMsg: '📊 출근 ${morningTotal}명 · 퇴근 ${eveningTotal}명',
      time: t,
    ));
  }

  void _sendEmergency(RoomModel room) {
    if (_emergencyType == null) return;
    final user = ref.read(userProvider)!;
    final t = timeNow();
    final today = dateToday();
    final msg = MessageModel(
      id: DateTime.now().millisecondsSinceEpoch,
      userId: 'me',
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
      if (ref.read(userProvider)!.isAdmin) _emergencyAlert = msg;
      _emergencyType = null;
    });
    _scrollToBottom();
  }

  void _handleReact(RoomModel room, int msgId, String emoji, String userName) {
    if (room.id == 998 || room.id == 999) return;
    ref.read(messageProvider.notifier).react(msgId, emoji, userName);
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(currentRoomProvider);
    if (room == null) {
      if (_activeChatRoomId != null) {
        _persistScrollForRoom(_activeChatRoomId!);
        _activeChatRoomId = null;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/rooms'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = ref.watch(userProvider)!;
    final isAdmin = user.isAdmin;
    final isAdminRoom = room.id == 999;
    final isDbRoom = room.id == 998;
    final isVendorRoom = room.isVendorRoom;
    final messages = _getMessages(room);

    if (_activeChatRoomId != room.id) {
      if (_activeChatRoomId != null) {
        _persistScrollForRoom(_activeChatRoomId!);
      }
      _activeChatRoomId = room.id;
      _pendingRestoreRoomId = room.id;
    }
    _queueScrollMaintenance(room.id, messages.length);

    // 운행 관리 현황: 입장 시 및 보고 메시지 변경 시 자동 집계
    if (isAdminRoom) {
      ref.listen(messageProvider, (prev, next) {
        if (prev?.length != next.length || prev != next) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _generateSummary());
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _generateSummary());
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(room, isAdmin, isAdminRoom, isDbRoom, isVendorRoom),
              Expanded(
                child: GestureDetector(
                  onTap: () { if (_showReportPanel) setState(() => _showReportPanel = false); },
                  behavior: HitTestBehavior.translucent,
                  child: _buildMessageArea(room, messages, user, isAdmin),
                ),
              ),
              if (!isAdminRoom)
                _buildInputArea(room, isAdmin, isDbRoom, isVendorRoom),
            ],
          ),

          // 사이드 메뉴
          if (_showSideMenu) _buildSideMenu(room, messages, user, isAdmin, isAdminRoom, isDbRoom, isVendorRoom),

          // 긴급 호출 확인 팝업
          if (_showEmergencyConfirm) _buildEmergencyConfirm(room),

          // 관리자 긴급 알림
          if (_emergencyAlert != null && isAdmin) _buildEmergencyAlert(),

          // 채팅방 삭제 확인
          if (_showDeleteRoomPopup) _buildDeleteRoomPopup(room),

          // 배차 시간표
          if (_showTimetable && room.hasTimetable) _buildTimetable(room),
        ],
      ),
    );
  }

  // ─── 헤더 ───────────────────────────────────────────────────
  Widget _buildHeader(RoomModel room, bool isAdmin, bool isAdminRoom, bool isDbRoom, bool isVendorRoom) {
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
            onPressed: () {
              _persistScrollForRoom(room.id);
              context.go('/rooms');
            },
          ),
          Expanded(
            child: Text(room.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          ),
          if (!isAdminRoom && !isDbRoom && room.hasTimetable)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Tooltip(
                message: '배차 시간표',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() {
                      _timetableViewIndex = 0;
                      _showTimetable = true;
                    }),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.morningBlueBg,
                        border: Border.all(color: AppColors.morningBlue.withValues(alpha: 0.28)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '배차표',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.morningBlue,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
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
          if (!isAdminRoom && !isDbRoom)
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
                onTap: () => setState(() => _showSideMenu = true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 메시지 영역 ─────────────────────────────────────────────
  Widget _buildMessageArea(RoomModel room, List<MessageModel> messages, dynamic user, bool isAdmin) {
    if (messages.isEmpty) {
      return const Center(child: Text('메시지가 없어요', style: TextStyle(color: AppColors.textHint, fontSize: 14)));
    }

    final allImages = messages
        .where((m) => m.type == MessageType.image && (m.imageUrl?.isNotEmpty ?? false))
        .map((m) => m.imageUrl!)
        .toList();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final msg = messages[i];
        final prevMsg = i > 0 ? messages[i - 1] : null;
        final showDate = prevMsg == null || prevMsg.date != msg.date;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDate) DateDivider(date: msg.date),
            MessageBubble(
              msg: msg,
              isAdmin: isAdmin,
              currentUser: user.name,
              onEdit: (id, newText) => _editMessage(room, id, newText),
              onDelete: (id) => ref.read(messageProvider.notifier).remove(id),
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
            ),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }

  // ─── 입력창 ──────────────────────────────────────────────────
  Widget _buildInputArea(RoomModel room, bool isAdmin, bool isDbRoom, bool isVendorRoom) {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 인원 보고 패널
          if (_showReportPanel)
            isVendorRoom
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
                      child: const Text('인원보고', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black)),
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    onChanged: (v) => setState(() => _inputText = v),
                    onSubmitted: (_) => _sendText(room, isDbRoom),
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

          // 하단 Safe Area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  // ─── 사이드 메뉴 ─────────────────────────────────────────────
  Widget _buildSideMenu(RoomModel room, List<MessageModel> messages, dynamic user, bool isAdmin, bool isAdminRoom, bool isDbRoom, bool isVendorRoom) {
    final today = dateToday();
    final todayReports = messages.where((m) => m.type == MessageType.report && m.date == today && m.route == room.name).toList();
    final morningTotal = todayReports.where((m) => m.reportData?.type == '출근').fold(0, (s, m) => s + (m.reportData?.count ?? 0));
    final eveningTotal = todayReports.where((m) => m.reportData?.type == '퇴근').fold(0, (s, m) => s + (m.reportData?.count ?? 0));

    // 내 보고 내역: 전체 채팅방에서 오늘 내가 보낸 report (최신순)
    final allMyReports = ref.watch(messageProvider)
        .where((m) => m.type == MessageType.report && m.date == today && m.name == user.name)
        .toList()
        .reversed
        .toList();
    const int _pageSize = 3;
    final totalPages = (allMyReports.length / _pageSize).ceil().clamp(1, 999);
    final pagedReports = allMyReports.skip(_reportPage * _pageSize).take(_pageSize).toList();

    return GestureDetector(
      onTap: () => setState(() => _showSideMenu = false),
      child: Container(
        color: Colors.black45,
        child: Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              height: double.infinity,
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
                          if (!isVendorRoom && !isAdminRoom && !isDbRoom) ...[
                            Text('$today 당일 집계', style: const TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                            const SizedBox(height: 16),
                            Row(children: [
                              Expanded(child: _SummaryCard(label: '총 출근', value: morningTotal, color: AppColors.morningBlue, bg: AppColors.morningBlueBg)),
                              const SizedBox(width: 10),
                              Expanded(child: _SummaryCard(label: '총 퇴근', value: eveningTotal, color: AppColors.eveningRed, bg: AppColors.eveningRedBg)),
                            ]),
                            const SizedBox(height: 20),
                            // 세부 노선별 집계
                            if (room.subRoutes.isNotEmpty) ...[
                              const Text('세부 노선별', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF333333))),
                              const SizedBox(height: 10),
                              ...room.subRoutes.map((sub) {
                                final subMorning = todayReports.where((m) => m.reportData?.type == '출근' && m.subRoute == sub).fold(0, (s, m) => s + (m.reportData?.count ?? 0));
                                final subEvening = todayReports.where((m) => m.reportData?.type == '퇴근' && m.subRoute == sub).fold(0, (s, m) => s + (m.reportData?.count ?? 0));
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12)),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(sub, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black)),
                                      const SizedBox(height: 8),
                                      Row(children: [
                                        Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                          const Text('출근', style: TextStyle(fontSize: 12, color: AppColors.morningBlue, fontWeight: FontWeight.w600)),
                                          Text('$subMorning명', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.morningBlue)),
                                        ])),
                                        const SizedBox(width: 12, child: VerticalDivider(color: Color(0xFFE0E0E0))),
                                        Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                          const Text('퇴근', style: TextStyle(fontSize: 12, color: AppColors.eveningRed, fontWeight: FontWeight.w600)),
                                          Text('$subEvening명', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.eveningRed)),
                                        ])),
                                      ]),
                                    ],
                                  ),
                                );
                              }),
                            ],
                            if (todayReports.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 20),
                                child: Center(child: Text('오늘 보고 내역이 없어요', style: TextStyle(fontSize: 13, color: AppColors.textHint))),
                              ),

                            // ─── 내 보고 내역 (전체 채팅방) ─────────────
                            if (allMyReports.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  RichText(text: const TextSpan(children: [
                                    TextSpan(text: '내 보고 내역', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF333333))),
                                    TextSpan(text: '  전체 채팅방', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textHint)),
                                  ])),
                                  Text('${_reportPage + 1} / $totalPages', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ...pagedReports.map((m) {
                                final isOut = m.reportData?.type == '퇴근';
                                final color = isOut ? AppColors.eveningRed : AppColors.morningBlue;
                                final bg    = isOut ? AppColors.eveningRedBg : AppColors.morningBlueBg;
                                final routeLabel = m.route != null ? (m.subRoute != null ? '${m.route} · ${m.subRoute}' : m.route!) : '';
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 7),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(11)),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
                                        child: Text(m.reportData?.type ?? '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(routeLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111111)), overflow: TextOverflow.ellipsis),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(m.car ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                                      const SizedBox(width: 8),
                                      Text('${m.reportData?.count ?? 0}명', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
                                      const SizedBox(width: 8),
                                      Text(m.time, style: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB))),
                                    ],
                                  ),
                                );
                              }),
                              // 페이지네이션
                              if (totalPages > 1) ...[
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    GestureDetector(
                                      onTap: _reportPage > 0 ? () => setState(() => _reportPage--) : null,
                                      child: Container(
                                        width: 36, height: 36,
                                        decoration: BoxDecoration(
                                          border: Border.all(color: const Color(0xFFE0E0E0)),
                                          borderRadius: BorderRadius.circular(10),
                                          color: _reportPage == 0 ? const Color(0xFFF5F5F5) : Colors.white,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text('▲', style: TextStyle(fontSize: 14, color: _reportPage == 0 ? const Color(0xFFCCCCCC) : const Color(0xFF333333))),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    ...List.generate(totalPages, (pi) => GestureDetector(
                                      onTap: () => setState(() => _reportPage = pi),
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 3),
                                        width: pi == _reportPage ? 18 : 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: pi == _reportPage ? const Color(0xFF333333) : const Color(0xFFDDDDDD),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                    )),
                                    const SizedBox(width: 10),
                                    GestureDetector(
                                      onTap: _reportPage < totalPages - 1 ? () => setState(() => _reportPage++) : null,
                                      child: Container(
                                        width: 36, height: 36,
                                        decoration: BoxDecoration(
                                          border: Border.all(color: const Color(0xFFE0E0E0)),
                                          borderRadius: BorderRadius.circular(10),
                                          color: _reportPage >= totalPages - 1 ? const Color(0xFFF5F5F5) : Colors.white,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text('▼', style: TextStyle(fontSize: 14, color: _reportPage >= totalPages - 1 ? const Color(0xFFCCCCCC) : const Color(0xFF333333))),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
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
                        if (isAdmin && !isAdminRoom)
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
                          onTap: () => context.go('/rooms'),
                          child: const Text('← 채팅방 나가기', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── 긴급 호출 확인 팝업 ─────────────────────────────────────
  Widget _buildEmergencyConfirm(RoomModel room) {
    final items = [
      ('🚗', '차량 고장'),
      ('🚑', '응급 환자'),
      ('⚠️', '사고 발생'),
      ('👊', '승객 난동'),
    ];
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Container(
        width: 300,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 32)]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🚨 긴급 호출', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.eveningRed)),
            const SizedBox(height: 4),
            const Text('상황을 선택해주세요', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
            const SizedBox(height: 14),
            ...items.map((item) => GestureDetector(
              onTap: () => setState(() => _emergencyType = item.$2),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _emergencyType == item.$2 ? const Color(0x12C62828) : Colors.white,
                  border: Border.all(color: _emergencyType == item.$2 ? AppColors.eveningRed : const Color(0xFFEEEEEE), width: _emergencyType == item.$2 ? 2 : 1.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  Text(item.$1, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Text(item.$2, style: TextStyle(fontSize: 17, fontWeight: _emergencyType == item.$2 ? FontWeight.w700 : FontWeight.w500, color: _emergencyType == item.$2 ? AppColors.eveningRed : const Color(0xFF333333))),
                ]),
              ),
            )),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => setState(() { _showEmergencyConfirm = false; _emergencyType = null; }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFDDDDDD)), borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: const Text('취소', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF555555))),
                ),
              )),
              const SizedBox(width: 8),
              Expanded(child: GestureDetector(
                onTap: _emergencyType != null ? () => _sendEmergency(room) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: _emergencyType != null ? AppColors.eveningRed : const Color(0xFFCCCCCC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Text('전송', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              )),
            ]),
          ],
        ),
      ),
    );
  }

  // ─── 관리자 긴급 알림 ────────────────────────────────────────
  Widget _buildEmergencyAlert() {
    final msg = _emergencyAlert!;
    return Container(
      color: AppColors.eveningRed.withValues(alpha: 0.92),
      alignment: Alignment.center,
      child: Container(
        width: 300,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.eveningRed, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 32)]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🚨', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text('🚨 ${msg.emergencyType}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.eveningRed)),
            const SizedBox(height: 12),
            Text(msg.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF333333))),
            Text(msg.phone ?? '', style: const TextStyle(fontSize: 14, color: Color(0xFF333333))),
            Text(msg.car ?? '', style: const TextStyle(fontSize: 14, color: Color(0xFF333333))),
            Text('${msg.route} · ${msg.time}', style: const TextStyle(fontSize: 14, color: Color(0xFF333333))),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => setState(() => _emergencyAlert = null),
              child: Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: AppColors.eveningRed, borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: const Text('확인 완료', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
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
    final images = room.timetableImages;
    if (images.isEmpty) return const SizedBox.shrink();
    return _TimetablePhotoViewOverlay(
      room: room,
      images: images,
      initialIndex: _timetableViewIndex,
      onClose: () => setState(() => _showTimetable = false),
    );
  }
}

/// 배차 시간표 모달: 채팅 이미지와 동일하게 PhotoViewGallery로 스와이프·줌
class _TimetablePhotoViewOverlay extends StatefulWidget {
  final RoomModel room;
  final List<String> images;
  final int initialIndex;
  final VoidCallback onClose;

  const _TimetablePhotoViewOverlay({
    required this.room,
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
                  '${widget.room.name} 배차 시간표',
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
    final msg = MessageModel(
      id: DateTime.now().millisecondsSinceEpoch,
      userId: 'me',
      name: user.name,
      car: user.car,
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
    if (!kIsWeb) _triggerGps(user, msg);
  }

  Future<void> _triggerGps(user, MessageModel msg) async {
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

    await gps.start(
      name: user.name,
      car: user.car,
      route: widget.room.name,
      subRoute: msg.subRoute ?? '',
      count: msg.reportData?.count ?? 0,
    );

    // 자동 종료 시 Provider 상태 업데이트
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
      subRoute: msg.subRoute ?? '',
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
      userId: 'me',
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
                  child: TimetableImage(
                    source: urls[index],
                    fit: BoxFit.contain,
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

class _SummaryCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final Color bg;
  const _SummaryCard({required this.label, required this.value, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
    child: Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.3)),
        const SizedBox(height: 6),
        Text('$value', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: color, height: 1)),
      ],
    ),
  );
}


