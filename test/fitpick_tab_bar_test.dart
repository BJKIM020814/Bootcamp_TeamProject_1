import 'package:bootcamp_teamproject_1/common/fitpick_tab_bar.dart';
import 'package:bootcamp_teamproject_1/order/cartController.dart';
import 'package:bootcamp_teamproject_1/order/cartPage.dart';
import 'package:bootcamp_teamproject_1/user/authController.dart';
import 'package:bootcamp_teamproject_1/user/mypage/my_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put(AuthController(), permanent: true);
    Get.put(CartController(), permanent: true);
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets(
    'order tab can switch to cart and my without GetX observer errors',
    (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(home: _TabTestPage(selectedIndex: 3)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('장바구니'));
      await tester.pumpAndSettle();
      expect(find.text('tab:2'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('마이'));
      await tester.pumpAndSettle();
      expect(find.text('tab:4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('real cart page can switch to my without GetX observer errors', (
    tester,
  ) async {
    AuthController.to.login(email: 'test@example.com');
    await tester.pumpWidget(
      GetMaterialApp(
        home: const Cartpage(),
        getPages: [GetPage(name: '/my', page: () => const MyPage())],
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('마이'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(find.text('마이페이지'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _TabTestPage extends StatelessWidget {
  const _TabTestPage({required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Text('tab:$selectedIndex')),
    bottomNavigationBar: FitpickTabBar(
      selectedIndex: selectedIndex,
      onSelected: (index) =>
          Get.offAll(() => _TabTestPage(selectedIndex: index)),
    ),
  );
}
