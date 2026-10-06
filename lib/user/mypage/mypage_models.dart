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

  factory MpCoupon.fromJson(Map<String, dynamic> json) => MpCoupon(
    name: json['name'] as String,
    discount: json['discount'] as String,
    desc: json['desc'] as String,
    period: json['period'] as String,
    badge: json['badge'] as String,
    available: json['available'] as bool,
  );
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

/// GET /mypage/summary 응답 (마이페이지 첫 화면).
class MpSummary {
  final int? shoeSize;
  final String grade;
  final String? favoriteStore;
  final int orderCount;
  final int wishlistCount;
  final int reviewCount;

  const MpSummary({
    required this.shoeSize,
    required this.grade,
    required this.favoriteStore,
    required this.orderCount,
    required this.wishlistCount,
    required this.reviewCount,
  });

  factory MpSummary.fromJson(Map<String, dynamic> json) => MpSummary(
    shoeSize: json['shoe_size'] as int?,
    grade: json['grade'] as String,
    favoriteStore: json['favorite_store'] as String?,
    orderCount: json['order_count'] as int,
    wishlistCount: json['wishlist_count'] as int,
    reviewCount: json['review_count'] as int,
  );
}
