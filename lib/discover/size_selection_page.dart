import 'package:bootcamp_teamproject_1/discover/discover_api.dart';
import 'package:bootcamp_teamproject_1/common/fitpick_snackbar.dart';
import 'package:bootcamp_teamproject_1/discover/store_selection_page.dart';
import 'package:bootcamp_teamproject_1/order/cartController.dart';
import 'package:bootcamp_teamproject_1/order/cartPage.dart';
import 'package:bootcamp_teamproject_1/user/authController.dart';
import 'package:bootcamp_teamproject_1/user/loginpage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
            onPressed: () => _selectStoreAndAddToCart(context),
            child: const SizedBox(
              width: double.infinity,
              child: Center(child: Text('수령 매장 선택')),
            ),
          ),
        ],
      ),
    ),
  );

  /// 선택한 옵션 코드로 장바구니에 담고, 서버에 수령 매장을 함께 지정한다.
  Future<void> _selectStoreAndAddToCart(BuildContext context) async {
    if (!AuthController.to.isLoggedIn.value) {
      await Get.to(() => const LoginPage());
      return;
    }
    final store = await Navigator.of(context).push<PickupStore>(
      MaterialPageRoute(
        builder: (_) => StoreSelectionPage(
          productCode: product.code,
          color: selectedColor,
          size: selectedSize,
        ),
      ),
    );
    if (store == null || !context.mounted) return;

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
    if (!await cart.updateStore(store.id)) {
      if (context.mounted) {
        showFitpickSnackbar(
          cart.errorMessage.value ??
              '상품은 담았지만 수령 매장을 지정하지 못했습니다. 장바구니에서 매장을 다시 선택해 주세요.',
          title: '오류',
        );
      }
      return;
    }
    if (context.mounted) Get.to(() => const Cartpage());
  }
}
