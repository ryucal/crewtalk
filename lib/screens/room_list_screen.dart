import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../models/room_model.dart';
import '../models/company_model.dart';
import '../models/message_model.dart';
import '../providers/app_provider.dart';
import '../providers/gps_provider.dart';
import '../services/auth_repository.dart';
import '../services/gps_service.dart';
import '../utils/app_colors.dart';
import '../utils/helpers.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/timetable_image.dart';

class RoomListScreen extends ConsumerStatefulWidget {
  const RoomListScreen({super.key});

  @override
  ConsumerState<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends ConsumerState<RoomListScreen> {
  bool _editMode = false;
  bool _showActionSheet = false;
  bool _showAddPopup = false;
  bool _showCompanyMgmt = false;
  bool _showBroadcastPopup = false;
  bool _showSettings = false;
  bool _settingNotifSound = true;
  bool _settingVibration = true;
  RoomModel? _pinPopup;
  RoomModel? _editRoomPopup;

  // 채팅방 추가 폼
  String _newRoomName = '';
  List<String> _newRoomCompanies = [];
  List<String> _newRoomSubRoutes = [];
  String _newSubRouteInput = '';
  RoomType _newRoomType = RoomType.normal;
  final _subRouteController = TextEditingController();
  final _roomNameController = TextEditingController();

  // 소속 관리
  final _companyNameController = TextEditingController();
  final _companyPwController = TextEditingController();

  // 전체 공지
  final _broadcastController = TextEditingController();
  List<String> _broadcastCompanies = [];
  /// null: 일반+솔라티 모두, normal/vendor: 해당 유형 채팅방만. 모달 기본값은 일반.
  RoomType? _broadcastRoomKind = RoomType.normal;

  // 채팅방 수정 - 세부노선 추가
  final _editSubRouteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _companyNameController.addListener(() => setState(() {}));
    _companyPwController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _subRouteController.dispose();
    _roomNameController.dispose();
    _companyNameController.dispose();
    _companyPwController.dispose();
    _broadcastController.dispose();
    _editSubRouteController.dispose();
    super.dispose();
  }

  void _enterRoom(RoomModel room) {
    ref.read(currentRoomProvider.notifier).state = room;
    context.go('/chat');
  }

  List<RoomModel> _sortedRooms(List<RoomModel> rooms, bool isAdmin, String userCompany) {
    final adminRooms = isAdmin ? rooms.where((r) => r.adminOnly).toList() : <RoomModel>[];
    final visible = rooms.where((r) =>
      !r.adminOnly &&
      (isAdmin || r.companies.isEmpty || r.companies.contains(userCompany))
    ).toList();
    final pinned = visible.where((r) => r.pinned).toList();
    final normal = visible.where((r) => !r.pinned).toList();
    return [...adminRooms, ...pinned, ...normal];
  }

  void _confirmStopGps() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 280,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, 4))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('운행 종료', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                const Text('운행을 마치겠습니까?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Color(0xFF555555))),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: const Text('취소',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF555555))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          Navigator.pop(context);
                          await GpsService.instance.stop();
                          ref.read(gpsActiveProvider.notifier).state = false;
                          ref.read(gpsRunInfoProvider.notifier).state = null;
                        },
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B30),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: const Text('종료',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleBroadcast() {
    final text = _broadcastController.text.trim();
    if (text.isEmpty) return;
    final t = timeNow();
    final d = dateToday();
    final user = ref.read(userProvider)!;

    ref.read(roomProvider.notifier).reorder(
      ref.read(roomProvider).map((r) {
        if (r.adminOnly) return r;
        if (_broadcastRoomKind != null && r.roomType != _broadcastRoomKind) return r;
        final isTarget = _broadcastCompanies.isEmpty ||
            r.companies.isEmpty ||
            r.companies.any((c) => _broadcastCompanies.contains(c));
        return isTarget ? r.copyWith(lastMsg: '📢 $text', time: t) : r;
      }).toList(),
    );

    ref.read(messageProvider.notifier).add(MessageModel(
      id: DateTime.now().millisecondsSinceEpoch,
      userId: user.phone.isNotEmpty ? user.phone : 'admin',
      name: user.name,
      text: text,
      time: t,
      date: d,
      type: MessageType.notice,
      isMe: true,
      noticeForRoomType: _broadcastRoomKind,
    ));

    _broadcastController.clear();
    setState(() { _broadcastCompanies = []; _broadcastRoomKind = RoomType.normal; _showBroadcastPopup = false; });
  }

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(roomProvider);
    final user = ref.watch(userProvider)!;
    final companies = ref.watch(companyProvider);
    final isAdmin = user.isAdmin;
    final sorted = _sortedRooms(rooms, isAdmin, user.company);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(isAdmin, companies),
              Expanded(
                child: _editMode
                    ? _buildEditList(rooms, isAdmin, user.company)
                    : _buildRoomList(sorted, isAdmin),
              ),
              _buildProfileBar(user),
            ],
          ),

          // 액션시트 (관리자 +버튼)
          if (_showActionSheet) _buildActionSheet(companies),

          // 전체 공지 팝업
          if (_showBroadcastPopup) _buildBroadcastPopup(companies),

          // 채팅방 추가 팝업
          if (_showAddPopup) _buildAddRoomPopup(companies),

          // 소속 관리 팝업
          if (_showCompanyMgmt) _buildCompanyMgmtPopup(companies),

          // 길게 누르기 팝업 (고정/수정)
          if (_pinPopup != null) _buildPinPopup(isAdmin),

          // 채팅방 수정 팝업
          if (_editRoomPopup != null) _buildEditRoomPopup(companies),

          // 앱 설정 팝업
          if (_showSettings) _buildSettingsPanel(user),
        ],
      ),
    );
  }

  // ─── 헤더 ───────────────────────────────────────────────────
  Widget _buildHeader(bool isAdmin, List<CompanyModel> companies) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 14,
        bottom: 10,
        left: 16,
        right: 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
        boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Row(
        children: [
          const Text('채팅', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const Spacer(),
          // 운행종료 버튼 (GPS 활성화 중일 때만 표시)
          if (!kIsWeb && ref.watch(gpsActiveProvider)) ...[
            GestureDetector(
              onTap: () => _confirmStopGps(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '운행종료',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          _TextBtn(label: '프로필설정', onTap: () => context.go('/profile')),
          if (isAdmin) ...[
            const SizedBox(width: 8),
            if (_editMode)
              Material(
                color: AppColors.adminIndigo,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => setState(() => _editMode = false),
                  borderRadius: BorderRadius.circular(10),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Text(
                      '완료',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ),
              )
            else
              _IconBtn(label: '＋', onTap: () => setState(() => _showActionSheet = true)),
          ],
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _showSettings = true),
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: const Icon(Icons.settings_outlined, size: 18, color: Color(0xFF444444)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 채팅방 목록 ─────────────────────────────────────────────
  Widget _buildRoomList(List<RoomModel> sorted, bool isAdmin) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: sorted.length,
      itemBuilder: (context, i) {
        final room = sorted[i];
        return _RoomItem(
          room: room,
          isAdmin: isAdmin,
          onTap: () => _enterRoom(room),
          onLongPress: () => setState(() => _pinPopup = room),
        );
      },
    );
  }

  // ─── 편집 모드 목록 ──────────────────────────────────────────
  Widget _buildEditList(List<RoomModel> rooms, bool isAdmin, String userCompany) {
    final editable = rooms.where((r) =>
      !r.adminOnly &&
      (isAdmin || r.companies.isEmpty || r.companies.contains(userCompany))
    ).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.touch_app_rounded, size: 20, color: Color(0xFF64748B)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '순서 편집',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '항목을 길게 끌어 원하는 위치에 놓으세요',
                        style: TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            itemCount: editable.length,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex--;
              final list = [...rooms];
              final item = editable[oldIndex];
              final realOld = list.indexOf(item);
              final target = editable[newIndex < editable.length ? newIndex : editable.length - 1];
              final realNew = list.indexOf(target);
              list.removeAt(realOld);
              list.insert(realNew, item);
              ref.read(roomProvider.notifier).reorder(list);
            },
            itemBuilder: (context, i) {
              final room = editable[i];
              return Material(
                key: ValueKey(room.id),
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: AvatarWidget(name: room.name, size: 46),
                    title: Text(
                      room.name,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.3, color: Color(0xFF0F172A)),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '길게 눌러 끌어서 이동',
                        style: TextStyle(fontSize: 12, color: Colors.black.withValues(alpha: 0.38)),
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.drag_indicator_rounded, color: Color(0xFF64748B), size: 22),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── 하단 프로필바 ────────────────────────────────────────────
  Widget _buildProfileBar(dynamic user) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Text(todayLocalized(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const _Dot(),
          Text(user.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const _Dot(),
          Text(user.company.isEmpty ? '소속 미설정' : user.company,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const _Dot(),
          Expanded(
            child: Text(
              user.car.isEmpty ? '차량번호 미설정' : user.car,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 액션시트 ─────────────────────────────────────────────────
  Widget _buildActionSheet(List<CompanyModel> companies) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return _BottomSheet(
      onDismiss: () => setState(() => _showActionSheet = false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.adminIndigoBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC5CAE9).withValues(alpha: 0.5)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.admin_panel_settings_outlined, size: 22, color: AppColors.adminIndigo),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '관리 메뉴',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '공지·채팅방·소속·순서',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(height: 24, thickness: 1, color: Color(0xFFF1F5F9)),
          ),
          _ActionSheetRow(
            icon: Icons.campaign_outlined,
            iconBackground: const Color(0xFFFFF7ED),
            iconColor: const Color(0xFFEA580C),
            title: '전체 공지',
            subtitle: '선택한 소속 채팅방에 공지 보내기',
            onTap: () => setState(() { _showActionSheet = false; _showBroadcastPopup = true; }),
          ),
          _ActionSheetRow(
            icon: Icons.add_comment_rounded,
            iconBackground: const Color(0xFFECFDF5),
            iconColor: const Color(0xFF059669),
            title: '채팅방 추가',
            subtitle: '일반·솔라티 노선 만들기',
            onTap: () => setState(() { _showActionSheet = false; _showAddPopup = true; }),
          ),
          _ActionSheetRow(
            icon: Icons.apartment_outlined,
            iconBackground: AppColors.adminIndigoBg,
            iconColor: AppColors.adminIndigo,
            title: '소속 관리',
            subtitle: '로그인용 소속·비밀번호',
            onTap: () => setState(() { _showActionSheet = false; _showCompanyMgmt = true; }),
          ),
          _ActionSheetRow(
            icon: Icons.swap_vert_rounded,
            iconBackground: const Color(0xFFF1F5F9),
            iconColor: const Color(0xFF475569),
            title: '순서 편집',
            subtitle: '채팅방 목록 끌어서 정렬',
            onTap: () => setState(() { _showActionSheet = false; _editMode = true; }),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottomInset),
            child: _SheetDismissBtn(label: '닫기', onTap: () => setState(() => _showActionSheet = false)),
          ),
        ],
      ),
    );
  }

  // ─── 전체 공지 팝업 ───────────────────────────────────────────
  Widget _buildBroadcastPopup(List<CompanyModel> companies) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return _BottomSheet(
      onDismiss: () => setState(() { _showBroadcastPopup = false; _broadcastController.clear(); _broadcastCompanies = []; _broadcastRoomKind = RoomType.normal; }),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHandle(),
          _sheetModalHeader(
            icon: Icons.campaign_outlined,
            title: '전체 공지',
            subtitle: '일반/솔라티·소속을 고르면 받는 채팅방을 나눌 수 있어요',
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel(label: '채팅방 유형'),
                  const SizedBox(height: 10),
                  _broadcastAudienceSegmented(),
                  const SizedBox(height: 18),
                  const _SectionLabel(label: '전송 대상'),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _broadcastSummaryIcon(),
                              size: 18,
                              color: AppColors.adminIndigo.withValues(alpha: 0.85),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _broadcastSummaryLine(),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: companies.map((c) {
                            final selected = _broadcastCompanies.contains(c.name);
                            final colors = AppColors.avatarColor(c.name);
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => setState(() {
                                  if (selected) {
                                    _broadcastCompanies.remove(c.name);
                                  } else {
                                    _broadcastCompanies.add(c.name);
                                  }
                                }),
                                borderRadius: BorderRadius.circular(22),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  curve: Curves.easeOutCubic,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: selected ? colors.bg : Colors.white,
                                    border: Border.all(
                                      color: selected ? colors.color : const Color(0xFFE2E8F0),
                                      width: selected ? 1.5 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(22),
                                    boxShadow: selected
                                        ? [
                                            BoxShadow(
                                              color: colors.color.withValues(alpha: 0.12),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (selected)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 6),
                                          child: Icon(Icons.check_circle_rounded, size: 16, color: colors.color),
                                        ),
                                      Text(
                                        c.name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                          color: selected ? colors.color : const Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _broadcastFooterHint(),
                    style: const TextStyle(fontSize: 11.5, height: 1.45, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 22),
                  const _SectionLabel(label: '공지 내용'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _broadcastController,
                    maxLines: 5,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 15, height: 1.55, color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: '공지 내용을 입력하세요',
                      hintStyle: TextStyle(color: AppColors.textLight.withValues(alpha: 0.95), fontSize: 15),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.adminIndigo, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                _OutlineBtn(label: '취소', onTap: () => setState(() { _showBroadcastPopup = false; _broadcastController.clear(); _broadcastCompanies = []; _broadcastRoomKind = RoomType.normal; })),
                const SizedBox(width: 10),
                Expanded(
                  child: _BlackBtn(
                    label: '전송',
                    enabled: _broadcastController.text.trim().isNotEmpty,
                    onTap: _handleBroadcast,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 채팅방 추가 팝업 ─────────────────────────────────────────
  Widget _buildAddRoomPopup(List<CompanyModel> companies) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return _BottomSheet(
      onDismiss: () => setState(() {
        _showAddPopup = false;
        _newRoomName = '';
        _newRoomCompanies = [];
        _newRoomSubRoutes = [];
        _newSubRouteInput = '';
        _newRoomType = RoomType.normal;
        _roomNameController.clear();
        _subRouteController.clear();
      }),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHandle(),
          _sheetModalHeader(
            icon: Icons.add_comment_rounded,
            title: '채팅방 추가',
            subtitle: '노선과 공개 소속을 설정한 뒤 만들 수 있어요',
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel(label: '채팅방 타입'),
                  const SizedBox(height: 10),
                  _roomTypeSegmented(),
                  const SizedBox(height: 22),
                  const _SectionLabel(label: '노선명'),
                  const SizedBox(height: 10),
                  _RoundInput(
                    controller: _roomNameController,
                    placeholder: '예: 안성',
                    onChanged: (v) => setState(() => _newRoomName = v),
                    onSubmitted: (_) => _addRoom(),
                    autofocus: true,
                  ),
                  const SizedBox(height: 22),
                  const _SectionLabel(label: '세부 노선', optional: true),
                  const SizedBox(height: 10),
                  if (_newRoomSubRoutes.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _newRoomSubRoutes.asMap().entries.map((e) => _SubRouteChip(
                        label: e.value,
                        onRemove: () => setState(() => _newRoomSubRoutes.removeAt(e.key)),
                      )).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _RoundInput(
                          controller: _subRouteController,
                          placeholder: '예: 중앙대',
                          onChanged: (v) => setState(() => _newSubRouteInput = v),
                          onSubmitted: (_) => _addSubRoute(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: _SmallBlackBtn(label: '추가', icon: Icons.add_rounded, onTap: _addSubRoute),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const _SectionLabel(label: '공개 소속'),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: companies.map((c) {
                        final selected = _newRoomCompanies.contains(c.name);
                        final colors = AppColors.avatarColor(c.name);
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => setState(() {
                              if (selected) {
                                _newRoomCompanies.remove(c.name);
                              } else {
                                _newRoomCompanies.add(c.name);
                              }
                            }),
                            borderRadius: BorderRadius.circular(22),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              curve: Curves.easeOutCubic,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected ? colors.bg : Colors.white,
                                border: Border.all(
                                  color: selected ? colors.color : const Color(0xFFE2E8F0),
                                  width: selected ? 1.5 : 1,
                                ),
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: colors.color.withValues(alpha: 0.12),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (selected)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: Icon(Icons.check_circle_rounded, size: 16, color: colors.color),
                                    ),
                                  Text(
                                    c.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                      color: selected ? colors.color : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '미선택 시 모든 기사에게 공개돼요',
                    style: TextStyle(fontSize: 11.5, height: 1.35, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                _OutlineBtn(label: '취소', onTap: () => setState(() {
                  _showAddPopup = false;
                  _newRoomName = '';
                  _newRoomCompanies = [];
                  _newRoomSubRoutes = [];
                  _newSubRouteInput = '';
                  _newRoomType = RoomType.normal;
                  _roomNameController.clear();
                  _subRouteController.clear();
                })),
                const SizedBox(width: 10),
                Expanded(
                  child: _BlackBtn(
                    label: '추가',
                    enabled: _newRoomName.trim().isNotEmpty,
                    onTap: _addRoom,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addSubRoute() {
    if (_newSubRouteInput.trim().isEmpty) return;
    setState(() {
      _newRoomSubRoutes.add(_newSubRouteInput.trim());
      _newSubRouteInput = '';
      _subRouteController.clear();
    });
  }

  void _addRoom() {
    if (_newRoomName.trim().isEmpty) return;
    ref.read(roomProvider.notifier).add(RoomModel(
      id: DateTime.now().millisecondsSinceEpoch,
      name: _newRoomName.trim(),
      lastMsg: '새 채팅방이 생성됐습니다',
      time: timeNow(),
      companies: List.from(_newRoomCompanies),
      subRoutes: List.from(_newRoomSubRoutes),
      roomType: _newRoomType,
    ));
    setState(() {
      _showAddPopup = false;
      _newRoomName = '';
      _newRoomCompanies = [];
      _newRoomSubRoutes = [];
      _newSubRouteInput = '';
      _newRoomType = RoomType.normal;
      _roomNameController.clear();
      _subRouteController.clear();
    });
  }

  // ─── 소속 관리 팝업 ───────────────────────────────────────────
  Widget _buildCompanyMgmtPopup(List<CompanyModel> companies) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return _BottomSheet(
      onDismiss: () => setState(() {
        _showCompanyMgmt = false;
        _companyNameController.clear();
        _companyPwController.clear();
      }),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHandle(),
          _sheetModalHeader(
            icon: Icons.apartment_outlined,
            title: '소속 관리',
            subtitle: '${companies.length}개 소속이 등록되어 있어요',
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          Flexible(
            child: companies.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        '등록된 소속이 없어요.\n아래에서 추가할 수 있어요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    itemCount: companies.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final c = companies[i];
                      final colors = AppColors.avatarColor(c.name);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                              blurRadius: 8,
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
                                color: colors.bg,
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(color: colors.color.withValues(alpha: 0.25)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                c.name.isNotEmpty ? c.name[0] : '?',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: colors.color),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.name,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '비밀번호 · ${c.password}',
                                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),
                            Material(
                              color: const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    barrierColor: Colors.black54,
                                    builder: (_) => Center(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: Container(
                                          width: 300,
                                          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(20),
                                            boxShadow: const [
                                              BoxShadow(color: Color(0x40000000), blurRadius: 40, offset: Offset(0, 12)),
                                            ],
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 48,
                                                height: 48,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFFF1F2),
                                                  borderRadius: BorderRadius.circular(14),
                                                ),
                                                alignment: Alignment.center,
                                                child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 26),
                                              ),
                                              const SizedBox(height: 14),
                                              const Text(
                                                '소속 삭제',
                                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                "'${c.name}'을(를) 삭제할까요?",
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(fontSize: 14, height: 1.4, color: Color(0xFF64748B)),
                                              ),
                                              const SizedBox(height: 22),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: GestureDetector(
                                                      onTap: () => Navigator.pop(context),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(vertical: 13),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFF8FAFC),
                                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                                          borderRadius: BorderRadius.circular(14),
                                                        ),
                                                        alignment: Alignment.center,
                                                        child: const Text(
                                                          '취소',
                                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: GestureDetector(
                                                      onTap: () async {
                                                        Navigator.pop(context);
                                                        final messenger = ScaffoldMessenger.of(context);
                                                        final u = ref.read(userProvider);
                                                        if (u?.firebaseUid != null &&
                                                            u!.isAdmin &&
                                                            AuthRepository.firebaseAvailable) {
                                                          try {
                                                            await AuthRepository.adminDeleteCompany(
                                                              name: c.name,
                                                            );
                                                          } catch (e) {
                                                            if (mounted) {
                                                              messenger.showSnackBar(
                                                                SnackBar(
                                                                  content: Text('Cloud 삭제 실패: $e'),
                                                                ),
                                                              );
                                                            }
                                                            return;
                                                          }
                                                        }
                                                        ref.read(companyProvider.notifier).remove(i);
                                                      },
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(vertical: 13),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFDC2626),
                                                          borderRadius: BorderRadius.circular(14),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: const Color(0xFFDC2626).withValues(alpha: 0.35),
                                                              blurRadius: 10,
                                                              offset: const Offset(0, 4),
                                                            ),
                                                          ],
                                                        ),
                                                        alignment: Alignment.center,
                                                        child: const Text(
                                                          '삭제',
                                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFDC2626)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, 14, 20, 16 + bottomInset),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel(label: '새 소속 추가'),
                const SizedBox(height: 12),
                _RoundInput(
                  controller: _companyNameController,
                  placeholder: '소속명',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                _RoundInput(
                  controller: _companyPwController,
                  placeholder: '로그인 비밀번호',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _BlackBtn(
                        label: '추가',
                        enabled: _companyNameController.text.trim().isNotEmpty && _companyPwController.text.trim().isNotEmpty,
                        onTap: () async {
                          final nm = _companyNameController.text.trim();
                          final pw = _companyPwController.text.trim();
                          if (nm.isEmpty || pw.isEmpty) return;
                          final messenger = ScaffoldMessenger.of(context);
                          final u = ref.read(userProvider);
                          if (u?.firebaseUid != null &&
                              u!.isAdmin &&
                              AuthRepository.firebaseAvailable) {
                            try {
                              await AuthRepository.adminUpsertCompany(name: nm, password: pw);
                            } catch (e) {
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Cloud 등록 실패: $e')),
                                );
                              }
                              return;
                            }
                          }
                          ref.read(companyProvider.notifier).add(CompanyModel(name: nm, password: pw));
                          _companyNameController.clear();
                          _companyPwController.clear();
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    _OutlineBtn(
                      label: '닫기',
                      onTap: () => setState(() {
                        _showCompanyMgmt = false;
                        _companyNameController.clear();
                        _companyPwController.clear();
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 고정 팝업 ───────────────────────────────────────────────
  Widget _buildPinPopup(bool isAdmin) {
    final room = _pinPopup!;
    return _PopupOverlay(
      onDismiss: () => setState(() => _pinPopup = null),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            room.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.35, color: Color(0xFF000000)),
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PinPopupRow(
                  icon: room.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                  label: room.pinned ? '상단 고정 해제' : '상단에 고정',
                  onTap: () {
                    ref.read(roomProvider.notifier).pin(room.id, !room.pinned);
                    setState(() => _pinPopup = null);
                  },
                ),
                if (isAdmin && !room.adminOnly) ...[
                  const Padding(
                    padding: EdgeInsets.only(left: 52),
                    child: Divider(height: 1, thickness: 0.5, color: Color(0xFFD1D1D6)),
                  ),
                  _PinPopupRow(
                    icon: Icons.edit_outlined,
                    label: '채팅방 수정',
                    onTap: () => setState(() {
                      _editRoomPopup = room;
                      _pinPopup = null;
                    }),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _pinPopup = null),
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Text(
                    '닫기',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF8E8E93)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTimetableImages(int roomId) async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty || !mounted) return;
    final paths = files.map((x) => x.path).toList();
    ref.read(roomProvider.notifier).updateRoom(roomId, (r) => r.copyWith(timetableImages: [...r.timetableImages, ...paths]));
    setState(() {});
  }

  void _removeTimetableImage(int roomId, int index) {
    ref.read(roomProvider.notifier).updateRoom(roomId, (r) {
      final next = List<String>.from(r.timetableImages)..removeAt(index);
      return r.copyWith(timetableImages: next);
    });
    setState(() {});
  }

  // ─── 채팅방 수정 팝업 ─────────────────────────────────────────
  Widget _buildEditRoomPopup(List<CompanyModel> companies) {
    final room = _editRoomPopup!;
    final currentRoom = ref.watch(roomProvider).firstWhere((r) => r.id == room.id, orElse: () => room);
    final subRoutes = currentRoom.subRoutes;
    final currentCompanies = currentRoom.companies;
    final timetable = currentRoom.timetableImages;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return _BottomSheet(
      onDismiss: () => setState(() {
        _editRoomPopup = null;
        _editSubRouteController.clear();
      }),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHandle(),
          _sheetModalHeader(
            icon: Icons.edit_calendar_rounded,
            title: room.name,
            subtitle: '채팅방 편집 · 세부 노선, 배차표, 공개 소속',
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel(label: '세부 노선', optional: true),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (subRoutes.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Icon(Icons.route_rounded, size: 18, color: AppColors.adminIndigo.withValues(alpha: 0.7)),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    '등록된 세부 노선이 없어요',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8)),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: subRoutes.asMap().entries.map((e) => _SubRouteChip(
                              label: e.value,
                              onRemove: () {
                                final updated = List<String>.from(subRoutes)..removeAt(e.key);
                                ref.read(roomProvider.notifier).updateRoom(room.id, (r) => r.copyWith(subRoutes: updated));
                                setState(() {});
                              },
                            )).toList(),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _RoundInput(
                                controller: _editSubRouteController,
                                placeholder: '예: 중앙대',
                                onSubmitted: (_) {
                                  if (_editSubRouteController.text.trim().isEmpty) return;
                                  final updated = [...subRoutes, _editSubRouteController.text.trim()];
                                  ref.read(roomProvider.notifier).updateRoom(room.id, (r) => r.copyWith(subRoutes: updated));
                                  _editSubRouteController.clear();
                                  setState(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: _SmallBlackBtn(
                                label: '추가',
                                icon: Icons.add_rounded,
                                onTap: () {
                                  if (_editSubRouteController.text.trim().isEmpty) return;
                                  final updated = [...subRoutes, _editSubRouteController.text.trim()];
                                  ref.read(roomProvider.notifier).updateRoom(room.id, (r) => r.copyWith(subRoutes: updated));
                                  _editSubRouteController.clear();
                                  setState(() {});
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _SectionLabel(label: '배차 시간표', optional: true),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '배차확인에서 기사가 볼 수 있어요. 사진을 여러 장 넣을 수 있어요.',
                          style: TextStyle(fontSize: 12.5, height: 1.4, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 92,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.none,
                            children: [
                              ...timetable.asMap().entries.map((e) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(14),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(14),
                                          child: SizedBox(
                                            width: 84,
                                            height: 84,
                                            child: TimetableImage(source: e.value, fit: BoxFit.cover, width: 84, height: 84),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: -5,
                                        right: -5,
                                        child: Material(
                                          color: const Color(0xFF0F172A),
                                          shape: const CircleBorder(),
                                          clipBehavior: Clip.antiAlias,
                                          child: InkWell(
                                            onTap: () => _removeTimetableImage(room.id, e.key),
                                            child: const Padding(
                                              padding: EdgeInsets.all(6),
                                              child: Icon(Icons.close_rounded, size: 14, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _pickTimetableImages(room.id),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    width: 84,
                                    height: 84,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                                    ),
                                    alignment: Alignment.center,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate_outlined, size: 28, color: AppColors.adminIndigo.withValues(alpha: 0.75)),
                                        const SizedBox(height: 6),
                                        const Text(
                                          '추가',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _SectionLabel(label: '공개 소속'),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: companies.map((c) {
                            final selected = currentCompanies.contains(c.name);
                            final colors = AppColors.avatarColor(c.name);
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  final updated = selected
                                      ? currentCompanies.where((x) => x != c.name).toList()
                                      : [...currentCompanies, c.name];
                                  ref.read(roomProvider.notifier).updateRoom(room.id, (r) => r.copyWith(companies: updated));
                                  setState(() {});
                                },
                                borderRadius: BorderRadius.circular(22),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  curve: Curves.easeOutCubic,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: selected ? colors.bg : Colors.white,
                                    border: Border.all(
                                      color: selected ? colors.color : const Color(0xFFE2E8F0),
                                      width: selected ? 1.5 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(22),
                                    boxShadow: selected
                                        ? [
                                            BoxShadow(
                                              color: colors.color.withValues(alpha: 0.12),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (selected)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 6),
                                          child: Icon(Icons.check_circle_rounded, size: 16, color: colors.color),
                                        ),
                                      Text(
                                        c.name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                          color: selected ? colors.color : const Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '미선택 시 모든 기사에게 공개돼요',
                          style: TextStyle(fontSize: 11.5, height: 1.35, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: _BlackBtn(
              label: '완료',
              enabled: true,
              onTap: () => setState(() {
                _editRoomPopup = null;
                _editSubRouteController.clear();
              }),
            ),
          ),
        ],
      ),
    );
  }


  // ─── 앱 설정 패널 ─────────────────────────────────────────────
  Widget _buildSettingsPanel(dynamic user) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return _BottomSheet(
      onDismiss: () => setState(() => _showSettings = false),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sheetHandle(),
              const SizedBox(height: 10),
              const Text(
                '앱 설정',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8E8E93),
                  letterSpacing: 0.15,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _settingsSwitchTile(
                      icon: Icons.notifications_none_rounded,
                      title: '알림 소리',
                      subtitle: '메시지 알림음',
                      value: _settingNotifSound,
                      onChanged: (v) => setState(() => _settingNotifSound = v),
                      showDivider: true,
                    ),
                    _settingsSwitchTile(
                      icon: Icons.vibration_rounded,
                      title: '진동',
                      subtitle: '메시지 수신 시',
                      value: _settingVibration,
                      onChanged: (v) => setState(() => _settingVibration = v),
                      showDivider: true,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 22, color: Color(0xFF636366)),
                          const SizedBox(width: 14),
                          const Text(
                            '앱 버전',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF000000),
                              letterSpacing: -0.35,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5E5EA),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'v 1.0.0',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3C3C43),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Material(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    setState(() => _showSettings = false);
                    showDialog(
                      context: context,
                      barrierColor: Colors.black54,
                      builder: (_) => Center(
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            width: 260,
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 32, offset: Offset(0, 8))],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('로그아웃', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, decoration: TextDecoration.none, color: Colors.black)),
                                const SizedBox(height: 8),
                                const Text('로그아웃 하시겠습니까?', style: TextStyle(fontSize: 13, color: Color(0xFF666666), decoration: TextDecoration.none)),
                                const SizedBox(height: 20),
                                Row(children: [
                                  Expanded(child: GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFDDDDDD)), borderRadius: BorderRadius.circular(10)),
                                      alignment: Alignment.center,
                                      child: const Text('취소', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF555555), decoration: TextDecoration.none)),
                                    ),
                                  )),
                                  const SizedBox(width: 8),
                                  Expanded(child: GestureDetector(
                                    onTap: () async {
                                      Navigator.pop(context);
                                      await ref.read(userProvider.notifier).logout();
                                      if (!mounted) return;
                                      context.go('/login');
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)),
                                      alignment: Alignment.center,
                                      child: const Text('로그아웃', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white, decoration: TextDecoration.none)),
                                    ),
                                  )),
                                ]),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        '로그아웃',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF3B30),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingsSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool showDivider = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: const Color(0xFF636366)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF000000),
                        letterSpacing: -0.35,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8E8E93),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.9,
                child: Switch.adaptive(
                  value: value,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.only(left: 52),
            child: Divider(height: 1, thickness: 0.5, color: Color(0xFFD1D1D6)),
          ),
      ],
    );
  }

  Widget _sheetHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Center(
        child: Container(
          width: 44,
          height: 5,
          decoration: BoxDecoration(
            color: const Color(0xFFCBD5E1),
            borderRadius: BorderRadius.circular(100),
          ),
        ),
      ),
    );
  }

  /// + 메뉴에서 열리는 시트용 헤더 (아이콘 + 제목/부제)
  Widget _sheetModalHeader({required IconData icon, required String title, String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.adminIndigoBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFC5CAE9).withValues(alpha: 0.6)),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 24, color: AppColors.adminIndigo),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.45,
                    height: 1.2,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12.5, height: 1.35, color: Color(0xFF64748B)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roomTypeSegmented() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _newRoomType = RoomType.normal),
                borderRadius: BorderRadius.circular(11),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _newRoomType == RoomType.normal ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: _newRoomType == RoomType.normal
                        ? [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.07),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '일반 기사용',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: _newRoomType == RoomType.normal ? FontWeight.w800 : FontWeight.w500,
                      color: _newRoomType == RoomType.normal ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _newRoomType = RoomType.vendor),
                borderRadius: BorderRadius.circular(11),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _newRoomType == RoomType.vendor ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: _newRoomType == RoomType.vendor
                        ? [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.07),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '솔라티(하청)',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: _newRoomType == RoomType.vendor ? FontWeight.w800 : FontWeight.w500,
                      color: _newRoomType == RoomType.vendor ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _broadcastSummaryIcon() {
    if (_broadcastRoomKind == RoomType.vendor) return Icons.local_shipping_outlined;
    if (_broadcastRoomKind == RoomType.normal) return Icons.directions_bus_outlined;
    return Icons.public_outlined;
  }

  String _broadcastKindLabel() {
    if (_broadcastRoomKind == RoomType.vendor) return '솔라티만';
    if (_broadcastRoomKind == RoomType.normal) return '일반만';
    return '일반·솔라티 전체';
  }

  String _broadcastSummaryLine() {
    final kind = _broadcastKindLabel();
    final comp = _broadcastCompanies.isEmpty ? '소속 전체' : _broadcastCompanies.join(' · ');
    return '$kind · $comp';
  }

  String _broadcastFooterHint() {
    final typeHint = _broadcastRoomKind == null
        ? '채팅방 유형이 전체일 때는 일반·솔라티 모두 받아요.'
        : (_broadcastRoomKind == RoomType.normal
            ? '일반(기사용) 채팅방에만 공지가 갑니다.'
            : '솔라티 채팅방에만 공지가 갑니다.');
    final compHint = _broadcastCompanies.isEmpty
        ? ' 소속을 고르지 않으면 해당 유형의 모든 채팅방에 보내요.'
        : ' 선택한 소속 채팅방만 골라 보내요.';
    return typeHint + compHint;
  }

  Widget _broadcastAudienceSegmented() {
    Widget seg(String label, bool active, VoidCallback onTap) {
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
              decoration: BoxDecoration(
                color: active ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.07),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: active ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          seg('전체', _broadcastRoomKind == null, () => setState(() => _broadcastRoomKind = null)),
          seg('일반', _broadcastRoomKind == RoomType.normal, () => setState(() => _broadcastRoomKind = RoomType.normal)),
          seg('솔라티', _broadcastRoomKind == RoomType.vendor, () => setState(() => _broadcastRoomKind = RoomType.vendor)),
        ],
      ),
    );
  }
}

// ─── 채팅방 아이템 ────────────────────────────────────────────
class _RoomItem extends StatefulWidget {
  final RoomModel room;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _RoomItem({
    required this.room,
    required this.isAdmin,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_RoomItem> createState() => _RoomItemState();
}

class _RoomItemState extends State<_RoomItem> {
  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final isAdmin = widget.isAdmin;

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: room.adminOnly ? const Color(0xFFF0F4FF) : Colors.white,
          border: Border(
            left: room.adminOnly ? const BorderSide(color: AppColors.morningBlue, width: 3) : BorderSide.none,
            bottom: const BorderSide(color: Color(0xFFF0F0F0)),
          ),
        ),
        child: Row(
          children: [
            // 아이콘
            Stack(
              clipBehavior: Clip.none,
              children: [
                room.adminOnly
                    ? Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(color: const Color(0xFFE8EAF6), borderRadius: BorderRadius.circular(14)),
                        alignment: Alignment.center,
                        child: Text(room.id == 999 ? '📊' : '🗂', style: const TextStyle(fontSize: 24)),
                      )
                    : AvatarWidget(name: room.name),
                if (room.pinned)
                  const Positioned(
                    top: -4, right: -4,
                    child: Text('📌', style: TextStyle(fontSize: 10)),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(room.name,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // 소속 태그 (관리자만)
                      if (isAdmin && room.companies.isNotEmpty) ...[
                        ...room.companies.take(2).map((c) => Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8EAF6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(c, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.adminIndigo)),
                        )),
                        if (room.companies.length > 2)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(10)),
                            child: Text('+${room.companies.length - 2}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF666666))),
                          ),
                      ],
                      const SizedBox(width: 4),
                      Text(room.time, style: const TextStyle(fontSize: 11, color: Color(0xFF555555))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(room.lastMsg,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF333333)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (room.unread > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.unreadBadge,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('${room.unread}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
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
    );
  }
}

// ─── 공용 소형 위젯들 ─────────────────────────────────────────
class _Dot extends StatelessWidget {
  const _Dot();
  @override
  Widget build(BuildContext context) =>
      const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('·', style: TextStyle(fontSize: 13, color: Color(0xFFCCCCCC))));
}

class _TextBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TextBtn({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 34,
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFDDDDDD)), borderRadius: BorderRadius.circular(8)),
      alignment: Alignment.center,
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF333333))),
    ),
  );
}

class _IconBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _IconBtn({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 34, height: 34,
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFDDDDDD)), borderRadius: BorderRadius.circular(8)),
      alignment: Alignment.center,
      child: Text(label, style: const TextStyle(fontSize: 16)),
    ),
  );
}

class _BottomSheet extends StatelessWidget {
  final Widget child;
  final VoidCallback onDismiss;
  const _BottomSheet({required this.child, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: ColoredBox(
        color: Colors.black54,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                    blurRadius: 36,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
                  color: Colors.white,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PopupOverlay extends StatelessWidget {
  final Widget child;
  final VoidCallback onDismiss;
  const _PopupOverlay({required this.child, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: Colors.black54,
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 360),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 40, offset: Offset(0, 12))],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ActionSheetRow extends StatelessWidget {
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionSheetRow({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: iconColor, size: 23),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.35,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 12.5, height: 1.3, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.black.withValues(alpha: 0.2), size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetDismissBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SheetDismissBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
    ),
  );
}

class _BlackBtn extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _BlackBtn({required this.label, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(16),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: enabled ? Colors.white : const Color(0xFF94A3B8),
        ),
      ),
    ),
  );
}

class _RoundInput extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  const _RoundInput({required this.controller, required this.placeholder, this.onChanged, this.onSubmitted, this.autofocus = false});

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    autofocus: autofocus,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    style: const TextStyle(fontSize: 14, color: Colors.black),
    decoration: InputDecoration(
      hintText: placeholder,
      hintStyle: TextStyle(color: AppColors.textLight.withValues(alpha: 0.95), fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.adminIndigo, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}

class _SmallBlackBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  const _SmallBlackBtn({required this.label, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
          ],
        ),
      ),
    ),
  );
}

class _SubRouteChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _SubRouteChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
    decoration: BoxDecoration(
      color: AppColors.adminIndigoBg,
      border: Border.all(color: const Color(0xFFC5CAE9).withValues(alpha: 0.65)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.adminIndigo)),
        const SizedBox(width: 4),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
            ),
          ),
        ),
      ],
    ),
  );
}

/// 채팅방 롱프레스 메뉴 — 그룹 리스트 행
class _PinPopupRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PinPopupRow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: const Color(0xFF636366)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.35,
                    color: Color(0xFF000000),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool optional;
  const _SectionLabel({required this.label, this.optional = false});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.25,
          color: Color(0xFF64748B),
        ),
      ),
      if (optional) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Text('선택', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
        ),
      ],
    ],
  );
}





