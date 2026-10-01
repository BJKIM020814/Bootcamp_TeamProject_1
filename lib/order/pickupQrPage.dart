import 'package:bootcamp_teamproject_1/order/cartPage.dart';
import 'package:bootcamp_teamproject_1/order/orderDetailPage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Pickupqrpage extends StatefulWidget {
  const Pickupqrpage({
    super.key,
    this.orderNumber = 'FP260927-004',
    this.storeName = '신사 스토어',
    this.visitWindow = '09.24-09.27 · 운영시간 내 방문 (예시)',
    this.brand = 'NEW BALANCE',
    this.productName = '530',
    this.colorLabel = '화이트 / 네추럴 인디고 · 270mm',
    this.price = 129000,
    this.quantity = 1,
    this.alreadyPickedUp = false,
  });

  final String orderNumber;
  final String storeName;
  final String visitWindow;
  final String brand;
  final String productName;
  final String colorLabel;
  final int price;
  final int quantity;
  final bool alreadyPickedUp;

  @override
  State<Pickupqrpage> createState() => _PickupqrpageState();
}

class _PickupqrpageState extends State<Pickupqrpage> {
  late final bool _pickedUp;

  @override
  void initState() {
    super.initState();
    _pickedUp = widget.alreadyPickedUp;
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

  // 시연용 난수. 실제 서비스에서는 서버가 발급한 일회성 인증번호로 교체한다.
  String get _demoCode {
    final n = widget.orderNumber.hashCode.abs() % 1000000;
    final s = n.toString().padLeft(6, '0');
    return '${s.substring(0, 3)} ${s.substring(3)}';
  }

  void _markPickedUp() {
    Navigator.of(context).pop(true);
  }

  void _goOrderDetail() {
    Get.off(
      () => Orderdetailpage(
        orderNumber: widget.orderNumber,
        brand: widget.brand,
        productName: widget.productName,
        colorLabel: widget.colorLabel,
        price: widget.price,
        quantity: widget.quantity,
        storeName: widget.storeName,
        initialStage: PickupStage.completed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('수령 인증 QR'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => Get.to(Cartpage()),
            icon: Icon(Icons.shopping_bag_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: _pickedUp ? _buildAlreadyPickedUpState() : _buildPickupFlow(),
      ),
    );
  }

  Widget _buildAlreadyPickedUpState() {
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
            '이미 수령한 주문이에요',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '모든 상품의 준비가 완료된 주문에서만 수령증을 확인할 수 있습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _goOrderDetail,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                '주문·준비 상태 확인',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickupFlow() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            children: [
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '상품이 준비됐어요!',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '매장 직원에게 수령증을 보여주세요.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildTicketCard(),
              const SizedBox(height: 20),
              _buildProductCard(),
              const SizedBox(height: 14),
              _buildMockNotice(),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '수령 전 확인해 주세요',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Text(
                  '주문한 사이즈와 상품 상태를 매장에서 확인해 주세요.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _markPickedUp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                '수령 완료 시연',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTicketCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on_outlined, size: 16),
              const SizedBox(width: 4),
              Text(
                widget.storeName,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.visitWindow,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          _buildDashedDivider(),
          const SizedBox(height: 16),
          Text(
            '수령 인증 QR · DEMO PICKUP PASS',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 14),
          // TODO: QR 패키지 연동 전까지는 자리만 확보해 둔 placeholder.
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Icon(Icons.qr_code_2, size: 160, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 16),
          // TODO: 서버가 발급하는 실제 일회성 인증번호로 교체할 자리.
          Text(
            _demoCode,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.orderNumber,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 10),
          Text(
            '수령 인증 시연용 QR · 실제 매장에서는 사용할 수 없습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedDivider() {
    return Row(
      children: List.generate(30, (i) {
        return Expanded(
          child: Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            color: i.isEven ? Colors.grey.shade400 : Colors.transparent,
          ),
        );
      }),
    );
  }

  Widget _buildProductCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.image_outlined, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.brand,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  widget.productName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.colorLabel,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      _formatWon(widget.price),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '수령 ${widget.quantity}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
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

  Widget _buildMockNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFFB7791F)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '실제 서비스에서는 서버 검증을 거친 일회성 인증번호를 사용합니다. 이 QR은 인증 기능이 없는 목업입니다.',
              style: TextStyle(fontSize: 12, color: Colors.brown.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
