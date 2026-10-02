import 'package:bootcamp_teamproject_1/discover/discover_api.dart';
import 'package:bootcamp_teamproject_1/discover/size_selection_page.dart';
import 'package:flutter/material.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.productCode});
  final String productCode;
  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final _api = DiscoverApi();
  late Future<DiscoverProduct> _future;
  String? _color;
  int? _size;
  @override
  void initState() {
    super.initState();
    _future = _api.product(widget.productCode);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('상품 상세', style: TextStyle(fontWeight: FontWeight.w900)),
    ),
    body: FutureBuilder<DiscoverProduct>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(
            child: OutlinedButton(
              onPressed: () =>
                  setState(() => _future = _api.product(widget.productCode)),
              child: const Text('상품 다시 불러오기'),
            ),
          );
        return _content(snapshot.data!);
      },
    ),
  );

  Widget _content(DiscoverProduct product) {
    _color ??= product.colors.isNotEmpty ? product.colors.first : product.color;
    _size ??= product.sizes.isNotEmpty ? product.sizes.first : product.size;
    final image = _api.imageUrl(product);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SizedBox(
          height: 300,
          child: image == null
              ? const Center(child: Icon(Icons.image_outlined, size: 64))
              : Image.network(
                  image,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined, size: 64),
                ),
        ),
        Text(product.brand, style: const TextStyle(color: Color(0xFF777068))),
        Text(
          product.name,
          style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
        ),
        Text(
          '₩${product.price}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 24),
        const Text('색상 선택', style: TextStyle(fontWeight: FontWeight.w900)),
        _options(
          product.colors,
          _color,
          (value) => setState(() => _color = value),
          product.optionNotice,
        ),
        const SizedBox(height: 20),
        const Text('구매 사이즈', style: TextStyle(fontWeight: FontWeight.w900)),
        _sizeOptions(product.sizes, product.optionNotice),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: (_color == null && _size == null)
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SizeSelectionPage(
                      product: product,
                      selectedColor: _color,
                      selectedSize: _size,
                    ),
                  ),
                ),
          child: const Text('수령 매장 선택'),
        ),
        const SizedBox(height: 18),
        const Text('구매 리뷰', style: TextStyle(fontWeight: FontWeight.w900)),
        const Text(
          '리뷰는 등록된 구매 데이터만 표시됩니다. 현재 DB에는 리뷰가 없습니다.',
          style: TextStyle(fontSize: 12, color: Color(0xFF6E675F)),
        ),
      ],
    );
  }

  Widget _options(
    List<String> values,
    String? selected,
    ValueChanged<String> select,
    String? notice,
  ) {
    if (values.isEmpty)
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(notice ?? '등록된 옵션이 없습니다.'),
      );
    return Wrap(
      spacing: 8,
      children: [
        for (final value in values)
          ChoiceChip(
            label: Text(value),
            selected: selected == value,
            onSelected: (_) => select(value),
          ),
      ],
    );
  }

  Widget _sizeOptions(List<int> values, String? notice) {
    if (values.isEmpty)
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(notice ?? '등록된 옵션이 없습니다.'),
      );
    return Wrap(
      spacing: 8,
      children: [
        for (final value in values)
          ChoiceChip(
            label: Text('$value mm'),
            selected: _size == value,
            onSelected: (_) => setState(() => _size = value),
          ),
      ],
    );
  }
}
