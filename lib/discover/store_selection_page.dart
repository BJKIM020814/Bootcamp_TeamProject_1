import 'package:bootcamp_teamproject_1/discover/discover_api.dart';
import 'package:flutter/material.dart';

/// 본사 발송 상품의 픽업 지점만 조회한다. 대리점 재고·판매 가능 여부는 판단하지 않는다.
class StoreSelectionPage extends StatefulWidget {
  const StoreSelectionPage({
    super.key,
    this.productCode,
    this.color,
    this.size,
  });
  final String? productCode;
  final String? color;
  final int? size;
  @override
  State<StoreSelectionPage> createState() => _StoreSelectionPageState();
}

class _StoreSelectionPageState extends State<StoreSelectionPage> {
  final _api = DiscoverApi();
  final _search = TextEditingController();
  late Future<List<PickupStore>> _stores;
  PickupStore? _selected;
  @override
  void initState() {
    super.initState();
    _stores = _api.pickupStores();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() =>
      setState(() => _stores = _api.pickupStores(keyword: _search.text));
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('매장 찾기', style: TextStyle(fontWeight: FontWeight.w900)),
      centerTitle: true,
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.all(20),
      child: FilledButton(
        onPressed: _selected == null
            ? null
            : () => Navigator.of(context).pop(_selected),
        child: Text(
          _selected == null ? '수령 매장을 선택하세요' : '${_selected!.name} 선택',
        ),
      ),
    ),
    body: FutureBuilder<List<PickupStore>>(
      future: _stores,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snap.hasError)
          return Center(
            child: OutlinedButton(
              onPressed: _reload,
              child: const Text('매장 목록 다시 시도'),
            ),
          );
        final stores = snap.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: [
            TextField(
              controller: _search,
              onSubmitted: (_) => _reload(),
              decoration: InputDecoration(
                hintText: '매장 또는 지역 검색',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: const Color(0xFFF3F1EE),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '매장은 본사 발송 상품의 수령 지점입니다. 판매 재고로 구매 가능 여부를 판단하지 않습니다.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF6E675F),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            if (stores.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 50),
                child: Center(child: Text('등록된 수령 매장이 없습니다.')),
              )
            else
              for (final store in stores)
                Card(
                  child: RadioListTile<int>(
                    value: store.id,
                    groupValue: _selected?.id,
                    onChanged: (_) => setState(() => _selected = store),
                    title: Text(
                      store.name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text('${store.address}\n담당자: ${store.manager}'),
                  ),
                ),
          ],
        );
      },
    ),
  );
}
