import 'package:flutter/material.dart';

const fitpickBrandColor = Color(0xFF222222);

/// FITPICK 마이페이지 계열 화면의 공통 상단 바와 빈 상태 표현.
class FitpickMyPageScaffold extends StatelessWidget {
  const FitpickMyPageScaffold({
    required this.title,
    required this.body,
    super.key,
  });

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      foregroundColor: fitpickBrandColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      title: Text(
        title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      leading: IconButton(
        tooltip: '뒤로가기',
        onPressed: () {
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        },
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
    body: SafeArea(top: false, child: body),
  );
}

class FitpickEmptyState extends StatelessWidget {
  const FitpickEmptyState({
    required this.icon,
    required this.title,
    this.description,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 50, color: const Color(0xFF999999)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF777777), height: 1.45),
            ),
          ],
        ],
      ),
    ),
  );
}
