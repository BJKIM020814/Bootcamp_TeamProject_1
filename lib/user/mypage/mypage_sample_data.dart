// 마이페이지 화면에서 사용하는 시연용 데이터입니다.
// 서버 연동 시에는 호출부를 바꾸지 않고, 각 sample 값만 API/DB 결과로 교체합니다.
import 'mypage_models.dart';
import 'mypage_product_list.dart';

/// 프로필·사이즈 카드·내 정보 수정 화면에서 공통으로 사용하는 사용자 정보.
const MpProfile sampleProfile = MpProfile(
  name: '홍길동',
  phone: '010-1234-5678',
  email: 'demo@example.com',
  shoeSize: '270mm',
  grade: '브론즈',
);

/// 서버 주문/리뷰 집계가 연결되기 전 마이페이지에 표시할 시연용 수치.
const int sampleOrderCount = 5;
const int sampleReviewCount = 0;
const String sampleFavoriteStoreName = '강남 스토어';

/// 찜 해제 화면의 변경이 원본 데이터에 남지 않도록 매 호출마다 새 목록을 반환합니다.
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

/// 최근 본 상품 화면의 시연용 목록입니다.
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

/// 쿠폰함에 표시할 시연용 쿠폰 목록입니다.
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
    period: '첫 리뷰 작성 후 발급',
    badge: '첫 리뷰 작성 후 사용 가능',
  ),
  MpCoupon(
    name: '가을 행사 30%',
    discount: '30% 할인',
    desc: '가을 행사 한정 쿠폰',
    period: '2026-09-20 ~ 2026-10-15',
    badge: '행사 기간 한정',
  ),
];
