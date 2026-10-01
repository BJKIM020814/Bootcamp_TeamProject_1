import 'package:flutter/material.dart';

class StoreSelectionPage extends StatefulWidget {
  const StoreSelectionPage({super.key});

  @override
  State<StoreSelectionPage> createState() => _StoreSelectionPageState();
}

class _StoreSelectionPageState extends State<StoreSelectionPage> {
  bool _showMap = true;
  String _store = '강남 스토어';

  @override
  Widget build(BuildContext context) {
    const stores = [
      ('강남 스토어', '서울 강남구 강남역 인근 · 예시 위치'),
      ('신사 스토어', '서울 강남구 신사역 인근 · 예시 위치'),
      ('성수 스토어', '서울 성동구 성수역 인근 · 예시 위치'),
      ('홍대 스토어', '서울 마포구 홍대입구역 인근 · 예시 위치'),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '매장 찾기',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFFFFDF9),
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Badge(
              label: Text('1'),
              child: Icon(Icons.shopping_bag_outlined),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 18),
        child: FilledButton(
          onPressed: _confirmStore,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF26221F),
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text('$_store 선택'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        children: [
          // 목업의 매장·지역 검색 영역입니다.
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
                Text('매장 또는 지역 검색', style: TextStyle(color: Color(0xFF908880))),
              ],
            ),
          ),
          const SizedBox(height: 13),
          // 지도/목록 전환은 목업 화면 내에서 작동합니다.
          Row(
            children: [
              ChoiceChip(
                label: const Text('지도 보기'),
                selected: _showMap,
                onSelected: (_) => setState(() => _showMap = true),
                selectedColor: const Color(0xFF26221F),
                labelStyle: TextStyle(
                  color: _showMap ? Colors.white : const Color(0xFF3F3933),
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('목록 보기'),
                selected: !_showMap,
                onSelected: (_) => setState(() => _showMap = false),
                selectedColor: const Color(0xFF26221F),
                labelStyle: TextStyle(
                  color: !_showMap ? Colors.white : const Color(0xFF3F3933),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => setState(() => _store = '강남 스토어'),
            icon: const Icon(Icons.my_location_rounded, size: 18),
            label: const Text('현 위치에서 가까운 매장 추천'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF26221F),
              side: const BorderSide(color: Color(0xFFDCD7D1)),
              alignment: Alignment.centerLeft,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '위치는 거리 계산에만 사용하며 저장하지 않습니다.',
            style: TextStyle(fontSize: 11, color: Color(0xFF908880)),
          ),
          const SizedBox(height: 18),
          if (_showMap)
            Container(
              height: 225,
              decoration: BoxDecoration(
                color: const Color(0xFFE8ECE5),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Text(
                      'Naver Map API 연결 영역',
                      style: TextStyle(
                        color: Color(0xFF6E675F),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final pin in const [
                    (70.0, 55.0, '1'),
                    (200.0, 82.0, '2'),
                    (122.0, 155.0, '3'),
                    (260.0, 145.0, '4'),
                  ])
                    Positioned(
                      left: pin.$1,
                      top: pin.$2,
                      child: InkWell(
                        onTap: () => setState(
                          () => _store = stores[int.parse(pin.$3) - 1].$1,
                        ),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              _store == stores[int.parse(pin.$3) - 1].$1
                              ? const Color(0xFF26221F)
                              : Colors.white,
                          child: Text(
                            pin.$3,
                            style: TextStyle(
                              color: _store == stores[int.parse(pin.$3) - 1].$1
                                  ? Colors.white
                                  : const Color(0xFF26221F),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            '지도 핀으로 매장을 선택하거나, 빈 곳을 눌러 거리 기준점을 정하세요. 4개 매장 서울 지역',
            style: TextStyle(fontSize: 11, color: Color(0xFF777068)),
          ),
          const SizedBox(height: 14),
          // 목업의 수령 매장 카드 목록입니다.
          for (final store in stores)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => setState(() => _store = store.$1),
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: _store == store.$1
                        ? const Color(0xFFF0ECE5)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: _store == store.$1
                          ? const Color(0xFF26221F)
                          : const Color(0xFFE5E1DC),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _store == store.$1
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: const Color(0xFF26221F),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              store.$1,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              store.$2,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6E675F),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Wrap(
                              spacing: 6,
                              children: [
                                Chip(
                                  label: Text('매장 수령'),
                                  visualDensity: VisualDensity.compact,
                                ),
                                Chip(
                                  label: Text('본사 발송 후 픽업'),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 4),
          const Text(
            '매장에는 판매 재고를 보관하지 않습니다. 본사에서 상품을 발송하고 도착·검수 후 픽업을 안내합니다.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6E675F),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // 선택한 수령 매장을 확정하고 이전 주문 단계로 돌아갑니다.
  void _confirmStore() => Navigator.of(context).pop();
}
