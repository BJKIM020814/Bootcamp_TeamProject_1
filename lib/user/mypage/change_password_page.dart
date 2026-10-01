import 'package:flutter/material.dart';

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

  /// 시연용 입력 검증 (서버 전송/저장 없음)
  void _validate() {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? '입력 형식이 올바릅니다. (시연용 · 실제 변경되지 않음)')),
    );
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
          const MpNotice(
            '인증 서버가 연결되지 않은 목업입니다. 실제 사용 중인 비밀번호를 입력하지 마세요.',
            background: Color(0xFFFFF4E0),
            textColor: Color(0xFF9A5B13),
          ),
          const SizedBox(height: 28),
          _field('현재 비밀번호 (시연)', _current),
          _field('새 비밀번호', _next, hint: '영문·숫자 포함 8자 이상'),
          _field('새 비밀번호 확인', _confirm),
          const Text(
            '입력값은 전송·저장하지 않으며 화면을 나가면 폐기됩니다.',
            style: TextStyle(fontSize: 13, color: MpColors.icon),
          ),
        ],
      ),
      bottomNavigationBar:
          MpBottomBar(actionLabel: '비밀번호 입력 검증', onAction: _validate),
    );
  }
}
