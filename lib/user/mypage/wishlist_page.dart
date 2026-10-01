import 'package:flutter/material.dart';

import 'mypage_common.dart';
import 'mypage_product_list.dart';

class WishlistPage extends StatelessWidget {
  final List<MpProduct> products;

  const WishlistPage({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: mpAppBar('찜한 상품'),
      body: MpProductListView(products: products, removeOnUnlike: true),
      bottomNavigationBar: const MpBottomBar(),
    );
  }
}
