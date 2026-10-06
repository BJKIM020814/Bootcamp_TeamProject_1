import 'package:bootcamp_teamproject_1/common/review_image_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty review image reserves space and explains no image', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ReviewImageView(imageUrl: null, height: 180)),
      ),
    );

    expect(find.text('등록된 이미지가 없습니다'), findsOneWidget);
    expect(tester.getSize(find.byType(ReviewImageView)).height, 180);
  });
}
