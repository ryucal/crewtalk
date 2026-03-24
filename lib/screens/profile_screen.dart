import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_provider.dart';
import '../utils/app_colors.dart';
import '../utils/helpers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _carCtrl;

  String _carError = '';
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(userProvider);
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
    _carCtrl = TextEditingController(text: user?.car ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _carCtrl.dispose();
    super.dispose();
  }

  void _handleSave() {
    String carVal = _carCtrl.text.trim();
    if (carVal.isNotEmpty) {
      carVal = formatCarNumber(carVal);
      if (!isValidCarNumber(carVal)) {
        setState(() => _carError = '차량번호 형식을 확인해주세요. (예: 경기 78사 2918호)');
        return;
      }
    }
    setState(() => _carError = '');

    final user = ref.read(userProvider);
    if (user == null) return;
    ref.read(userProvider.notifier).update(
      user.copyWith(car: carVal),
    );

    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  void _handleLogout() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 260,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, 8))]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('로그아웃', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, decoration: TextDecoration.none, color: Colors.black)),
                const SizedBox(height: 8),
                const Text('정말 로그아웃 하시겠습니까?', style: TextStyle(fontSize: 13, color: Color(0xFF666666), decoration: TextDecoration.none)),
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
                      ref.read(userProvider.notifier).logout();
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
  }

  void _handleDeleteAccount() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 280,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, 8))]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('계정 삭제', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, decoration: TextDecoration.none, color: Color(0xFFEF4444))),
                const SizedBox(height: 8),
                const Text('계정을 삭제하면 복구할 수 없습니다.\n정말 삭제하시겠습니까?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF666666), decoration: TextDecoration.none, height: 1.5)),
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
                      ref.read(userProvider.notifier).logout();
                      context.go('/login');
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    if (user == null) return const SizedBox();

    final avatarColors = AppColors.avatarColor(user.name);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: Column(
        children: [
          // ─── 헤더 ────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(4, 44, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 28),
                  onPressed: () => context.go('/rooms'),
                ),
                const Expanded(
                  child: Text('프로필 설정', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          // ─── 본문 ─────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
              child: Column(
                children: [
                  // ─── 아바타 + 이름 + 소속 ────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))]),
                    child: Column(
                      children: [
                        Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(color: avatarColors.bg, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text(user.avatar, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: avatarColors.color)),
                        ),
                        const SizedBox(height: 12),
                        Text(user.name.isEmpty ? '이름 미설정' : user.name,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(20)),
                          child: Text(user.company.isEmpty ? '소속 미설정' : user.company,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                        ),
                        if (user.isAdmin) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFF1A237E), borderRadius: BorderRadius.circular(20)),
                            child: const Text('관리자', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ─── 입력 폼 ──────────────────────────────────
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))]),
                    child: Column(
                      children: [
                        _LineField(label: '이름', controller: _nameCtrl, hint: '홍길동', readOnly: true),
                        _divider(),
                        _LineField(
                          label: '전화번호',
                          controller: _phoneCtrl,
                          hint: '010-0000-0000',
                          keyboardType: TextInputType.phone,
                          readOnly: true,
                        ),
                        _divider(),
                        _LineField(
                          label: '차량번호',
                          controller: _carCtrl,
                          hint: '경기 78사 2918호',
                          onChanged: (_) => setState(() => _carError = ''),
                          errorText: _carError.isEmpty ? null : _carError,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ─── 저장 버튼 ────────────────────────────────
                  GestureDetector(
                    onTap: _handleSave,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: _saved ? const Color(0xFF4CAF50) : Colors.black,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _saved ? '✓  저장완료!' : '저장하기',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // ─── 로그아웃 / 계정삭제 ──────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _handleLogout,
                        child: const Text('로그아웃',
                          style: TextStyle(fontSize: 13, color: Color(0xFF888888), fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline, decorationColor: Color(0xFF888888))),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('|', style: TextStyle(color: Color(0xFFDDDDDD))),
                      ),
                      GestureDetector(
                        onTap: _handleDeleteAccount,
                        child: const Text('계정삭제',
                          style: TextStyle(fontSize: 13, color: Color(0xFFEF4444), fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline, decorationColor: Color(0xFFEF4444))),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 입력 라인 필드 ───────────────────────────────────────────
class _LineField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final void Function(String)? onChanged;
  final String? errorText;
  final bool readOnly;

  const _LineField({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.onChanged,
    this.errorText,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF999999), fontWeight: FontWeight.w700)),
              if (readOnly) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(4)),
                  child: const Text('변경불가', style: TextStyle(fontSize: 9, color: Color(0xFFAAAAAA), fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            onChanged: onChanged,
            readOnly: readOnly,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: readOnly ? const Color(0xFF999999) : const Color(0xFF1A1A1A),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
              errorText: errorText,
              errorStyle: const TextStyle(fontSize: 11, color: Color(0xFFC62828)),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

Widget _divider() => Container(
  height: 1,
  margin: const EdgeInsets.symmetric(horizontal: 20),
  color: const Color(0xFFF0F0F0),
);
