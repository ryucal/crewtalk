import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
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
  final void Function(MessageModel msg, String newStatus)? onMaintenanceStatusChanged;
  final void Function(MessageModel msg, {required String car, required String route, String? subRoute, required String reportType, required int count, required int maxCount})? onEditReport;

  const MessageBubble({
    super.key,
    required this.msg,
    required this.isAdmin,
    required this.currentUser,
    required this.onEdit,
    required this.onDelete,
    required this.onReact,
    required this.onOpenGallery,
    this.onMaintenanceStatusChanged,
    this.onEditReport,
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

  void _showReportEditDialog() {
    final rd = msg.reportData;
    if (rd == null) return;
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _ReportEditDialog(
        car: msg.car ?? '',
        route: msg.route ?? '',
        subRoute: msg.subRoute ?? '',
        reportType: rd.type,
        count: rd.count,
        maxCount: rd.maxCount,
        onSave: ({
          required String car,
          required String route,
          String? subRoute,
          required String reportType,
          required int count,
          required int maxCount,
        }) {
          widget.onEditReport?.call(
            msg,
            car: car,
            route: route,
            subRoute: subRoute,
            reportType: reportType,
            count: count,
            maxCount: maxCount,
          );
        },
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
                Text(
                  msg.type == MessageType.image
                      ? '이 사진 메시지를 삭제하시겠습니까?'
                      : '이 메시지를 삭제하시겠습니까?',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF666666), decoration: TextDecoration.none),
                  textAlign: TextAlign.center,
                ),
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

  static const _textEditableTypes = {MessageType.text, MessageType.notice};

  void _showReactionDialog() {
    final canEditText = widget.isAdmin && _textEditableTypes.contains(msg.type);
    final canEditReport = widget.isAdmin && msg.type == MessageType.report && widget.onEditReport != null;
    final canEdit = canEditText || canEditReport;
    final canDelete = widget.isAdmin;
    if (!canEdit && !canDelete) return;

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
                  if (canEdit) ...[
                    _popupBtn(
                      onTap: () {
                        Navigator.pop(context);
                        if (canEditReport) {
                          _showReportEditDialog();
                        } else {
                          _showEditDialog();
                        }
                      },
                      child: const Icon(Icons.edit_outlined, size: 24, color: Color(0xFF3B82F6)),
                    ),
                    if (canDelete) _divider(),
                  ],
                  if (canDelete) ...[
                    _popupBtn(
                      onTap: () {
                        Navigator.pop(context);
                        _showDeleteConfirmDialog();
                      },
                      child: const Icon(Icons.delete_outline_rounded, size: 26, color: Color(0xFFEF4444)),
                    ),
                  ],
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
    if (msg.isDeleted) return _buildDeletedPlaceholder();
    switch (msg.type) {
      case MessageType.dbResult:     return _buildDbResult();
      case MessageType.summary:      return _buildSummary();
      case MessageType.emergency:    return _buildEmergency();
      case MessageType.vendorReport: return _buildVendorReport();
      case MessageType.maintenance:  return _buildMaintenance();
      case MessageType.notice:       return _buildNotice();
      case MessageType.image:        return _buildImage();
      case MessageType.report:       return _buildReport();
      case MessageType.text:         return _buildText();
    }
  }

  Widget _buildDeletedPlaceholder() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!msg.isMe) const SizedBox(width: 44),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: const BoxConstraints(maxWidth: 260),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              '삭제된 메시지입니다',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF999999),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(msg.text ?? '', style: const TextStyle(fontSize: 15, color: Colors.black, height: 1.5)),
                                if (msg.editedAtMs != null)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 2),
                                    child: Text('(수정됨)', style: TextStyle(fontSize: 10, color: Color(0xFF999999), fontStyle: FontStyle.italic)),
                                  ),
                              ],
                            ),
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
    final rd = msg.reportData;
    if (rd == null) return const SizedBox.shrink();
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
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (msg.isMe) ...[_timeText(stripSeconds: true), const SizedBox(width: 4)],
                    Flexible(
                      child: GestureDetector(
                        onLongPress: _showReactionDialog,
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
                    if (!msg.isMe) ...[const SizedBox(width: 4), _timeText(stripSeconds: true)],
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
          Padding(
            padding: const EdgeInsets.only(left: 42, bottom: 2),
            child: Text(
              msg.name.trim().isNotEmpty ? msg.name.trim() : '관리자',
              style: const TextStyle(fontSize: 11, color: Color(0xFF555555), fontWeight: FontWeight.w600),
            ),
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
                      child: GestureDetector(
                        onLongPress: _showReactionDialog,
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
                              if (msg.editedAtMs != null)
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Text('(수정됨)', style: TextStyle(fontSize: 10, color: Color(0xFF999999), fontStyle: FontStyle.italic)),
                                ),
                            ],
                          ),
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

  // ─── 4. 이미지 (단일 / 묶음 그리드) ───────────────────────────
  Widget _buildImage() {
    final src = msg.imageSources;
    if (src.isEmpty) return const SizedBox.shrink();

    const maxW = 220.0;
    const gap = 3.0;
    final multi = src.length > 1;
    final cellW = multi ? (maxW - gap) / 2 : maxW;
    final cellH = multi ? (maxW - gap) / 2 : 280.0;
    final rowCount = multi ? (src.length / 2).ceil() : 1;
    final gridH = multi ? rowCount * cellH + (rowCount > 1 ? (rowCount - 1) * gap : 0) : 280.0;

    Widget imageBlock() {
      if (!multi) {
        return GestureDetector(
          onTap: () => widget.onOpenGallery(src.first),
          onLongPress: _showReactionDialog,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: TimetableImage(
              source: src.first,
              width: maxW,
              height: gridH,
              fit: BoxFit.cover,
            ),
          ),
        );
      }
      final rows = <Widget>[];
      for (var r = 0; r < rowCount; r++) {
        final i0 = r * 2;
        final cells = <Widget>[
          GestureDetector(
            onTap: () => widget.onOpenGallery(src[i0]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TimetableImage(
                source: src[i0],
                width: cellW,
                height: cellH,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ];
        if (i0 + 1 < src.length) {
          cells.add(SizedBox(width: gap));
          cells.add(
            GestureDetector(
              onTap: () => widget.onOpenGallery(src[i0 + 1]),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TimetableImage(
                  source: src[i0 + 1],
                  width: cellW,
                  height: cellH,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        }
        rows.add(Row(mainAxisSize: MainAxisSize.min, children: cells));
        if (r < rowCount - 1) rows.add(SizedBox(height: gap));
      }
      return GestureDetector(
        onLongPress: _showReactionDialog,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: maxW,
            height: gridH,
            child: Align(
              alignment: msg.isMe ? Alignment.topRight : Alignment.topLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: rows,
              ),
            ),
          ),
        ),
      );
    }

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
                    imageBlock(),
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
  Future<void> _dialEmergencyPhone(String raw) async {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: digits);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전화 앱을 열 수 없어요.')),
      );
    }
  }

  Widget _buildEmergency() {
    final maxW = (MediaQuery.of(context).size.width * 0.88).clamp(240.0, 360.0).toDouble();
    final name = msg.name.trim();
    final phone = (msg.phone ?? '').trim();
    final emergencyType = (msg.emergencyType ?? '').trim();
    final car = (msg.car ?? '').trim();
    final route = (msg.route ?? '').trim();
    final detail = [if (car.isNotEmpty) car, if (route.isNotEmpty) route].join(' · ');

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: GestureDetector(
          onLongPress: _showReactionDialog,
          child: Container(
            constraints: BoxConstraints(maxWidth: maxW),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFCDD2)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    const Icon(Icons.emergency_rounded, size: 16, color: Color(0xFFC62828)),
                    Text(
                      emergencyType.isNotEmpty ? '긴급 호출 · $emergencyType' : '긴급 호출',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFC62828)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 5,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (name.isNotEmpty)
                      Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                    if (phone.isNotEmpty)
                      GestureDetector(
                        onTap: () => _dialEmergencyPhone(phone),
                        child: Text(
                          phone,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.morningBlue,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.morningBlue.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    if (detail.isNotEmpty)
                      Text(
                        detail,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(msg.time, style: TextStyle(fontSize: 11, color: AppColors.textHint.withValues(alpha: 0.9))),
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
    final vd = msg.vendorData;
    if (vd == null) return const SizedBox.shrink();

    const ink = Color(0xFF0F172A);
    const muted = Color(0xFF64748B);
    const label = Color(0xFF94A3B8);
    const hairline = Color(0xFFE8ECF0);
    const softSurface = Color(0xFFF8FAFC);
    const statTile = Color(0xFFF1F5F9);

    final distanceDisplay = vd.distanceKm.isEmpty
        ? ''
        : (vd.distanceKm.toLowerCase().contains('km') ? vd.distanceKm : '${vd.distanceKm} km');

    Widget detailRow(String k, String v) {
      final show = v.isEmpty ? '—' : v;
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 56,
              child: Text(k, style: const TextStyle(fontSize: 12, color: label, height: 1.35)),
            ),
            Expanded(
              child: Text(
                show,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ink, height: 1.35),
              ),
            ),
          ],
        ),
      );
    }

    Widget endpointColumn(String title, String value) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: label)),
            const SizedBox(height: 4),
            Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ink, height: 1.3),
            ),
          ],
        ),
      );
    }

    Widget statTileChild(String title, String value) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: statTile,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, color: muted)),
            const SizedBox(height: 2),
            Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ink, height: 1.2),
            ),
          ],
        ),
      );
    }

    final carLine = (msg.car != null && msg.car!.trim().isNotEmpty)
        ? '운행 인원 보고 · ${msg.car!.trim()}'
        : '운행 인원 보고';

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
                    if (msg.isMe) ...[_timeText(stripSeconds: true), const SizedBox(width: 4)],
                    GestureDetector(
                      onLongPress: _showReactionDialog,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 292),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: hairline),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.apartment_outlined,
                                    size: 20,
                                    color: AppColors.adminIndigo.withValues(alpha: 0.88),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      vd.company,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: ink,
                                        height: 1.25,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.adminIndigoBg,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '솔라티',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.adminIndigo.withValues(alpha: 0.92),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 28, top: 4),
                                child: Text(
                                  carLine,
                                  style: const TextStyle(fontSize: 12, color: muted, height: 1.3),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: softSurface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '운행일시',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: label,
                                        letterSpacing: -0.1,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      vd.operationDateTime.isEmpty ? '—' : vd.operationDateTime,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: ink,
                                        height: 1.25,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  endpointColumn('출발지', vd.departure),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 6, right: 6, top: 18),
                                    child: Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 16,
                                      color: Colors.blueGrey.shade200,
                                    ),
                                  ),
                                  endpointColumn('도착지', vd.destination),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(child: statTileChild('탑승인원', vd.passengerCount)),
                                  const SizedBox(width: 8),
                                  Expanded(child: statTileChild('이동거리', distanceDisplay)),
                                ],
                              ),
                              detailRow('예약자', vd.reserver),
                              detailRow('특이사항', vd.specialNote),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (!msg.isMe) ...[const SizedBox(width: 4), _timeText(stripSeconds: true)],
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

  // ─── 7. 차량 정비 접수 카드 ──────────────────────────────────
  Widget _buildMaintenanceConsumableSimple(MaintenanceData md) {
    final line = md.consumableRequestDisplayLine;
    if (line.isEmpty) return const SizedBox.shrink();

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
                    if (msg.isMe) ...[_timeText(stripSeconds: true), const SizedBox(width: 4)],
                    GestureDetector(
                      onLongPress: _showReactionDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: const BoxConstraints(maxWidth: 280),
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
                        child: Text(
                          line,
                          style: const TextStyle(fontSize: 15, color: Colors.black, height: 1.45),
                        ),
                      ),
                    ),
                    if (!msg.isMe) ...[const SizedBox(width: 4), _timeText(stripSeconds: true)],
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

  Widget _buildMaintenance() {
    final md = msg.maintenanceData;
    if (md == null) return const SizedBox.shrink();

    if (md.consumableOnly && md.consumableItems.isNotEmpty) {
      return _buildMaintenanceConsumableSimple(md);
    }

    const border = Color(0xFFE2E8F0);
    const ink = Color(0xFF0F172A);
    const muted = Color(0xFF64748B);
    const labelColor = Color(0xFF94A3B8);
    const hairline = Color(0xFFF1F5F9);

    late final Color urgencyBg;
    late final Color urgencyFg;
    late final IconData urgencyIconData;
    if (md.driveability == '즉시 점검 필요') {
      urgencyBg = const Color(0xFFFEF2F2);
      urgencyFg = const Color(0xFFDC2626);
      urgencyIconData = Icons.error_outline_rounded;
    } else if (md.driveability == '조심 운행 가능') {
      urgencyBg = const Color(0xFFFFF7ED);
      urgencyFg = const Color(0xFFEA580C);
      urgencyIconData = Icons.warning_amber_rounded;
    } else {
      urgencyBg = const Color(0xFFF0FDF4);
      urgencyFg = const Color(0xFF16A34A);
      urgencyIconData = Icons.check_circle_outline_rounded;
    }

    late final Color statusBg;
    late final Color statusFg;
    late final String statusLabel;
    if (md.status == '정비완료') {
      statusBg = const Color(0xFFDCFCE7);
      statusFg = const Color(0xFF15803D);
      statusLabel = '정비완료';
    } else if (md.status == '정비예정') {
      statusBg = const Color(0xFFDBEAFE);
      statusFg = const Color(0xFF1D4ED8);
      statusLabel = '정비예정';
    } else {
      statusBg = const Color(0xFFF1F5F9);
      statusFg = const Color(0xFF475569);
      statusLabel = '접수';
    }

    Widget detailRow(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              k,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                letterSpacing: -0.1,
                color: labelColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v.isEmpty ? '—' : v,
              style: const TextStyle(
                fontSize: 15,
                height: 1.35,
                letterSpacing: -0.2,
                fontWeight: FontWeight.w500,
                color: ink,
              ),
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
                    if (msg.isMe) ...[_timeText(stripSeconds: true), const SizedBox(width: 4)],
                    GestureDetector(
                      onLongPress: _showReactionDialog,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 300),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(17),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  md.car,
                                                  style: const TextStyle(
                                                    fontSize: 17,
                                                    height: 1.25,
                                                    letterSpacing: -0.35,
                                                    fontWeight: FontWeight.w700,
                                                    color: ink,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '정비 예약 · ${md.driverName}',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    height: 1.3,
                                                    color: muted,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: statusBg,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              statusLabel,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: statusFg,
                                                letterSpacing: -0.1,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Divider(height: 1, thickness: 1, color: hairline),
                                    detailRow('발생일시', md.occurredAt),
                                    const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: hairline),
                                    detailRow('고장증상', md.symptom),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(
                                            width: 76,
                                            child: Text(
                                              '운행여부',
                                              style: TextStyle(
                                                fontSize: 12,
                                                height: 1.35,
                                                color: labelColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: urgencyBg,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                child: Row(
                                                  children: [
                                                    Icon(urgencyIconData, size: 18, color: urgencyFg),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        md.driveability,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w600,
                                                          color: urgencyFg,
                                                          height: 1.25,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: hairline),
                                    detailRow('연락처', md.phone),
                                    if (md.specialNote.isNotEmpty) ...[
                                      const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: hairline),
                                      detailRow('특이사항', md.specialNote),
                                    ],
                                    if (md.photoUrls.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: md.photoUrls.map((url) {
                                            return GestureDetector(
                                              onTap: () => widget.onOpenGallery(url),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(10),
                                                child: Image.network(
                                                  url,
                                                  width: 60,
                                                  height: 60,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => Container(
                                                    width: 60,
                                                    height: 60,
                                                    color: hairline,
                                                    child: const Icon(Icons.broken_image_outlined, size: 22, color: Color(0xFFCBD5E1)),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    if (widget.onMaintenanceStatusChanged != null && !md.consumableOnly)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
                                        child: Row(
                                          children: [
                                            _maintenanceStatusBtn('정비예정', const Color(0xFF2563EB), md.status == '정비예정'),
                                            const SizedBox(width: 8),
                                            _maintenanceStatusBtn('정비완료', const Color(0xFF16A34A), md.status == '정비완료'),
                                          ],
                                        ),
                                      )
                                    else
                                      const SizedBox(height: 14),
                                  ],
                          ),
                        ),
                      ),
                    ),
                    if (!msg.isMe) ...[const SizedBox(width: 4), _timeText(stripSeconds: true)],
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

  Widget _maintenanceStatusBtn(String label, Color color, bool active) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          final newStatus = active ? '접수' : label;
          widget.onMaintenanceStatusChanged?.call(msg, newStatus);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.1) : Colors.transparent,
            border: Border.all(
              color: active ? color.withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? color : const Color(0xFF64748B),
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }

  // ─── 8. DB 검색 결과 (기사·차량) ─────────────────────────────
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
                padding: EdgeInsets.fromLTRB(
                  18,
                  16,
                  18,
                  16 + MediaQuery.viewPaddingOf(context).bottom,
                ),
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

  Widget _timeText({bool stripSeconds = false}) {
    var t = msg.time;
    if (stripSeconds && t.length >= 8 && t.split(':').length == 3) {
      t = t.substring(0, 5);
    }
    return Text(t, style: const TextStyle(fontSize: 10, color: Color(0xFF555555)));
  }

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

// ─── 인원보고 수정 다이얼로그 ────────────────────────────────────
class _ReportEditDialog extends StatefulWidget {
  final String car;
  final String route;
  final String subRoute;
  final String reportType;
  final int count;
  final int maxCount;
  final void Function({
    required String car,
    required String route,
    String? subRoute,
    required String reportType,
    required int count,
    required int maxCount,
  }) onSave;

  const _ReportEditDialog({
    required this.car,
    required this.route,
    required this.subRoute,
    required this.reportType,
    required this.count,
    required this.maxCount,
    required this.onSave,
  });

  @override
  State<_ReportEditDialog> createState() => _ReportEditDialogState();
}

class _ReportEditDialogState extends State<_ReportEditDialog> {
  late final TextEditingController _carCtrl;
  late final TextEditingController _routeCtrl;
  late final TextEditingController _subRouteCtrl;
  late final TextEditingController _countCtrl;
  late final TextEditingController _maxCountCtrl;
  late String _reportType;

  @override
  void initState() {
    super.initState();
    _carCtrl = TextEditingController(text: widget.car);
    _routeCtrl = TextEditingController(text: widget.route);
    _subRouteCtrl = TextEditingController(text: widget.subRoute);
    _countCtrl = TextEditingController(text: widget.count.toString());
    _maxCountCtrl = TextEditingController(text: widget.maxCount.toString());
    _reportType = widget.reportType;
  }

  @override
  void dispose() {
    _carCtrl.dispose();
    _routeCtrl.dispose();
    _subRouteCtrl.dispose();
    _countCtrl.dispose();
    _maxCountCtrl.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecor(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5)),
  );

  @override
  Widget build(BuildContext context) {
    final isOut = _reportType == '퇴근';
    final accentColor = isOut ? const Color(0xFFEF4444) : const Color(0xFF3B82F6);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Color(0x28000000), blurRadius: 40, offset: Offset(0, 12))],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.edit_note_rounded, size: 22, color: accentColor),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('인원보고 수정', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // 출근/퇴근 토글
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: ['출근', '퇴근'].map((t) {
                      final selected = _reportType == t;
                      final c = t == '퇴근' ? const Color(0xFFEF4444) : const Color(0xFF3B82F6);
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _reportType = t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: selected ? [BoxShadow(color: c.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))] : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              t,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                color: selected ? c : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(controller: _carCtrl, style: const TextStyle(fontSize: 14), decoration: _fieldDecor('차량번호')),
                const SizedBox(height: 10),
                TextField(controller: _routeCtrl, style: const TextStyle(fontSize: 14), decoration: _fieldDecor('노선')),
                const SizedBox(height: 10),
                TextField(controller: _subRouteCtrl, style: const TextStyle(fontSize: 14), decoration: _fieldDecor('세부 노선 (선택)')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _countCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 14),
                        decoration: _fieldDecor('인원'),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('/', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w300, color: Color(0xFFCBD5E1))),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _maxCountCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 14),
                        decoration: _fieldDecor('정원'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text('취소', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          final count = int.tryParse(_countCtrl.text.trim()) ?? 0;
                          final maxCount = int.tryParse(_maxCountCtrl.text.trim()) ?? 0;
                          final car = _carCtrl.text.trim();
                          final route = _routeCtrl.text.trim();
                          if (car.isEmpty || route.isEmpty) return;
                          Navigator.pop(context);
                          widget.onSave(
                            car: car,
                            route: route,
                            subRoute: _subRouteCtrl.text.trim().isEmpty ? null : _subRouteCtrl.text.trim(),
                            reportType: _reportType,
                            count: count,
                            maxCount: maxCount,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text('저장', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
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
}
