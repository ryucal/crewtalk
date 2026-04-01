import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/company_directory_provider.dart';
import '../services/auth_repository.dart';
import '../utils/app_colors.dart';
import '../widgets/auth_form_widgets.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _pwFocus = FocusNode();
  final _pw2Focus = FocusNode();

  String _name = '';
  String _phone = '';
  String _password = '';
  String _password2 = '';
  String _company = '';
  String _error = '';
  bool _loading = false;

  @override
  void dispose() {
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _pwFocus.dispose();
    _pw2Focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = '');
    if (_name.trim().isEmpty) {
      setState(() => _error = '이름을 입력해주세요');
      return;
    }
    if (_phone.replaceAll(RegExp(r'\D'), '').length < 10) {
      setState(() => _error = '전화번호를 올바르게 입력해주세요');
      return;
    }
    if (_company.isEmpty) {
      setState(() => _error = '소속을 선택해주세요');
      return;
    }
    if (_password.length < 6 || !RegExp(r'^\d+$').hasMatch(_password)) {
      setState(() => _error = '개인 비밀번호는 숫자 6자 이상이어야 해요');
      return;
    }
    if (_password != _password2) {
      setState(() => _error = '비밀번호 확인이 일치하지 않아요');
      return;
    }
    if (!AuthRepository.firebaseAvailable) {
      setState(() => _error = 'Firebase가 설정되지 않았어요. 관리자에게 문의하세요.');
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthRepository.signUpDriver(
        name: _name.trim(),
        phoneFormatted: _phone,
        company: _company,
        personalPassword: _password,
      );
      await AuthRepository.signOutFirebase();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('가입이 완료됐어요. 로그인해 주세요.')),
      );
      context.go('/login');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '가입에 실패했어요. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final namesAsync = ref.watch(companyNamesForAuthProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('회원가입'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'CREW TALK',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '이름·전화번호·소속·개인 비밀번호로 가입해요',
                    style: TextStyle(fontSize: 13, color: AppColors.textHint),
                  ),
                  if (!AuthRepository.firebaseAvailable) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFB74D)),
                      ),
                      child: const Text(
                        'Firebase가 연결되지 않았습니다. 터미널에서 flutterfire configure 후 '
                        '앱을 다시 실행하면 가입할 수 있어요.',
                        style: TextStyle(fontSize: 12, color: Color(0xFFE65100), height: 1.35),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  AuthLineField(
                    label: '이름',
                    placeholder: '홍길동',
                    focusNode: _nameFocus,
                    onChanged: (v) => setState(() {
                      _name = v;
                      _error = '';
                    }),
                    onSubmitted: (_) => _phoneFocus.requestFocus(),
                  ),
                  const SizedBox(height: 8),
                  AuthLineField(
                    label: '전화번호',
                    placeholder: '010-0000-0000',
                    focusNode: _phoneFocus,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [PhoneHyphenFormatter()],
                    maxLength: 13,
                    onChanged: (v) => setState(() {
                      _phone = v;
                      _error = '';
                    }),
                    onSubmitted: (_) => _pwFocus.requestFocus(),
                  ),
                  const SizedBox(height: 8),
                  namesAsync.when(
                    data: (items) => items.isEmpty
                        ? Text(
                            '등록된 소속이 없어요. 관리자가 Firebase에서 소속 목록을 동기화한 뒤 다시 시도해 주세요.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black.withValues(alpha: 0.65),
                              height: 1.35,
                            ),
                          )
                        : AuthLineDropdown(
                            label: '소속',
                            value: _company.isEmpty ? null : _company,
                            items: items,
                            onChanged: (v) => setState(() {
                              _company = v ?? '';
                              _error = '';
                            }),
                          ),
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    error: (_, __) => const Text('소속 목록을 불러오지 못했어요'),
                  ),
                  const SizedBox(height: 8),
                  AuthLineField(
                    label: '개인 비밀번호',
                    placeholder: '숫자 6자 이상',
                    focusNode: _pwFocus,
                    obscureText: true,
                    keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) => setState(() {
                      _password = v;
                      _error = '';
                    }),
                    onSubmitted: (_) => _pw2Focus.requestFocus(),
                  ),
                  const SizedBox(height: 8),
                  AuthLineField(
                    label: '비밀번호 확인',
                    placeholder: '한 번 더 입력',
                    focusNode: _pw2Focus,
                    obscureText: true,
                    keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) => setState(() {
                      _password2 = v;
                      _error = '';
                    }),
                    onSubmitted: (_) => _submit(),
                  ),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error,
                      style: const TextStyle(color: Color(0xFFE53935), fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 24),
                  AuthBlackButton(
                    label: _loading
                        ? '처리 중…'
                        : AuthRepository.firebaseAvailable
                            ? '가입하기'
                            : 'Firebase 설정 후 가입 가능',
                    onTap: (_loading || !AuthRepository.firebaseAvailable) ? null : _submit,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
