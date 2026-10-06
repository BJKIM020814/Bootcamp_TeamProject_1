import 'package:bootcamp_teamproject_1/order/cartPage.dart';
import 'package:bootcamp_teamproject_1/order/exchangeHistoryPage.dart';
import 'package:bootcamp_teamproject_1/order/exchangeRequestPage.dart';
import 'package:bootcamp_teamproject_1/order/orderApi.dart';
import 'package:bootcamp_teamproject_1/order/orderDetailPage.dart';
import 'package:bootcamp_teamproject_1/order/returnRequestPage.dart';
import 'package:bootcamp_teamproject_1/user/mypage/reviewwritepage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 주문내역. 서버(/api/v1/order/orders?status=...)에서 탭별로 불러온다.
class Orderhistorypage extends StatefulWidget {
  const Orderhistorypage({super.key});

  @override
  State<Orderhistorypage> createState() => _OrderhistorypageState();
}

class _OrderhistorypageState extends State<Orderhistorypage> {
  int _filterIndex = 0;
  static const _filters = ['전체', '진행 중', '수령 완료', '취소'];
  static const _filterValues = ['all', 'in_progress', 'completed', 'cancelled'];

  List<OrderSummary>? _orders;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _orders = null;
    });
    try {
      final orders = await OrderApi.orders(status: _filterValues[_filterIndex]);
      if (mounted) setState(() => _orders = orders);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  void _selectFilter(int index) {
    if (_filterIndex == index) return;
    _filterIndex = index;
    _load();
  }

  Future<void> _openOrderDetailFor(OrderSummary order) async {
    await Get.to(() => Orderdetailpage(orderNumber: order.orderNumber));
    _load();
  }

  /// 상품이 하나면 바로 신청 화면으로, 여러 개면 상세에서 상품을 고르게 한다.
  Future<void> _openExchangeRequest(OrderSummary order) async {
    if (order.items.length != 1) return _openOrderDetailFor(order);
    await Get.to(
      () => Exchangerequestpage(
        orderNumber: order.orderNumber,
        orderItemId: order.items.first.orderItemId,
      ),
    );
    _load();
  }

  Future<void> _openReturnRequest(OrderSummary order) async {
    if (order.items.length != 1) return _openOrderDetailFor(order);
    await Get.to(
      () => Returnrequestpage(
        orderNumber: order.orderNumber,
        orderItemId: order.items.first.orderItemId,
      ),
    );
    _load();
  }

  void _openExchangeReturnHistory() => Get.to(() => const Exchangehistorypage());

  void _writeReview() => Get.to(() => const ReviewWritePage());

  @override
  Widget build(BuildContext context) {
    final orders = _orders;
    return Scaffold(
      appBar: AppBar(
        title: Text('주문내역'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => Get.to(() => const Cartpage()),
            icon: Icon(Icons.shopping_bag_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildFilterTabs(),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    Text(
                      '본사 발송부터 매장 픽업까지 안전하게 확인하세요.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 20),
                    if (_error != null)
                      _buildErrorState(_error!)
                    else if (orders == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (orders.isEmpty)
                      _buildEmptyFilterState()
                    else
                      for (final order in orders) ...[
                        _buildOrderCard(order),
                        const SizedBox(height: 16),
                      ],
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _openExchangeReturnHistory,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          '교환·반품 신청 내역',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _load, child: const Text('다시 시도')),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Row(
      children: [
        for (var i = 0; i < _filters.length; i++) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => _selectFilter(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _filterIndex == i ? Colors.black : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _filters[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _filterIndex == i ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          ),
          if (i != _filters.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _buildEmptyFilterState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          '표시할 주문이 없습니다.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        ),
      ),
    );
  }

  Widget _buildOrderCard(OrderSummary order) {
    final first = order.items.isEmpty ? null : order.items.first;
    final extra = order.items.length - 1;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatDate(order.orderedAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                    Text(
                      order.orderNumber,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(order),
            ],
          ),
          if (first != null) ...[
            const SizedBox(height: 12),
            Row(
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
                  child: first.imageUrl == null
                      ? const Icon(Icons.image_outlined, color: Colors.grey)
                      : Image.network(
                          first.imageUrl!,
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
                        first.brand,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        extra > 0 ? '${first.name} 외 $extra건' : first.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        first.optionLabel,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            formatWon(order.paidAmount),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '수량 ${order.items.fold<int>(0, (sum, item) => sum + item.quantity)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                order.storeName,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '본사 발송 · 매장 픽업',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
          if (order.statusGroup != 'cancelled') ...[
            const SizedBox(height: 14),
            _buildProgressStepper(order.stageIndex),
          ],
          const SizedBox(height: 14),
          _buildOrderActions(order),
        ],
      ),
    );
  }

  Widget _buildStatusChip(OrderSummary order) {
    final cancelled = order.statusGroup == 'cancelled';
    final bg = cancelled ? Colors.grey.shade200 : const Color(0xFFE3F3EA);
    final fg = cancelled ? Colors.grey.shade600 : const Color(0xFF1F5A46);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        order.statusLabel,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildProgressStepper(int stageIndex) {
    const labels = ['결제', '준비', '이동', '수령'];
    final green = const Color(0xFF1F5A46);
    final grey = Colors.grey.shade300;

    return Row(
      children: List.generate(labels.length, (i) {
        final reached = i <= stageIndex;
        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 2,
                      color: i == 0 ? Colors.transparent : (i <= stageIndex ? green : grey),
                    ),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: reached ? green : grey,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 2,
                      color: i == labels.length - 1
                          ? Colors.transparent
                          : (i < stageIndex ? green : grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                labels[i],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: reached ? FontWeight.bold : FontWeight.normal,
                  color: reached ? Colors.black : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _outlined(String label, VoidCallback onPressed) {
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

  Widget _filled(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label),
    );
  }

  Widget _buildOrderActions(OrderSummary order) {
    if (order.statusGroup == 'completed') {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _outlined('상세 보기', () => _openOrderDetailFor(order))),
              const SizedBox(width: 10),
              Expanded(child: _filled('리뷰 작성', _writeReview)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _outlined('교환 신청', () => _openExchangeRequest(order))),
              const SizedBox(width: 10),
              Expanded(child: _outlined('반품 신청', () => _openReturnRequest(order))),
            ],
          ),
        ],
      );
    }

    if (order.statusGroup == 'cancelled') {
      return SizedBox(
        width: double.infinity,
        child: _outlined('상세 보기', () => _openOrderDetailFor(order)),
      );
    }

    return Row(
      children: [
        Expanded(child: _outlined('상세 보기', () => _openOrderDetailFor(order))),
        const SizedBox(width: 10),
        Expanded(
          child: _filled(
            order.status == 'READY' ? '수령증 보기' : '준비 상태 보기',
            () => _openOrderDetailFor(order),
          ),
        ),
      ],
    );
  }
}
