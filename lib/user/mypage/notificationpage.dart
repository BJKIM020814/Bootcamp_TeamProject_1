import 'package:flutter/material.dart';

import 'fitpick_mypage_ui.dart';

/// 10. 알림
/// 현재 ERD에는 알림 이력이 없어 빈 상태를 표시한다.
class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) => const FitpickMyPageScaffold(
    title: '알림',
    body: FitpickEmptyState(
      icon: Icons.notifications_none_rounded,
      title: '새로운 알림이 없습니다.',
    ),
  );
}
