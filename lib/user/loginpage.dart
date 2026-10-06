import 'package:flutter/material.dart';
import '../common/fitpick_snackbar.dart';
import '../discover/home_page.dart';
import '../services/fitpick_api_service.dart';
import 'authController.dart';
import 'signuppage.dart';

/// FITPICK 로그인 화면.
///
/// FastAPI에서 Firebase account 비밀번호를 검증하고 서버 세션을 발급한다.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.initialEmail = '', this.api});
  // 가입 완료 후 이동한 경우 이메일을 미리 채우고 비밀번호는 새로 입력받는다.
  final String initialEmail;
  // 테스트에서 HTTP 서비스를 교체할 수 있도록 의존성을 선택적으로 받는다.
  final FitpickApiService? api;

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
  FitpickApiService get _api => widget.api ?? FitpickApiService.instance;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Firestore 비밀번호를 앱에서 직접 비교하지 않고 서버의 해시 검증 결과를 사용한다.
  Future<void> _login() async {
    if (_isLoading || !(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final result = await _api.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      // 비동기 요청 중 화면이 닫히면 화면 이동이나 메시지 표시를 하지 않는다.
      if (!mounted) return;
      _onLoginSuccess(
        '${(result['account'] as Map)['name']}',
        '${(result['account'] as Map)['email']}',
      );
    } on FitpickApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('로그인 서버에 연결할 수 없습니다. 서버 주소와 실행 상태를 확인해 주세요.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    showFitpickSnackbar(message);
  }

  // 서버 인증에 성공한 다음에만 기존 앱의 로그인 UI 상태를 변경한다.
  void _onLoginSuccess(String name, String email) {
    AuthController.to.login(email: email);
    _showMessage('$name님, 환영합니다.');
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
    }
  }

  // 회원가입 화면의 pop(email) 결과를 받아 기존 로그인 입력칸에 반영한다.
  Future<void> _goToSignUp() async {
    final email = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SignUpPage(api: _api, returnToLogin: true),
      ),
    );
    if (!mounted || email == null) return;
    _emailController.text = email;
    // 기존에 입력했던 비밀번호는 남기지 않아 새 계정으로 다시 로그인하게 한다.
    _passwordController.clear();
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
