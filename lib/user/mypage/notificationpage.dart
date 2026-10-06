import 'package:flutter/material.dart';

import 'fitpick_mypage_ui.dart';

/// 10. 알림
/// 서버 SQLite 알림 API는 있지만 이 화면은 아직 API를 호출하지 않는 빈 상태 UI다.
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
