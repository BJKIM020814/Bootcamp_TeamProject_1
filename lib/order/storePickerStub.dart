import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'cartController.dart';

/// 매장 선택 화면이 아직 없어서 넣어둔 임시 화면.
/// 담당 팀원이 실제 매장 선택 페이지를 만들면 pickAndApplyStore()에서
/// 이 위젯 대신 그 페이지를 호출하도록 교체하면 된다.
/// 반환 계약: Navigator.pop(context, {'name': 매장명, 'address': 주소})
class StorePickerStub extends StatelessWidget {
  const StorePickerStub({super.key});

  static const _stores = [
    {'name': '강남 스토어', 'address': '서울 강남구 강남역 인근 · 예시 위치'},
    {'name': '홍대 스토어', 'address': '서울 마포구 홍대입구역 인근 · 예시 위치'},
    {'name': '잠실 스토어', 'address': '서울 송파구 잠실역 인근 · 예시 위치'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('수령 매장 변경'), centerTitle: true),
      body: ListView.separated(
        itemCount: _stores.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final store = _stores[index];
          return ListTile(
            leading: const Icon(Icons.store_outlined),
            title: Text(store['name']!),
            subtitle: Text(store['address']!),
            onTap: () => Navigator.pop(context, store),
          );
        },
      ),
    );
  }
}

/// 매장 선택 스텁 화면을 열고, 선택 결과를 [controller]에 반영한다.
Future<void> pickAndApplyStore(CartController controller) async {
  final result = await Get.to<Map<String, String>>(() => const StorePickerStub());
  if (result != null) {
    controller.updateStore(result['name']!, result['address']!);
  }
}
