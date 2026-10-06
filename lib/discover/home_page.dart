import 'package:bootcamp_teamproject_1/discover/discover_api.dart';
import 'package:bootcamp_teamproject_1/common/fitpick_tab_bar.dart';
import 'package:bootcamp_teamproject_1/discover/product_detail_page.dart';
import 'package:bootcamp_teamproject_1/discover/product_list_page.dart';
import 'package:bootcamp_teamproject_1/discover/store_selection_page.dart';
import 'package:bootcamp_teamproject_1/order/cartPage.dart';
import 'package:bootcamp_teamproject_1/order/orderHistoryPage.dart';
import 'package:bootcamp_teamproject_1/user/authController.dart';
import 'package:bootcamp_teamproject_1/user/loginpage.dart';
import 'package:bootcamp_teamproject_1/user/mypage/my_page.dart';
import 'package:bootcamp_teamproject_1/user/mypage/notificationpage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 홈의 상품·대상·브랜드·배너는 FastAPI가 반환한 DB 레코드만 표시한다.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DiscoverApi _api = DiscoverApi();
  String? _gender;
  String? _brand;
  String? _purpose;
  late Future<_HomeData> _home;

  @override
  void initState() {
    super.initState();
    _home = _load();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<_HomeData> _load() async {
    final values = await Future.wait<Object>([
      _api.filters(),
      _api.banners(),
      _api.products(gender: _gender, brand: _brand, purpose: _purpose),
    ]);
    return _HomeData(
      filters: values[0] as DiscoverFilters,
      banners: values[1] as List<DiscoverBanner>,
      products: values[2] as List<DiscoverProduct>,
    );
  }

  void _reload() {
    final nextHome = _load();
    setState(() {
      _home = nextHome;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: FutureBuilder<_HomeData>(
        future: _home,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _HomeError(error: snapshot.error, onRetry: _reload);
          }
          return _body(snapshot.data!);
        },
      ),
    ),
    bottomNavigationBar: _buildNavigation(),
  );

  Widget _body(_HomeData data) => RefreshIndicator(
    onRefresh: () async => _reload(),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
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
              onPressed: () => Get.to(
                () => AuthController.to.isLoggedIn.value
                    ? const NotificationPage()
                    : const LoginPage(),
              ),
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          '오늘 신을 한 켤레를 찾아보세요',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
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
                Icon(Icons.search_rounded),
                SizedBox(width: 10),
                Text('신발 검색', style: TextStyle(color: Color(0xFF948C84))),
                Spacer(),
                Icon(Icons.tune_rounded, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (data.banners.isNotEmpty)
          _BannerCarousel(api: _api, banners: data.banners),
        if (data.banners.isEmpty) const _EmptyBanner(),
        const SizedBox(height: 26),
        const Text(
          '용도로 둘러보기',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        if (data.filters.purposes.isEmpty)
          const _MissingPurposeNotice()
        else
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: data.filters.purposes.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final purpose = index == 0
                    ? null
                    : data.filters.purposes[index - 1];
                final selected = _purpose == purpose;
                return ChoiceChip(
                  label: Text(purpose ?? '전체'),
                  selected: selected,
                  showCheckmark: true,
                  selectedColor: const Color(0xFF292522),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF292522),
                    fontWeight: FontWeight.w700,
                  ),
                  onSelected: (_) {
                    _purpose = purpose;
                    _reload();
                  },
                );
              },
            ),
          ),
        const SizedBox(height: 24),
        const Text(
          '대상별 신발',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        _filterChips(
          values: data.filters.genders,
          selected: _gender,
          allLabel: '전체 대상',
          onSelected: (value) {
            _gender = value;
            _reload();
          },
        ),
        const SizedBox(height: 24),
        const Text(
          '브랜드로 둘러보기',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        _filterChips(
          values: data.filters.brands,
          selected: _brand,
          allLabel: '전체 브랜드',
          onSelected: (value) {
            _brand = value;
            _reload();
          },
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Text(
              '등록 상품',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
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
        Text(
          '${data.products.length}개 표시 · 대상/브랜드 필터 적용',
          style: const TextStyle(color: Color(0xFF918981), fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (data.products.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: Text('선택한 조건에 맞는 상품이 없습니다.')),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: data.products.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 18,
              childAspectRatio: .60,
            ),
            itemBuilder: (context, index) => _ProductCard(
              product: data.products[index],
              api: _api,
              onTap: () => _openProduct(data.products[index]),
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
                    '수령 매장 찾기',
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
  );

  Widget _filterChips({
    required List<String> values,
    required String? selected,
    required String allLabel,
    required ValueChanged<String?> onSelected,
  }) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final value in <String?>[null, ...values])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(value ?? allLabel),
              selected: value == selected,
              onSelected: (_) => onSelected(value),
              selectedColor: const Color(0xFF272A2D),
              labelStyle: TextStyle(
                color: value == selected
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
  );

  Widget _buildNavigation() => FitpickTabBar(
    selectedIndex: 0,
    onSelected: (index) {
      switch (index) {
        case 1:
          Get.offAll(
            () => ProductListPage(initialBrand: _brand, initialGender: _gender),
          );
        case 2:
          _switchTab(() => const Cartpage(), requiresLogin: true);
        case 3:
          _switchTab(() => const Orderhistorypage(), requiresLogin: true);
        case 4:
          _switchTab(() => const MyPage(), requiresLogin: true);
      }
    },
  );

  /// 홈 콘텐츠 안의 탐색 링크는 일반 페이지 이동으로 유지한다.
  void _openProductList() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          ProductListPage(initialBrand: _brand, initialGender: _gender),
    ),
  );

  void _openProduct(DiscoverProduct product) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ProductDetailPage(productCode: product.code),
    ),
  );

  void _openStoreSelection() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const StoreSelectionPage()));

  void _switchTab(Widget Function() builder, {bool requiresLogin = false}) {
    final target = AuthController.to.isLoggedIn.value
        ? builder()
        : (requiresLogin ? const LoginPage() : builder());
    Get.offAll(() => target);
  }
}

class _HomeData {
  const _HomeData({
    required this.filters,
    required this.banners,
    required this.products,
  });

  final DiscoverFilters filters;
  final List<DiscoverBanner> banners;
  final List<DiscoverProduct> products;
}

class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel({required this.api, required this.banners});

  final DiscoverApi api;
  final List<DiscoverBanner> banners;

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final PageController _controller = PageController(viewportFraction: .94);
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 205,
        child: PageView.builder(
          controller: _controller,
          itemCount: widget.banners.length,
          onPageChanged: (index) => setState(() => _index = index),
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                color: const Color(0xFFE8E0D6),
                child: Image.network(
                  widget.api.bannerUrl(widget.banners[index]),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(Icons.broken_image_outlined, size: 52),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 9),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < widget.banners.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _index ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == _index
                    ? const Color(0xFF302B27)
                    : const Color(0xFFAFA79F),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
        ],
      ),
    ],
  );
}

class _EmptyBanner extends StatelessWidget {
  const _EmptyBanner();

  @override
  Widget build(BuildContext context) => Container(
    height: 180,
    decoration: BoxDecoration(
      color: const Color(0xFFF3F1EE),
      borderRadius: BorderRadius.circular(24),
    ),
    child: const Center(child: Text('등록된 배너가 없습니다.')),
  );
}

class _MissingPurposeNotice extends StatelessWidget {
  const _MissingPurposeNotice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F2ED),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Text(
      '현재 상품 DB에 용도 분류가 없어 용도별 상품을 구분할 수 없습니다. 분류 데이터가 등록되면 이곳에 표시됩니다.',
      style: TextStyle(fontSize: 12, color: Color(0xFF6E675F), height: 1.5),
    ),
  );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.api,
    required this.onTap,
  });

  final DiscoverProduct product;
  final DiscoverApi api;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F3F1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: _image(),
          ),
        ),
        const SizedBox(height: 9),
        Text(
          product.brand,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF766E66),
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          product.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        Text(
          '₩${product.price}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        Text(
          product.gender,
          style: const TextStyle(fontSize: 10, color: Color(0xFF918981)),
        ),
      ],
    ),
  );

  Widget _image() {
    final url = api.imageUrl(product);
    if (url == null) {
      return const Center(child: Icon(Icons.image_outlined, size: 42));
    }
    return Image.network(
      url,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          const Center(child: Icon(Icons.broken_image_outlined)),
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 42),
          const SizedBox(height: 12),
          Text('$error', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    ),
  );
}
