import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 서버 로그인 결과에서 얻은 회원 ID를 Flutter 화면들이 공유한다.
/// 실제 비밀번호 인증과 세션 토큰 검증은 [FitpickApiService]와 FastAPI가 담당한다.
class AuthController extends GetxController {
  static AuthController get to => Get.isRegistered<AuthController>()
      ? Get.find<AuthController>()
      : Get.put(AuthController(), permanent: true);

  final RxBool isLoggedIn = false.obs;

  /// 로그인 계정 이메일. 서버 토큰의 소유자이며 MySQL customer 키로도 사용한다.
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

/// 앱바에서 로그인 상태에 따라 장바구니 배지를 표시하는 아이콘.
/// count는 호출 화면이 제공하며, 현재 장바구니는 로컬 데모 상태다.
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
