import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/user_model.dart';
import '../providers/app_provider.dart';
import '../providers/company_directory_provider.dart';
import '../services/auth_repository.dart';
import '../utils/app_colors.dart';
import '../utils/sample_data.dart';
import '../widgets/auth_form_widgets.dart';

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
  bool _loading = false;

  @override
  void dispose() {
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _personalPwFocus.dispose();
    _companyPwFocus.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() => _error = '');

    if (_personalPassword.trim().isEmpty) {
      setState(() => _error = '개인 비밀번호를 입력해주세요');
      return;
    }

    // Firebase 기사 로그인 (이름 입력 없음 — 프로필은 서버에서 복원)
    if (AuthRepository.firebaseAvailable) {
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

      setState(() => _loading = true);
      try {
        final user = await AuthRepository.signInDriver(
          phoneFormatted: _phone,
          personalPassword: _personalPassword,
          company: _company,
          companyPassword: _companyPassword,
        );
        await ref.read(userProvider.notifier).login(user);
        if (!mounted) return;
        context.go('/rooms');
      } on AuthException catch (e) {
        setState(() => _error = e.message);
      } catch (_) {
        setState(() => _error = '로그인에 실패했어요. 잠시 후 다시 시도해주세요.');
      } finally {
        if (mounted) setState(() => _loading = false);
      }
      return;
    }

    // Firebase 미설정 시 레거시 기사 로그인 (이름 + 로컬 소속 DB)
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
    if (_companyPassword.trim().isEmpty) {
      setState(() => _error = '소속 비밀번호를 입력해주세요');
      return;
    }

    final companyNames = ref.read(companyNamesForAuthProvider).valueOrNull ?? [];
    final isValid = companyNames.contains(_company) && sampleCompanies.any((c) => c.name == _company && c.password == _companyPassword);
    if (!isValid) {
      setState(() => _error = '소속 비밀번호가 올바르지 않아요');
      return;
    }

    await ref.read(userProvider.notifier).login(UserModel(
      name: _name.trim(),
      phone: _phone,
      company: _company,
    ));
    if (!mounted) return;
    context.go('/rooms');
  }

  @override
  Widget build(BuildContext context) {
    final firebaseOn = AuthRepository.firebaseAvailable;
    final companyNamesAsync = ref.watch(companyNamesForAuthProvider);

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
                  Text(
                    firebaseOn
                        ? '전화번호·개인 비밀번호·소속으로 로그인해요'
                        : '버스 운행 관리 채팅 (로컬 모드)',
                    style: const TextStyle(fontSize: 13, color: AppColors.textHint),
                  ),
                  if (firebaseOn) ...[
                    const SizedBox(height: 8),
                    Text(
                      '이름은 가입 시 저장된 정보로 표시돼요',
                      style: TextStyle(fontSize: 12, color: Colors.black.withValues(alpha: 0.45)),
                    ),
                  ],
                  const SizedBox(height: 52),

                  if (!firebaseOn) ...[
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
                  ],

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
                    onSubmitted: (_) => _personalPwFocus.requestFocus(),
                  ),
                  const SizedBox(height: 8),

                  AuthLineField(
                    label: '개인 비밀번호',
                    placeholder: '개인 비밀번호',
                    focusNode: _personalPwFocus,
                    obscureText: true,
                    keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) => setState(() {
                      _personalPassword = v;
                      _error = '';
                    }),
                    onSubmitted: (_) => _companyPwFocus.requestFocus(),
                  ),
                  const SizedBox(height: 8),

                  companyNamesAsync.when(
                    data: (items) => items.isEmpty
                        ? Text(
                            firebaseOn
                                ? '등록된 소속이 없어요. 관리자가 Firebase에서 소속 목록을 동기화한 뒤 다시 시도해 주세요.'
                                : '소속 목록이 비어 있어요.',
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
                    label: '소속 비밀번호',
                    placeholder: '소속 공통 비밀번호',
                    focusNode: _companyPwFocus,
                    obscureText: true,
                    keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) => setState(() {
                      _companyPassword = v;
                      _error = '';
                    }),
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
                  AuthBlackButton(
                    label: _loading ? '로그인 중…' : '로그인',
                    onTap: _loading ? null : _handleSubmit,
                  ),

                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: _loading ? null : () => context.push('/signup'),
                      child: const Text('계정이 없으신가요? 회원가입'),
                    ),
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
