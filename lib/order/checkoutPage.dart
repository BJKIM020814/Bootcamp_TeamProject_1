import 'package:bootcamp_teamproject_1/order/cartController.dart';
import 'package:bootcamp_teamproject_1/common/fitpick_snackbar.dart';
import 'package:bootcamp_teamproject_1/order/cartPage.dart';
import 'package:bootcamp_teamproject_1/order/orderApi.dart';
import 'package:bootcamp_teamproject_1/order/orderCompletePage.dart';
import 'package:bootcamp_teamproject_1/order/storePickerStub.dart';
import 'package:bootcamp_teamproject_1/services/fitpick_api_service.dart';
import 'package:bootcamp_teamproject_1/user/authController.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Checkoutpage extends StatefulWidget {
  const Checkoutpage({super.key});

  @override
  State<Checkoutpage> createState() => _CheckoutpageState();
}

class _CheckoutpageState extends State<Checkoutpage> {
  final CartController cartController = CartController.to;

  // 주문자 정보: Firebase account(이름/전화번호)에서 불러오고, "수정"으로 이번 주문에만 바꿀 수 있다.
  String _ordererName = '';
  String _ordererPhone = '';

  /// 서버(/api/v1/order/checkout)가 내려준 결제수단·쿠폰. null 이면 불러오는 중.
  CheckoutData? _checkout;
  String? _loadError;
  bool _paying = false;

  int _paymentMethodIndex = 0;
  List<String> get _paymentMethods =>
      _checkout?.paymentMethods ?? const ['신용 / 체크카드'];

  /// 0 = 쿠폰 사용 안 함, 1.. = 서버 쿠폰 목록
  int _selectedCouponIndex = 0;
  List<CheckoutCoupon> get _coupons => _checkout?.coupons ?? const [];
  CheckoutCoupon? get _selectedCoupon =>
      _selectedCouponIndex == 0 ? null : _coupons[_selectedCouponIndex - 1];

  /// 서버 쿠폰 할인액은 주문 상품 금액 기준이다. 현재 금액을 넘지 않게만 맞춘다.
  int _discountOf(int subtotal) {
    final coupon = _selectedCoupon;
    if (coupon == null) return 0;
    return coupon.discountAmount > subtotal ? subtotal : coupon.discountAmount;
  }

  bool _agreed = false;

  List<CartItem> get _orderItems =>
      cartController.items.where((item) => item.selected.value).toList();

  String _formatWon(int value) => formatWon(value);

  @override
  void initState() {
    super.initState();
    _loadCheckout();
    _loadOrderer();
  }

  Future<void> _loadCheckout() async {
    setState(() => _loadError = null);
    try {
      final data = await OrderApi.checkout();
      if (!mounted) return;
      setState(() {
        _checkout = data;
        final index = data.paymentMethods.indexOf(data.defaultPayment);
        _paymentMethodIndex = index < 0 ? 0 : index;
        _selectedCouponIndex = 0;
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = error.toString());
    }
  }

  Future<void> _loadOrderer() async {
    final email = AuthController.to.customerId.value;
    if (email == null) return;
    try {
      final account = await FitpickApiService.instance.me();
      if (!mounted) return;
      setState(() {
        if (_ordererName.isEmpty) {
          _ordererName = account['name']?.toString() ?? '';
        }
        if (_ordererPhone.isEmpty) {
          _ordererPhone = account['phoneNumber']?.toString() ?? '';
        }
      });
    } catch (_) {
      // 계정 정보를 못 불러와도 "수정"으로 직접 입력할 수 있다.
    }
  }

  int _subtotal(List<CartItem> items) =>
      items.fold(0, (sum, item) => sum + item.price * item.quantity.value);

  Future<void> _editOrdererInfo() async {
    final nameController = TextEditingController(text: _ordererName);
    final phoneController = TextEditingController(text: _ordererPhone);

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '주문자 정보 수정',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '이름'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: '연락처'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, {
                    'name': nameController.text.trim(),
                    'phone': phoneController.text.trim(),
                  }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('저장'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result == null) return;
    setState(() {
      if (result['name']!.isNotEmpty) _ordererName = result['name']!;
      if (result['phone']!.isNotEmpty) _ordererPhone = result['phone']!;
    });
  }

  void _showMessage(String message) {
    showFitpickSnackbar(message, title: '오류');
  }

  /// 서버에 주문을 만든다. 가격·할인은 서버가 다시 계산하고, 주문된 상품은 장바구니에서 빠진다.
  Future<void> _pay(List<CartItem> orderItems) async {
    if (!_agreed || orderItems.isEmpty || _paying) return;
    if (!cartController.hasStore) {
      _showMessage('수령 매장을 선택해 주세요.');
      return;
    }
    if (_ordererName.isEmpty || _ordererPhone.isEmpty) {
      _showMessage('주문자 이름과 연락처를 입력해 주세요.');
      return;
    }
    setState(() => _paying = true);
    try {
      final order = await OrderApi.createOrder(
        ordererName: _ordererName,
        ordererPhone: _ordererPhone,
        paymentMethod:
            _paymentMethods[_paymentMethodIndex < _paymentMethods.length
                ? _paymentMethodIndex
                : 0],
        couponId: _selectedCoupon?.couponId,
        dealerSeq: cartController.storeSeq.value,
        agreed: _agreed,
      );
      await cartController.load();
      Get.off(
        () => Ordercompletepage(
          orderNumber: order.orderNumber,
          storeName: order.storeName,
          paymentMethod: order.paymentMethod,
          paidAmount: order.paidAmount,
        ),
      );
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('주문하기'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => Get.to(Cartpage()),
            icon: Icon(Icons.shopping_bag_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          final orderItems = _orderItems;
          if (_loadError != null) return _buildErrorState(_loadError!);
          if (_checkout == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (orderItems.isEmpty) return _buildEmptyState();
          return _buildCheckoutForm(orderItems);
        }),
      ),
    );
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
              onPressed: _loadCheckout,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
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
            '주문할 상품이 없어요',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '장바구니에서 상품을 먼저 선택해 주세요.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => Get.to(() => const Cartpage()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                '장바구니로',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutForm(List<CartItem> orderItems) {
    final subtotal = _subtotal(orderItems);
    final discount = _discountOf(subtotal);
    final total = subtotal - discount;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              _buildStepIndicator(),
              const SizedBox(height: 20),
              _sectionTitle('1. 수령 매장'),
              const SizedBox(height: 8),
              _buildStoreCard(),
              const SizedBox(height: 10),
              _buildPickupNotice(),
              const SizedBox(height: 24),
              _sectionTitle('2. 주문 상품'),
              const SizedBox(height: 8),
              for (final item in orderItems) ...[
                _buildOrderItemCard(item),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 12),
              _sectionTitle('3. 주문자 정보', action: ('수정', _editOrdererInfo)),
              const SizedBox(height: 8),
              _buildOrdererCard(),
              const SizedBox(height: 24),
              _sectionTitle('4. 결제 방법'),
              const SizedBox(height: 8),
              _buildPaymentMethods(),
              const SizedBox(height: 24),
              _sectionTitle('5. 쿠폰'),
              const SizedBox(height: 8),
              _buildCouponDropdown(),
              const SizedBox(height: 20),
              _buildPriceSummary(subtotal, discount, total),
              const SizedBox(height: 16),
              _buildAgreementRow(),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '모의 결제입니다. 실제 결제는 발생하지 않으며, 주문은 서버에 저장되어 주문내역에서 확인할 수 있습니다.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
        _buildPayBar(orderItems, total),
      ],
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['01 주문 확인', '02 결제', '03 완료'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < steps.length; i++)
          Text(
            steps[i],
            style: TextStyle(
              fontSize: 13,
              fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal,
              color: i == 0 ? Colors.black : Colors.grey.shade400,
            ),
          ),
      ],
    );
  }

  Widget _sectionTitle(String title, {(String, VoidCallback)? action}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        if (action != null)
          GestureDetector(
            onTap: action.$2,
            child: Row(
              children: [
                Text(
                  action.$1,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStoreCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
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
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => pickAndApplyStore(cartController),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('변경'),
          ),
        ],
      ),
    );
  }

  Widget _buildPickupNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 18,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '상품은 본사에서 선택한 수령 매장으로 발송됩니다. 도착 후 수령 안내를 확인해 주세요.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemCard(CartItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
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
                const SizedBox(height: 4),
                Text(
                  item.colorLabel,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '본사 발송 준비',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdererCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _ordererName.isEmpty ? '이름을 입력해 주세요' : _ordererName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          Text(
            _ordererPhone.isEmpty ? '연락처 미입력' : _ordererPhone,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods() {
    return Column(
      children: [
        for (var i = 0; i < _paymentMethods.length; i++)
          RadioListTile<int>(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: i,
            groupValue: _paymentMethodIndex,
            onChanged: (value) =>
                setState(() => _paymentMethodIndex = value ?? 0),
            title: Text(_paymentMethods[i]),
          ),
      ],
    );
  }

  Widget _buildCouponDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedCouponIndex,
          isExpanded: true,
          items: [
            DropdownMenuItem(
              value: 0,
              child: Text(_coupons.isEmpty ? '사용 가능한 쿠폰이 없습니다' : '쿠폰 사용 안 함'),
            ),
            for (var i = 0; i < _coupons.length; i++)
              DropdownMenuItem(
                value: i + 1,
                child: Text(
                  '${_coupons[i].name} (${_formatWon(-_coupons[i].discountAmount)})',
                ),
              ),
          ],
          onChanged: (value) =>
              setState(() => _selectedCouponIndex = value ?? 0),
        ),
      ),
    );
  }

  Widget _buildPriceSummary(int subtotal, int discount, int total) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('상품 금액', style: TextStyle(color: Colors.grey.shade700)),
            Text(_formatWon(subtotal)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('쿠폰 할인', style: TextStyle(color: Colors.grey.shade700)),
            Text(_formatWon(-discount)),
          ],
        ),
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '최종 결제 금액',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Text(
              _formatWon(total),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAgreementRow() {
    return GestureDetector(
      onTap: () => setState(() => _agreed = !_agreed),
      child: Row(
        children: [
          Checkbox(
            value: _agreed,
            onChanged: (value) => setState(() => _agreed = value ?? false),
          ),
          Expanded(
            child: Text(
              '상품·수령 매장과 주문 내용을 확인했습니다.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayBar(List<CartItem> orderItems, int total) {
    final enabled = _agreed && orderItems.isNotEmpty && !_paying;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: enabled ? () => _pay(orderItems) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            _paying ? '주문 처리 중…' : '${_formatWon(total)} 모의 결제하기',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
