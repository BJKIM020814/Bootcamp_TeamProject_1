import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'fitpick_api_service.dart';

/// 서버 응답 오류 / 연결 실패. message 는 화면에 그대로 보여줄 수 있는 문장이다.
class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// FastAPI(python/fastapi/user) 호출 공통 클라이언트.
///
/// 주소는 ApiConfig에서 모든 사용자 API 클라이언트와 공유한다.
/// `--dart-define=API_BASE_URL=http://서버주소:8000`으로 변경할 수 있다.
class ApiClient {
  static const _timeout = Duration(seconds: 8);
  static String get baseUrl => ApiConfig.baseUrl;

  /// 서버가 돌려준 상대 경로(/products/..../image)를 전체 주소로 바꾼다.
  static String absoluteUrl(String path) => '$baseUrl$path';

  static Uri _uri(String path, Map<String, String>? query) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  static Map<String, String> get _jsonHeaders => {
    'Content-Type': 'application/json; charset=utf-8',
    ...FitpickApiService.instance.authorizationHeaders,
  };

  static Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send(() => http.get(_uri(path, query), headers: _jsonHeaders));

  static Future<dynamic> post(String path, Map<String, dynamic> body) => _send(
    () => http.post(
      _uri(path, null),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    ),
  );

  static Future<dynamic> put(String path, Map<String, dynamic> body) => _send(
    () => http.put(
      _uri(path, null),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    ),
  );

  static Future<dynamic> delete(String path, {Map<String, String>? query}) =>
      _send(() => http.delete(_uri(path, query), headers: _jsonHeaders));

  static Future<dynamic> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on TimeoutException {
      throw ApiException('서버 응답이 없습니다. 잠시 후 다시 시도해 주세요.');
    } catch (_) {
      throw ApiException('서버에 연결할 수 없습니다. 서버가 켜져 있는지 확인해 주세요.');
    }

    // 한글이 깨지지 않도록 바이트를 직접 UTF-8 로 해석한다.
    if (response.statusCode == 401) FitpickApiService.instance.clearSession();
    final dynamic data;
    try {
      final text = utf8.decode(response.bodyBytes);
      data = text.isEmpty ? null : jsonDecode(text);
    } on FormatException {
      throw ApiException('서버 응답 형식이 올바르지 않습니다.', response.statusCode);
    }
    if (response.statusCode >= 400) {
      final detail = data is Map ? data['detail'] : null;
      throw ApiException(
        detail is String
            ? detail
            : detail is Map && detail['message'] is String
            ? detail['message'] as String
            : '요청을 처리하지 못했습니다. (${response.statusCode})',
        response.statusCode,
      );
    }
    return data;
  }
}
