import 'package:bootcamp_teamproject_1/discover/product_list_page.dart';
import 'package:bootcamp_teamproject_1/discover/store_selection_page.dart';
import 'package:bootcamp_teamproject_1/order/cartPage.dart';
import 'package:bootcamp_teamproject_1/order/orderHistoryPage.dart';
import 'package:bootcamp_teamproject_1/user/authController.dart';
import 'package:bootcamp_teamproject_1/user/loginpage.dart';
import 'package:bootcamp_teamproject_1/user/mypage/my_page.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _audience = '전체';
  String _brand = '전체';
  String _purpose = '전체';

  @override
  Widget build(BuildContext context) {
    const products = [
      (
        'NEW BALANCE',
        '530',
        '₩129,000',
        '데일리',
        'https://fitpick-o2o.higgsfield.app/assets/products/nb530.jpg',
      ),
      (
        'NIKE',
        "에어 포스 1 '07",
        '₩119,000',
        '데일리',
        'https://fitpick-o2o.higgsfield.app/assets/products/airforce.png',
      ),
      (
        'ADIDAS',
        '삼바 OG',
        '₩139,000',
        '클래식',
        'https://fitpick-o2o.higgsfield.app/assets/products/samba.jpg',
      ),
      (
        'NIKE',
        '페가수스 41',
        '₩159,000',
        '러닝화',
        'https://fitpick-o2o.higgsfield.app/assets/products/pegasus41.jpg',
      ),
      (
        'PUMA',
        '스웨이드 클래식',
        '₩99,000',
        '클래식',
        'https://fitpick-o2o.higgsfield.app/assets/products/puma-suede.jpg',
      ),
      (
        'ASICS',
        '노바블라스트 6',
        '₩179,000',
        '러닝화',
        'https://fitpick-o2o.higgsfield.app/assets/products/novablast6.webp',
      ),
    ];
    final visibleProducts = _purpose == '전체'
        ? products
        : products.where((product) => product.$4 == _purpose).toList();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          children: [
            // 브랜드 제목과 알림 진입 영역입니다.
            Row(
              children: [
                const Text(
                  'FITPICK.',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.3,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              '안녕하세요!',
              style: TextStyle(color: Color(0xFF827A71), fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              '오늘도 좋은 하루 되세요 👋',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 18),
            // 상품 목록 화면으로 이동하는 검색 입력 목업입니다.
            InkWell(
              onTap: _openProductList,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F1EE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search_rounded, color: Color(0xFF5D5751)),
                    SizedBox(width: 10),
                    Text('신발 검색', style: TextStyle(color: Color(0xFF948C84))),
                    Spacer(),
                    Icon(Icons.tune_rounded, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            // 참고 목업의 큰 프로모션 카드 비율과 색상을 반영한 배너입니다.
            InkWell(
              onTap: _openProductDetail,
              borderRadius: BorderRadius.circular(25),
              child: Container(
                height: 210,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E0D6),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -5,
                      bottom: -5,
                      child: Image.network(
                        'https://fitpick-o2o.higgsfield.app/assets/products/nb530.jpg',
                        width: 220,
                        height: 180,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.image_outlined, size: 80),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      top: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NEW SEASON / NEW STEP',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            '새로운 계절.\n새로운 시작.',
                            style: TextStyle(
                              fontSize: 23,
                              height: 1.2,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            '지금, 당신의 스타일을\n찾아보세요.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF5F574F),
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            '530 만나보기  →',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 20,
                      bottom: 12,
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 4,
                            color: Color(0xFF302B27),
                          ),
                          SizedBox(width: 5),
                          CircleAvatar(
                            radius: 2.5,
                            backgroundColor: Color(0xFFAFA79F),
                          ),
                          SizedBox(width: 5),
                          CircleAvatar(
                            radius: 2.5,
                            backgroundColor: Color(0xFFAFA79F),
                          ),
                          SizedBox(width: 5),
                          CircleAvatar(
                            radius: 2.5,
                            backgroundColor: Color(0xFFAFA79F),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 26),
            // 용도별 필터를 선택하면 이 화면 하단의 상품 그리드가 즉시 바뀝니다.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final item in const [
                  ('러닝화', Icons.directions_run_rounded),
                  ('데일리', Icons.ice_skating_rounded),
                  ('클래식', Icons.checkroom_rounded),
                  ('아웃도어', Icons.terrain_rounded),
                ])
                  InkWell(
                    onTap: () => setState(() => _purpose = item.$1),
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      children: [
                        Container(
                          width: 68,
                          height: 58,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F3F2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(item.$2, color: const Color(0xFF39342F)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.$1,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 30),
            const Text(
              '대상별 신발',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 13),
            // 대상 필터는 데이터 연결 전 선택 상태만 화면에 반영합니다.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final item in const ['전체', '남성·공용', '여성용', '아동용'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(item),
                        selected: _audience == item,
                        onSelected: (_) => setState(() => _audience = item),
                        selectedColor: const Color(0xFF272A2D),
                        labelStyle: TextStyle(
                          color: _audience == item
                              ? Colors.white
                              : const Color(0xFF49433D),
                          fontWeight: FontWeight.w700,
                        ),
                        side: BorderSide.none,
                        backgroundColor: const Color(0xFFF3F1EE),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              '브랜드로 둘러보기',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 13),
            // 브랜드 필터 역시 서버 상품 데이터와 연결하기 전의 인터랙션 목업입니다.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final item in const [
                    '전체',
                    'NIKE',
                    'ADIDAS',
                    'NB',
                    'ASICS',
                    'VANS',
                    'SALOMON',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(item),
                        selected: _brand == item,
                        onSelected: (_) => setState(() => _brand = item),
                        selectedColor: const Color(0xFF272A2D),
                        labelStyle: TextStyle(
                          color: _brand == item
                              ? Colors.white
                              : const Color(0xFF49433D),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        side: const BorderSide(color: Color(0xFFE4E0DB)),
                        backgroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            // 홈 하단에서 전체 상품을 계속 확인할 수 있는 상품 그리드입니다.
            Row(
              children: [
                const Text(
                  '추천 상품',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _openProductList,
                  child: const Text(
                    '전체 보기  ›',
                    style: TextStyle(
                      color: Color(0xFF4D4740),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const Text(
              '27개의 실제 모델',
              style: TextStyle(color: Color(0xFF918981), fontSize: 12),
            ),
            const SizedBox(height: 15),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleProducts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 22,
                childAspectRatio: .58,
              ),
              itemBuilder: (context, index) => _ProductCard(
                brand: visibleProducts[index].$1,
                name: visibleProducts[index].$2,
                price: visibleProducts[index].$3,
                imageUrl: visibleProducts[index].$5,
                onTap: _openProductDetail,
              ),
            ),
            const SizedBox(height: 20),
            InkWell(
              onTap: _openStoreSelection,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0ECE5),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.storefront_rounded),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '가까운 매장에서 직접 신어보세요',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          switch (index) {
            case 1:
              _openProductList();
            case 2:
              _openCart();
            case 3:
              _openOrderHistory();
            case 4:
              _openMyPage();
          }
        },
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: '카테고리',
          ),
          NavigationDestination(icon: CartBadgeIcon(), label: '장바구니'),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: '주문내역',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            label: '마이',
          ),
        ],
      ),
    );
  }

  // 검색·카테고리·전체 보기에서 상품 목록으로 이동합니다.
  void _openProductList() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const ProductListPage()));

  // 배너는 현재 DB 등록 상품을 확인할 수 있는 목록으로 이동합니다.
  void _openProductDetail() => _openProductList();

  // 오프라인 매장 확인 카드를 누르면 매장 선택으로 이동합니다.
  void _openStoreSelection() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const StoreSelectionPage()));

  // 로그인하지 않은 상태라면 로그인 화면으로, 로그인된 상태라면 요청한 화면으로 이동합니다.
  void _openIfLoggedIn(Widget Function() builder) {
    final target = AuthController.to.isLoggedIn.value
        ? builder()
        : const LoginPage();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => target));
  }

  // 하단 탭바의 장바구니 탭으로 이동합니다.
  void _openCart() => _openIfLoggedIn(() => const Cartpage());

  // 하단 탭바의 주문내역 탭으로 이동합니다.
  void _openOrderHistory() => _openIfLoggedIn(() => const Orderhistorypage());

  // 하단 탭바의 마이 탭으로 이동합니다.
  void _openMyPage() => _openIfLoggedIn(() => const MyPage());
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.brand,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.onTap,
  });

  final String brand;
  final String name;
  final String price;
  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F3F1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          const Center(child: Icon(Icons.image_outlined)),
                    ),
                  ),
                  const Positioned(
                    top: 10,
                    right: 10,
                    child: Icon(
                      Icons.favorite_border_rounded,
                      color: Color(0xFF706962),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            brand,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF766E66),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(
            price,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          const Text(
            '공용 · 데일리 · 예시 가격',
            style: TextStyle(fontSize: 10, color: Color(0xFF918981)),
          ),
        ],
      ),
    );
  }
}
