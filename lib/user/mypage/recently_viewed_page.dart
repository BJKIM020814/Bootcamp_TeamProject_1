import 'package:flutter/material.dart';

import 'package:bootcamp_teamproject_1/services/mypage_api.dart';
import 'package:bootcamp_teamproject_1/user/authController.dart';

import 'mypage_common.dart';
import 'mypage_loader.dart';
import 'mypage_product_list.dart';

/// 로그인 사용자의 최근 본 상품을 서버 데이터로 보여주는 화면.
class RecentlyViewedPage extends StatelessWidget {
  const RecentlyViewedPage({super.key});

  /// 공통 상품 목록 UI를 재사용하고 찜 변경은 사용자 계정 API에 반영한다.
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
