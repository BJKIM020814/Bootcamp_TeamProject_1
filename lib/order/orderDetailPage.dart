import 'package:bootcamp_teamproject_1/order/cartpage.dart';
import 'package:bootcamp_teamproject_1/order/exchangeRequestPage.dart';
import 'package:bootcamp_teamproject_1/order/orderHistoryPage.dart';
import 'package:bootcamp_teamproject_1/order/pickupQrPage.dart';
import 'package:bootcamp_teamproject_1/order/returnRequestPage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum PickupStage { preparing, completed }

class Orderdetailpage extends StatefulWidget {
  const Orderdetailpage({
    super.key,
    this.orderNumber = 'FP260908-005',
    this.brand = 'PUMA',
    this.productName = '스웨이드 클래식',
    this.colorLabel = '푸마 콜렉 / 푸마 화이트 · 260mm',
    this.sizeLabel = '260mm',
    this.price = 99000,
    this.quantity = 1,
    this.paymentMethod = '신용 / 체크카드',
    this.storeName = '강남 스토어',
    this.storeAddress = '서울 강남구 강남역 인근 · 예시 위치',
    this.storeHours = '운영 예시 10:00 - 20:00',
    this.initialStage = PickupStage.completed,
  });

  final String orderNumber;
  final String brand;
  final String productName;
  final String colorLabel;
  final String sizeLabel;
  final int price;
  final int quantity;
  final String paymentMethod;
  final String storeName;
  final String storeAddress;
  final String storeHours;
  final PickupStage initialStage;

  @override
  State<Orderdetailpage> createState() => _OrderdetailpageState();
}

class _OrderdetailpageState extends State<Orderdetailpage> {
  late PickupStage _stage = widget.initialStage;
  late bool _pickedUp = widget.initialStage == PickupStage.completed;

  static const _timelineSteps = [
    '주문 접수',
    '결제 완료',
    '본사 상품 준비',
    '발송 시작·매장 이동',
    '입고·검수',
    '수령 준비 완료',
  ];

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

  Future<void> _openPickupQr() async {
    final pickedUp = await Get.to<bool>(
      () => Pickupqrpage(
        orderNumber: widget.orderNumber,
        storeName: widget.storeName,
        brand: widget.brand,
        productName: widget.productName,
        colorLabel: widget.colorLabel,
        price: widget.price,
        quantity: widget.quantity,
        alreadyPickedUp: _pickedUp,
      ),
    );
    if (pickedUp == true) {
      setState(() {
        _pickedUp = true;
        _stage = PickupStage.completed;
      });
    }
  }

  void _requestExchange() {
    Get.to(
      () => Exchangerequestpage(
        brand: widget.brand,
        productName: widget.productName,
        colorLabel: widget.colorLabel,
        price: widget.price,
        quantity: widget.quantity,
        currentSize: widget.sizeLabel,
      ),
    );
  }

  void _requestReturn() {
    Get.to(
      () => Returnrequestpage(
        brand: widget.brand,
        productName: widget.productName,
        colorLabel: widget.colorLabel,
        price: widget.price,
        quantity: widget.quantity,
      ),
    );
  }

  void _goPurchaseHistory() => Get.to(() => const Orderhistorypage());

  void _writeReview() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('리뷰 작성 기능은 준비 중입니다.')),
    );
  }

  // TODO: 네이버 지도(웹) API 연동 예정. 지금은 UI 자리만 잡아두고,
  // 추후 매장 좌표/주소로 네이버 지도 웹 페이지를 WebView나 외부 브라우저로 띄운다.
  void _openMapView() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.storeName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                widget.storeAddress,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.location_on, size: 40, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '네이버 지도 연동은 준비 중입니다. 연동되면 이 영역에 실제 지도가 표시됩니다.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final completed = _stage == PickupStage.completed;

    return Scaffold(
      appBar: AppBar(
        title: Text('주문·준비상태'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => Get.to(Cartpage()),
            icon: Icon(Icons.shopping_bag_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                children: [
                  if (completed) ...[
                    _buildCompletedHeader(),
                    const SizedBox(height: 20),
                    _sectionTitle('주문 진행 상황'),
                    const SizedBox(height: 10),
                    _buildTimeline(),
                    const SizedBox(height: 24),
                  ],
                  _sectionTitle('상품별 준비 상태'),
                  const SizedBox(height: 10),
                  _buildProductCard(completed),
                  const SizedBox(height: 24),
                  _sectionTitle('사이즈·수령 매장'),
                  const SizedBox(height: 10),
                  _buildStoreCard(),
                  const SizedBox(height: 10),
                  _buildLockNotice(),
                  const SizedBox(height: 24),
                  _sectionTitle('결제 상세'),
                  const SizedBox(height: 10),
                  if (completed)
                    _buildCompletedPaymentSection()
                  else
                    _buildPreparingPaymentSection(),
                  const SizedBox(height: 20),
                  _buildDemoStageToggle(),
                  const SizedBox(height: 10),
                  Text(
                    '상태는 화면 검증용 시연입니다. 푸시 알림·배송 추적·실시간 재고 서비스는 연결되지 않았습니다.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            _buildBottomActions(completed),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildCompletedHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DEMO ORDER · ${widget.orderNumber}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 16),
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
                '좋은 신발과 좋은 하루를',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '매장 수령이 완료되었어요. 착용 후기를 들려주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '본사에서 수령 매장으로 보내는 주문입니다. 도착·검수 후 픽업을 안내합니다.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline() {
    return Column(
      children: [
        for (final step in _timelineSteps) ...[
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(step, style: const TextStyle(fontSize: 14)),
              ),
              Text(
                '처리 완료',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
          if (step != _timelineSteps.last) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildProductCard(bool completed) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
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
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.colorLabel,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatWon(widget.price),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Text(
                '구매 ${widget.sizeLabel} · ${widget.quantity}개',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const Spacer(),
              Text(
                completed ? '수령 완료' : '준비 완료',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: completed
                      ? const Color(0xFF1F5A46)
                      : const Color(0xFFB7791F),
                ),
              ),
            ],
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
                    Text(
                      widget.storeName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.storeAddress,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.storeHours,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _openMapView,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '지도에서 위치 보기',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade700),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockNotice() {
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
              '발송이 시작되어 사이즈와 수령 매장을 변경할 수 없습니다.',
              style: TextStyle(fontSize: 12, color: Colors.brown.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedPaymentSection() {
    final total = widget.price * widget.quantity;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('상품 금액', style: TextStyle(color: Colors.grey.shade700)),
            Text(_formatWon(total)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.paymentMethod, style: TextStyle(color: Colors.grey.shade700)),
            Text(_formatWon(total)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _requestExchange,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('교환 신청', style: TextStyle(color: Colors.black)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: _requestReturn,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('반품 신청', style: TextStyle(color: Colors.black)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreparingPaymentSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '모든 상품이 준비되었습니다. 매장에 수령증을 보여주세요.',
        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
      ),
    );
  }

  Widget _buildDemoStageToggle() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Text(
          '시연 상태 변경 · 실제 주문에 영향 없음',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      setState(() => _stage = PickupStage.preparing),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _stage == PickupStage.preparing
                        ? Colors.black
                        : Colors.white,
                    foregroundColor: _stage == PickupStage.preparing
                        ? Colors.white
                        : Colors.black,
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: const Text('준비 중'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      setState(() => _stage = PickupStage.completed),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _stage == PickupStage.completed
                        ? Colors.black
                        : Colors.white,
                    foregroundColor: _stage == PickupStage.completed
                        ? Colors.white
                        : Colors.black,
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: const Text('수령 완료'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(bool completed) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: completed
          ? Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _goPurchaseHistory,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('구매 내역', style: TextStyle(color: Colors.black)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _writeReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('리뷰 작성'),
                  ),
                ),
              ],
            )
          : SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _openPickupQr,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_2, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '매장 수령증 보기',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
