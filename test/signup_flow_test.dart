// 가입 성공 시 로그인 복귀와 이메일 자동 입력, 실패 시 화면 유지 및 오류 표시를 검증한다.
import 'dart:convert';
import 'package:bootcamp_teamproject_1/services/fitpick_api_service.dart';
import 'package:bootcamp_teamproject_1/user/loginpage.dart';
import 'package:bootcamp_teamproject_1/user/signuppage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Future<void> fillSignup(WidgetTester tester) async {
  final inputs = find.byType(TextFormField);
  for (final entry in [
    '홍길동',
    'user@example.com',
    'password123',
    '010-1234-5678',
    '서울',
  ].asMap().entries) {
    await tester.enterText(inputs.at(entry.key), entry.value);
  }
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pump();
}

void main() {
  testWidgets('successful signup returns to login with the email filled', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var signupRequests = 0;
    final api = FitpickApiService(
      client: MockClient((request) async {
        expect(request.url.path, '/api/signup');
        expect(jsonDecode(request.body)['agreed'], isTrue);
        signupRequests++;
        return http.Response(
          jsonEncode({'accessToken': 'signup-token', 'customerSynced': true}),
          201,
        );
      }),
    );
    await tester.pumpWidget(MaterialApp(home: LoginPage(api: api)));
    await tester.tap(find.widgetWithText(OutlinedButton, '회원가입'));
    await tester.pumpAndSettle();
    await fillSignup(tester);
    await tester.tap(find.widgetWithText(FilledButton, '회원가입'));
    await tester.pumpAndSettle();
    expect(signupRequests, 1);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(SignUpPage), findsNothing);
    expect(find.text('user@example.com'), findsOneWidget);
    expect(api.hasSession, isFalse);
    api.dispose();
  });

  testWidgets('failed signup keeps form visible and shows the server error', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = FitpickApiService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({'detail': '이미 가입된 이메일입니다.'}),
          409,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    await tester.pumpWidget(MaterialApp(home: SignUpPage(api: api)));
    await fillSignup(tester);
    await tester.tap(find.widgetWithText(FilledButton, '회원가입'));
    await tester.pumpAndSettle();
    expect(find.byType(SignUpPage), findsOneWidget);
    expect(find.text('이미 가입된 이메일입니다.'), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
    api.dispose();
  });
}
