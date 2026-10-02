import 'package:bootcamp_teamproject_1/discover/discover_api.dart';
import 'package:bootcamp_teamproject_1/discover/store_selection_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'cartController.dart';

/// Discover 의 수령 매장 선택 화면(StoreSelectionPage)을 열고,
/// 선택 결과를 서버 장바구니 수령 매장으로 저장한다.
/// 반환 계약: StoreSelectionPage 는 Navigator.pop(context, PickupStore) 로 선택한 매장을 돌려준다.
Future<void> pickAndApplyStore(CartController controller) async {
  final result = await Get.to<PickupStore>(() => const StoreSelectionPage());
  if (result == null) return;
  final ok = await controller.updateStore(result.id);
  if (!ok && Get.context != null) {
    ScaffoldMessenger.of(Get.context!).showSnackBar(
      SnackBar(content: Text(controller.errorMessage.value ?? '매장을 변경하지 못했습니다.')),
    );
  }
}
