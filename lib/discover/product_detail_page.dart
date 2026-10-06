import 'package:bootcamp_teamproject_1/discover/discover_api.dart';
import 'package:bootcamp_teamproject_1/discover/size_selection_page.dart';
import 'package:flutter/material.dart';
import 'package:bootcamp_teamproject_1/services/mypage_api.dart';
import 'package:bootcamp_teamproject_1/user/authController.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.productCode});
  final String productCode;
  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final _api = DiscoverApi();
  late Future<DiscoverProduct> _future;
  Future<List<Map<String, dynamic>>>? _reviews;
  String? _historyError;
  String? _color;
  int? _size;
  @override
  void initState() {
    super.initState();
    _future = _api.product(widget.productCode);
    _recordView();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _recordView() async {
    final email = AuthController.to.customerId.value;
    if (email == null) return;
    try {
      await MyPageApi.recordView(email, widget.productCode);
    } catch (_) {
      if (mounted) setState(() => _historyError = '최근 본 상품 기록을 저장하지 못했습니다.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('상품 상세', style: TextStyle(fontWeight: FontWeight.w900)),
    ),
    body: FutureBuilder<DiscoverProduct>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: OutlinedButton(
              onPressed: () =>
                  setState(() => _future = _api.product(widget.productCode)),
              child: const Text('상품 다시 불러오기'),
            ),
          );
        }
        return _content(snapshot.data!);
      },
    ),
  );

  Widget _content(DiscoverProduct product) {
    // 리뷰를 표시할 때 요청해 오류가 FutureBuilder 밖으로 누락되지 않게 한다.
    _reviews ??= _api.reviews(widget.productCode);
    _color ??= product.color;
    _size ??= product.size;
    final variants = product.variants.isEmpty ? [product] : product.variants;
    final sizes =
        variants
            .where((v) => v.color == _color && v.size != null)
            .map((v) => v.size!)
            .toSet()
            .toList()
          ..sort();
    if (!sizes.contains(_size)) _size = sizes.isEmpty ? null : sizes.first;
    final matches = variants
        .where((v) => v.color == _color && v.size == _size)
        .toList();
    final selected = matches.length == 1 ? matches.single : null;
    final image = _api.imageUrl(selected ?? product);
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
          '₩${(selected ?? product).price}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 24),
        const Text('색상 선택', style: TextStyle(fontWeight: FontWeight.w900)),
        _options(
          product.colors,
          _color,
          (value) => setState(() {
            _color = value;
            _size = null;
          }),
          product.optionNotice,
        ),
        const SizedBox(height: 20),
        const Text('구매 사이즈', style: TextStyle(fontWeight: FontWeight.w900)),
        _sizeOptions(sizes, product.optionNotice),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: selected == null || _color == null || _size == null
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SizeSelectionPage(
                      product: selected,
                      selectedColor: _color,
                      selectedSize: _size,
                    ),
                  ),
                ),
          child: const Text('수령 매장 선택'),
        ),
        const SizedBox(height: 18),
        const Text('구매 리뷰', style: TextStyle(fontWeight: FontWeight.w900)),
        if (_historyError != null) Text(_historyError!),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _reviews,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator();
            }
            if (snapshot.hasError) {
              return TextButton(
                onPressed: () =>
                    setState(() => _reviews = _api.reviews(widget.productCode)),
                child: const Text('리뷰 다시 불러오기'),
              );
            }
            final reviews = snapshot.data ?? [];
            if (reviews.isEmpty) return const Text('등록된 구매 리뷰가 없습니다.');
            return Column(
              children: [
                for (final review in reviews)
                  ListTile(
                    title: Text('${review['content']}'),
                    subtitle: Text('평점 ${review['rating']} · ${review['fit']}'),
                  ),
              ],
            );
          },
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
    if (values.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(notice ?? '등록된 옵션이 없습니다.'),
      );
    }
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
    if (values.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(notice ?? '등록된 옵션이 없습니다.'),
      );
    }
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
