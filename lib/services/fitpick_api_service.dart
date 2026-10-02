import 'dart:convert';
import 'package:http/http.dart' as http;

/// 페이지에서 사용할 REST 어댑터. --dart-define=API_BASE_URL=...로 서버 지정.
/// 토큰은 메모리에만 보관하므로 앱 재시작 후 다시 로그인한다.
class FitpickApiService {
  FitpickApiService({http.Client? client}) : _client = client ?? http.Client();
  // 화면들이 같은 토큰을 공유하도록 공통 서비스 인스턴스를 사용한다.
  static final instance = FitpickApiService();
  final http.Client _client;
  // 실제 서버 주소는 --dart-define=API_BASE_URL=...로 빌드할 때 변경할 수 있다.
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.20.53:8000',
  );
  String? _token;
  bool get hasSession => _token != null;

  // 모든 페이지 요청의 JSON 변환, 인증 헤더, 타임아웃, 오류 처리를 한곳에서 담당한다.
  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final request = http.Request(method, Uri.parse('$baseUrl/api$path'));
    request.headers['Content-Type'] = 'application/json';
    // 서버는 이 토큰으로 회원을 결정한다. 회원 이메일을 별도 요청 필드로 보내지 않는다.
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await _client.send(request).timeout(const Duration(seconds: 15)),
    ).timeout(const Duration(seconds: 15));
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(utf8.decode(response.bodyBytes));
    // 204 성공은 빈 Map으로 처리하고, 인증 만료(401)는 저장된 토큰도 제거한다.
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) _token = null;
      throw FitpickApiException(
        response.statusCode,
        decoded is Map ? decoded['detail'] : '서버 요청을 처리할 수 없습니다.',
      );
    }
    return Map<String, dynamic>.from(decoded as Map);
  }

  /// 로그인 성공 후 받은 토큰을 저장해 이후 보호된 API 요청에 자동으로 첨부한다.
  Future<Map<String, dynamic>> login(String email, String password) async {
    final result = await _request(
      'POST',
      '/login',
      body: {'email': email, 'password': password},
    );
    _token = result['accessToken'] as String;
    return result;
  }

  /// account: email/password/name/phoneNumber/gender/address/agreed, 선택 age.
  /// startSession이 false이면 가입 후 자동 로그인하지 않고 로그인 화면으로 돌아갈 수 있다.
  Future<Map<String, dynamic>> signup(
    Map<String, dynamic> account, {
    bool startSession = true,
  }) async {
    final result = await _request('POST', '/signup', body: account);
    if (startSession) _token = result['accessToken'] as String;
    return result;
  }

  /// 현재 세션의 회원정보를 가져온다. 비밀번호는 서버 응답에 포함되지 않는다.
  Future<Map<String, dynamic>> me() => _request('GET', '/login/me');

  /// Firebase 가입은 됐지만 MySQL 연결이 실패했을 때 로그인 후 재시도한다.
  Future<Map<String, dynamic>> syncCustomer() =>
      _request('POST', '/signup/sync');

  /// 서버 세션을 폐기하며, 요청이 실패해도 앱에 저장된 토큰은 제거한다.
  Future<void> logout() async {
    try {
      await _request('POST', '/login/logout');
    } finally {
      _token = null;
    }
  }

  /// 리뷰관리 화면의 목록. items와 total로 목록/빈 상태/페이지 이동을 구성한다.
  Future<Map<String, dynamic>> reviews({int limit = 20, int offset = 0}) =>
      _request('GET', '/reviews?limit=$limit&offset=$offset');

  /// 로그인한 회원이 작성한 리뷰의 상세만 조회할 수 있다.
  Future<Map<String, dynamic>> review(int id) =>
      _request('GET', '/reviews/$id');

  /// 구매했고 아직 리뷰를 작성하지 않은 상품을 리뷰작성 선택 목록으로 가져온다.
  Future<Map<String, dynamic>> reviewableProducts({
    int limit = 20,
    int offset = 0,
  }) => _request('GET', '/reviewable-products?limit=$limit&offset=$offset');

  /// 선택한 productCode와 내용/별점/핏을 전달한다. 구매 여부와 중복은 서버가 검증한다.
  Future<Map<String, dynamic>> writeReview({
    required String productCode,
    required String content,
    required int rating,
    String fit = '정사이즈',
  }) => _request(
    'POST',
    '/reviews',
    body: {
      'productCode': productCode,
      'content': content,
      'rating': rating,
      'fit': fit,
    },
  );

  /// 수정 시에는 상품 코드와 소유자를 바꾸지 않고 내용/별점/핏만 보낸다.
  Future<Map<String, dynamic>> updateReview(
    int id, {
    required String content,
    required int rating,
    String fit = '정사이즈',
  }) => _request(
    'PUT',
    '/reviews/$id',
    body: {'content': content, 'rating': rating, 'fit': fit},
  );

  /// 삭제 성공은 204이므로 반환할 JSON 데이터를 기대하지 않는다.
  Future<void> deleteReview(int id) async {
    await _request('DELETE', '/reviews/$id');
  }

  /// 알림 목록 외에 unreadCount가 반환되므로 미읽음 배지를 함께 표시할 수 있다.
  Future<Map<String, dynamic>> notifications({
    int limit = 20,
    int offset = 0,
  }) => _request('GET', '/notifications?limit=$limit&offset=$offset');

  /// 알림을 열었을 때 읽음 처리한다. 타인의 알림 ID로는 처리할 수 없다.
  Future<Map<String, dynamic>> readNotification(int id) =>
      _request('PATCH', '/notifications/$id/read');

  /// 내 미읽음 알림을 일괄 처리하고 updatedCount를 반환받는다.
  Future<Map<String, dynamic>> readAllNotifications() =>
      _request('PATCH', '/notifications/read-all');

  /// 설정 화면을 열 때 저장된 두 스위치 값과 앱 버전을 읽는다.
  Future<Map<String, dynamic>> settings() => _request('GET', '/settings');

  /// null인 항목은 생략하고 false는 그대로 전송해 필요한 설정만 수정한다.
  Future<Map<String, dynamic>> updateSettings({
    bool? orderNotification,
    bool? marketingNotification,
  }) => _request(
    'PATCH',
    '/settings',
    body: {
      'orderNotification': ?orderNotification,
      'marketingNotification': ?marketingNotification,
    },
  );

  /// 로그인하지 않은 사용자에게도 고객센터 안내를 보여줄 수 있다.
  Future<Map<String, dynamic>> faqs() => _request('GET', '/support/faqs');

  /// 내 문의 목록과 본사에서 기록한 답변 상태를 가져온다.
  Future<Map<String, dynamic>> contacts({int limit = 20, int offset = 0}) =>
      _request('GET', '/support/contacts?limit=$limit&offset=$offset');

  /// 선택한 문의 한 건의 본문 및 답변을 확인한다.
  Future<Map<String, dynamic>> contact(int id) =>
      _request('GET', '/support/contacts/$id');

  /// MySQL contact.context 길이에 맞춰 문의를 접수한다(현재 최대 50자).
  Future<Map<String, dynamic>> writeContact(String content) =>
      _request('POST', '/support/contacts', body: {'content': content});
  void dispose() => _client.close();
}

class FitpickApiException implements Exception {
  const FitpickApiException(this.statusCode, this.detail);
  final int statusCode;
  final dynamic detail;
  // FastAPI의 문자열 오류와 입력검증 오류 배열을 화면용 메시지로 바꾼다.
  String get message {
    if (detail is String) return detail as String;
    if (detail is List) {
      return (detail as List)
          .map(
            (error) => error is Map
                ? error['msg']?.toString() ?? '입력값을 확인해 주세요.'
                : '입력값을 확인해 주세요.',
          )
          .join('\n');
    }
    return '요청을 처리할 수 없습니다. 다시 시도해 주세요.';
  }

  @override
  String toString() => message;
}
