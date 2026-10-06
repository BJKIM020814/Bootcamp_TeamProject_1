import 'package:bootcamp_teamproject_1/user/mypage/mypage_models.dart';
import 'package:bootcamp_teamproject_1/user/mypage/mypage_product_list.dart';

import 'api_client.dart';

/// 마이페이지(MY FITPICK) FastAPI 호출 모음. customerId 는 로그인한 계정의 email 이다.
class MyPageApi {
  static Map<String, String> _q(String customerId) => {
    'customer_id': customerId,
  };

  static Future<MpSummary> summary(String customerId) async =>
      MpSummary.fromJson(
        await ApiClient.get('/api/v1/mypage/summary', query: _q(customerId))
            as Map<String, dynamic>,
      );

  /// 기본 결제수단. 서버가 지원하는 수단 목록과 현재 선택값을 함께 돌려준다.
  static Future<({List<String> methods, String selected})> payment(
    String customerId,
  ) async {
    final data =
        await ApiClient.get('/api/v1/mypage/payment', query: _q(customerId))
            as Map<String, dynamic>;
    return (
      methods: List<String>.from(data['methods'] as List),
      selected: data['default'] as String,
    );
  }

  static Future<void> setPayment(String customerId, String method) =>
      ApiClient.put('/api/v1/mypage/payment', {
        'customer_id': customerId,
        'default': method,
      });

  static Future<List<MpCoupon>> coupons(String customerId) async {
    // 쿠폰 발급은 명시적 쓰기 요청으로 분리한다. GET 자체는 읽기 전용이다.
    await ApiClient.post('/api/v1/mypage/coupons/issue', {});
    final list =
        await ApiClient.get('/api/v1/mypage/coupons', query: _q(customerId))
            as List;
    return list
        .map((e) => MpCoupon.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<MpProduct>> wishlist(String customerId) async {
    final list =
        await ApiClient.get('/api/v1/wishlist', query: _q(customerId)) as List;
    return list
        .map((e) => MpProduct.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> addWish(String customerId, String pCode) =>
      ApiClient.post('/api/v1/wishlist', {
        'customer_id': customerId,
        'p_code': pCode,
      });

  static Future<void> removeWish(String customerId, String pCode) =>
      ApiClient.delete(
        '/api/v1/wishlist/${Uri.encodeComponent(pCode)}',
        query: _q(customerId),
      );

  static Future<List<MpProduct>> recentlyViewed(String customerId) async {
    final list =
        await ApiClient.get('/api/v1/recently-viewed', query: _q(customerId))
            as List;
    return list
        .map((e) => MpProduct.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 상품 상세 화면을 열 때 호출하면 '최근 본 상품'에 쌓인다.
  static Future<void> recordView(String customerId, String pCode) =>
      ApiClient.post('/api/v1/recently-viewed', {
        'customer_id': customerId,
        'p_code': pCode,
      });
}
