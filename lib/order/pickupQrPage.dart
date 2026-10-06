import 'package:bootcamp_teamproject_1/order/cartPage.dart';
import 'package:bootcamp_teamproject_1/common/fitpick_snackbar.dart';
import 'package:bootcamp_teamproject_1/order/orderApi.dart';
import 'package:bootcamp_teamproject_1/order/orderDetailPage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 매장 수령증. 서버가 발급한 일회성 인증번호(10분 유효)를 보여주고,
/// 매장 확인 후 "수령 완료"를 누르면 서버에서 인증번호를 검증해 수령 처리한다.
/// 수령 처리되면 Navigator.pop(context, true) 로 돌아간다.
class Pickupqrpage extends StatefulWidget {
  const Pickupqrpage({super.key, required this.orderNumber});

  final String orderNumber;

  @override
  State<Pickupqrpage> createState() => _PickupqrpageState();
}

class _PickupqrpageState extends State<Pickupqrpage> {
  OrderDetail? _order;
  PickupCode? _code;
  String? _error;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final order = await OrderApi.order(widget.orderNumber);
      final code = order.status == 'READY'
          ? await OrderApi.issuePickupCode(widget.orderNumber)
          : null;
      if (!mounted) return;
      setState(() {
        _order = order;
        _code = code;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  bool get _expired =>
      _code != null && DateTime.now().isAfter(_code!.expiresAt);

  Future<void> _markPickedUp() async {
    final code = _code;
    if (code == null || _confirming) return;
    if (_expired) {
      showFitpickSnackbar('인증번호가 만료되어 새로 발급합니다.');
      _load();
      return;
    }
    setState(() => _confirming = true);
    try {
      await OrderApi.confirmPickup(widget.orderNumber, code.code);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        showFitpickSnackbar(error.toString(), title: '오류');
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  void _goOrderDetail() {
    Get.off(() => Orderdetailpage(orderNumber: widget.orderNumber));
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Scaffold(
      appBar: AppBar(
        title: Text('수령 인증 QR'),
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
            ? _buildMessageState('수령증을 불러오지 못했어요', _error!, retry: true)
            : order == null
            ? const Center(child: CircularProgressIndicator())
            : order.pickedUp
            ? _buildMessageState(
                '이미 수령한 주문이에요',
                '수령이 완료된 주문은 주문 상세에서 확인할 수 있습니다.',
              )
            : _code == null
            ? _buildMessageState(
                '아직 수령할 수 없어요',
                '현재 상태: ${order.statusLabel}\n모든 상품이 매장에 도착해 수령 준비가 완료되면 수령증이 열립니다.',
              )
            : _buildPickupFlow(order, _code!),
      ),
    );
  }

  Widget _buildMessageState(
    String title,
    String message, {
    bool retry = false,
  }) {
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
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: retry ? _load : _goOrderDetail,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                retry ? '다시 시도' : '주문·준비 상태 확인',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickupFlow(OrderDetail order, PickupCode code) {
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '매장 직원에게 수령증을 보여주세요.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildTicketCard(order, code),
              const SizedBox(height: 20),
              for (final item in order.items) ...[
                _buildProductCard(item),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '수령 전 확인해 주세요',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
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
              onPressed: _confirming ? null : _markPickedUp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                _confirming ? '확인 중…' : '수령 완료',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _shortDate(DateTime date) =>
      '${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

  Widget _buildTicketCard(OrderDetail order, PickupCode code) {
    final from = code.visitFrom;
    final until = code.visitUntil;
    final visitWindow = from != null && until != null
        ? '${_shortDate(from)}-${_shortDate(until)} · 운영시간 내 방문'
        : '운영시간 내 방문';
    final expiresAt =
        '${code.expiresAt.hour.toString().padLeft(2, '0')}:${code.expiresAt.minute.toString().padLeft(2, '0')}';
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
                order.storeName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            visitWindow,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          _buildDashedDivider(),
          const SizedBox(height: 16),
          Text(
            '수령 인증 QR · PICKUP PASS',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 14),
          // TODO: QR 패키지(qr_flutter 등) 추가 시 code.qrPayload 로 실제 QR 을 그린다.
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Icon(
              Icons.qr_code_2,
              size: 160,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            code.code,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            order.orderNumber,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 10),
          Text(
            '인증번호는 $expiresAt까지 유효합니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          TextButton(onPressed: _load, child: const Text('인증번호 새로 받기')),
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

  Widget _buildProductCard(OrderLine item) {
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
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
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
                  item.optionLabel,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
                      '수령 ${item.quantity}',
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
    );
  }
}
