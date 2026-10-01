import 'package:bootcamp_teamproject_1/discover/product_detail_page.dart';
import 'package:bootcamp_teamproject_1/user/authController.dart';
import 'package:flutter/material.dart';

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
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
        '공용',
        '데일리',
        'https://fitpick-o2o.higgsfield.app/assets/products/nb530.jpg',
      ),
      (
        'NIKE',
        "에어 포스 1 '07",
        '₩119,000',
        '공용',
        '데일리',
        'https://fitpick-o2o.higgsfield.app/assets/products/airforce.png',
      ),
      (
        'ADIDAS',
        '삼바 OG',
        '₩139,000',
        '공용',
        '클래식',
        'https://fitpick-o2o.higgsfield.app/assets/products/samba.jpg',
      ),
      (
        'NIKE',
        '페가수스 41',
        '₩159,000',
        '공용',
        '러닝화',
        'https://fitpick-o2o.higgsfield.app/assets/products/pegasus41.jpg',
      ),
      (
        'PUMA',
        '스웨이드 클래식',
        '₩99,000',
        '공용',
        '클래식',
        'https://fitpick-o2o.higgsfield.app/assets/products/puma-suede.jpg',
      ),
      (
        'ASICS',
        '노바블라스트 6',
        '₩179,000',
        '공용',
        '러닝화',
        'https://fitpick-o2o.higgsfield.app/assets/products/novablast6.webp',
      ),
    ];
    final filteredProducts = products.where((product) {
      final matchesAudience =
          _audience == '전체' || product.$4 == _audience.replaceAll('남성·', '');
      final matchesBrand = _brand == '전체' || product.$1 == _brand;
      final matchesPurpose = _purpose == '전체' || product.$5 == _purpose;
      return matchesAudience && matchesBrand && matchesPurpose;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '상품 목록',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFFFFDF9),
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('장바구니 기능은 서버 연결 후 사용할 수 있습니다.')),
            ),
            icon: const CartBadgeIcon(),
            tooltip: '장바구니 보기',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        children: [
          // 참고 목업의 상품명 또는 브랜드 검색 입력 영역입니다.
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F1EE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.search_rounded),
                SizedBox(width: 9),
                Text('상품명 또는 브랜드', style: TextStyle(color: Color(0xFF908880))),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text('대상', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in const ['전체', '남성·공용', '여성용', '아동용'])
                ChoiceChip(
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
            ],
          ),
          const SizedBox(height: 20),
          const Text('브랜드', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in const [
                '전체',
                'NIKE',
                'ADIDAS',
                'NEW BALANCE',
                'ASICS',
                'VANS',
                'SALOMON',
                'PUMA',
              ])
                FilterChip(
                  label: Text(item == 'NEW BALANCE' ? '뉴발란스' : item),
                  selected: _brand == item,
                  onSelected: (_) => setState(() => _brand = item),
                  selectedColor: const Color(0xFFE9E4DE),
                  checkmarkColor: const Color(0xFF272A2D),
                  side: const BorderSide(color: Color(0xFFE4E0DB)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('용도', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in const ['전체', '러닝화', '데일리', '클래식', '아웃도어'])
                FilterChip(
                  label: Text(item),
                  selected: _purpose == item,
                  onSelected: (_) => setState(() => _purpose = item),
                  selectedColor: const Color(0xFFE9E4DE),
                  checkmarkColor: const Color(0xFF272A2D),
                  side: const BorderSide(color: Color(0xFFE4E0DB)),
                ),
            ],
          ),
          const SizedBox(height: 24),
          // 필터 적용 결과와 목업의 정렬 버튼을 표시합니다.
          Row(
            children: [
              Text(
                '총 ${filteredProducts.length}개의 상품',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.swap_vert_rounded, size: 17),
                label: const Text('추천순'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredProducts.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 22,
              childAspectRatio: .59,
            ),
            itemBuilder: (context, index) => _CatalogCard(
              product: filteredProducts[index],
              onTap: _openProductDetail,
            ),
          ),
        ],
      ),
    );
  }

  // 상품 카드 선택 시 상품 상세 화면으로 이동합니다.
  void _openProductDetail() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const ProductDetailPage()));
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({required this.product, required this.onTap});

  final (String, String, String, String, String, String) product;
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
                      product.$6,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.image_outlined),
                    ),
                  ),
                  const Positioned(
                    top: 9,
                    right: 9,
                    child: Icon(
                      Icons.favorite_border_rounded,
                      color: Color(0xFF706962),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            product.$1,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF766E66),
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            product.$2,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            product.$3,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          Text(
            '${product.$4} · ${product.$5} · 예시 가격',
            style: const TextStyle(fontSize: 10, color: Color(0xFF918981)),
          ),
        ],
      ),
    );
  }
}
