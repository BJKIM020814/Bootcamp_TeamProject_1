import 'package:flutter/material.dart';

import 'mypage_common.dart';
import 'mypage_product_list.dart';

class RecentlyViewedPage extends StatelessWidget {
  final List<MpProduct> products;

  const RecentlyViewedPage({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: mpAppBar('최근 본 상품'),
      body: MpProductListView(products: products),
      bottomNavigationBar: const MpBottomBar(),
    );
  }
}
