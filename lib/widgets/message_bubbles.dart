import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/message_model.dart';
import '../utils/app_colors.dart';
import '../utils/helpers.dart';
import 'timetable_image.dart';

// ─── 날짜 구분선 ──────────────────────────────────────────────
class DateDivider extends StatelessWidget {
  final String date;
  const DateDivider({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFE0E0E0))),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              formatDateLabel(date),
              style: const TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w500),
            ),
          ),
          const Expanded(child: Divider(color: Color(0xFFE0E0E0))),
        ],
      ),
    );
  }
}

// ─── 이모지 리액션 상수 ───────────────────────────────────────
const List<String> kReactionEmojis = ['👍', '👌', '❤️', '✔️'];

// ─── 통합 메시지 버블 ─────────────────────────────────────────
class MessageBubble extends StatefulWidget {
  final MessageModel msg;
  final bool isAdmin;
  final String currentUser;
  final void Function(int id, String newText) onEdit;
  final void Function(int id) onDelete;
  final void Function(int id, String emoji, String user) onReact;
  final void Function(String imageUrl) onOpenGallery;

  const MessageBubble({
    super.key,
    required this.msg,
    required this.isAdmin,
    required this.currentUser,
    required this.onEdit,
    required this.onDelete,
    required this.onReact,
    required this.onOpenGallery,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  String? _tooltip;

  MessageModel get msg => widget.msg;

  void _showEditDialog() {
    final controller = TextEditingController(text: msg.text ?? '');
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 300,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 32, offset: Offset(0, 8))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('메시지 수정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, decoration: TextDecoration.none, color: Colors.black)),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: null,
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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
                    onTap: () {
                      final newText = controller.text.trim();
                      if (newText.isNotEmpty) {
                        Navigator.pop(context);
                        widget.onEdit(msg.id, newText);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(color: const Color(0xFF3B82F6), borderRadius: BorderRadius.circular(10)),
                      alignment: Alignment.center,
                      child: const Text('수정', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white, decoration: TextDecoration.none)),
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

  Widget _popupBtn({
    required Widget child,
    required VoidCallback onTap,
    bool highlighted = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: highlighted ? const Color(0x141565C0) : Colors.transparent,
          border: Border.all(
            color: highlighted ? AppColors.morningBlue : Colors.transparent,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: child,
      ),
    );
  }

  Widget _divider() => Container(
    width: 1, height: 32,
    color: const Color(0xFFEEEEEE),
    margin: const EdgeInsets.symmetric(horizontal: 6),
  );

  void _showDeleteConfirmDialog() {
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
                const Text('메시지 삭제', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, decoration: TextDecoration.none, color: Colors.black)),
                const SizedBox(height: 8),
                const Text('이 메시지를 삭제하시겠습니까?', style: TextStyle(fontSize: 13, color: Color(0xFF666666), decoration: TextDecoration.none)),
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
                    onTap: () {
                      Navigator.pop(context);
                      widget.onDelete(msg.id);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(10)),
                      alignment: Alignment.center,
                      child: const Text('삭제', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white, decoration: TextDecoration.none)),
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

  void _showReactionDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 6))],
                border: Border.all(color: const Color(0xFFF0F0F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ─── 수정 (관리자 전용) ───────────────────────
                  if (widget.isAdmin) ...[
                    _popupBtn(
                      onTap: () {
                        Navigator.pop(context);
                        _showEditDialog();
                      },
                      child: const Icon(Icons.edit_outlined, size: 24, color: Color(0xFF3B82F6)),
                    ),
                    _divider(),
                  ],
                  // ─── 리액션 이모지 ─────────────────────────────
                  ...kReactionEmojis.map((emoji) {
                    final isMine = (msg.reactions[emoji] ?? []).contains(widget.currentUser);
                    return _popupBtn(
                      onTap: () {
                        Navigator.pop(context);
                        widget.onReact(msg.id, emoji, widget.currentUser);
                      },
                      highlighted: isMine,
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    );
                  }),
                  // ─── 삭제 ──────────────────────────────────────
                  _divider(),
                  _popupBtn(
                    onTap: () {
                      Navigator.pop(context);
                      _showDeleteConfirmDialog();
                    },
                    child: const Icon(Icons.delete_outline_rounded, size: 26, color: Color(0xFFEF4444)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (msg.type) {
      case MessageType.dbResult:   return _buildDbResult();
      case MessageType.summary:    return _buildSummary();
      case MessageType.emergency:  return _buildEmergency();
      case MessageType.vendorReport: return _buildVendorReport();
      case MessageType.notice:     return _buildNotice();
      case MessageType.image:      return _buildImage();
      case MessageType.report:     return _buildReport();
      case MessageType.text:       return _buildText();
    }
  }

  // ─── 1. 일반 텍스트 ─────────────────────────────────────────
  Widget _buildText() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!msg.isMe) ...[_avatar(), const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment: msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!msg.isMe) _senderName(),
                Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (msg.isMe) ...[_timeText(), const SizedBox(width: 4)],
                        GestureDetector(
                          onLongPress: _showReactionDialog,
                          onDoubleTap: widget.isAdmin ? _showEditDialog : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            constraints: const BoxConstraints(maxWidth: 260),
                            decoration: BoxDecoration(
                              color: msg.isMe ? AppColors.kakaoYellow : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(msg.isMe ? 18 : 0),
                                topRight: Radius.circular(msg.isMe ? 0 : 18),
                                bottomLeft: const Radius.circular(18),
                                bottomRight: const Radius.circular(18),
                              ),
                              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 3, offset: Offset(0, 1))],
                            ),
                            child: Text(msg.text ?? '', style: const TextStyle(fontSize: 15, color: Colors.black, height: 1.5)),
                          ),
                        ),
                        if (!msg.isMe) ...[const SizedBox(width: 4), _timeText()],
                      ],
                    ),
                if (_hasReactions()) _reactionBar(),
              ],
            ),
          ),
          if (msg.isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  // ─── 2. 인원 보고 카드 ───────────────────────────────────────
  Widget _buildReport() {
    final rd = msg.reportData!;
    final isOut = rd.type == '퇴근';
    final color = isOut ? AppColors.eveningRed : AppColors.morningBlue;
    final bg = isOut ? AppColors.eveningRedBg : AppColors.morningBlueBg;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!msg.isMe) ...[_avatar(), const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment: msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!msg.isMe) _senderName(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (msg.isMe) ...[_timeText(), const SizedBox(width: 4)],
                    Flexible(
                      child: Align(
                        alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: GestureDetector(
                          onLongPress: _showReactionDialog,
                          onDoubleTap: widget.isAdmin ? _showEditDialog : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                            decoration: BoxDecoration(
                              color: bg,
                              border: Border.all(color: color, width: 1.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(msg.car ?? '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                                Text('·', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.4))),
                                Text(msg.route ?? '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                                if (msg.subRoute != null) ...[
                                  Text('·', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.4))),
                                  Text(msg.subRoute!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                                ],
                                Text('·', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.4))),
                                Text(rd.type, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                                Text('·', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.4))),
                                Text('${rd.count}명', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                                if (rd.isOverCapacity) Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(color: AppColors.overCapacity, borderRadius: BorderRadius.circular(4)),
                                  child: const Text('만차', style: TextStyle(fontSize: 11, color: Colors.white)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!msg.isMe) ...[const SizedBox(width: 4), _timeText()],
                  ],
                ),
              ],
            ),
          ),
          if (msg.isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  // ─── 3. 공지 메시지 ──────────────────────────────────────────
  Widget _buildNotice() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 42, bottom: 2),
            child: Text('관리자', style: TextStyle(fontSize: 11, color: Color(0xFF555555), fontWeight: FontWeight.w600)),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34, height: 34,
                decoration: const BoxDecoration(color: AppColors.noticeDeep, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Icon(Icons.person, size: 18, color: Color(0xFFEEEDFE)),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: const BoxConstraints(maxWidth: 260),
                        decoration: BoxDecoration(
                          color: AppColors.noticeBackground,
                          border: Border.all(color: AppColors.noticeBorder, width: 0.5),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4), topRight: Radius.circular(16),
                            bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('📢 전체 공지', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.noticePurple, letterSpacing: 0.4)),
                            const SizedBox(height: 4),
                            Text(msg.text ?? '', style: const TextStyle(fontSize: 14, color: AppColors.noticeDeep, height: 1.55)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(msg.time, style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 4. 이미지 ──────────────────────────────────────────────
  Widget _buildImage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!msg.isMe) ...[_avatar(), const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment: msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!msg.isMe) _senderName(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (msg.isMe) ...[_timeText(), const SizedBox(width: 4)],
                    GestureDetector(
                      onTap: () => widget.onOpenGallery(msg.imageUrl ?? ''),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: TimetableImage(
                          source: msg.imageUrl ?? '',
                          width: 220,
                          height: 280,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    if (!msg.isMe) ...[const SizedBox(width: 4), _timeText()],
                  ],
                ),
              ],
            ),
          ),
          if (msg.isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  // ─── 5. 긴급 호출 ────────────────────────────────────────────
  Widget _buildEmergency() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: AppColors.eveningRed,
                  child: Row(
                    children: [
                      const Text('🚨', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(msg.emergencyType ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${msg.name} · ${msg.phone}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
                          const SizedBox(height: 4),
                          Text('${msg.car} · ${msg.route}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
                        ],
                      ),
                      Text(msg.time, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── 6. 솔라티(구 하청업체) 보고 ─────────────────────────────
  Widget _buildVendorReport() {
    final vd = msg.vendorData!;
    const headerBg = AppColors.adminIndigo;

    Widget row(String k, String v, {bool emphasize = false}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(k, style: TextStyle(fontSize: 12, color: emphasize ? const Color(0xFF333333) : const Color(0xFF888888), fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(
              v.isEmpty ? '—' : v,
              style: TextStyle(fontSize: 13, fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500, color: const Color(0xFF222222), height: 1.25),
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!msg.isMe) ...[_avatar(), const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment: msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!msg.isMe) _senderName(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (msg.isMe) ...[_timeText(), const SizedBox(width: 4)],
                    Container(
                      constraints: const BoxConstraints(maxWidth: 280),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              color: headerBg,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Text('🏢 ${vd.company}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                                      ),
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                                        child: const Text('솔라티', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    (msg.car != null && msg.car!.trim().isNotEmpty)
                                        ? '운행 인원 보고 · ${msg.car!.trim()}'
                                        : '운행 인원 보고',
                                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                            row('운행일시', vd.operationDateTime, emphasize: true),
                            const Divider(height: 1, color: Color(0xFFF0F0F0)),
                            row('출발지', vd.departure),
                            row('도착지', vd.destination),
                            row('탑승인원', vd.passengerCount),
                            row('이동거리', vd.distanceKm.isEmpty ? '' : (vd.distanceKm.toLowerCase().contains('km') ? vd.distanceKm : '${vd.distanceKm} km')),
                            row('예약자', vd.reserver),
                            row('특이사항', vd.specialNote),
                          ],
                        ),
                      ),
                    ),
                    if (!msg.isMe) ...[const SizedBox(width: 4), _timeText()],
                  ],
                ),
              ],
            ),
          ),
          if (msg.isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  // ─── 7. DB 검색 결과 (기사·차량) ─────────────────────────────
  Widget _buildDbResult() {
    final r = msg.resultCard;
    if (r == null) return const SizedBox.shrink();

    final isNameSearch = r.searchType == 'name';
    final shiftColor = r.reportData?.type == '출근'
        ? AppColors.morningBlue
        : r.reportData?.type == '퇴근'
            ? AppColors.eveningRed
            : const Color(0xFF64748B);
    final shiftBg = r.reportData?.type == '출근'
        ? AppColors.morningBlueBg
        : r.reportData?.type == '퇴근'
            ? AppColors.eveningRedBg
            : const Color(0xFFF1F5F9);

    final dtShort = shortDateTime(r.reportDateTime);
    const labelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Color(0xFF64748B),
      height: 1.25,
    );
    const dividerColor = Color(0xFFF1F5F9);

    Widget infoRow(String label, String value,
        {bool isPhone = false, bool isHighlight = false, bool isNote = false, bool showDivider = true}) {
      final hasNote = isNote && value.isNotEmpty;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 76, child: Text(label, style: labelStyle)),
                Expanded(
                  child: isPhone
                      ? GestureDetector(
                          onTap: () {},
                          child: Row(
                            children: [
                              Icon(Icons.phone_rounded, size: 17, color: AppColors.morningBlue.withValues(alpha: 0.9)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  value,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.morningBlue,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : hasNote
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8E6),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.info_outline_rounded, size: 18, color: AppColors.warning.withValues(alpha: 0.9)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      value,
                                      style: const TextStyle(fontSize: 14, color: Color(0xFFB45309), fontWeight: FontWeight.w600, height: 1.35),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Text(
                              value,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
                                color: isHighlight ? const Color(0xFF0F172A) : const Color(0xFF334155),
                                height: 1.35,
                              ),
                            ),
                ),
              ],
            ),
          ),
          if (showDivider) const Divider(height: 1, thickness: 1, color: dividerColor, indent: 16, endIndent: 16),
        ],
      );
    }

    Widget routeRow() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 76, child: Text('노선', style: labelStyle)),
            Expanded(
              child: r.route != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.subRoute != null ? '${r.route} · ${r.subRoute}' : r.route!,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), height: 1.3),
                        ),
                        if (dtShort.isNotEmpty && r.reportData != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                            decoration: BoxDecoration(
                              color: shiftBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: shiftColor.withValues(alpha: 0.22)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.schedule_rounded, size: 16, color: shiftColor),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '$dtShort ${r.reportData!.type} ${r.reportData!.count}명',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: shiftColor, height: 1.2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '당일 인원 보고 없음',
                              style: TextStyle(fontSize: 13, color: Colors.black.withValues(alpha: 0.38), fontWeight: FontWeight.w500),
                            ),
                          ),
                      ],
                    )
                  : Text(
                      '미보고',
                      style: TextStyle(fontSize: 15, color: Colors.black.withValues(alpha: 0.38), fontWeight: FontWeight.w500),
                    ),
            ),
          ],
        ),
      );
    }

    final title = isNameSearch ? (r.name ?? '') : (r.car ?? '차량 정보');
    final subtitle = isNameSearch ? '기사 정보' : '차량 · 기사 연계';

    final bodyChildren = isNameSearch
        ? <Widget>[
            infoRow('이름', r.name ?? '', isHighlight: true),
            infoRow('전화번호', r.phone ?? '미등록', isPhone: (r.phone ?? '미등록') != '미등록'),
            infoRow('소속', r.company ?? '미등록'),
            infoRow('차량번호', r.car ?? '미보고', isHighlight: r.car != null),
            const Divider(height: 1, thickness: 1, color: dividerColor, indent: 16, endIndent: 16),
            routeRow(),
            infoRow(
              '기타사항',
              (r.specialNote != null && r.specialNote!.trim().isNotEmpty) ? r.specialNote!.trim() : '등록된 특이사항 없음',
              isNote: r.specialNote != null && r.specialNote!.trim().isNotEmpty,
              showDivider: false,
            ),
          ]
        : <Widget>[
            infoRow('차량번호', r.car ?? '미확인', isHighlight: true),
            infoRow('이름', r.name ?? '미확인', isHighlight: r.name != null),
            infoRow('전화번호', r.phone ?? '미등록', isPhone: (r.phone ?? '미등록') != '미등록'),
            infoRow('소속', r.company ?? '미등록'),
            const Divider(height: 1, thickness: 1, color: dividerColor, indent: 16, endIndent: 16),
            routeRow(),
            infoRow(
              '기타사항',
              (r.specialNote != null && r.specialNote!.trim().isNotEmpty) ? r.specialNote!.trim() : '등록된 특이사항 없음',
              isNote: r.specialNote != null && r.specialNote!.trim().isNotEmpty,
              showDivider: false,
            ),
          ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.adminIndigoBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isNameSearch ? Icons.person_rounded : Icons.directions_bus_filled_rounded,
                      color: AppColors.adminIndigo,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, height: 1.2, color: Color(0xFF0F172A), letterSpacing: -0.3),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black.withValues(alpha: 0.42)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      msg.time,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: dividerColor),
            Padding(padding: const EdgeInsets.only(top: 4, bottom: 14), child: Column(children: bodyChildren)),
          ],
        ),
      ),
    );
  }

  // ─── 8. 운행 집계 요약 ───────────────────────────────────────
  Widget _buildSummary() {
    final morningLines = msg.morningLines ?? [];
    final eveningLines = msg.eveningLines ?? [];
    bool copied = false;

    const dividerColor = Color(0xFFF1F5F9);

    Widget shiftPill({required bool reported, required bool morning, required int total}) {
      final color = morning ? AppColors.morningBlue : AppColors.eveningRed;
      final bg = morning ? AppColors.morningBlueBg : AppColors.eveningRedBg;
      if (reported) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Text(
            '${morning ? '출근' : '퇴근'} $total명',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color, height: 1.1),
          ),
        );
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          '${morning ? '출근' : '퇴근'} 미보고',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black.withValues(alpha: 0.38), height: 1.1),
        ),
      );
    }

    return StatefulBuilder(builder: (context, setSt) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.adminIndigoBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(msg.emoji ?? '📊', style: const TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${msg.date} 운행 집계',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${msg.time} · 자동 생성',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black.withValues(alpha: 0.42),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () {
                          // 붙여넣기 시 줄바꿈이 유지되도록: ASCII만·짧은 줄·공백 구분 (카카오톡 등 메시지 입력창 호환)
                          String pairMorningEvening(SummaryLine m, SummaryLine? e) {
                            final am = m.reported ? '출근 ${m.total}명' : '출근 미보고';
                            final pm = e?.reported == true ? '퇴근 ${e!.total}명' : '퇴근 미보고';
                            return '$am $pm';
                          }

                          String pairSub(SummaryLine sub, SummaryLine? eveSub) {
                            final am = sub.reported ? '출근 ${sub.total}명' : '출근 미보고';
                            final pm = eveSub?.reported == true ? '퇴근 ${eveSub!.total}명' : '퇴근 미보고';
                            return '$am $pm';
                          }

                          final buf = StringBuffer();
                          buf.writeln('${msg.date} 운행집계 (${msg.time})');
                          for (var i = 0; i < morningLines.length; i++) {
                            final line = morningLines[i];
                            final eve = i < eveningLines.length ? eveningLines[i] : null;
                            if (line.subLines.isNotEmpty) {
                              for (var si = 0; si < line.subLines.length; si++) {
                                final sub = line.subLines[si];
                                final eveSub = eve != null && si < eve.subLines.length ? eve.subLines[si] : null;
                                buf.writeln('${line.name} ${sub.name} ${pairSub(sub, eveSub)}');
                              }
                            } else {
                              buf.writeln('${line.name} ${pairMorningEvening(line, eve)}');
                            }
                          }
                          buf.writeln('합계 출근 ${msg.morningTotal}명 퇴근 ${msg.eveningTotal}명');
                          Clipboard.setData(ClipboardData(text: buf.toString().trimRight()));
                          setSt(() => copied = true);
                          Future.delayed(const Duration(seconds: 2), () {
                            if (mounted) setSt(() => copied = false);
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            copied ? Icons.check_rounded : Icons.copy_rounded,
                            size: 20,
                            color: copied ? const Color(0xFF15803D) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: dividerColor),
              ...morningLines.asMap().entries.map((entry) {
                final i = entry.key;
                final line = entry.value;
                final eve = i < eveningLines.length ? eveningLines[i] : null;
                final unreported = !line.reported && !(eve?.reported ?? false);
                final hasSubLines = line.subLines.isNotEmpty;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, hasSubLines ? 12 : 12, 16, hasSubLines ? 6 : 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 3,
                            margin: const EdgeInsets.only(top: 4, right: 10),
                            height: 16,
                            decoration: BoxDecoration(
                              color: unreported ? AppColors.eveningRed.withValues(alpha: 0.65) : AppColors.morningBlue.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              line.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: unreported ? FontWeight.w800 : FontWeight.w700,
                                color: unreported ? AppColors.eveningRed : const Color(0xFF0F172A),
                                height: 1.25,
                              ),
                            ),
                          ),
                          if (!hasSubLines)
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              alignment: WrapAlignment.end,
                              children: [
                                shiftPill(reported: line.reported, morning: true, total: line.total),
                                shiftPill(reported: eve?.reported == true, morning: false, total: eve?.total ?? 0),
                              ],
                            ),
                        ],
                      ),
                    ),
                    if (hasSubLines) ...line.subLines.asMap().entries.map((se) {
                      final sub = se.value;
                      final eveSub = eve != null && se.key < eve.subLines.length ? eve.subLines[se.key] : null;
                      final subUnreported = !sub.reported && !(eveSub?.reported ?? false);
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          decoration: BoxDecoration(
                            color: subUnreported ? const Color(0xFFFFF5F5) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: subUnreported ? AppColors.eveningRed.withValues(alpha: 0.12) : const Color(0xFFEEF2F6),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.subdirectory_arrow_right_rounded, size: 18, color: Colors.black.withValues(alpha: 0.28)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  sub.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: subUnreported ? FontWeight.w700 : FontWeight.w600,
                                    color: subUnreported ? AppColors.eveningRed : const Color(0xFF334155),
                                    height: 1.25,
                                  ),
                                ),
                              ),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                alignment: WrapAlignment.end,
                                children: [
                                  shiftPill(reported: sub.reported, morning: true, total: sub.total),
                                  shiftPill(reported: eveSub?.reported == true, morning: false, total: eveSub?.total ?? 0),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (i < morningLines.length - 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Divider(height: 1, thickness: 1, color: dividerColor),
                      ),
                  ],
                );
              }),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: dividerColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '출근 ${msg.morningTotal}명',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.morningBlue, letterSpacing: -0.2),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      width: 1,
                      height: 18,
                      color: const Color(0xFFCBD5E1),
                    ),
                    Text(
                      '퇴근 ${msg.eveningTotal}명',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.eveningRed, letterSpacing: -0.2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ─── 공용 서브 위젯 ───────────────────────────────────────────
  Widget _avatar() {
    final colors = AppColors.avatarColor(msg.name);
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: colors.bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(msg.avatar ?? (msg.name.isNotEmpty ? msg.name[0] : '?'),
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: colors.color)),
    );
  }

  Widget _senderName() => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(msg.name, style: const TextStyle(fontSize: 12, color: Color(0xFF333333), fontWeight: FontWeight.w600)),
  );

  Widget _timeText() => Text(msg.time, style: const TextStyle(fontSize: 10, color: Color(0xFF555555)));

  bool _hasReactions() => msg.reactions.values.any((users) => users.isNotEmpty);

  Widget _reactionBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: kReactionEmojis.where((e) => (msg.reactions[e]?.isNotEmpty ?? false)).map((emoji) {
          final users = msg.reactions[emoji] ?? [];
          final isMine = users.contains(widget.currentUser);
          return GestureDetector(
            onTap: () => setState(() => _tooltip = _tooltip == emoji ? null : emoji),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isMine ? const Color(0x141565C0) : Colors.white,
                border: Border.all(color: isMine ? AppColors.morningBlue : const Color(0xFFE0E0E0), width: 1.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 3),
                  Text('${users.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isMine ? AppColors.morningBlue : const Color(0xFF555555))),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}


