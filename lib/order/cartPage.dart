import 'package:bootcamp_teamproject_1/discover/home_page.dart';
import 'package:bootcamp_teamproject_1/discover/product_detail_page.dart';
import 'package:bootcamp_teamproject_1/common/fitpick_snackbar.dart';
import 'package:bootcamp_teamproject_1/common/fitpick_tab_bar.dart';
import 'package:bootcamp_teamproject_1/order/cartController.dart';
import 'package:bootcamp_teamproject_1/order/checkoutPage.dart';
import 'package:bootcamp_teamproject_1/order/orderApi.dart';
import 'package:bootcamp_teamproject_1/order/orderHistoryPage.dart';
import 'package:bootcamp_teamproject_1/discover/product_list_page.dart';
import 'package:bootcamp_teamproject_1/user/authController.dart';
import 'package:bootcamp_teamproject_1/user/loginpage.dart';
import 'package:bootcamp_teamproject_1/user/mypage/my_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Cartpage extends StatefulWidget {
  const Cartpage({super.key});

  @override
  State<Cartpage> createState() => _CartpageState();
}

class _CartpageState extends State<Cartpage> {
  final CartController cartController = CartController.to;

  @override
  void initState() {
    super.initState();
    // 다른 화면에서 라우트가 교체/추가되는 빌드 도중 Rx 값을 바꾸지 않는다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) cartController.load();
    });
  }

  String _formatWon(int value) => formatWon(value);

  /// 서버 요청 결과가 실패면 이유를 스낵바로 보여준다.
  Future<void> _act(Future<bool> request) async {
    if (await request || !mounted) return;
    showFitpickSnackbar(
      cartController.errorMessage.value ?? '요청을 처리하지 못했습니다.',
      title: '오류',
    );
  }

  Future<void> _goBrowseShoes() async {
    Get.to(() => const HomePage());
  }

  Future<void> _checkout() async {
    if (cartController.selectedCount == 0) return;
    await Get.to(() => const Checkoutpage());
    cartController.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('장바구니'), centerTitle: true),
      body: SafeArea(
        child: Obx(() {
          final error = cartController.errorMessage.value;
          if (cartController.isEmpty && cartController.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          if (cartController.isEmpty && error != null) {
            return _buildErrorState(error);
          }
          if (cartController.isEmpty) return _buildEmptyState(context);
          return _buildCartList(context);
        }),
      ),
      bottomNavigationBar: FitpickTabBar(
        selectedIndex: 2,
        onSelected: _selectAppTab,
      ),
    );
  }

  void _selectAppTab(int index) {
    if (index == 2) return;
    final authenticated = AuthController.to.isLoggedIn.value;
    switch (index) {
      case 0:
        Get.offAll(() => const HomePage());
      case 1:
        Get.offAll(() => const ProductListPage());
      case 3:
        Get.offAll(
          () => authenticated ? const Orderhistorypage() : const LoginPage(),
        );
      case 4:
        Get.offAll(() => authenticated ? const MyPage() : const LoginPage());
    }
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: cartController.load,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 100),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shopping_bag_outlined, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          const Text(
            '장바구니가 비어 있어요',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '마음에 드는 신발을 담고 매장에서 신어보세요.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _goBrowseShoes,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                '신발 둘러보기',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartList(BuildContext context) {
    final items = cartController.items;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Checkbox(
                value: cartController.isAllSelected,
                onChanged: (value) =>
                    _act(cartController.toggleSelectAll(value ?? false)),
              ),
              Text('전체 선택 (${items.length})'),
              const Spacer(),
              TextButton(
                onPressed: () => _act(cartController.removeSelected()),
                child: const Text(
                  '선택 삭제',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final item in items) ...[
                _buildCartItemTile(item),
                const Divider(height: 24),
              ],
              Text(
                '체크아웃에서 수령 대리점을 선택할 수 있습니다. 주문 완료 후에는 변경할 수 없습니다. 결제는 모의 결제입니다.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildCartItemTile(CartItem item) {
    return Obx(
      () => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: item.selected.value,
            onChanged: (_) => _act(cartController.toggleItem(item.id)),
          ),
          Container(
            width: 64,
            height: 64,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: item.imageUrl == null
                ? const Icon(Icons.image_outlined, color: Colors.grey)
                : Image.network(
                    item.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.image_outlined, color: Colors.grey),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.brand,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _act(cartController.removeItem(item.id)),
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.colorLabel,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      _formatWon(item.price),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Obx(
                      () => Text(
                        '수량 ${item.quantity.value}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '구매 사이즈 ${item.size}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const Spacer(),
                    _buildQuantityStepper(item),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      await Get.to(
                        () => ProductDetailPage(
                          productCode: item.productCode,
                          cartItemId: item.id,
                        ),
                      );
                    },
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text('색상·사이즈 변경'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityStepper(CartItem item) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            iconSize: 16,
            onPressed: () => _act(cartController.updateQuantity(item.id, -1)),
            icon: const Icon(Icons.remove),
          ),
          Obx(
            () => Text(
              '${item.quantity.value}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            iconSize: 16,
            onPressed: () => _act(cartController.updateQuantity(item.id, 1)),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Obx(
                () => Text(
                  '선택 ${cartController.selectedCount}개 상품',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ),
              const Spacer(),
              Obx(
                () => Text(
                  _formatWon(cartController.selectedTotal),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Obx(
            () => SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: cartController.selectedCount == 0 ? null : _checkout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  '주문하기',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
