import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 로그인 여부를 앱 전역에서 공유하는 간단한 상태.
/// 실제 인증 연동 전까지는 로그인 성공 시 true로만 바뀐다.
class AuthController extends GetxController {
  static AuthController get to => Get.isRegistered<AuthController>()
      ? Get.find<AuthController>()
      : Get.put(AuthController(), permanent: true);

  final RxBool isLoggedIn = false.obs;

  /// 로그인한 계정의 email. 서버(MySQL)에서는 이 값이 customer_id 이다.
  final RxnString customerId = RxnString();

  void login({String? email}) {
    isLoggedIn.value = true;
    customerId.value = email;
  }

  void logout() {
    isLoggedIn.value = false;
    customerId.value = null;
  }
}

/// 장바구니 아이콘 + 담긴 수량 배지.
/// 로그인하지 않았으면 배지를 숨긴다.
/// TODO: DB 연동 후에는 count를 로그인한 사용자의 실제 장바구니 수량으로 교체한다.
class CartBadgeIcon extends StatelessWidget {
  const CartBadgeIcon({
    super.key,
    this.icon = Icons.shopping_bag_outlined,
    this.count = 1,
  });

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!AuthController.to.isLoggedIn.value) return Icon(icon);
      return Badge(label: Text('$count'), child: Icon(icon));
    });
  }
}
