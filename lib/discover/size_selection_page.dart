import 'package:bootcamp_teamproject_1/discover/store_selection_page.dart';
import 'package:bootcamp_teamproject_1/user/authController.dart';
import 'package:flutter/material.dart';

class SizeSelectionPage extends StatefulWidget {
  const SizeSelectionPage({super.key});

  @override
  State<SizeSelectionPage> createState() => _SizeSelectionPageState();
}

class _SizeSelectionPageState extends State<SizeSelectionPage> {
  String _color = '화이트 / 화이트';
  int _size = 275;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '사이즈 선택',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFFFFDF9),
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const CartBadgeIcon(),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 18),
        child: FilledButton(
          onPressed: _openStoreSelection,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF26221F),
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text('수령 매장 선택'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          // 목업의 선택 상품 요약입니다.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F3F1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 66,
                  height: 66,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.network(
                    'https://fitpick-o2o.higgsfield.app/assets/products/airforce.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(Icons.image_outlined),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    "NIKE 에어 포스 1 '07\n$_color  ·  $_size mm\n₩119,000",
                    style: const TextStyle(
                      height: 1.55,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 27),
          const Text(
            '색상',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 11),
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
          const SizedBox(height: 28),
          const Text(
            '구매 사이즈',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            '평소 신는 사이즈  270 mm · 상품별 착화감은 리뷰를 참고하세요.',
            style: TextStyle(fontSize: 12, color: Color(0xFF777068)),
          ),
          const SizedBox(height: 14),
          // 목업의 구매 사이즈 선택 버튼입니다.
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
          const SizedBox(height: 22),
          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            backgroundColor: const Color(0xFFF4F3F1),
            collapsedBackgroundColor: const Color(0xFFF4F3F1),
            title: const Text(
              '사이즈 선택 가이드',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            children: const [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  '발볼이 넓거나 두꺼운 양말을 신는다면 반 사이즈 크게 선택해 보세요.',
                  style: TextStyle(color: Color(0xFF6E675F), height: 1.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          const Text(
            '내 발 사이즈 270 mm의 선택',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F3F1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '같은 평소 사이즈  리뷰 1건 / 이 모델 전체 15건',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6E675F)),
                ),
                SizedBox(height: 12),
                Text('270 mm', style: TextStyle(fontWeight: FontWeight.w900)),
                SizedBox(height: 7),
                LinearProgressIndicator(
                  value: 1,
                  color: Color(0xFF26221F),
                  backgroundColor: Colors.white,
                ),
                SizedBox(height: 6),
                Text('100% (1명)', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Text(
            '선택한 사이즈 $_size mm 상품은 본사에서 수령 매장으로 발송합니다. 발송 시작 전까지 사이즈와 매장을 변경할 수 있어요.',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6E675F),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // 목업의 다음 단계인 수령 매장 선택 화면으로 이동합니다.
  void _openStoreSelection() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const StoreSelectionPage()));
}
