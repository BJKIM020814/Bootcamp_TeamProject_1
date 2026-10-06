import 'package:get/get.dart';

import 'package:bootcamp_teamproject_1/services/fitpick_api_service.dart';
import 'package:bootcamp_teamproject_1/services/mypage_api.dart';
import 'package:bootcamp_teamproject_1/user/authController.dart';

import 'mypage_models.dart';

/// 마이페이지 첫 화면과 내 정보 화면이 함께 쓰는 사용자 정보.
/// 이름/전화번호/사이즈는 Firebase account, 등급/개수는 MySQL에서 가져온다.
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
  int _loadVersion = 0;
  late final Worker _accountWorker;

  @override
  void onInit() {
    super.onInit();
    // permanent 컨트롤러이므로 계정 변경 즉시 이전 사용자의 표시를 비운다.
    _accountWorker = ever(AuthController.to.customerId, (_) {
      ++_loadVersion;
      _clearProfile();
      error.value = null;
      loading.value = false;
      if (customerId != null) load();
    });
  }

  @override
  void onClose() {
    ++_loadVersion;
    _accountWorker.dispose();
    super.onClose();
  }

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
    final version = ++_loadVersion;
    if (id == null || id.isEmpty) {
      _clearProfile();
      loading.value = false;
      error.value = null;
      return;
    }

    loading.value = true;
    error.value = null;

    // 계정 프로필은 인증된 /login/me, 마이페이지 통계는 Discover API에서 각각 조회한다.
    final results = await Future.wait<Object?>([
      _capture(() => FitpickApiService.instance.me()),
      _capture(() => MyPageApi.summary(id)),
    ]);

    // 요청 도중 로그아웃/계정 전환이 발생했으면 이전 사용자의 응답을 반영하지 않는다.
    if (version != _loadVersion || customerId != id) return;

    final accountResult = results[0];
    if (accountResult case final Map<String, dynamic> account) {
      name.value = account['name']?.toString() ?? '';
      phone.value = account['phoneNumber']?.toString() ?? '';
      final accountShoeSize = account['shoeSize'];
      shoeSize.value = accountShoeSize is int ? '${accountShoeSize}mm' : '-';
    } else {
      error.value = _errorMessage(accountResult);
    }

    final summaryResult = results[1];
    if (summaryResult case final MpSummary summary) {
      grade.value = summary.grade;
      favoriteStore.value = summary.favoriteStore ?? '';
      orderCount.value = summary.orderCount;
      wishlistCount.value = summary.wishlistCount;
      reviewCount.value = summary.reviewCount;
    } else {
      error.value ??= _errorMessage(summaryResult);
    }

    loading.value = false;
  }

  /// 한쪽 요청 실패가 다른 프로필 데이터 표시까지 막지 않도록 오류를 값으로 반환한다.
  Future<Object?> _capture(Future<Object?> Function() request) async {
    try {
      return await request();
    } catch (exception) {
      return exception;
    }
  }

  String _errorMessage(Object? result) =>
      result is FitpickApiException ? result.message : result.toString();

  /// 로그아웃 시 이전 사용자의 프로필과 통계가 화면에 남지 않게 비운다.
  void _clearProfile() {
    name.value = '';
    phone.value = '';
    shoeSize.value = '-';
    grade.value = '-';
    favoriteStore.value = '';
    orderCount.value = 0;
    wishlistCount.value = 0;
    reviewCount.value = 0;
  }
}
