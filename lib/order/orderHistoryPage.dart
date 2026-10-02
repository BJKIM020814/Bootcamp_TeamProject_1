import 'package:bootcamp_teamproject_1/order/cartpage.dart';
import 'package:bootcamp_teamproject_1/order/exchangeRequestPage.dart';
import 'package:bootcamp_teamproject_1/order/orderDetailPage.dart';
import 'package:bootcamp_teamproject_1/order/exchangeHistoryPage.dart';
import 'package:bootcamp_teamproject_1/order/returnRequestPage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum _OrderStatus { inProgress, completed, cancelled }

class _OrderRecord {
  const _OrderRecord({
    required this.date,
    required this.orderNumber,
    required this.status,
    required this.brand,
    required this.name,
    required this.colorLabel,
    required this.price,
    required this.quantity,
    required this.storeName,
    required this.stageIndex,
  });

  final String date;
  final String orderNumber;
  final _OrderStatus status;
  final String brand;
  final String name;
  final String colorLabel;
  final int price;
  final int quantity;
  final String storeName;
  final int stageIndex; // 0=결제, 1=준비, 2=이동, 3=수령
}

class Orderhistorypage extends StatefulWidget {
  const Orderhistorypage({super.key});

  @override
  State<Orderhistorypage> createState() => _OrderhistorypageState();
}

class _OrderhistorypageState extends State<Orderhistorypage> {
  int _filterIndex = 0;
  static const _filters = ['전체', '진행 중', '수령 완료', '취소'];

  // TODO: 실제 주문 데이터 연동 시 서버/DB 조회 결과로 교체한다.
  static const _orders = <_OrderRecord>[
    _OrderRecord(
      date: '2026.10.01',
      orderNumber: 'DEMO-AC66E209',
      status: _OrderStatus.inProgress,
      brand: 'NEW BALANCE',
      name: '530',
      colorLabel: '화이트 / 네추럴 인디고 · 270mm',
      price: 129000,
      quantity: 1,
      storeName: '강남 스토어',
      stageIndex: 1,
    ),
    _OrderRecord(
      date: '2026.10.01',
      orderNumber: 'DEMO-2382EE5B',
      status: _OrderStatus.inProgress,
      brand: 'NEW BALANCE',
      name: '530',
      colorLabel: '화이트 / 네추럴 인디고 · 270mm',
      price: 129000,
      quantity: 1,
      storeName: '성수 스토어',
      stageIndex: 2,
    ),
    _OrderRecord(
      date: '2026.09.08',
      orderNumber: 'FP260908-005',
      status: _OrderStatus.completed,
      brand: 'PUMA',
      name: '스웨이드 클래식',
      colorLabel: '푸마 컬렉 / 푸마 화이트 · 260mm',
      price: 99000,
      quantity: 1,
      storeName: '강남 스토어',
      stageIndex: 3,
    ),
    _OrderRecord(
      date: '2026.08.20',
      orderNumber: 'DEMO-7781CA02',
      status: _OrderStatus.cancelled,
      brand: 'ADIDAS',
      name: '삼바 OG',
      colorLabel: '블랙 / 화이트 · 265mm',
      price: 139000,
      quantity: 1,
      storeName: '강남 스토어',
      stageIndex: 0,
    ),
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

  List<_OrderRecord> get _filteredOrders {
    switch (_filterIndex) {
      case 1:
        return _orders.where((o) => o.status == _OrderStatus.inProgress).toList();
      case 2:
        return _orders.where((o) => o.status == _OrderStatus.completed).toList();
      case 3:
        return _orders.where((o) => o.status == _OrderStatus.cancelled).toList();
      default:
        return _orders;
    }
  }

  void _openOrderDetail() => Get.to(() => const Orderdetailpage());

  void _openOrderDetailFor(_OrderRecord order) {
    Get.to(
      () => Orderdetailpage(
        orderNumber: order.orderNumber,
        brand: order.brand,
        productName: order.name,
        colorLabel: order.colorLabel,
        price: order.price,
        quantity: order.quantity,
        storeName: order.storeName,
        initialStage: order.status == _OrderStatus.completed
            ? PickupStage.completed
            : PickupStage.preparing,
      ),
    );
  }

  void _openExchangeCases() => Get.to(() => const Exchangehistorypage());

  void _openExchangeRequest(_OrderRecord order) {
    Get.to(
      () => Exchangerequestpage(
        brand: order.brand,
        productName: order.name,
        colorLabel: order.colorLabel,
        price: order.price,
        quantity: order.quantity,
      ),
    );
  }

  void _openReturnRequest(_OrderRecord order) {
    Get.to(
      () => Returnrequestpage(
        brand: order.brand,
        productName: order.name,
        colorLabel: order.colorLabel,
        price: order.price,
        quantity: order.quantity,
      ),
    );
  }

  void _openExchangeReturnHistory() => Get.to(() => const Exchangehistorypage());

  void _writeReview() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('리뷰 작성 기능은 준비 중입니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('주문내역'),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildFilterTabs(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Text(
                    '본사 발송부터 매장 픽업까지 안전하게 확인하세요.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  _buildDemoButtonsRow(),
                  const SizedBox(height: 20),
                  if (_filteredOrders.isEmpty) _buildEmptyFilterState(),
                  for (final order in _filteredOrders) ...[
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
                  const SizedBox(height: 12),
                  Text(
                    '실시간 서버 연결 전 시연 데이터입니다. 새로고침하면 초기화됩니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Row(
      children: [
        for (var i = 0; i < _filters.length; i++) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _filterIndex = i),
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

  Widget _buildDemoButtonsRow() {
    final buttons = [
      ('발송 시작·변경 잠금 확인', _openOrderDetail),
      ('QR 수령 인증 시연', _openOrderDetail),
      ('교환·반품 사례 보기', _openExchangeCases),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (label, onTap) in buttons) ...[
            OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.black),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
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

  Widget _buildOrderCard(_OrderRecord order) {
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
                      order.date,
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
              _buildStatusChip(order.status),
            ],
          ),
          const SizedBox(height: 12),
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
                      order.brand,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      order.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.colorLabel,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          _formatWon(order.price),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '수량 ${order.quantity}',
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
          if (order.status != _OrderStatus.cancelled) ...[
            const SizedBox(height: 14),
            _buildProgressStepper(order.stageIndex),
          ],
          const SizedBox(height: 14),
          _buildOrderActions(order),
        ],
      ),
    );
  }

  Widget _buildStatusChip(_OrderStatus status) {
    late String label;
    late Color bg;
    late Color fg;
    switch (status) {
      case _OrderStatus.completed:
        label = '수령 완료';
        bg = const Color(0xFFE3F3EA);
        fg = const Color(0xFF1F5A46);
      case _OrderStatus.inProgress:
        label = '결제 완료';
        bg = const Color(0xFFE3F3EA);
        fg = const Color(0xFF1F5A46);
      case _OrderStatus.cancelled:
        label = '주문 취소';
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade600;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        label,
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

  Widget _buildOrderActions(_OrderRecord order) {
    if (order.status == _OrderStatus.completed) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _openOrderDetailFor(order),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('상세 보기', style: TextStyle(color: Colors.black)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _writeReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('리뷰 작성'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _openExchangeRequest(order),
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
                  onPressed: () => _openReturnRequest(order),
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

    if (order.status == _OrderStatus.cancelled) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => _openOrderDetailFor(order),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: BorderSide(color: Colors.grey.shade300),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('상세 보기', style: TextStyle(color: Colors.black)),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _openOrderDetailFor(order),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('상세 보기', style: TextStyle(color: Colors.black)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: () => _openOrderDetailFor(order),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('준비 상태 보기'),
          ),
        ),
      ],
    );
  }
}
