import 'package:bootcamp_teamproject_1/discover/discover_api.dart';
import 'package:bootcamp_teamproject_1/discover/store_selection_page.dart';
import 'package:flutter/material.dart';

/// 상세에서 선택한 상품 코드·색상·사이즈를 수령 매장 화면까지 유지합니다.
class SizeSelectionPage extends StatelessWidget {
  const SizeSelectionPage({
    super.key,
    required this.product,
    this.selectedColor,
    this.selectedSize,
  });
  final DiscoverProduct product;
  final String? selectedColor;
  final int? selectedSize;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        '사이즈 선택',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
    ),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(product.brand, style: const TextStyle(color: Color(0xFF777068))),
          Text(
            product.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          Text('상품 코드: ${product.code}'),
          Text('선택 색상: ${selectedColor ?? '등록 없음'}'),
          Text(
            '선택 사이즈: ${selectedSize == null ? '등록 없음' : '$selectedSize mm'}',
          ),
          const Spacer(),
          FilledButton(
            // 매장 선택 화면은 값을 반환하지만 현재 이 페이지가 받아 저장하지는 않는다.
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StoreSelectionPage(
                  productCode: product.code,
                  color: selectedColor,
                  size: selectedSize,
                ),
              ),
            ),
            child: const SizedBox(
              width: double.infinity,
              child: Center(child: Text('수령 매장 선택')),
            ),
          ),
        ],
      ),
    ),
  );
}
