import 'package:bootcamp_teamproject_1/discover/home_page.dart';
import 'package:bootcamp_teamproject_1/order/cartController.dart';
import 'package:bootcamp_teamproject_1/order/checkoutPage.dart';
import 'package:bootcamp_teamproject_1/order/storePickerStub.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 선택한 장바구니 목업을 보여 주고 결제 화면으로 이동한다.
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
    // 서버 장바구니가 아직 없으므로 최초 진입 때만 화면용 샘플을 채운다.
    cartController.seedSampleData();
  }

  String _formatWon(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      if (i > 0 && remaining % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return '₩$buffer';
  }

  Future<void> _goBrowseShoes() async {
    Get.to(() => const HomePage());
  }

  void _checkout() {
    if (cartController.selectedCount == 0) return;
    Get.to(() => const Checkoutpage());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('장바구니'), centerTitle: true),
      body: SafeArea(
        child: Obx(() {
          if (cartController.isEmpty) return _buildEmptyState(context);
          return _buildCartList(context);
        }),
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
                    cartController.toggleSelectAll(value ?? false),
              ),
              Text('전체 선택 (${items.length})'),
              const Spacer(),
              TextButton(
                onPressed: cartController.removeSelected,
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
              _buildStoreCard(),
              const SizedBox(height: 12),
              Text(
                '인터랙티브 목업 · 신규 상품은 실제 가격 참고, 기존 상품과 색상별 품번 · 본사 방침 · 주문은 시연 데이터입니다.',
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
            onChanged: (_) => cartController.toggleItem(item.id),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.image_outlined, color: Colors.grey),
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
                      onPressed: () => cartController.removeItem(item.id),
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
            onPressed: () => cartController.updateQuantity(item.id, -1),
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
            onPressed: () => cartController.updateQuantity(item.id, 1),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: Colors.grey),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Obx(
                      () => Text(
                        cartController.storeName.value,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Obx(
                      () => Text(
                        cartController.storeAddress.value,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => pickAndApplyStore(cartController),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '수령 매장 변경',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
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
