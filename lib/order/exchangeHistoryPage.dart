import 'package:bootcamp_teamproject_1/order/cartPage.dart';
import 'package:bootcamp_teamproject_1/common/fitpick_snackbar.dart';
import 'package:bootcamp_teamproject_1/order/orderApi.dart';
import 'package:bootcamp_teamproject_1/order/orderDetailPage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 교환·반품 내역. 서버(/api/v1/order/claims)에서 불러온다.
class Exchangehistorypage extends StatefulWidget {
  const Exchangehistorypage({super.key});

  @override
  State<Exchangehistorypage> createState() => _ExchangehistorypageState();
}

class _ExchangehistorypageState extends State<Exchangehistorypage> {
  static const _claimStages = ['신청 접수', '본사 확인', '방문', '완료'];

  List<ClaimRecord>? _claims;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final claims = await OrderApi.claims();
      if (mounted) setState(() => _claims = claims);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  void _openOrderDetail(ClaimRecord claim) {
    Get.to(() => Orderdetailpage(orderNumber: claim.orderNumber));
  }

  /// 서버에서 최신 처리 상태를 다시 받아 첨부 사진과 함께 보여준다.
  Future<void> _showProcessingStatus(ClaimRecord claim) async {
    final ClaimRecord latest;
    try {
      latest = await OrderApi.claim(claim.claimId);
    } catch (error) {
      if (mounted) {
        showFitpickSnackbar(error.toString(), title: '오류');
      }
      return;
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${latest.claimTypeLabel} 처리 상태 · ${latest.statusLabel}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '신청일 ${formatDate(latest.requestedAt)} · 방문 매장 ${latest.storeName}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            _buildClaimStepper(latest.stageIndex),
            if (latest.photoUrls.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                '첨부 사진',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final url in latest.photoUrls) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(
                          width: 72,
                          height: 72,
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final claims = _claims;
    return Scaffold(
      appBar: AppBar(
        title: Text('교환내역'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => Get.to(() => const Cartpage()),
            icon: Icon(Icons.shopping_bag_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
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
              if (_error != null)
                Column(
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _load,
                      child: const Text('다시 시도'),
                    ),
                  ],
                )
              else if (claims == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (claims.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      '교환·반품 신청 내역이 없습니다.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                )
              else
                for (final claim in claims) ...[
                  _buildClaimCard(claim),
                  const SizedBox(height: 16),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClaimCard(ClaimRecord claim) {
    final item = claim.item;
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
                      formatDate(claim.requestedAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    Text(
                      claim.orderNumber,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              _buildClaimChip(claim),
            ],
          ),
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
                child: item.imageUrl == null
                    ? const Icon(Icons.image_outlined, color: Colors.grey)
                    : Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.image_outlined,
                          color: Colors.grey,
                        ),
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
                      item.optionLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          formatWon(item.price),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '수량 ${item.quantity}',
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
                claim.isExchange ? '구매금액' : '예상 환불금액',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              Text(
                formatWon(
                  claim.isExchange
                      ? item.price * item.quantity
                      : claim.refundAmount,
                ),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '신청 사유',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              Text(
                claim.reason,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
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
              '교환 요청 사이즈 ${claim.requestedSize}mm',
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
                  child: const Text(
                    '구매 내역 보기',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showProcessingStatus(claim),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '처리 상태 확인',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClaimChip(ClaimRecord claim) {
    final isExchange = claim.isExchange;
    final bg = isExchange ? const Color(0xFFE8EEF9) : const Color(0xFFFFF1DC);
    final fg = isExchange ? const Color(0xFF2F5D9E) : const Color(0xFF8A5A17);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${claim.claimTypeLabel} · ${claim.statusLabel}',
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
                      color: i == 0
                          ? Colors.transparent
                          : (i <= stageIndex ? green : grey),
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
