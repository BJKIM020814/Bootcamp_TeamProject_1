import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../discover/home_page.dart';
import '../models/erd_entities.dart';
import 'authController.dart';
import 'signuppage.dart';

/// FITPICK 로그인 화면.
///
/// 기존 ERD의 `account` 컬렉션에서 이메일(email)과 비밀번호(password)를
/// 사용한다. Firebase Authentication 모델이나 별도 회원 모델은 만들지 않는다.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _brandColor = Color(0xFF222222);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final result = await FirebaseFirestore.instance
          .collection('account')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (!mounted) return;
      if (result.docs.isEmpty) {
        _showMessage('등록되지 않은 이메일입니다.');
        return;
      }

      // 기존 범용 ERD 모델로 Firestore 문서를 읽는다.
      final account = ErpEntity.fromFirestore('account', result.docs.first);
      if (account.fields['password'] != _passwordController.text) {
        _showMessage('비밀번호가 일치하지 않습니다.');
        return;
      }

      _onLoginSuccess('${account.fields['name']}');
    } on FirebaseException {
      if (mounted) _showMessage('로그인 정보를 확인할 수 없습니다. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onLoginSuccess(String name) {
    AuthController.to.login();
    _showMessage('$name님, 환영합니다.');
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
    }
  }

  void _goToSignUp() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SignUpPage()));
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _brandColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          '로그인',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          tooltip: '뒤로가기',
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
        actions: [
          IconButton(
            tooltip: '장바구니',
            onPressed: () {},
            icon: const Icon(Icons.shopping_bag_outlined, size: 23),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFEEEEEE)),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 36),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              const _LoginBrandHeader(),
              const SizedBox(height: 34),
              const Text(
                '다시 만나 반가워요',
                style: TextStyle(
                  color: _brandColor,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 28),
              _LoginInputField(
                label: '이메일',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final email = value?.trim() ?? '';
                  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
                      ? null
                      : '올바른 이메일 주소를 입력해 주세요.';
                },
              ),
              const SizedBox(height: 16),
              _LoginInputField(
                label: '비밀번호',
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? '비밀번호 표시' : '비밀번호 숨기기',
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
                validator: (value) =>
                    (value?.isNotEmpty ?? false) ? null : '비밀번호를 입력해 주세요.',
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _isLoading ? null : _login,
                  style: FilledButton.styleFrom(
                    backgroundColor: _brandColor,
                    disabledBackgroundColor: const Color(0xFF777777),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '로그인',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _goToSignUp,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _brandColor,
                    side: const BorderSide(color: Color(0xFFD9D9D9)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    '회원가입',
                    style: TextStyle(fontWeight: FontWeight.w700),
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

InputDecoration _loginInputDecoration() => InputDecoration(
  filled: true,
  fillColor: const Color(0xFFFAFAFA),
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(
      color: _LoginPageState._brandColor,
      width: 1.5,
    ),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: Color(0xFFD32F2F)),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
  ),
);

class _LoginInputField extends StatelessWidget {
  const _LoginInputField({
    required this.label,
    required this.controller,
    required this.validator,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffixIcon,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        obscureText: obscureText,
        obscuringCharacter: '•',
        decoration: _loginInputDecoration().copyWith(suffixIcon: suffixIcon),
        validator: validator,
        onFieldSubmitted: onSubmitted,
      ),
    ],
  );
}

class _LoginBrandHeader extends StatelessWidget {
  const _LoginBrandHeader();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'FITPICK.',
        style: TextStyle(
          color: _LoginPageState._brandColor,
          fontSize: 29,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.2,
        ),
      ),
      SizedBox(height: 4),
      Text(
        '좋은 신발이 좋은 하루를 만듭니다.',
        style: TextStyle(color: Color(0xFF777777), fontSize: 13),
      ),
    ],
  );
}
