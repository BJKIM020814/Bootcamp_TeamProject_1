import 'package:flutter/material.dart';

import 'fitpick_mypage_ui.dart';

/// 08. 리뷰 관리
///
/// 현재 ERD에는 리뷰 컬렉션이 없어, 존재하지 않는 데이터를 생성하거나 조회하지 않는다.
class ReviewManagementPage extends StatelessWidget {
  const ReviewManagementPage({super.key});

  @override
  Widget build(BuildContext context) => const FitpickMyPageScaffold(
    title: '리뷰 관리',
    body: FitpickEmptyState(
      icon: Icons.rate_review_outlined,
      title: '작성한 리뷰가 없습니다.',
      description: '주문 후 상품 리뷰를 작성해 보세요.',
    ),
  );
}
