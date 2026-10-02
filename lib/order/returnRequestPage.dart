import 'package:bootcamp_teamproject_1/order/claimRequestForm.dart';
import 'package:flutter/material.dart';

/// 반품 신청. 화면·서버 연동은 교환과 같은 [ClaimRequestForm] 을 쓴다.
class Returnrequestpage extends StatelessWidget {
  const Returnrequestpage({
    super.key,
    required this.orderNumber,
    required this.orderItemId,
  });

  final String orderNumber;
  final int orderItemId;

  @override
  Widget build(BuildContext context) => ClaimRequestForm(
    orderNumber: orderNumber,
    orderItemId: orderItemId,
    isExchange: false,
  );
}
