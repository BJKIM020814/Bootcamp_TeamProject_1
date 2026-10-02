import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:bootcamp_teamproject_1/services/account_service.dart';
import 'package:bootcamp_teamproject_1/services/mypage_api.dart';
import 'package:bootcamp_teamproject_1/user/authController.dart';

import 'change_password_page.dart';
import 'mypage_controller.dart';
import 'mypage_common.dart';
import 'mypage_models.dart';
import 'payment_methods_page.dart';

// 결제수단은 DB 테이블이 없어 화면 안에서 고정값으로 사용
const List<String> _paymentMethods = ['신용 / 체크카드', '카카오페이', '네이버페이'];

class ProfilePage extends StatefulWidget {
  final MpProfile profile;

  const ProfilePage({super.key, required this.profile});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static final List<String> _sizes = [
    for (int s = 220; s <= 310; s += 5) '${s}mm',
  ];

  late final _name = TextEditingController(text: widget.profile.name);
  late final _phone = TextEditingController(text: widget.profile.phone);
  late final _email = TextEditingController(text: widget.profile.email);
  late String _size = widget.profile.shoeSize;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  void _toast(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  /// 이름/전화번호는 Firebase account 에, 신발 사이즈는 서버(MySQL)에 저장한다.
  Future<void> _save() async {
    if (_saving) return;
    final email = AuthController.to.customerId.value;
    if (email == null) return _toast('로그인이 필요합니다.');
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    if (name.isEmpty) return _toast('이름을 입력해 주세요.');
    if (!RegExp(r'^[0-9\-\s]{9,13}$').hasMatch(phone)) {
      return _toast('휴대폰 번호 형식이 올바르지 않습니다.');
    }

    setState(() => _saving = true);
    try {
      await AccountService.updateBasic(email, name: name, phone: phone);
      await MyPageApi.updateShoeSize(
        email,
        int.parse(_size.replaceAll('mm', '')),
      );
      await MyPageController.to.load();
      if (!mounted) return;
      _toast('변경 내용이 저장되었습니다.');
    } catch (e) {
      if (mounted) _toast('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _section(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [MpLabel(label), child],
      ),
    );
  }

  Widget _textField(
    TextEditingController c,
    TextInputType type, {
    bool readOnly = false,
  }) {
    return TextField(
      controller: c,
      keyboardType: type,
      readOnly: readOnly,
      style: const TextStyle(fontSize: 17, color: MpColors.ink),
      decoration: mpInputDecoration(),
    );
  }

  Widget _dropdown(
    String value,
    List<String> items,
    ValueChanged<String> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      icon: const Icon(Icons.keyboard_arrow_down, color: MpColors.ink),
      decoration: mpInputDecoration(),
      style: const TextStyle(fontSize: 17, color: MpColors.ink),
      borderRadius: BorderRadius.circular(12),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _linkTile(
    IconData icon,
    String title,
    VoidCallback onTap, {
    String? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: MpColors.divider)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: MpColors.icon),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, color: MpColors.ink),
              ),
            ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  trailing,
                  style: const TextStyle(fontSize: 12, color: MpColors.sub),
                ),
              ),
            const Icon(Icons.chevron_right, color: Color(0xFFB5BDC4)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: mpAppBar('내 정보 변경'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          const Text(
            '나를 위한 쇼핑 정보',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: MpColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '주문에 필요한 정보와 내 신발 사이즈를 확인하세요.',
            style: TextStyle(fontSize: 14, color: MpColors.icon),
          ),
          const SizedBox(height: 24),
          const Center(
            child: CircleAvatar(
              radius: 52,
              backgroundColor: Color(0xFFEDF0F3),
              child: Icon(
                Icons.person_outline,
                size: 56,
                color: Color(0xFF9AA5AD),
              ),
            ),
          ),
          const SizedBox(height: 28),
          _section('이름', _textField(_name, TextInputType.name)),
          _section('휴대폰 번호', _textField(_phone, TextInputType.phone)),
          // 이메일은 로그인 ID 이자 서버의 회원 키라서 수정할 수 없다.
          _section(
            '이메일',
            _textField(_email, TextInputType.emailAddress, readOnly: true),
          ),
          _section(
            '내 신발 사이즈',
            _dropdown(_size, _sizes, (v) => setState(() => _size = v)),
          ),
          _section(
            '회원 등급',
            Container(
              height: 56,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: MpColors.panel,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${widget.profile.grade} (누적 결제금액 기준 자동 산정)',
                style: const TextStyle(fontSize: 17, color: MpColors.icon),
              ),
            ),
          ),
          _linkTile(
            Icons.credit_card_outlined,
            '결제수단 관리',
            () => Get.to(
              () => const PaymentMethodsPage(methods: _paymentMethods),
            ),
          ),
          _linkTile(
            Icons.lock_outline,
            '비밀번호 변경',
            () => Get.to(() => const ChangePasswordPage()),
          ),
        ],
      ),
      bottomNavigationBar: MpBottomBar(
        actionLabel: _saving ? '저장 중...' : '변경 내용 저장',
        onAction: _save,
      ),
    );
  }
}
