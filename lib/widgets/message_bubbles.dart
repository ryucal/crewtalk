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

  // ─── 7. DB 검색 결과 ─────────────────────────────────────────
  Widget _buildDbResult() {
    final r = msg.resultCard;
    if (r == null) return const SizedBox.shrink();

    final shiftColor = r.reportData?.type == '출근' ? AppColors.morningBlue
        : r.reportData?.type == '퇴근' ? AppColors.eveningRed : const Color(0xFF555555);
    final shiftBg = r.reportData?.type == '출근' ? AppColors.morningBlueBg
        : r.reportData?.type == '퇴근' ? AppColors.eveningRedBg : const Color(0xFFF5F5F5);

    final dtShort = shortDateTime(r.reportDateTime);

    Widget infoRow(String label, String value, {bool isPhone = false, bool isHighlight = false, bool isNote = false}) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5)))),
        child: Row(
          children: [
            SizedBox(width: 62, child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w600, letterSpacing: 0.3))),
            const SizedBox(width: 8),
            Expanded(
              child: isPhone
                  ? GestureDetector(
                      onTap: () {},
                      child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.morningBlue)),
                    )
                  : isNote
                  ? Text('⚠️ $value', style: const TextStyle(fontSize: 13, color: AppColors.warning, fontWeight: FontWeight.w600))
                  : Text(value, style: TextStyle(fontSize: 14, fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500, color: isHighlight ? Colors.black : const Color(0xFF444444))),
            ),
          ],
        ),
      );
    }

    Widget routeRow() {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5)))),
        child: Row(
          children: [
            const SizedBox(width: 62, child: Text('노선', style: TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w600, letterSpacing: 0.3))),
            const SizedBox(width: 8),
            Expanded(
              child: r.route != null
                  ? Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      children: [
                        Text(r.subRoute != null ? '${r.route} · ${r.subRoute}' : r.route!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black)),
                        if (dtShort.isNotEmpty && r.reportData != null) Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                          decoration: BoxDecoration(color: shiftBg, borderRadius: BorderRadius.circular(20)),
                          child: Text('$dtShort ${r.reportData!.type} ${r.reportData!.count}명',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: shiftColor)),
                        ),
                        if (dtShort.isEmpty) const Text('(미보고)', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
                      ],
                    )
                  : const Text('미보고', style: TextStyle(color: AppColors.textLight)),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: const BoxDecoration(
                color: AppColors.adminIndigo,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Text(r.searchType == 'name' ? '👤' : '🚌', style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r.searchType == 'name' ? (r.name ?? '') : (r.car ?? '차량 정보'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                  Text(msg.time, style: const TextStyle(fontSize: 11, color: Colors.white54)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: r.searchType == 'name' ? Column(children: [
                infoRow('이름', r.name ?? '', isHighlight: true),
                infoRow('전화번호', r.phone ?? '미등록', isPhone: (r.phone ?? '미등록') != '미등록'),
                infoRow('소속', r.company ?? '미등록'),
                infoRow('차량번호', r.car ?? '미보고', isHighlight: r.car != null),
                routeRow(),
                infoRow('기타사항', r.specialNote ?? '없음', isNote: r.specialNote != null && r.specialNote!.isNotEmpty),
              ]) : Column(children: [
                infoRow('차량번호', r.car ?? '미확인', isHighlight: true),
                infoRow('이름', r.name ?? '미확인', isHighlight: r.name != null),
                infoRow('전화번호', r.phone ?? '미등록', isPhone: (r.phone ?? '미등록') != '미등록'),
                infoRow('소속', r.company ?? '미등록'),
                routeRow(),
                infoRow('기타사항', r.specialNote ?? '없음', isNote: r.specialNote != null && r.specialNote!.isNotEmpty),
              ]),
            ),
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

    return StatefulBuilder(builder: (context, setSt) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  children: [
                    Text(msg.emoji ?? '📊', style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(text: TextSpan(
                        children: [
                          TextSpan(text: '${msg.date} 운행 집계', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black)),
                          TextSpan(text: '  · ${msg.time} 자동 생성', style: const TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w400)),
                        ],
                      )),
                    ),
                    GestureDetector(
                      onTap: () {
                        final lines = <String>[];
                        lines.add('📊 ${msg.date} 운행 집계 (${msg.time})');
                        lines.add('─────────────────────');
                        for (var i = 0; i < morningLines.length; i++) {
                          final line = morningLines[i];
                          final eve = i < eveningLines.length ? eveningLines[i] : null;
                          if (line.subLines.isNotEmpty) {
                            lines.add(line.name);
                            for (var si = 0; si < line.subLines.length; si++) {
                              final sub = line.subLines[si];
                              final eveSub = eve != null && si < eve.subLines.length ? eve.subLines[si] : null;
                              lines.add('  └ ${sub.name}  ${sub.reported ? '출근 ${sub.total}명' : '출근 미보고'} | ${eveSub?.reported == true ? '퇴근 ${eveSub!.total}명' : '퇴근 미보고'}');
                            }
                          } else {
                            lines.add('${line.name}  ${line.reported ? '출근 ${line.total}명' : '출근 미보고'} | ${eve?.reported == true ? '퇴근 ${eve!.total}명' : '퇴근 미보고'}');
                          }
                        }
                        lines.add('─────────────────────');
                        lines.add('합계  출근 ${msg.morningTotal}명 | 퇴근 ${msg.eveningTotal}명');
                        Clipboard.setData(ClipboardData(text: lines.join('\n')));
                        setSt(() => copied = true);
                        Future.delayed(const Duration(seconds: 2), () { if (mounted) setSt(() => copied = false); });
                      },
                      child: Icon(copied ? Icons.check : Icons.copy_outlined,
                        size: 18, color: copied ? const Color(0xFF2E7D32) : AppColors.textLight),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              ...morningLines.asMap().entries.map((entry) {
                final i = entry.key;
                final line = entry.value;
                final eve = i < eveningLines.length ? eveningLines[i] : null;
                final unreported = !line.reported && !(eve?.reported ?? false);
                final hasSubLines = line.subLines.isNotEmpty;
                return Container(
                  decoration: BoxDecoration(border: i < morningLines.length - 1 ? const Border(bottom: BorderSide(color: Color(0xFFF5F5F5))) : null),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, hasSubLines ? 10 : 10, 16, hasSubLines ? 4 : 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(line.name, style: TextStyle(fontSize: 14, fontWeight: unreported ? FontWeight.w700 : FontWeight.w600, color: unreported ? AppColors.eveningRed : const Color(0xFF333333))),
                            if (!hasSubLines) Row(children: [
                              line.reported
                                  ? Text('출근 ${line.total}명', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.morningBlue))
                                  : const Text('출근 미보고', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                              const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('|', style: TextStyle(color: Color(0xFFDDDDDD)))),
                              eve?.reported == true
                                  ? Text('퇴근 ${eve!.total}명', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.eveningRed))
                                  : const Text('퇴근 미보고', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                            ]),
                          ],
                        ),
                      ),
                      if (hasSubLines) ...line.subLines.asMap().entries.map((se) {
                        final sub = se.value;
                        final eveSub = eve != null && se.key < eve.subLines.length ? eve.subLines[se.key] : null;
                        final subUnreported = !sub.reported && !(eveSub?.reported ?? false);
                        return Container(
                          color: subUnreported ? const Color(0x08C62828) : const Color(0xFFFAFAFA),
                          padding: const EdgeInsets.fromLTRB(28, 6, 16, 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(children: [
                                const Text('└ ', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
                                Text(sub.name, style: TextStyle(fontSize: 13, fontWeight: subUnreported ? FontWeight.w600 : FontWeight.w400, color: subUnreported ? AppColors.eveningRed : const Color(0xFF555555))),
                              ]),
                              Row(children: [
                                sub.reported
                                    ? Text('출근 ${sub.total}명', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.morningBlue))
                                    : const Text('출근 미보고', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                                const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('|', style: TextStyle(color: Color(0xFFDDDDDD)))),
                                eveSub?.reported == true
                                    ? Text('퇴근 ${eveSub!.total}명', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.eveningRed))
                                    : const Text('퇴근 미보고', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                              ]),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    (msg.unreported ?? 0) > 0
                        ? Text('⚠️ 미보고 ${msg.unreported}개 노선', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.eveningRed))
                        : const Text('✅ 전 노선 보고 완료', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
                    Row(children: [
                      Text('출근 ${msg.morningTotal}명', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.morningBlue)),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('|', style: TextStyle(color: Color(0xFFDDDDDD)))),
                      Text('퇴근 ${msg.eveningTotal}명', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.eveningRed)),
                    ]),
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


