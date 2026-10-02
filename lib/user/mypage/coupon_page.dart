import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:bootcamp_teamproject_1/discover/product_list_page.dart';

import 'package:bootcamp_teamproject_1/services/mypage_api.dart';

import 'mypage_common.dart';
import 'mypage_loader.dart';
import 'mypage_models.dart';
import 'mypage_controller.dart';

class CouponPage extends StatelessWidget {
  const CouponPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: mpAppBar('쿠폰'),
      body: MpLoader<List<MpCoupon>>(
        load: MyPageApi.coupons,
        builder: (context, coupons) => _buildBody(coupons),
      ),
      bottomNavigationBar: const MpBottomBar(),
    );
  }

  Widget _buildBody(List<MpCoupon> coupons) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: [
        const Text(
          '나의 쿠폰함',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: MpColors.ink,
          ),
        ),
        const SizedBox(height: 12),
        Obx(
          () => Text(
            '현재 등급: ${MyPageController.to.grade.value} · 할인 쿠폰은 한 번에 1개만 적용됩니다.',
            style: const TextStyle(fontSize: 14, color: MpColors.icon),
          ),
        ),
        const SizedBox(height: 20),
        ...coupons.map(_buildCoupon),
        const SizedBox(height: 4),
        const MpNotice(
          '가을 행사 30% 쿠폰은 2026.09.20~10.15에만 사용 가능합니다. '
          '회원가입·첫 리뷰 쿠폰은 발급일로부터 30일 이내 사용합니다.',
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 56,
          child: OutlinedButton(
            onPressed: () => Get.to(() => const ProductListPage()),
            style: OutlinedButton.styleFrom(
              foregroundColor: MpColors.ink,
              side: const BorderSide(color: MpColors.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              '새로운 한 켤레 찾기',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoupon(MpCoupon c) {
    final bool on = c.available;
    return Opacity(
      opacity: on ? 1 : 0.45,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        width: double.infinity,
        decoration: BoxDecoration(
          color: on ? const Color(0xFFF4F7F5) : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: MpColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.confirmation_number_outlined,
              size: 34,
              color: on ? const Color(0xFF6E9C8A) : MpColors.icon,
            ),
            const SizedBox(height: 18),
            Text(
              c.name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: on ? const Color(0xFF5E8574) : MpColors.icon,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              c.discount,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: MpColors.ink,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              c.desc,
              style: const TextStyle(fontSize: 13, color: MpColors.sub),
            ),
            const SizedBox(height: 12),
            Text(
              c.period,
              style: const TextStyle(fontSize: 13, color: MpColors.sub),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEDF0F3),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                c.badge,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5C6B75),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
