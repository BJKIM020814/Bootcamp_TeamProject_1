import 'package:flutter/material.dart';

import 'mypage_common.dart';

class PaymentMethodsPage extends StatefulWidget {
  final List<String> methods;

  const PaymentMethodsPage({super.key, required this.methods});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: mpAppBar('결제수단'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        children: [
          const Text(
            '기본 결제수단',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: MpColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '주문 시 먼저 선택할 수단을 지정하세요.',
            style: TextStyle(fontSize: 14, color: MpColors.icon),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: MpColors.line),
            ),
            child: Column(
              children: [
                for (int i = 0; i < widget.methods.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: MpColors.divider),
                  _buildMethod(i),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          const MpNotice(
            '카드번호·계좌정보를 수집하지 않습니다. 실제 결제수단 등록은 결제 서비스 연동 후 제공됩니다.',
          ),
        ],
      ),
      bottomNavigationBar: const MpBottomBar(),
    );
  }

  Widget _buildMethod(int index) {
    final bool on = _selected == index;
    return InkWell(
      onTap: () => setState(() => _selected = index),
      child: SizedBox(
        height: 96,
        child: Row(
          children: [
            const Icon(Icons.credit_card_outlined,
                size: 28, color: MpColors.ink),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.methods[index],
                      style: const TextStyle(
                          fontSize: 16, color: MpColors.ink)),
                  const SizedBox(height: 6),
                  const Text('실제 결제정보 미등록',
                      style: TextStyle(fontSize: 11, color: MpColors.sub)),
                ],
              ),
            ),
            // 라디오 모양 (선택 시 검정 테두리 + 속 채움)
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: on ? MpColors.ink : MpColors.icon,
                  width: on ? 2 : 1.5,
                ),
              ),
              child: on
                  ? Center(
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: MpColors.ink,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
