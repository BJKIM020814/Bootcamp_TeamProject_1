// 마이페이지 하위 화면 모델.
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
