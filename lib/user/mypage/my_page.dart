import 'package:flutter/material.dart';
import 'package:get/get.dart';

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

  int _tabIndex = 4;

  final List<_MenuItem> _menus = const [
    _MenuItem(Icons.receipt_long_outlined, '주문 · 수령 내역'),
    _MenuItem(Icons.favorite_border, '찜한 상품'),
    _MenuItem(Icons.person_outline, '내 정보'),
    _MenuItem(Icons.location_on_outlined, '자주 찾는 매장', trailing: '강남 스토어'),
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
            onPressed: () {
              // TODO: 장바구니 이동
            },
            icon: const Icon(Icons.shopping_bag_outlined, color: _ink),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
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
    return Row(
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
                  const Text(
                    '홍길동님',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0EEE9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      '브론즈',
                      style: TextStyle(
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
                onTap: () {
                  // TODO: 내 정보 수정 이동
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('내 정보 수정',
                        style: TextStyle(fontSize: 12, color: _sub)),
                    SizedBox(width: 6),
                    Icon(Icons.north_east, size: 13, color: _sub),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
        child: Row(
          children: [
            _statItem('5', '주문 내역'),
            const VerticalDivider(width: 1, color: Color(0xFFE3E7EA)),
            _statItem('1', '찜한 상품'),
            const VerticalDivider(width: 1, color: Color(0xFFE3E7EA)),
            _statItem('0', '작성한 리뷰'),
          ],
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
    return Container(
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
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '270',
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'mm',
                      style: TextStyle(fontSize: 18, color: Color(0xFF9FB0B8)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () {
                    // TODO: 사이즈 변경 이동
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('사이즈 변경',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFFD0D8DC))),
                      SizedBox(width: 8),
                      Icon(Icons.north_east,
                          size: 14, color: Color(0xFFD0D8DC)),
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

  Widget _buildMenuTile(_MenuItem item) {
    return InkWell(
      onTap: () {
        // TODO: ${item.title} 화면 이동
      },
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
            if (item.trailing != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  item.trailing!,
                  style: const TextStyle(fontSize: 12, color: _sub),
                ),
              ),
            const Icon(Icons.chevron_right, color: Color(0xFFB5BDC4)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEDEFF1))),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _tabItem(0, Icons.home_outlined, Icons.home, '홈'),
              _tabItem(1, Icons.grid_view_outlined, Icons.grid_view, '카테고리'),
              _tabItem(2, Icons.shopping_bag_outlined, Icons.shopping_bag, '장바구니',
                  badge: 1),
              _tabItem(
                  3, Icons.receipt_long_outlined, Icons.receipt_long, '주문내역'),
              _tabItem(4, Icons.person_outline, Icons.person, '마이'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabItem(int index, IconData icon, IconData activeIcon, String label,
      {int badge = 0}) {
    final bool selected = _tabIndex == index;
    final Color color = selected ? _ink : const Color(0xFF8A96A0);
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tabIndex = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: badge > 0,
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

class _MenuItem {
  final IconData icon;
  final String title;
  final String? trailing;

  const _MenuItem(this.icon, this.title, {this.trailing});
}
