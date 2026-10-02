import 'package:get/get.dart';

import 'package:bootcamp_teamproject_1/services/account_service.dart';
import 'package:bootcamp_teamproject_1/services/mypage_api.dart';
import 'package:bootcamp_teamproject_1/user/authController.dart';

import 'mypage_models.dart';

/// 마이페이지 첫 화면과 내 정보 화면이 함께 쓰는 사용자 정보.
/// 이름/전화번호는 Firebase account, 등급/사이즈/개수는 FastAPI(MySQL)에서 가져온다.
class MyPageController extends GetxController {
  static MyPageController get to => Get.isRegistered<MyPageController>()
      ? Get.find<MyPageController>()
      : Get.put(MyPageController(), permanent: true);

  final RxString name = ''.obs;
  final RxString phone = ''.obs;
  final RxString shoeSize = '-'.obs; // 예: 270mm
  final RxString grade = '-'.obs;
  final RxString favoriteStore = ''.obs;
  final RxInt orderCount = 0.obs;
  final RxInt wishlistCount = 0.obs;
  final RxInt reviewCount = 0.obs;
  final RxBool loading = false.obs;
  final RxnString error = RxnString();

  /// 로그인한 계정의 email (= 서버의 customer_id). 로그인 전에는 null.
  String? get customerId => AuthController.to.customerId.value;

  MpProfile get profile => MpProfile(
    name: name.value,
    phone: phone.value,
    email: customerId ?? '',
    shoeSize: shoeSize.value,
    grade: grade.value,
  );

  Future<void> load() async {
    final id = customerId;
    if (id == null) return;
    loading.value = true;
    error.value = null;
    try {
      final summary = await MyPageApi.summary(id);
      shoeSize.value = '${summary.shoeSize}mm';
      grade.value = summary.grade;
      favoriteStore.value = summary.favoriteStore ?? '';
      orderCount.value = summary.orderCount;
      wishlistCount.value = summary.wishlistCount;
      reviewCount.value = summary.reviewCount;
    } catch (e) {
      error.value = '$e';
    }
    try {
      final basic = await AccountService.getBasic(id);
      name.value = basic.name;
      phone.value = basic.phone;
    } catch (e) {
      error.value ??= '$e';
    }
    loading.value = false;
  }
}
