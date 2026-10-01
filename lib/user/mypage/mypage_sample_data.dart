// 마이페이지 하위 화면 모델 + 시연용 샘플 데이터.
// DB 연동 시 이 파일의 sample* 값을 DB 조회 결과로 교체하면 됩니다.
import 'mypage_product_list.dart';

class MpCoupon {
  final String name;
  final String discount;
  final String desc;
  final String period;
  final String badge;
  final bool available;

  const MpCoupon({
    required this.name,
    required this.discount,
    required this.desc,
    required this.period,
    required this.badge,
    this.available = false,
  });
}

class MpProfile {
  final String name;
  final String phone;
  final String email;
  final String shoeSize; // 예: 270mm
  final String grade; // 예: 브론즈

  const MpProfile({
    required this.name,
    required this.phone,
    required this.email,
    required this.shoeSize,
    required this.grade,
  });
}

// ---------------- 샘플 데이터 ----------------

List<MpProduct> sampleWishlist() => [
      MpProduct(
        brand: '아디다스',
        brandEn: 'ADIDAS',
        name: '삼바 OG',
        price: 139000,
        target: '남성·공용',
        targetLabel: '공용',
        purpose: '클래식',
        liked: true,
      ),
    ];

List<MpProduct> sampleRecentlyViewed() => [
      MpProduct(
        brand: '뉴발란스',
        brandEn: 'NEW BALANCE',
        name: '530',
        price: 129000,
        target: '남성·공용',
        targetLabel: '공용',
        purpose: '데일리',
      ),
      MpProduct(
        brand: '나이키',
        brandEn: 'NIKE',
        name: "에어 포스 1 '07",
        price: 119000,
        target: '남성·공용',
        targetLabel: '공용',
        purpose: '데일리',
      ),
    ];

const List<MpCoupon> sampleCoupons = [
  MpCoupon(
    name: '회원가입 10%',
    discount: '10% 할인',
    desc: '신규 회원 웰컴 쿠폰',
    period: '2026-09-23 ~ 2026-10-23',
    badge: '사용 가능',
    available: true,
  ),
  MpCoupon(
    name: '첫 리뷰 ₩10,000',
    discount: '₩10,000 할인',
    desc: '첫 구매 리뷰 저장 후 발급',
    period: '2026-10-01 ~ 2026-10-01',
    badge: '첫 리뷰 작성 후 사용 가능',
  ),
  MpCoupon(
    name: '가을 행사 30%',
    discount: '30% 할인',
    desc: '가을 행사 한정 쿠폰',
    period: '2026-09-20 ~ 2026-10-15',
    badge: '행사 기간 한정',
  ),
  MpCoupon(
    name: '골드 15%',
    discount: '15% 할인',
    desc: '회원 등급 혜택 · 발급 후 1년 이내 사용',
    period: '2026-09-23 ~ 2027-09-23',
    badge: '골드 등급 회원 전용',
  ),
  MpCoupon(
    name: 'VIP 20%',
    discount: '20% 할인',
    desc: '회원 등급 혜택 · 발급 후 1년 이내 사용',
    period: '2026-09-23 ~ 2027-09-23',
    badge: 'VIP 등급 회원 전용',
  ),
];

const MpProfile sampleProfile = MpProfile(
  name: '홍길동',
  phone: '010-1234-5678',
  email: 'demo@example.com',
  shoeSize: '270mm',
  grade: '브론즈',
);

const List<String> samplePaymentMethods = ['신용 / 체크카드', '카카오페이', '네이버페이'];
