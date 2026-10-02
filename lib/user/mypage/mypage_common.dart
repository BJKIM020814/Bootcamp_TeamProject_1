import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:bootcamp_teamproject_1/discover/home_page.dart';
import 'package:bootcamp_teamproject_1/discover/product_list_page.dart';
import 'package:bootcamp_teamproject_1/order/cartPage.dart';
import 'package:bootcamp_teamproject_1/order/orderHistoryPage.dart';
import 'package:bootcamp_teamproject_1/user/authController.dart';
import 'package:bootcamp_teamproject_1/user/loginpage.dart';
import 'package:bootcamp_teamproject_1/user/mypage/my_page.dart';

/// 마이페이지 하위 화면 공통 색상
class MpColors {
  static const Color ink = Color(0xFF1B2A33);
  static const Color sub = Color(0xFF8A96A0);
  static const Color green = Color(0xFF1F5A46);
  static const Color panel = Color(0xFFF4F6F7);
  static const Color line = Color(0xFFE3E7EA);
  static const Color divider = Color(0xFFEDEFF1);
  static const Color icon = Color(0xFF6B7A85);
}

/// 하위 화면 공통 AppBar (뒤로가기 / 가운데 제목 / 장바구니)
PreferredSizeWidget mpAppBar(String title) {
  return AppBar(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.white,
    elevation: 0,
    centerTitle: true,
    leading: IconButton(
      onPressed: () => Get.back(),
      icon: const Icon(Icons.chevron_left, color: MpColors.ink, size: 30),
    ),
    title: Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 18,
        color: MpColors.ink,
      ),
    ),
    actions: [
      IconButton(
        onPressed: () => Get.to(() => const Cartpage()),
        icon: const Icon(Icons.shopping_bag_outlined, color: MpColors.ink),
      ),
    ],
  );
}

// 로그인하지 않은 상태라면 로그인 화면으로, 로그인된 상태라면 요청한 화면으로 이동합니다.
void _goToMpIfLoggedIn(Widget Function() builder) {
  Get.to(AuthController.to.isLoggedIn.value ? builder : () => const LoginPage());
}

void _goToMpTab(int index) {
  switch (index) {
    case 0:
      Get.to(() => const HomePage());
    case 1:
      Get.to(() => const ProductListPage());
    case 2:
      _goToMpIfLoggedIn(() => const Cartpage());
    case 3:
      _goToMpIfLoggedIn(() => const Orderhistorypage());
    case 4:
      _goToMpIfLoggedIn(() => const MyPage());
  }
}

/// 하단 영역: (선택) 고정 액션 버튼 + 탭바
class MpBottomBar extends StatelessWidget {
  final String? actionLabel;
  final VoidCallback? onAction;

  const MpBottomBar({super.key, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (actionLabel != null)
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: MpColors.divider)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MpColors.ink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          const MpTabBar(),
        ],
      ),
    );
  }
}

/// 하단 탭바 (마이 탭 선택 상태 고정)
class MpTabBar extends StatelessWidget {
  const MpTabBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: MpColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: const [
              _Tab(Icons.home_outlined, Icons.home, '홈', false, 0),
              _Tab(Icons.grid_view_outlined, Icons.grid_view, '카테고리', false, 1),
              _Tab(Icons.shopping_bag_outlined, Icons.shopping_bag, '장바구니',
                  false, 2,
                  badge: 1),
              _Tab(Icons.receipt_long_outlined, Icons.receipt_long, '주문내역',
                  false, 3),
              _Tab(Icons.person_outline, Icons.person, '마이', true, 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final int index;
  final int badge;

  const _Tab(this.icon, this.activeIcon, this.label, this.selected, this.index,
      {this.badge = 0});

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? MpColors.ink : MpColors.sub;
    return Expanded(
      child: InkWell(
        onTap: () => _goToMpTab(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: badge > 0 && AuthController.to.isLoggedIn.value,
              label: Text('$badge'),
              backgroundColor: const Color(0xFFC0392B),
              child: Icon(selected ? activeIcon : icon, color: color, size: 26),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 입력창 공통 데코레이션
InputDecoration mpInputDecoration({String? hint}) {
  OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFB5BDC4), fontSize: 15),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
    enabledBorder: border(MpColors.line),
    focusedBorder: border(MpColors.ink),
    errorBorder: border(const Color(0xFFC0392B)),
    focusedErrorBorder: border(const Color(0xFFC0392B)),
  );
}

/// 폼 라벨
class MpLabel extends StatelessWidget {
  final String text;
  const MpLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: MpColors.ink,
        ),
      ),
    );
  }
}

/// 회색 안내 박스
class MpNotice extends StatelessWidget {
  final String text;
  final Color background;
  final Color textColor;

  const MpNotice(
    this.text, {
    super.key,
    this.background = const Color(0xFFEFF3F4),
    this.textColor = const Color(0xFF5C6B75),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, height: 1.5, color: textColor),
      ),
    );
  }
}
