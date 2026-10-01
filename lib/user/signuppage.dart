import 'package:flutter/material.dart';

import '../models/erd_entities.dart';

/// FITPICK 회원가입 화면.
///
/// 기존 ERD의 `account` 엔티티 필드만 사용한다.
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  static const _brandColor = Color(0xFF222222);
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _addressController = TextEditingController();
  String _gender = '선택 안 함';
  bool _agreed = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneNumberController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _submit() {
    final isFormValid = _formKey.currentState?.validate() ?? false;
    if (!isFormValid) return;

    if (!_agreed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('약관에 동의해 주세요.')));
      return;
    }

    // 프로젝트의 기존 회원(account) 모델과 동일한 필드명으로만 구성한다.
    final account = ErpEntity('account', _emailController.text.trim(), {
      'email': _emailController.text.trim(),
      'password': _passwordController.text,
      'phoneNumber': _phoneNumberController.text.trim(),
      'name': _nameController.text.trim(),
      'gender': _gender,
      'address': _addressController.text.trim(),
      'signupPath': '이메일',
    });

    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${account.fields['name']}님의 회원가입 정보를 확인했습니다.')),
    );
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
          '회원가입',
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
              const _BrandHeader(),
              const SizedBox(height: 34),
              const Text(
                '나만의 걸음을 시작해요',
                style: TextStyle(
                  color: _brandColor,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 24),
              _InputField(
                label: '이름',
                controller: _nameController,
                textInputAction: TextInputAction.next,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? '이름을 입력해 주세요.'
                    : null,
              ),
              const SizedBox(height: 16),
              _InputField(
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
              _InputField(
                label: '비밀번호',
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
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
                    (value?.length ?? 0) >= 8 ? null : '비밀번호는 8자 이상 입력해 주세요.',
              ),
              const SizedBox(height: 16),
              _InputField(
                label: '전화번호',
                controller: _phoneNumberController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final phone = value?.trim() ?? '';
                  return RegExp(
                        r'^01[0-9]-?[0-9]{3,4}-?[0-9]{4}$',
                      ).hasMatch(phone)
                      ? null
                      : '휴대폰 번호를 입력해 주세요. (예: 010-1234-5678)';
                },
              ),
              const SizedBox(height: 16),
              const Text(
                '성별',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _gender,
                isExpanded: true,
                decoration: _inputDecoration(),
                borderRadius: BorderRadius.circular(12),
                items: const ['선택 안 함', '여성', '남성', '기타']
                    .map(
                      (gender) =>
                          DropdownMenuItem(value: gender, child: Text(gender)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _gender = value ?? _gender),
              ),
              const SizedBox(height: 16),
              _InputField(
                label: '주소',
                controller: _addressController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? '주소를 입력해 주세요.'
                    : null,
              ),
              const SizedBox(height: 18),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _agreed,
                activeColor: _brandColor,
                onChanged: (value) => setState(() => _agreed = value ?? false),
                title: const Text(
                  '약관에 동의합니다.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF555555)),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _brandColor,
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
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _goBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _brandColor,
                    side: const BorderSide(color: Color(0xFFD9D9D9)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    '로그인으로 돌아가기',
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

InputDecoration _inputDecoration() => InputDecoration(
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
      color: _SignUpPageState._brandColor,
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

class _InputField extends StatelessWidget {
  const _InputField({
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
        decoration: _inputDecoration().copyWith(suffixIcon: suffixIcon),
        validator: validator,
        onFieldSubmitted: onSubmitted,
      ),
    ],
  );
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'FITPICK.',
        style: TextStyle(
          color: _SignUpPageState._brandColor,
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
