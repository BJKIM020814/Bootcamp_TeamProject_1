import 'dart:convert';

import 'package:bootcamp_teamproject_1/discover/discover_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('review response keeps total count for the detail tab label', () async {
    final api = DiscoverApi(
      client: MockClient((request) async {
        expect(request.url.path, contains('/products/SKU-1/reviews'));
        return http.Response(
          jsonEncode({
            'items': [
              {'rating': 5, 'content': 'Good', 'image_url': null},
            ],
            'total': 7,
          }),
          200,
        );
      }),
    );

    final reviews = await api.reviews('SKU-1');
    api.dispose();

    expect(reviews.items, hasLength(1));
    expect(reviews.total, 7);
  });
}
