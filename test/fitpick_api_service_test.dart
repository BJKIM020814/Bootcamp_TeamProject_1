// API 어댑터의 토큰 전달/로그아웃/만료 처리와 PATCH 요청을 가짜 HTTP로 확인한다.
import 'dart:convert';
import 'package:bootcamp_teamproject_1/services/fitpick_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'login token is sent to protected routes and removed on logout',
    () async {
      final requests = <http.Request>[];
      final api = FitpickApiService(
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/api/login') {
            expect(jsonDecode(request.body)['password'], 'secret password ');
            return http.Response(
              jsonEncode({'accessToken': 'test-token'}),
              200,
            );
          }
          if (request.url.path == '/api/login/logout') {
            return http.Response('', 204);
          }
          return http.Response(jsonEncode({'items': []}), 200);
        }),
      );
      await api.login('user@example.com', 'secret password ');
      await api.reviews();
      expect(requests.last.headers['Authorization'], 'Bearer test-token');
      await api.logout();
      expect(api.hasSession, isFalse);
      await api.faqs();
      expect(requests.last.headers.containsKey('Authorization'), isFalse);
      api.dispose();
    },
  );

  test('expired session clears token and returns API error', () async {
    final api = FitpickApiService(
      client: MockClient((request) async {
        if (request.url.path == '/api/login') {
          return http.Response('{"accessToken":"test-token"}', 200);
        }
        return http.Response('{"detail":"expired"}', 401);
      }),
    );
    await api.login('user@example.com', 'password');
    await expectLater(api.settings(), throwsA(isA<FitpickApiException>()));
    expect(api.hasSession, isFalse);
    api.dispose();
  });

  test('settings patch sends only provided fields including false', () async {
    final api = FitpickApiService(
      client: MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(jsonDecode(request.body), {'orderNotification': false});
        return http.Response('{}', 200);
      }),
    );
    await api.updateSettings(orderNotification: false);
    api.dispose();
  });
}
