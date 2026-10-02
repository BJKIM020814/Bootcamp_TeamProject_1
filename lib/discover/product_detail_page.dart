import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:bootcamp_teamproject_1/user/authController.dart';
import 'package:bootcamp_teamproject_1/user/loginpage.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  String _color = '화이트 / 화이트';
  int _size = 275;
  String _detailTab = '상품 정보';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '상품 상세',
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
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 18),
        child: Row(
          children: [
            OutlinedButton(
              onPressed: () => ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('장바구니에 담았습니다.'))),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(54, 54),
                foregroundColor: const Color(0xFF26221F),
                side: const BorderSide(color: Color(0xFF26221F)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _buyNow,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: const Color(0xFF26221F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text('$_size mm 바로 구매'),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          // 목업의 단일 상품 사진과 페이지 표시 영역입니다.
          Container(
            height: 310,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F3F1),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.network(
                    'https://fitpick-o2o.higgsfield.app/assets/products/airforce.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Center(
                      child: Icon(Icons.image_outlined, size: 70),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  top: 16,
                  child: Text(
                    'PRODUCT PHOTO / NIKE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 14,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF26221F),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'NIKE  /  CW2288-111',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF777068),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "에어 포스 1 '07",
            style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            '₩119,000',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 9),
          const Text(
            '코트에서 시작해 일상의 클래식이 된 실루엣. 깔끔한 화이트 컬러와 가죽 갑피가 특징입니다.',
            style: TextStyle(
              color: Color(0xFF6E675F),
              height: 1.55,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            '색상 선택',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          // 색상 선택은 목업처럼 버튼의 선택 상태만 바꿉니다.
          Wrap(
            spacing: 8,
            children: [
              for (final item in const ['화이트 / 화이트', '블랙', '화이트'])
                ChoiceChip(
                  label: Text(item),
                  selected: _color == item,
                  onSelected: (_) => setState(() => _color = item),
                  selectedColor: const Color(0xFF26221F),
                  labelStyle: TextStyle(
                    color: _color == item
                        ? Colors.white
                        : const Color(0xFF3F3933),
                    fontWeight: FontWeight.w700,
                  ),
                  side: const BorderSide(color: Color(0xFFE1DDD8)),
                  backgroundColor: Colors.white,
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '사진은 대표 색상으로 고정됩니다. 색상별 재고·품절은 시연 데이터입니다.',
            style: TextStyle(fontSize: 11, color: Color(0xFF918981)),
          ),
          const SizedBox(height: 28),
          Text(
            '구매 사이즈  $_size mm 선택됨',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          // 목업의 230~280 mm 구매 사이즈 선택 그리드입니다.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final size in const [
                230,
                235,
                240,
                245,
                250,
                255,
                260,
                265,
                270,
                275,
                280,
              ])
                ChoiceChip(
                  label: SizedBox(
                    width: 40,
                    child: Center(child: Text('$size')),
                  ),
                  selected: _size == size,
                  onSelected: (_) => setState(() => _size = size),
                  selectedColor: const Color(0xFF26221F),
                  labelStyle: TextStyle(
                    color: _size == size
                        ? Colors.white
                        : const Color(0xFF3F3933),
                    fontWeight: FontWeight.w800,
                  ),
                  side: const BorderSide(color: Color(0xFFE1DDD8)),
                  backgroundColor: Colors.white,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '선택한 $_color · $_size mm로 바로 구매하고 수령 매장은 주문 화면에서 변경할 수 있어요.',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6E675F),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F3F1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.storefront_outlined),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '구매 전 직접 신어보고, 맞는 사이즈를 골라요.',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          // 상세 정보·구매 리뷰·교환 반품 탭을 전환합니다.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final tab in const ['상품 정보', '구매 리뷰', '교환 · 반품'])
                TextButton(
                  onPressed: () => setState(() => _detailTab = tab),
                  child: Text(
                    tab,
                    style: TextStyle(
                      color: _detailTab == tab
                          ? const Color(0xFF26221F)
                          : const Color(0xFF8B837A),
                      fontWeight: _detailTab == tab
                          ? FontWeight.w900
                          : FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 28),
          if (_detailTab == '상품 정보') ...[
            const Text(
              '오리지널을 확인하세요',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              '사진과 표시 가격은 연결된 상품 정보의 해당 모델·색상 기준입니다. 할인·거래가는 변동될 수 있습니다.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF6E675F),
                height: 1.5,
              ),
            ),
          ],
          if (_detailTab == '구매 리뷰') ...[
            const Text(
              '구매 리뷰',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            const Text(
              '사이즈 선택에 도움 되는 리뷰를 확인하세요.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6E675F)),
            ),
            const SizedBox(height: 14),
            Container(
              height: 185,
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F3F1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: BarChart(
                BarChartData(
                  maxY: 100,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const labels = ['작게', '정사이즈', '크게'];
                          return Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: Text(
                              labels[value.toInt()],
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                          toY: 12,
                          color: const Color(0xFFBEB8B1),
                          width: 30,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 1,
                      barRods: [
                        BarChartRodData(
                          toY: 76,
                          color: const Color(0xFF26221F),
                          width: 30,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 2,
                      barRods: [
                        BarChartRodData(
                          toY: 12,
                          color: const Color(0xFFBEB8B1),
                          width: 30,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E1DC)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 18),
                      SizedBox(width: 7),
                      Text(
                        '구매자 리뷰',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Spacer(),
                      Text(
                        '정사이즈',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6E675F),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 9),
                  Text(
                    '발볼이 넓은 편인데도 편하게 맞아요. 데일리로 신기 좋습니다.',
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '270 mm · 화이트 / 화이트',
                    style: TextStyle(fontSize: 11, color: Color(0xFF8B837A)),
                  ),
                ],
              ),
            ),
          ],
          if (_detailTab == '교환 · 반품')
            const Text(
              '상품 수령 후 7일 이내 교환·반품을 신청할 수 있습니다. 사용 흔적이 있는 상품은 교환·반품이 제한됩니다.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF6E675F),
                height: 1.6,
              ),
            ),
        ],
      ),
    );
  }

  // 로그인하지 않은 상태라면 로그인 화면으로 이동합니다.
  void _buyNow() {
    if (!AuthController.to.isLoggedIn.value) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const LoginPage()));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('주문 기능은 서버 연결 후 사용할 수 있습니다.')),
    );
  }
}
