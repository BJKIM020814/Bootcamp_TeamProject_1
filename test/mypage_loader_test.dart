import 'dart:async';

import 'package:bootcamp_teamproject_1/user/authController.dart';
import 'package:bootcamp_teamproject_1/user/mypage/mypage_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  tearDown(() => Get.reset());

  testWidgets('계정 전환 후 이전 계정의 늦은 응답을 표시하지 않는다', (tester) async {
    final first = Completer<String>();
    final second = Completer<String>();
    final auth = AuthController.to;
    auth.login(email: 'first@example.com');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MpLoader<String>(
            load: (id) =>
                id == 'first@example.com' ? first.future : second.future,
            builder: (_, data) => Text(data),
          ),
        ),
      ),
    );
    auth.login(email: 'second@example.com');
    await tester.pump();
    first.complete('이전 계정 정보');
    await tester.pump();
    expect(find.text('이전 계정 정보'), findsNothing);
    second.complete('현재 계정 정보');
    await tester.pumpAndSettle();
    expect(find.text('현재 계정 정보'), findsOneWidget);
    auth.logout();
    await tester.pumpAndSettle();
    expect(find.text('현재 계정 정보'), findsNothing);
    expect(find.text('로그인이 필요합니다.'), findsOneWidget);
  });

  testWidgets('조회 오류 후 재시도로 복구한다', (tester) async {
    var attempts = 0;
    AuthController.to.login(email: 'self@example.com');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MpLoader<String>(
            load: (_) async {
              if (++attempts == 1) throw Exception('연결 오류');
              return '복구됨';
            },
            builder: (_, data) => Text(data),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('연결 오류'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('복구됨'), findsOneWidget);
    expect(attempts, 2);
  });
}
