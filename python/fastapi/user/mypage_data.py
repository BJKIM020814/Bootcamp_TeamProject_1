"""마이페이지(프로필/결제수단/쿠폰/찜/최근 본 상품) 데이터 접근 함수

이름·전화번호·신발 사이즈의 원본은 Firebase account, 비밀번호 검증은 Firebase Auth이다.
MySQL 쪽은 누적결제금액(등급), 기본 결제수단, 찜/최근 본 상품, 쿠폰을 다룬다.
기존 customer_setting.shoe_size는 호환 조회만 유지하고 고객 API에서 직접 변경하지 않는다.
모든 쿼리는 db.py 의 파라미터 바인딩(%s)을 사용한다.
"""
import re
from urllib.parse import quote
from datetime import datetime, timedelta

from python import db

PAYMENT_METHODS = ["신용 / 체크카드", "카카오페이", "네이버페이"]
SHOE_SIZES = range(220, 311, 5)
RECENT_LIMIT = 30  # 최근 본 상품 보관 개수
# Discover 목록과 동일하게, 정상 이미지가 등록되어 실제 노출되는 상품 모델만 사용한다.
_VALID_DISCOVER_IMAGE = "(OCTET_LENGTH({alias}.p_image) >= 1024 AND ("
_VALID_DISCOVER_IMAGE += "LEFT({alias}.p_image,3)=0xFFD8FF OR "
_VALID_DISCOVER_IMAGE += "LEFT({alias}.p_image,8)=0x89504E470D0A1A0A OR "
_VALID_DISCOVER_IMAGE += "(LEFT({alias}.p_image,4)=0x52494646 AND "
_VALID_DISCOVER_IMAGE += "SUBSTRING({alias}.p_image,9,4)=0x57454250)))"

# 누적결제금액 기준 등급 (하한, 등급명). 아래에서 위로 갈수록 높은 등급.
_GRADES = [(0, "브론즈"), (300_000, "실버"), (1_000_000, "골드"), (3_000_000, "VIP")]
_EMAIL = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


class MyPageError(Exception):
    """업무 규칙 위반. status 는 라우터에서 HTTP 상태코드로 쓴다."""

    def __init__(self, message, status=400):
        super().__init__(message)
        self.status = status


def grade_of(total_price):
    grade = _GRADES[0][1]
    for floor, name in _GRADES:
        if total_price >= floor:
            grade = name
    return grade


# ---------- 회원 / 설정 ----------
def ensure_customer(customer_id):
    """조회는 기존 회원 연결만 확인한다. 빈 프로필을 임의 생성하지 않는다."""
    if not customer_id or len(customer_id) > 45 or not _EMAIL.match(customer_id):
        raise MyPageError("올바른 customer_id(이메일)가 아닙니다.", 422)
    if db.query_one('SELECT customer_id FROM customer WHERE customer_id=%s', (customer_id,)) is None:
        raise MyPageError('쇼핑 회원정보 연결이 필요합니다. 로그인 후 동기화를 확인해 주세요.', 409)


def ensure_settings(customer_id):
    # 설정 저장 요청에서만 행을 생성한다. GET에는 DB 쓰기가 없어야 한다.
    ensure_customer(customer_id)
    db.execute("INSERT IGNORE INTO customer_setting (customer_id) VALUES (%s)", (customer_id,))


def get_profile(customer_id):
    ensure_customer(customer_id)
    row = db.query_one(
        "SELECT s.shoe_size, s.default_payment, s.favorite_dealer_seq, d.name AS favorite_store, "
        "c.totalprice AS total_price "
        "FROM customer c LEFT JOIN customer_setting s ON c.customer_id = s.customer_id "
        "LEFT JOIN authorized_dealer d ON d.seq = s.favorite_dealer_seq "
        "WHERE c.customer_id = %s",
        (customer_id,),
    )
    if row is None:
        raise MyPageError('회원정보를 찾을 수 없습니다.', 404)
    row['default_payment'] = row['default_payment'] or PAYMENT_METHODS[0]
    row["grade"] = grade_of(row["total_price"])
    return row


def update_profile(customer_id, shoe_size=None, favorite_dealer_seq=None):
    ensure_customer(customer_id)
    sets, params = [], []
    if shoe_size is not None:
        if shoe_size not in SHOE_SIZES:
            raise MyPageError("신발 사이즈는 220~310mm, 5mm 단위로 선택해 주세요.", 422)
        sets.append("shoe_size = %s")
        params.append(shoe_size)
    if favorite_dealer_seq is not None:
        if db.query_one(
            "SELECT 1 AS found FROM authorized_dealer WHERE seq = %s", (favorite_dealer_seq,)
        ) is None:
            raise MyPageError("존재하지 않는 매장입니다.", 404)
        sets.append("favorite_dealer_seq = %s")
        params.append(favorite_dealer_seq)
    if sets:
        ensure_settings(customer_id)
        db.execute(
            f"UPDATE customer_setting SET {', '.join(sets)} WHERE customer_id = %s",
            (*params, customer_id),
        )
    return get_profile(customer_id)


def set_default_payment(customer_id, method):
    ensure_customer(customer_id)
    if method not in PAYMENT_METHODS:
        raise MyPageError("지원하지 않는 결제수단입니다.", 422)
    ensure_settings(customer_id)
    db.execute(
        "UPDATE customer_setting SET default_payment = %s WHERE customer_id = %s",
        (method, customer_id),
    )
    return {"methods": PAYMENT_METHODS, "default": method}


def get_payment(customer_id):
    return {"methods": PAYMENT_METHODS, "default": get_profile(customer_id)["default_payment"]}


def get_summary(customer_id):
    """마이페이지 첫 화면: 등급/사이즈/즐겨찾기 매장 + 주문·찜·리뷰 개수."""
    profile = get_profile(customer_id)

    def count(sql):
        return db.query_one(sql, (customer_id,))["n"]

    return {
        "shoe_size": profile["shoe_size"],
        "grade": profile["grade"],
        "favorite_store": profile["favorite_store"],
        "order_count": count("SELECT COUNT(DISTINCT order_code) AS n FROM purchase WHERE customer_customer_id = %s"),
        "wishlist_count": count("SELECT COUNT(*) AS n FROM wishlist WHERE customer_id = %s"),
        "review_count": count("SELECT COUNT(*) AS n FROM review WHERE customer_customer_id = %s"),
    }


# ---------- 상품 목록 (찜 / 최근 본) ----------
def _product_row(row):
    code = row["p_code"]
    return {
        "p_code": code,
        "brand": row["b_name"],
        "name": row["p_name"],
        "price": int(str(row["p_price"]).replace(",", "")),
        "gender": row["p_gender"],
        "liked": bool(row["liked"]),
        "image_url": f"/api/v1/products/{quote(code, safe='')}/image",
    }


def get_wishlist(customer_id):
    ensure_customer(customer_id)
    rows = db.query(
        "SELECT p.p_code, p.p_name, p.b_name, p.p_price, p.p_gender, 1 AS liked "
        "FROM wishlist w JOIN product p ON p.p_code = w.p_code "
        "WHERE w.customer_id = %s ORDER BY w.created_at DESC",
        (customer_id,),
    )
    return [_product_row(r) for r in rows]


def _require_product(p_code):
    if db.query_one("SELECT 1 AS found FROM product WHERE p_code = %s", (p_code,)) is None:
        raise MyPageError("존재하지 않는 상품입니다.", 404)


def add_wishlist(customer_id, p_code):
    ensure_customer(customer_id)
    _require_product(p_code)
    db.execute(
        "INSERT IGNORE INTO wishlist (customer_id, p_code) VALUES (%s, %s)", (customer_id, p_code)
    )


def remove_wishlist(customer_id, p_code):
    db.execute("DELETE FROM wishlist WHERE customer_id = %s AND p_code = %s", (customer_id, p_code))


def get_recently_viewed(customer_id):
    ensure_customer(customer_id)
    rows = db.query(
        "SELECT shown.p_code, shown.p_name, shown.b_name, shown.p_price, shown.p_gender, "
        "(w.p_code IS NOT NULL) AS liked FROM ("
        "SELECT visible.p_code, visible.p_name, visible.b_name, visible.p_price, "
        "visible.p_gender, MAX(r.viewed_at) AS viewed_at "
        "FROM recently_viewed r JOIN product source ON source.p_code = r.p_code "
        "JOIN (SELECT MIN(p_code) AS p_code, p_name, b_name, p_gender FROM product p "
        f"WHERE {_VALID_DISCOVER_IMAGE.format(alias='p')} "
        "GROUP BY p_name, b_name, p_gender) models "
        "ON models.p_name = source.p_name AND models.b_name = source.b_name "
        "AND models.p_gender = source.p_gender "
        "JOIN product visible ON visible.p_code = models.p_code "
        "WHERE r.customer_id = %s "
        "GROUP BY visible.p_code, visible.p_name, visible.b_name, visible.p_price, visible.p_gender"
        ") shown LEFT JOIN wishlist w ON w.customer_id = %s AND w.p_code = shown.p_code "
        "ORDER BY shown.viewed_at DESC LIMIT %s",
        (customer_id, customer_id, RECENT_LIMIT),
    )
    return [_product_row(r) for r in rows]


def record_view(customer_id, p_code):
    """노출 가능한 상품 모델의 대표 상품코드를 기록하고 오래된 기록은 정리한다."""
    ensure_customer(customer_id)
    valid = _VALID_DISCOVER_IMAGE.format(alias='p1')
    variant = _VALID_DISCOVER_IMAGE.format(alias='p2')
    visible = db.query_one(
        "SELECT MIN(p2.p_code) AS p_code FROM product p1 "
        "JOIN product p2 ON p2.p_name = p1.p_name AND p2.b_name = p1.b_name "
        "AND p2.p_gender = p1.p_gender AND " + variant +
        " WHERE p1.p_code = %s AND " + valid +
        " GROUP BY p1.p_name, p1.b_name, p1.p_gender",
        (p_code,),
    )
    if visible is None or visible["p_code"] is None:
        raise MyPageError("Discover에 노출되지 않는 상품은 최근 본 상품에 기록할 수 없습니다.", 404)
    p_code = visible["p_code"]
    db.execute(
        "INSERT INTO recently_viewed (customer_id, p_code) VALUES (%s, %s) "
        "ON DUPLICATE KEY UPDATE viewed_at = NOW()",
        (customer_id, p_code),
    )
    db.execute(
        "DELETE FROM recently_viewed WHERE customer_id = %s AND p_code NOT IN "
        "(SELECT p_code FROM (SELECT p_code FROM recently_viewed WHERE customer_id = %s "
        "ORDER BY viewed_at DESC LIMIT %s) AS keep)",
        (customer_id, customer_id, RECENT_LIMIT),
    )


def get_product_image(p_code):
    row = db.query_one("SELECT p_image FROM product WHERE p_code = %s", (p_code,))
    return row["p_image"] if row else None


# ---------- 쿠폰 ----------
def _discount_label(kind, value):
    return f"{value}% 할인" if kind == "PERCENT" else f"₩{value:,} 할인"


def _issue_due_coupons(customer_id, coupons, now):
    """조건을 만족했는데 아직 발급되지 않은 쿠폰을 발급한다. (가입 / 첫 리뷰 / 행사 기간)"""
    has_review = db.query_one(
        "SELECT 1 AS found FROM review WHERE customer_customer_id = %s LIMIT 1", (customer_id,)
    ) is not None
    for c in coupons:
        if c["issued_at"] is not None:
            continue
        kind = c["condition_type"]
        if kind in ('SIGNUP', 'FIRST_REVIEW') and (not isinstance(c['valid_days'], int) or c['valid_days'] <= 0):
            raise MyPageError('쿠폰 유효기간 설정을 확인해 주세요.', 409)
        if kind == "SIGNUP":
            expires = now + timedelta(days=c["valid_days"])
        elif kind == "FIRST_REVIEW" and has_review:
            expires = now + timedelta(days=c["valid_days"])
        elif kind == "EVENT" and c["event_start"] is not None and c["event_end"] is not None and c["event_start"] <= now <= c["event_end"]:
            expires = c["event_end"]
        else:
            continue
        db.execute(
            "INSERT IGNORE INTO customer_coupon (customer_id, coupon_id, issued_at, expires_at) "
            "VALUES (%s, %s, %s, %s)",
            (customer_id, c["coupon_id"], now, expires),
        )
        c["issued_at"], c["expires_at"], c["used_at"] = now, expires, None


def get_coupons(customer_id, issue=False):
    """쿠폰함 GET은 읽기 전용. 발급은 명시적인 POST에서만 실행한다."""
    ensure_customer(customer_id)
    now = datetime.now()
    sql = (
        "SELECT c.coupon_id, c.name, c.discount_type, c.discount_value, c.description, "
        "c.condition_type, c.valid_days, c.event_start, c.event_end, c.locked_badge, "
        "cc.issued_at, cc.expires_at, cc.used_at "
        "FROM coupon c LEFT JOIN customer_coupon cc "
        "ON cc.coupon_id = c.coupon_id AND cc.customer_id = %s ORDER BY c.coupon_id"
    )
    coupons = db.query(sql, (customer_id,))
    if issue:
        _issue_due_coupons(customer_id, coupons, now)

    result = []
    for c in coupons:
        issued = c["issued_at"] is not None
        if issued and c["used_at"] is not None:
            badge, available = "사용 완료", False
        elif issued and c['expires_at'] is None:
            raise MyPageError('쿠폰 만료일 설정을 확인해 주세요.', 409)
        elif issued and c["expires_at"] < now:
            badge, available = "기간 만료", False
        elif issued:
            badge, available = "사용 가능", True
        else:
            badge, available = c["locked_badge"], False

        if issued:
            period = f"{c['issued_at']:%Y-%m-%d} ~ {c['expires_at']:%Y-%m-%d}"
        elif c["condition_type"] == "EVENT" and c['event_start'] is not None and c['event_end'] is not None:
            period = f"{c['event_start']:%Y-%m-%d} ~ {c['event_end']:%Y-%m-%d}"
        else:
            period = "첫 리뷰 작성 후 발급"
        result.append({
            "coupon_id": c["coupon_id"],
            "name": c["name"],
            "discount": _discount_label(c["discount_type"], c["discount_value"]),
            "desc": c["description"],
            "period": period,
            "badge": badge,
            "available": available,
        })
    return result
