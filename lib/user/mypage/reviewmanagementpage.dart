import 'package:flutter/material.dart';

import 'fitpick_mypage_ui.dart';

/// 08. 리뷰 관리
///
/// MySQL 리뷰 및 리뷰 API는 있으나 이 화면은 아직 API를 연결하지 않은 빈 상태 UI다.
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
