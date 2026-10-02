import 'package:flutter/material.dart';

import 'package:bootcamp_teamproject_1/services/mypage_api.dart';
import 'package:bootcamp_teamproject_1/user/authController.dart';

import 'mypage_common.dart';
import 'mypage_loader.dart';
import 'mypage_product_list.dart';

class RecentlyViewedPage extends StatelessWidget {
  const RecentlyViewedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: mpAppBar('최근 본 상품'),
      body: MpLoader<List<MpProduct>>(
        load: MyPageApi.recentlyViewed,
        builder: (_, products) => MpProductListView(
          products: products,
          onToggleLike: (p) {
            final id = AuthController.to.customerId.value!;
            return p.liked
                ? MyPageApi.addWish(id, p.pCode)
                : MyPageApi.removeWish(id, p.pCode);
          },
        ),
      ),
      bottomNavigationBar: const MpBottomBar(),
    );
  }
}
