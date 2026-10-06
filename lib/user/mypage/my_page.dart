import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:bootcamp_teamproject_1/common/fitpick_tab_bar.dart';
import 'package:bootcamp_teamproject_1/discover/home_page.dart';
import 'package:bootcamp_teamproject_1/discover/product_list_page.dart';
import 'package:bootcamp_teamproject_1/discover/store_selection_page.dart';
import 'package:bootcamp_teamproject_1/order/cartPage.dart';
import 'package:bootcamp_teamproject_1/order/orderHistoryPage.dart';
import 'package:bootcamp_teamproject_1/user/authController.dart';
import 'package:bootcamp_teamproject_1/user/loginpage.dart';
import 'package:bootcamp_teamproject_1/user/mypage/coupon_page.dart';
import 'package:bootcamp_teamproject_1/user/mypage/customersupportpage.dart';
import 'package:bootcamp_teamproject_1/user/mypage/mypage_controller.dart';
import 'package:bootcamp_teamproject_1/user/mypage/profile_page.dart';
import 'package:bootcamp_teamproject_1/user/mypage/recently_viewed_page.dart';
import 'package:bootcamp_teamproject_1/user/mypage/reviewmanagementpage.dart';
import 'package:bootcamp_teamproject_1/user/mypage/settingspage.dart';
import 'package:bootcamp_teamproject_1/user/mypage/wishlist_page.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  static const Color _ink = Color(0xFF1B2A33);
  static const Color _sub = Color(0xFF8A96A0);
  static const Color _green = Color(0xFF1F5A46);
  static const Color _navy = Color(0xFF263B45);
  static const Color _panel = Color(0xFFF4F6F7);

  final int _tabIndex = 4;
  DateTime? _lastTabTap;

  final MyPageController _c = MyPageController.to;

  @override
  void initState() {
    super.initState();
    // 라우트 전환 중 기존 화면의 Obx와 겹쳐 갱신되지 않도록 첫 프레임 뒤 조회한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _c.load();
    });
  }

  /// 내 정보 화면에서 돌아오면 바뀐 이름/사이즈를 다시 불러온다.
  void _openProfile() =>
      Get.to(() => ProfilePage(profile: _c.profile))?.then((_) => _c.load());

  final List<_MenuItem> _menus = const [
    _MenuItem(Icons.receipt_long_outlined, '주문 · 수령 내역'),
    _MenuItem(Icons.favorite_border, '찜한 상품'),
    _MenuItem(Icons.person_outline, '내 정보'),
    _MenuItem(Icons.location_on_outlined, '자주 찾는 매장'),
    _MenuItem(Icons.snowshoeing_outlined, '리뷰 관리'),
    _MenuItem(Icons.history, '최근 본 상품'),
    _MenuItem(Icons.confirmation_number_outlined, '쿠폰함'),
    _MenuItem(Icons.headset_mic_outlined, '고객센터'),
    _MenuItem(Icons.settings_outlined, '앱 설정'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.chevron_left, color: _ink, size: 30),
        ),
        title: const Text(
          '마이페이지',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: _ink,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => Get.to(() => const Cartpage()),
            icon: const Icon(Icons.shopping_bag_outlined, color: _ink),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          Obx(() {
            if (_c.loading.value) return const LinearProgressIndicator();
            final error = _c.error.value;
            if (error == null) return const SizedBox.shrink();
            return ListTile(
              title: Text(error),
              trailing: TextButton(
                onPressed: _c.load,
                child: const Text('다시 시도'),
              ),
            );
          }),
          _buildProfile(),
          const SizedBox(height: 28),
          _buildStats(),
          const SizedBox(height: 28),
          _buildSizeCard(),
          const SizedBox(height: 12),
          ..._menus.map(_buildMenuTile),
          const SizedBox(height: 28),
        ],
      ),
      bottomNavigationBar: _buildTabBar(),
    );
  }

  Widget _buildProfile() {
    return Obx(
      () => Row(
        children: [
          const CircleAvatar(
            radius: 50,
            backgroundColor: Color(0xFFEDEFF1),
            child: Icon(Icons.person, size: 56, color: Color(0xFFB5BDC4)),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _c.name.value.isEmpty ? '회원님' : '${_c.name.value}님',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0EEE9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _c.grade.value,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _green,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '좋은 신발과 함께하는 하루.',
                  style: TextStyle(fontSize: 13, color: _sub),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _openProfile,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '내 정보 수정',
                        style: TextStyle(fontSize: 12, color: _sub),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.north_east, size: 13, color: _sub),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
      ),
      child: IntrinsicHeight(
        child: Obx(
          () => Row(
            children: [
              _statItem('${_c.orderCount.value}', '주문 내역'),
              const VerticalDivider(width: 1, color: Color(0xFFE3E7EA)),
              _statItem('${_c.wishlistCount.value}', '찜한 상품'),
              const VerticalDivider(width: 1, color: Color(0xFFE3E7EA)),
              _statItem('${_c.reviewCount.value}', '작성한 리뷰'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: _ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: _sub)),
        ],
      ),
    );
  }

  Widget _buildSizeCard() {
    return InkWell(
      onTap: _openProfile,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 276,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _navy,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: 20,
              child: Transform.rotate(
                angle: 0.18,
                child: Container(
                  width: 200,
                  height: 220,
                  color: const Color(0xFFC9CFD2),
                  child: const Icon(
                    Icons.snowshoeing,
                    size: 110,
                    color: Color(0xFF5C6B75),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'MY SHOE SIZE',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9FB0B8),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '내 신발 사이즈',
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Obx(
                        () => Text(
                          _c.shoeSize.value.replaceAll('mm', ''),
                          style: const TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 4),
                      const Text(
                        'mm',
                        style: TextStyle(
                          fontSize: 18,
                          color: Color(0xFF9FB0B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: _openProfile,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '사이즈 변경',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFD0D8DC),
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.north_east,
                          size: 14,
                          color: Color(0xFFD0D8DC),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 선택한 메뉴에 맞는 화면으로 이동합니다. 각 화면이 서버에서 직접 데이터를 불러옵니다.
  void _openMenu(_MenuItem item) {
    switch (item.title) {
      case '주문 · 수령 내역':
        Get.to(() => const Orderhistorypage());
      case '찜한 상품':
        Get.to(() => const WishlistPage())?.then((_) => _c.load());
      case '내 정보':
        _openProfile();
      case '자주 찾는 매장':
        Get.to(() => const StoreSelectionPage());
      case '리뷰 관리':
        Get.to(() => const ReviewManagementPage());
      case '최근 본 상품':
        Get.to(() => const RecentlyViewedPage());
      case '쿠폰함':
        Get.to(() => const CouponPage());
      case '고객센터':
        Get.to(() => const CustomerSupportPage());
      case '앱 설정':
        Get.to(() => const SettingsPage());
    }
  }

  Widget _buildMenuTile(_MenuItem item) {
    return InkWell(
      onTap: () => _openMenu(item),
      child: Container(
        height: 64,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFEDEFF1))),
        ),
        child: Row(
          children: [
            Icon(item.icon, size: 26, color: const Color(0xFF6B7A85)),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                item.title,
                style: const TextStyle(fontSize: 16, color: _ink),
              ),
            ),
            if (item.title == '자주 찾는 매장')
              Obx(
                () => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    _c.favoriteStore.value,
                    style: const TextStyle(fontSize: 12, color: _sub),
                  ),
                ),
              ),
            const Icon(Icons.chevron_right, color: Color(0xFFB5BDC4)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() =>
      FitpickTabBar(selectedIndex: _tabIndex, onSelected: _goToTab);

  // 로그인하지 않은 상태라면 로그인 화면으로, 로그인된 상태라면 요청한 화면으로 이동합니다.
  void _goToIfLoggedIn(Widget Function() builder) {
    Get.offAll(
      AuthController.to.isLoggedIn.value ? builder : () => const LoginPage(),
    );
  }

  void _goToTab(int index) {
    if (index == _tabIndex) return;
    final now = DateTime.now();
    if (_lastTabTap != null &&
        now.difference(_lastTabTap!) < const Duration(milliseconds: 400)) {
      return;
    }
    _lastTabTap = now;
    switch (index) {
      case 0:
        Get.offAll(() => const HomePage());
      case 1:
        Get.offAll(() => const ProductListPage());
      case 2:
        _goToIfLoggedIn(() => const Cartpage());
      case 3:
        _goToIfLoggedIn(() => const Orderhistorypage());
      case 4:
        _goToIfLoggedIn(() => const MyPage());
    }
  }
}

class _MenuItem {
  final IconData icon;
  final String title;

  const _MenuItem(this.icon, this.title);
}
