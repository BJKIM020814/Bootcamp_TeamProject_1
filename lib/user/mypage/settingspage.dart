import 'package:flutter/material.dart';

import 'fitpick_mypage_ui.dart';

/// 11. 앱 설정
/// 서버 설정 API는 있으나 이 화면은 아직 로컬 위젯 상태만 변경하고 저장하지 않는다.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _orderNotification = true;
  bool _marketingNotification = false;

  @override
  Widget build(BuildContext context) => FitpickMyPageScaffold(
    title: '앱 설정',
    body: ListView(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Text('알림 설정', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        SwitchListTile(
          title: const Text('주문 및 배송 알림'),
          value: _orderNotification,
          onChanged: (value) => setState(() => _orderNotification = value),
        ),
        SwitchListTile(
          title: const Text('혜택 및 마케팅 알림'),
          value: _marketingNotification,
          onChanged: (value) => setState(() => _marketingNotification = value),
        ),
        const Divider(height: 32),
        ListTile(
          title: const Text('앱 버전'),
          trailing: Text(
            '1.0.0',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
      ],
    ),
  );
}
