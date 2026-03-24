import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/user_model.dart';
import '../providers/app_provider.dart';
import '../utils/app_colors.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _personalPwFocus = FocusNode();
  final _companyPwFocus = FocusNode();

  String _name = '';
  String _phone = '';
  String _personalPassword = '';
  String _company = '';
  String _companyPassword = '';
  String _error = '';

  static const String _adminPassword = 'admin1234';

  @override
  void dispose() {
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _personalPwFocus.dispose();
    _companyPwFocus.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    setState(() => _error = '');

    if (_name.trim().isEmpty) {
      setState(() => _error = '이름을 입력해주세요');
      return;
    }
    if (_personalPassword.trim().isEmpty) {
      setState(() => _error = '개인 비밀번호를 입력해주세요');
      return;
    }

    // 관리자 로그인 (전화번호·소속 체크 없이 바로 통과)
    if (_personalPassword == _adminPassword) {
      ref.read(userProvider.notifier).login(UserModel(
        name: _name.trim(),
        phone: _phone,
        company: '관리자',
        isAdmin: true,
      ));
      context.go('/rooms');
      return;
    }

    // 일반 기사 — 전화번호·소속 추가 검증
    if (_phone.replaceAll(RegExp(r'\D'), '').length < 10) {
      setState(() => _error = '전화번호를 올바르게 입력해주세요');
      return;
    }
    if (_company.isEmpty) {
      setState(() => _error = '소속을 선택해주세요');
      return;
    }
    if (_companyPassword.trim().isEmpty) {
      setState(() => _error = '소속 비밀번호를 입력해주세요');
      return;
    }

    final companies = ref.read(companyProvider);
    final isValid = companies.any((c) => c.name == _company && c.password == _companyPassword);
    if (!isValid) {
      setState(() => _error = '소속 비밀번호가 올바르지 않아요');
      return;
    }

    ref.read(userProvider.notifier).login(UserModel(
      name: _name.trim(),
      phone: _phone,
      company: _company,
    ));
    context.go('/rooms');
  }

  @override
  Widget build(BuildContext context) {
    final companies = ref.watch(companyProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 60),
                  // 로고 영역
                  const Text(
                    'CREW TALK',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '버스 운행 관리 채팅',
                    style: TextStyle(fontSize: 13, color: AppColors.textHint),
                  ),
                  const SizedBox(height: 52),

                  // 이름
                  _LineField(
                    label: '이름',
                    placeholder: '홍길동',
                    focusNode: _nameFocus,
                    onChanged: (v) => setState(() { _name = v; _error = ''; }),
                    onSubmitted: (_) => _phoneFocus.requestFocus(),
                  ),
                  const SizedBox(height: 8),

                  // 전화번호
                  _LineField(
                    label: '전화번호',
                    placeholder: '010-0000-0000',
                    focusNode: _phoneFocus,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [_PhoneFormatter()],
                    maxLength: 13,
                    value: _phone,
                    onChanged: (v) => setState(() { _phone = v; _error = ''; }),
                    onSubmitted: (_) => _personalPwFocus.requestFocus(),
                  ),
                  const SizedBox(height: 8),

                  // 개인 비밀번호
                  _LineField(
                    label: '개인 비밀번호',
                    placeholder: '개인 비밀번호',
                    focusNode: _personalPwFocus,
                    obscureText: true,
                    onChanged: (v) => setState(() { _personalPassword = v; _error = ''; }),
                    onSubmitted: (_) => _companyPwFocus.requestFocus(),
                  ),
                  const SizedBox(height: 8),

                  // 소속 선택
                  _LineDropdown(
                    label: '소속',
                    value: _company.isEmpty ? null : _company,
                    items: companies.map((c) => c.name).toList(),
                    onChanged: (v) => setState(() { _company = v ?? ''; _error = ''; }),
                  ),
                  const SizedBox(height: 8),

                  // 소속 비밀번호
                  _LineField(
                    label: '소속 비밀번호',
                    placeholder: '소속 공통 비밀번호',
                    focusNode: _companyPwFocus,
                    obscureText: true,
                    onChanged: (v) => setState(() { _companyPassword = v; _error = ''; }),
                    onSubmitted: (_) => _handleSubmit(),
                  ),

                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error,
                      style: const TextStyle(color: Color(0xFFE53935), fontSize: 12),
                    ),
                  ],

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: _BlackButton(label: '로그인', onTap: _handleSubmit),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 라인형 입력 필드 ──────────────────────────────────────────
class _LineField extends StatelessWidget {
  final String label;
  final String placeholder;
  final FocusNode? focusNode;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final String? value;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

  const _LineField({
    required this.label,
    required this.placeholder,
    this.focusNode,
    this.obscureText = false,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.value,
    required this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600,
            color: AppColors.textHint, letterSpacing: 1.5,
          ),
        ),
        TextField(
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: const TextStyle(fontSize: 16, color: Colors.black),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 16),
            border: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE0E0E0)),
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.black, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            counterText: '',
          ),
        ),
      ],
    );
  }
}

// ─── 라인형 드롭다운 ──────────────────────────────────────────
class _LineDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _LineDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600,
            color: AppColors.textHint, letterSpacing: 1.5,
          ),
        ),
        DropdownButtonFormField<String>(
          value: value,
          hint: const Text(
            '소속 선택',
            style: TextStyle(color: AppColors.textLight, fontSize: 16),
          ),
          items: items.map((name) => DropdownMenuItem(
            value: name,
            child: Text(name, style: const TextStyle(fontSize: 16)),
          )).toList(),
          onChanged: onChanged,
          style: const TextStyle(fontSize: 16, color: Colors.black),
          decoration: const InputDecoration(
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE0E0E0)),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.black, width: 1.5),
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 8),
          ),
          dropdownColor: Colors.white,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textHint),
        ),
      ],
    );
  }
}

// ─── 검정 버튼 ────────────────────────────────────────────────
class _BlackButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _BlackButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// ─── 전화번호 포맷터 ──────────────────────────────────────────
class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    String formatted;
    if (digits.length <= 3) {
      formatted = digits;
    } else if (digits.length <= 7) {
      formatted = '${digits.substring(0, 3)}-${digits.substring(3)}';
    } else {
      final end = digits.length.clamp(0, 11);
      formatted = '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7, end)}';
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
