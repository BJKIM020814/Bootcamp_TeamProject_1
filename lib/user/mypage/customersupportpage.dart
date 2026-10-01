import 'package:flutter/material.dart';

import 'fitpick_mypage_ui.dart';

/// 12. 고객센터
/// 문의 컬렉션이 현재 ERD에 없으므로, 자주 묻는 질문과 안내만 제공한다.
class CustomerSupportPage extends StatelessWidget {
  const CustomerSupportPage({super.key});

  @override
  Widget build(BuildContext context) => FitpickMyPageScaffold(
    title: '고객센터',
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          '무엇을 도와드릴까요?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            leading: const Icon(Icons.headset_mic_outlined),
            title: const Text('1:1 문의'),
            subtitle: const Text('문의 데이터 모델 연결 후 이용할 수 있습니다.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('1:1 문의 기능은 준비 중입니다.')),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text('자주 묻는 질문', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const ExpansionTile(
          title: Text('주문 내역은 어디에서 확인하나요?'),
          childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [Text('마이페이지의 주문 내역 메뉴에서 확인할 수 있습니다.')],
        ),
        const ExpansionTile(
          title: Text('교환과 반품은 어떻게 신청하나요?'),
          childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [Text('주문 상세 화면에서 교환 또는 반품을 신청할 수 있습니다.')],
        ),
      ],
    ),
  );
}
