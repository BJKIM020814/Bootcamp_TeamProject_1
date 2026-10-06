import 'package:bootcamp_teamproject_1/order/cartPage.dart';
import 'package:bootcamp_teamproject_1/common/fitpick_snackbar.dart';
import 'package:bootcamp_teamproject_1/order/exchangeRequestPage.dart';
import 'package:bootcamp_teamproject_1/order/orderApi.dart';
import 'package:bootcamp_teamproject_1/order/orderHistoryPage.dart';
import 'package:bootcamp_teamproject_1/order/pickupQrPage.dart';
import 'package:bootcamp_teamproject_1/order/returnRequestPage.dart';
import 'package:bootcamp_teamproject_1/user/mypage/reviewwritepage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 주문·준비 상태 상세. 주문번호로 서버(/api/v1/order/orders/{주문번호})에서 불러온다.
class Orderdetailpage extends StatefulWidget {
  const Orderdetailpage({super.key, required this.orderNumber});

  final String orderNumber;

  @override
  State<Orderdetailpage> createState() => _OrderdetailpageState();
}

class _OrderdetailpageState extends State<Orderdetailpage> {
  OrderDetail? _order;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final order = await OrderApi.order(widget.orderNumber);
      if (mounted) setState(() => _order = order);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  void _showMessage(String message) {
    showFitpickSnackbar(message, title: '오류');
  }

  Future<void> _openPickupQr(OrderDetail order) async {
    final pickedUp = await Get.to<bool>(
      () => Pickupqrpage(orderNumber: order.orderNumber),
    );
    if (pickedUp == true) _load();
  }

  Future<void> _cancelOrder(OrderDetail order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('주문을 취소할까요?'),
        content: const Text('사용한 쿠폰은 유효기간이 남아 있으면 다시 사용할 수 있습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('닫기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('주문 취소'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      final updated = await OrderApi.cancelOrder(order.orderNumber);
      if (!mounted) return;
      setState(() => _order = updated);
      _showMessage('주문이 취소되었습니다.');
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestExchange(OrderDetail order, OrderLine item) async {
    await Get.to(
      () => Exchangerequestpage(
        orderNumber: order.orderNumber,
        orderItemId: item.orderItemId,
      ),
    );
    _load();
  }

  Future<void> _requestReturn(OrderDetail order, OrderLine item) async {
    await Get.to(
      () => Returnrequestpage(
        orderNumber: order.orderNumber,
        orderItemId: item.orderItemId,
      ),
    );
    _load();
  }

  void _goPurchaseHistory() => Get.to(() => const Orderhistorypage());

  void _writeReview() => Get.to(() => const ReviewWritePage());

  // TODO: 네이버 지도(웹) API 연동 예정. 서버가 매장 좌표(latitude/longitude)를 함께 내려준다.
  void _openMapView(OrderDetail order) {
    final store = order.pickupStore;
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
                order.storeName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                order.storeAddress,
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
                store?.latitude == null
                    ? '네이버 지도 연동은 준비 중입니다.'
                    : '네이버 지도 연동은 준비 중입니다. (좌표 ${store!.latitude}, ${store.longitude})',
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
    final order = _order;
    return Scaffold(
      appBar: AppBar(
        title: Text('주문·준비상태'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => Get.to(() => const Cartpage()),
            icon: Icon(Icons.shopping_bag_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: _error != null
            ? _buildErrorState(_error!)
            : order == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                        children: [
                          _buildHeader(order),
                          const SizedBox(height: 20),
                          if (!order.isCancelled) ...[
                            _sectionTitle('주문 진행 상황'),
                            const SizedBox(height: 10),
                            _buildTimeline(order),
                            const SizedBox(height: 24),
                          ],
                          _sectionTitle('상품별 준비 상태'),
                          const SizedBox(height: 10),
                          for (final item in order.items) ...[
                            _buildProductCard(order, item),
                            const SizedBox(height: 10),
                          ],
                          const SizedBox(height: 14),
                          _sectionTitle('수령 매장'),
                          const SizedBox(height: 10),
                          _buildStoreCard(order),
                          if (!order.canCancel &&
                              !order.pickedUp &&
                              !order.isCancelled) ...[
                            const SizedBox(height: 10),
                            _buildLockNotice(),
                          ],
                          const SizedBox(height: 24),
                          _sectionTitle('결제 상세'),
                          const SizedBox(height: 10),
                          _buildPaymentSection(order),
                        ],
                      ),
                    ),
                  ),
                  _buildBottomActions(order),
                ],
              ),
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
            OutlinedButton(onPressed: _load, child: const Text('다시 시도')),
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

  Widget _buildHeader(OrderDetail order) {
    final (
      IconData icon,
      Color color,
      String title,
      String message,
    ) = order.pickedUp
        ? (
            Icons.check,
            Colors.green,
            '좋은 신발과 좋은 하루를',
            '매장 수령이 완료되었어요. 착용 후기를 들려주세요.',
          )
        : order.isCancelled
        ? (Icons.close, Colors.grey, '취소된 주문입니다', '주문이 취소되어 상품이 발송되지 않습니다.')
        : order.status == 'READY'
        ? (
            Icons.inventory_2_outlined,
            Colors.black,
            '수령 준비가 완료되었어요',
            '매장에 방문해 수령증을 보여주세요.',
          )
        : (
            Icons.local_shipping_outlined,
            Colors.black,
            order.statusLabel,
            '본사에서 수령 매장으로 보내는 주문입니다. 도착·검수 후 픽업을 안내합니다.',
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ORDER · ${order.orderNumber} · ${formatDate(order.orderedAt)}',
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
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        if (order.status == 'READY' && order.pickupDueAt != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${formatDate(order.pickupDueAt!)}까지 매장 운영시간 내 방문해 주세요.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTimeline(OrderDetail order) {
    return Column(
      children: [
        for (final step in order.timeline) ...[
          Row(
            children: [
              Icon(
                step.done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: step.done ? Colors.green : Colors.grey.shade400,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  step.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: step.current
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: step.done ? Colors.black : Colors.grey.shade500,
                  ),
                ),
              ),
              Text(
                step.current
                    ? '진행 중'
                    : step.done
                    ? '처리 완료'
                    : '대기',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
          if (step != order.timeline.last) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildProductCard(OrderDetail order, OrderLine item) {
    final statusColor = order.pickedUp
        ? const Color(0xFF1F5A46)
        : order.isCancelled
        ? Colors.grey
        : const Color(0xFFB7791F);
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
              _buildThumbnail(item.imageUrl),
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
                      item.optionLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatWon(item.price),
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
                '구매 ${item.sizeLabel} · ${item.quantity}개',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const Spacer(),
              Text(
                order.statusLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),
          if (order.canClaim) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _outlinedButton(
                    '교환 신청',
                    () => _requestExchange(order, item),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _outlinedButton(
                    '반품 신청',
                    () => _requestReturn(order, item),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThumbnail(String? url) {
    return Container(
      width: 56,
      height: 56,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: url == null
          ? const Icon(Icons.image_outlined, color: Colors.grey)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.image_outlined, color: Colors.grey),
            ),
    );
  }

  Widget _outlinedButton(String label, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(color: Colors.black)),
    );
  }

  Widget _buildStoreCard(OrderDetail order) {
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
                      order.storeName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      order.storeAddress,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (order.pickupStore != null) ...[
            const SizedBox(height: 8),
            Text(
              '담당자 ${order.pickupStore!.manager}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 8),
          if (order.pickupStore != null)
            GestureDetector(
              onTap: () => _openMapView(order),
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
            )
          else
            Text(
              '수령 대리점은 주문 후 관리자가 배정합니다.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
              '발송이 시작되어 주문 취소와 수령 매장 변경을 할 수 없습니다.',
              style: TextStyle(fontSize: 12, color: Colors.brown.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection(OrderDetail order) {
    Widget row(String label, String value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
    return Column(
      children: [
        row('상품 금액', formatWon(order.subtotal)),
        row(
          order.couponName == null ? '쿠폰 할인' : '쿠폰 할인 (${order.couponName})',
          formatWon(-order.discount),
        ),
        row(order.paymentMethod, formatWon(order.paidAmount), bold: true),
        row('주문자', '${order.ordererName} · ${order.ordererPhone}'),
      ],
    );
  }

  Widget _buildBottomActions(OrderDetail order) {
    final Widget child;
    if (order.pickedUp) {
      child = Row(
        children: [
          Expanded(child: _outlinedButton('구매 내역', _goPurchaseHistory)),
          const SizedBox(width: 10),
          Expanded(child: _primaryButton('리뷰 작성', _writeReview)),
        ],
      );
    } else if (order.status == 'READY') {
      child = _primaryButton(
        '매장 수령증 보기',
        () => _openPickupQr(order),
        icon: Icons.qr_code_2,
      );
    } else if (order.canCancel) {
      child = _primaryButton(
        _busy ? '취소 처리 중…' : '주문 취소',
        _busy ? null : () => _cancelOrder(order),
      );
    } else if (order.isCancelled) {
      child = _outlinedButton('구매 내역', _goPurchaseHistory);
    } else {
      child = _primaryButton('매장 도착 후 수령증이 열립니다', null);
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SizedBox(width: double.infinity, child: child),
    );
  }

  Widget _primaryButton(
    String label,
    VoidCallback? onPressed, {
    IconData? icon,
  }) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
