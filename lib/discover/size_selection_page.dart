import 'package:bootcamp_teamproject_1/discover/discover_api.dart';
import 'package:bootcamp_teamproject_1/common/fitpick_snackbar.dart';
import 'package:bootcamp_teamproject_1/order/cartController.dart';
import 'package:bootcamp_teamproject_1/order/cartPage.dart';
import 'package:bootcamp_teamproject_1/user/authController.dart';
import 'package:bootcamp_teamproject_1/user/loginpage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 상세에서 선택한 실제 상품 코드·색상·사이즈를 장바구니에 전달합니다.
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
            onPressed: () => _addToCart(context),
            child: const SizedBox(
              width: double.infinity,
              child: Center(child: Text('장바구니 담기')),
            ),
          ),
        ],
      ),
    ),
  );

  /// 상품을 장바구니에 담는다. 픽업 지점은 주문 후 관리자가 배정한다.
  Future<void> _addToCart(BuildContext context) async {
    if (!AuthController.to.isLoggedIn.value) {
      await Get.to(() => const LoginPage());
      return;
    }
    if (!context.mounted) return;
    final cart = CartController.to;
    if (!await cart.addProduct(product.code)) {
      if (context.mounted) {
        showFitpickSnackbar(
          cart.errorMessage.value ?? '상품을 장바구니에 담지 못했습니다.',
          title: '오류',
        );
      }
      return;
    }
    if (context.mounted) Get.to(() => const Cartpage());
  }
}
