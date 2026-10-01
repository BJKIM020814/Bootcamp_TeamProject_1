import 'package:flutter/material.dart';

import 'fitpick_mypage_ui.dart';

/// 07. 최근 본 상품
///
/// 현재 ERD에는 최근 본 이력 컬렉션이 없다. 따라서 별도 컬렉션을 만들거나
/// 관계없는 재고 데이터를 최근 본 상품으로 표시하지 않는다.
class RecentlyViewedPage extends StatelessWidget {
  const RecentlyViewedPage({super.key});

  @override
  Widget build(BuildContext context) => const FitpickMyPageScaffold(
    title: '최근 본 상품',
    body: FitpickEmptyState(icon: Icons.history, title: '최근 본 상품이 없습니다.'),
  );
}
