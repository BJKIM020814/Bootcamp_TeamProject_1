import 'package:bootcamp_teamproject_1/discover/discover_api.dart';
import 'package:bootcamp_teamproject_1/discover/product_detail_page.dart';
import 'package:flutter/material.dart';

/// 목업의 상품 찾기 화면. 필터 값과 상품 카드는 API의 MySQL 응답만 표시한다.
class ProductListPage extends StatefulWidget {
  const ProductListPage({
    super.key,
    this.initialKeyword,
    this.initialBrand,
    this.initialGender,
  });
  final String? initialKeyword;
  final String? initialBrand;
  final String? initialGender;
  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final _api = DiscoverApi();
  late final _search = TextEditingController(text: widget.initialKeyword ?? '');
  String? _brand;
  String? _gender;
  late Future<_CatalogData> _catalog;

  @override
  void initState() {
    super.initState();
    _brand = widget.initialBrand;
    _gender = widget.initialGender;
    _catalog = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<_CatalogData> _load() async => _CatalogData(
    await _api.filters(),
    await _api.products(keyword: _search.text, brand: _brand, gender: _gender),
  );
  void _reload() {
    final nextCatalog = _load();
    setState(() {
      _catalog = nextCatalog;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('상품 목록', style: TextStyle(fontWeight: FontWeight.w900)),
      centerTitle: true,
    ),
    body: FutureBuilder<_CatalogData>(
      future: _catalog,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _ErrorState(error: snap.error, onRetry: _reload);
        }
        return _body(snap.data!);
      },
    ),
  );

  Widget _body(_CatalogData data) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
    children: [
      TextField(
        controller: _search,
        onSubmitted: (_) => _reload(),
        decoration: InputDecoration(
          hintText: '상품명 또는 브랜드',
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: const Color(0xFFF3F1EE),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      const SizedBox(height: 20),
      _FilterRow('대상', data.filters.genders, _gender, (value) {
        _gender = value;
        _reload();
      }),
      const SizedBox(height: 16),
      _FilterRow('브랜드', data.filters.brands, _brand, (value) {
        _brand = value;
        _reload();
      }),
      if (data.filters.purposes.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Text(
            '용도 분류는 현재 DB에 등록된 필드가 없어 제공되지 않습니다.',
            style: TextStyle(fontSize: 12, color: Color(0xFF777068)),
          ),
        ),
      const SizedBox(height: 24),
      Text(
        '총 ${data.products.length}개의 상품',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 14),
      if (data.products.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Center(child: Text('조건에 맞는 등록 상품이 없습니다.')),
        )
      else
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: data.products.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 22,
            childAspectRatio: .63,
          ),
          itemBuilder: (_, i) =>
              _CatalogCard(data.products[i], _api, _openProduct),
        ),
    ],
  );
  void _openProduct(DiscoverProduct product) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ProductDetailPage(productCode: product.code),
    ),
  );
}

class _CatalogData {
  const _CatalogData(this.filters, this.products);
  final DiscoverFilters filters;
  final List<DiscoverProduct> products;
}

class _FilterRow extends StatelessWidget {
  const _FilterRow(this.title, this.values, this.selected, this.onChanged);
  final String title;
  final List<String> values;
  final String? selected;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      const SizedBox(height: 9),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: const Text('전체'),
            selected: selected == null,
            onSelected: (_) => onChanged(null),
          ),
          for (final value in values)
            ChoiceChip(
              label: Text(value),
              selected: selected == value,
              onSelected: (_) => onChanged(value),
            ),
        ],
      ),
    ],
  );
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard(this.product, this.api, this.onTap);
  final DiscoverProduct product;
  final DiscoverApi api;
  final ValueChanged<DiscoverProduct> onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => onTap(product),
    borderRadius: BorderRadius.circular(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _image()),
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
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F3F1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: url == null
          ? const Center(child: Icon(Icons.image_outlined, size: 44))
          : Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Center(child: Icon(Icons.broken_image_outlined)),
            ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
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
          Text(error.toString(), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    ),
  );
}
