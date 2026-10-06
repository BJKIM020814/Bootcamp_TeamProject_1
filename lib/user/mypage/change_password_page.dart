import 'package:flutter/material.dart';
import 'package:bootcamp_teamproject_1/common/fitpick_snackbar.dart';

import 'package:get/get.dart';

import 'package:bootcamp_teamproject_1/services/account_service.dart';
import 'package:bootcamp_teamproject_1/user/authController.dart';

import 'mypage_common.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool _saving = false;

  void _toast(String message) => showFitpickSnackbar(message);

  /// 입력을 검증한 뒤 계정(Firebase account)의 비밀번호를 변경한다.
  Future<void> _submit() async {
    if (_saving) return;
    final pw = _next.text;
    String? error;
    if (_current.text.isEmpty) {
      error = '현재 비밀번호를 입력해 주세요.';
    } else if (pw.length < 8 ||
        !RegExp(r'[A-Za-z]').hasMatch(pw) ||
        !RegExp(r'\d').hasMatch(pw)) {
      error = '새 비밀번호는 영문·숫자 포함 8자 이상이어야 합니다.';
    } else if (pw != _confirm.text) {
      error = '새 비밀번호 확인이 일치하지 않습니다.';
    }
    if (error == null && _next.text == _current.text) {
      error = '새 비밀번호는 현재 비밀번호와 달라야 합니다.';
    }
    final email = AuthController.to.customerId.value;
    if (error == null && email == null) error = '로그인이 필요합니다.';
    if (error != null) return _toast(error);

    setState(() => _saving = true);
    try {
      await AccountService.changePassword(
        email!,
        current: _current.text,
        next: _next.text,
      );
      if (!mounted) return;
      _toast('비밀번호가 변경되었습니다.');
      Get.back();
    } catch (e) {
      if (mounted) _toast('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String label, TextEditingController c, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MpLabel(label),
          TextField(
            controller: c,
            obscureText: true,
            style: const TextStyle(fontSize: 16, color: MpColors.ink),
            decoration: mpInputDecoration(hint: hint),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: mpAppBar('비밀번호 변경'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          const Text(
            '안전한 계정 관리',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: MpColors.ink,
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 28),
          _field('현재 비밀번호', _current),
          _field('새 비밀번호', _next, hint: '영문·숫자 포함 8자 이상'),
          _field('새 비밀번호 확인', _confirm),
          const Text(
            '현재 비밀번호가 일치할 때만 변경됩니다.',
            style: TextStyle(fontSize: 13, color: MpColors.icon),
          ),
        ],
      ),
      bottomNavigationBar: MpBottomBar(
        actionLabel: _saving ? '변경 중...' : '비밀번호 변경',
        onAction: _submit,
      ),
    );
  }
}
