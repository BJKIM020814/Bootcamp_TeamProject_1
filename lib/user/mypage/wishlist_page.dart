import 'package:flutter/material.dart';

import 'package:bootcamp_teamproject_1/services/mypage_api.dart';
import 'package:bootcamp_teamproject_1/user/authController.dart';

import 'mypage_common.dart';
import 'mypage_loader.dart';
import 'mypage_product_list.dart';

class WishlistPage extends StatelessWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: mpAppBar('찜한 상품'),
      body: MpLoader<List<MpProduct>>(
        load: MyPageApi.wishlist,
        builder: (_, products) => MpProductListView(
          products: products,
          removeOnUnlike: true,
          // 이 화면에서는 하트를 누르면 곧 찜 해제 / 되돌리면 다시 찜
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
