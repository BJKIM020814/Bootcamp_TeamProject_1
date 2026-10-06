import 'package:bootcamp_teamproject_1/order/cartPage.dart';
import 'package:bootcamp_teamproject_1/order/orderDetailPage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum _ClaimType { exchange, returnItem }

/// 예시 교환/반품 이력을 로컬 목록으로 보여 준다. 신청 API 조회가 연결되지 않았다.
class _ClaimRecord {
  const _ClaimRecord({
    required this.date,
    required this.orderNumber,
    required this.type,
    required this.brand,
    required this.name,
    required this.colorLabel,
    required this.price,
    required this.quantity,
    required this.storeName,
    required this.reason,
    required this.detail,
    required this.stageIndex,
    this.requestedSize,
  });

  final String date;
  final String orderNumber;
  final _ClaimType type;
  final String brand;
  final String name;
  final String colorLabel;
  final int price;
  final int quantity;
  final String storeName;
  final String reason;
  final String detail;
  final int stageIndex; // 0=신청 접수, 1=본사 확인, 2=방문, 3=완료
  final String? requestedSize;
}

class Exchangehistorypage extends StatefulWidget {
  const Exchangehistorypage({super.key});

  @override
  State<Exchangehistorypage> createState() => _ExchangehistorypageState();
}

class _ExchangehistorypageState extends State<Exchangehistorypage> {
  static const _claimStages = ['신청 접수', '본사 확인', '방문', '완료'];

  // TODO: 실제 교환/반품 신청 데이터 연동 시 서버/DB 조회 결과로 교체한다.
  static const _claims = <_ClaimRecord>[
    _ClaimRecord(
      date: '2026.09.12',
      orderNumber: 'FP260910-002',
      type: _ClaimType.exchange,
      brand: 'NIKE',
      name: "에어 포스 1 '07",
      colorLabel: '화이트 / 화이트 · 265mm',
      price: 119000,
      quantity: 1,
      storeName: '성수 스토어',
      reason: '사이즈가 작아요',
      detail: '수령 후 착용해 보니 발끝이 닿아 사이즈 교환을 요청합니다.',
      requestedSize: '270mm',
      stageIndex: 0,
    ),
    _ClaimRecord(
      date: '2026.09.13',
      orderNumber: 'FP260908-005',
      type: _ClaimType.returnItem,
      brand: 'PUMA',
      name: '스웨이드 클래식',
      colorLabel: '푸마 콜렉 / 푸마 화이트 · 260mm',
      price: 99000,
      quantity: 1,
      storeName: '강남 스토어',
      reason: '상품이 설명과 달라요',
      detail: '실물 상태를 확인한 뒤 반품 절차를 문의합니다.',
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

  void _openOrderDetail(_ClaimRecord claim) {
    Get.to(
      () => Orderdetailpage(
        orderNumber: claim.orderNumber,
        brand: claim.brand,
        productName: claim.name,
        colorLabel: claim.colorLabel,
        price: claim.price,
        quantity: claim.quantity,
        storeName: claim.storeName,
        initialStage: PickupStage.completed,
      ),
    );
  }

  void _showProcessingStatus() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('처리 상태 상세 보기는 준비 중입니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('교환내역'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => Get.to(Cartpage()),
            icon: Icon(Icons.shopping_bag_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const Text(
              '교환 · 반품 내역',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              '구매 내역과 같은 상품·매장·금액 기준으로 확인합니다.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            for (final claim in _claims) ...[
              _buildClaimCard(claim),
              const SizedBox(height: 16),
            ],
            Text(
              '신청과 환불 상태는 시연용이며 실제 매장으로 전송되지 않습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimCard(_ClaimRecord claim) {
    final isExchange = claim.type == _ClaimType.exchange;

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
                      claim.date,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                    Text(
                      claim.orderNumber,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              _buildClaimChip(isExchange),
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
                      claim.brand,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      claim.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      claim.colorLabel,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          _formatWon(claim.price),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '수량 ${claim.quantity}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              claim.storeName,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isExchange ? '구매금액' : '예상 환불금액',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              Text(
                _formatWon(claim.price * claim.quantity),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('신청 사유', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              Text(
                claim.reason,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            claim.detail,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          if (claim.requestedSize != null) ...[
            const SizedBox(height: 10),
            Text(
              '교환 요청 사이즈 ${claim.requestedSize}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 16),
          _buildClaimStepper(claim.stageIndex),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _openOrderDetail(claim),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('구매 내역 보기', style: TextStyle(color: Colors.black)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _showProcessingStatus,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('처리 상태 확인', style: TextStyle(color: Colors.black)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClaimChip(bool isExchange) {
    final bg = isExchange ? const Color(0xFFE8EEF9) : const Color(0xFFFFF1DC);
    final fg = isExchange ? const Color(0xFF2F5D9E) : const Color(0xFF8A5A17);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        isExchange ? '교환 신청' : '반품 신청',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildClaimStepper(int stageIndex) {
    final green = const Color(0xFF1F5A46);
    final grey = Colors.grey.shade300;

    return Row(
      children: List.generate(_claimStages.length, (i) {
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
                      color: i == _claimStages.length - 1
                          ? Colors.transparent
                          : (i < stageIndex ? green : grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _claimStages[i],
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
}
