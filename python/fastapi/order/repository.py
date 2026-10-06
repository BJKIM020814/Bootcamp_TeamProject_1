"""Storage queries for Order: SQLite cart and MySQL catalogue/checkout data.

주문 시 가격·할인은 클라이언트 값을 믿지 않고 product/coupon 테이블로 다시 계산한다.
주문 생성·취소·수령·신청처럼 여러 행을 바꾸는 작업은 하나의 트랜잭션으로 묶는다.
수령 대리점은 판매 재고가 아닌 수령 장소이므로 대리점 재고는 조회하지 않는다. (Discover 와 동일)
"""
import os
import secrets
from contextlib import contextmanager
from datetime import datetime, timedelta

import pymysql
from python import db
from ..dependencies import get_local

MAX_QUANTITY = 10
PICKUP_HOLD_DAYS = 3          # 수령 준비 완료 후 매장 보관 기간
PICKUP_CODE_MINUTES = 10      # 수령 인증번호 유효 시간

# 주문 진행 순서. 한 단계씩만 앞으로 진행한다.
ORDER_FLOW = ["PAID", "PREPARING", "SHIPPING", "INSPECTING", "READY", "PICKED_UP"]
CANCELLABLE = {"PAID", "PREPARING"}
CLAIM_FLOW = ["RECEIVED", "CONFIRMED", "VISIT", "DONE"]


class OrderError(Exception):
    """업무 규칙 위반. 라우터에서 HTTP 상태코드와 code/message 로 바꾼다."""

    def __init__(self, status, code, message):
        super().__init__(message)
        self.status, self.code, self.message = status, code, message


@contextmanager
def _transaction():
    with db.connection() as conn:
        try:
            with conn.cursor() as cur:
                yield cur
            conn.commit()
        except pymysql.MySQLError as exc:
            conn.rollback()
            raise db.DBError("MySQL transaction failed") from exc
        except Exception:
            conn.rollback()
            raise


# ---------- 장바구니 ----------
_CART_COLUMNS = (
    "c.cart_item_id, c.quantity, c.selected, p.p_code, p.p_name, p.b_name, p.p_price, "
    "p.p_color, p.p_size, OCTET_LENGTH(p.p_image) AS image_bytes"
)


def list_cart(customer_id, selected_only=False):
    # 장바구니의 소유자·수량·선택 상태는 SQLite에 두고 상품의 최신 표시는 MySQL에서 읽는다.
    predicate = "customer_id = ?" + (" AND selected = 1" if selected_only else "")
    with get_local().connection() as conn:
        cart_rows = [dict(row) for row in conn.execute(
            f"SELECT cart_item_id, p_code, quantity, selected FROM cart_items "
            f"WHERE {predicate} ORDER BY added_at DESC, cart_item_id DESC", (customer_id,)
        ).fetchall()]
    if not cart_rows:
        return []
    codes = [row["p_code"] for row in cart_rows]
    marks = ", ".join(["%s"] * len(codes))
    products = db.query(
        "SELECT p_code, p_name, b_name, p_price, p_color, p_size, "
        "OCTET_LENGTH(p_image) AS image_bytes FROM product "
        f"WHERE p_code IN ({marks})", codes,
    )
    by_code = {row["p_code"]: row for row in products}
    return [{**by_code[row["p_code"]], **row} for row in cart_rows if row["p_code"] in by_code]


def product_exists(product_code):
    return db.query_one("SELECT 1 AS found FROM product WHERE p_code = %s", (product_code,)) is not None


def add_cart_item(customer_id, product_code, quantity):
    """같은 상품을 다시 담으면 수량을 더하고 선택 상태로 만든다."""
    with get_local().connection() as conn:
        conn.execute(
            "INSERT INTO cart_items (customer_id, p_code, quantity, selected) VALUES (?, ?, ?, 1) "
            "ON CONFLICT(customer_id, p_code) DO UPDATE SET "
            "quantity = MIN(cart_items.quantity + excluded.quantity, ?), selected = 1",
            (customer_id, product_code, quantity, MAX_QUANTITY),
        )


def update_cart_item(customer_id, cart_item_id, quantity=None, selected=None):
    has_updates = quantity is not None or selected is not None
    with get_local().connection() as conn:
        cursor = conn.execute("SELECT 1 FROM cart_items WHERE customer_id = ? AND cart_item_id = ?",
                              (customer_id, cart_item_id))
        if cursor.fetchone() is None:
            raise OrderError(404, "CART_ITEM_NOT_FOUND", "장바구니 상품을 찾을 수 없습니다.")
        if has_updates:
            assignments, sqlite_params = [], []
            if quantity is not None:
                assignments.append("quantity = ?")
                sqlite_params.append(quantity)
            if selected is not None:
                assignments.append("selected = ?")
                sqlite_params.append(int(selected))
            conn.execute(f"UPDATE cart_items SET {', '.join(assignments)} "
                         "WHERE customer_id = ? AND cart_item_id = ?",
                         (*sqlite_params, customer_id, cart_item_id))


def delete_cart_item(customer_id, cart_item_id):
    with get_local().connection() as conn:
        deleted = conn.execute("DELETE FROM cart_items WHERE customer_id = ? AND cart_item_id = ?",
                               (customer_id, cart_item_id)).rowcount
    if not deleted:
        raise OrderError(404, "CART_ITEM_NOT_FOUND", "장바구니 상품을 찾을 수 없습니다.")


def delete_selected_cart_items(customer_id):
    with get_local().connection() as conn:
        return conn.execute("DELETE FROM cart_items WHERE customer_id = ? AND selected = 1",
                            (customer_id,)).rowcount


def select_all_cart_items(customer_id, selected):
    with get_local().connection() as conn:
        conn.execute("UPDATE cart_items SET selected = ? WHERE customer_id = ?",
                     (int(selected), customer_id))


# ---------- 수령 매장 ----------
_DEALER_COLUMNS = "seq, name, dealer_number, manager, address, lat, lng"


def get_dealer(seq):
    return db.query_one(f"SELECT {_DEALER_COLUMNS} FROM authorized_dealer WHERE seq = %s", (seq,))


def get_cart_pickup(customer_id):
    """장바구니에서 고른 매장 → 마이페이지 단골 매장 순으로 찾는다."""
    with get_local().connection() as conn:
        selected = conn.execute("SELECT dealer_seq FROM cart_pickups WHERE customer_id = ?",
                                (customer_id,)).fetchone()
    dealer_seq = selected["dealer_seq"] if selected else None
    if dealer_seq is None:
        row = db.query_one("SELECT favorite_dealer_seq FROM customer_setting WHERE customer_id = %s",
                           (customer_id,))
        dealer_seq = row["favorite_dealer_seq"] if row else None
    return get_dealer(dealer_seq) if dealer_seq is not None else None


def set_cart_pickup(customer_id, dealer_seq):
    if get_dealer(dealer_seq) is None:
        raise OrderError(404, "STORE_NOT_FOUND", "수령 매장을 찾을 수 없습니다.")
    with get_local().connection() as conn:
        conn.execute("INSERT INTO cart_pickups (customer_id, dealer_seq) VALUES (?, ?) "
                     "ON CONFLICT(customer_id) DO UPDATE SET dealer_seq = excluded.dealer_seq",
                     (customer_id, dealer_seq))


# ---------- 쿠폰 ----------
def discount_of(coupon, subtotal):
    if coupon["discount_type"] == "PERCENT":
        return min(subtotal, round(subtotal * coupon["discount_value"] / 100))
    return min(subtotal, coupon["discount_value"])


def available_coupons(customer_id):
    """발급됐고 사용하지 않았으며 만료되지 않은 쿠폰. (발급 자체는 마이페이지 쿠폰함 로직이 담당)"""
    return db.query(
        "SELECT c.coupon_id, c.name, c.discount_type, c.discount_value, cc.expires_at "
        "FROM customer_coupon cc JOIN coupon c ON c.coupon_id = cc.coupon_id "
        "WHERE cc.customer_id = %s AND cc.used_at IS NULL AND cc.expires_at >= %s ORDER BY c.coupon_id",
        (customer_id, datetime.now()),
    )


# ---------- 주문 ----------
_ORDER_COLUMNS = (
    "order_number, customer_id, orderer_name, orderer_phone, dealer_seq, store_name, store_address, "
    "payment_method, coupon_id, coupon_name, subtotal, discount, paid_amount, status, ordered_at, "
    "status_changed_at, ready_at, picked_up_at, cancelled_at"
)
_ITEM_COLUMNS = (
    "i.order_item_id, i.order_number, i.p_code, i.p_name, i.b_name, i.p_color, i.p_size, "
    "i.unit_price, i.quantity, OCTET_LENGTH(p.p_image) AS image_bytes"
)


def _next_order_number(cur, now):
    prefix = f"FP{now:%y%m%d}-"
    cur.execute("SELECT order_number FROM shop_order WHERE order_number LIKE %s "
                "ORDER BY LENGTH(order_number) DESC, order_number DESC LIMIT 1 FOR UPDATE", (prefix + "%",))
    row = cur.fetchone()
    seq = int(row["order_number"][len(prefix):]) + 1 if row else 1
    return f"{prefix}{seq:03d}"


def create_order(customer_id, data, payment_methods):
    if not data.agreed:
        raise OrderError(422, "AGREEMENT_REQUIRED", "주문 내용 확인에 동의해 주세요.")
    if data.payment_method not in payment_methods:
        raise OrderError(422, "INVALID_PAYMENT_METHOD", "지원하지 않는 결제수단입니다.")
    now = datetime.now()
    with _transaction() as cur:
        # 장바구니 행을 잠가 같은 상품이 두 번 주문되지 않게 한다.
        cur.execute(f"SELECT {_CART_COLUMNS} FROM cart_item c JOIN product p ON p.p_code = c.p_code "
                    "WHERE c.customer_id = %s AND c.selected = 1 ORDER BY c.cart_item_id FOR UPDATE",
                    (customer_id,))
        items = cur.fetchall()
        if not items:
            raise OrderError(409, "CART_EMPTY", "주문할 상품을 장바구니에서 선택해 주세요.")

        dealer_seq = data.dealer_seq
        if dealer_seq is None:
            cur.execute("SELECT COALESCE((SELECT dealer_seq FROM cart_pickup WHERE customer_id = %s), "
                        "(SELECT favorite_dealer_seq FROM customer_setting WHERE customer_id = %s)) AS seq",
                        (customer_id, customer_id))
            dealer_seq = cur.fetchone()["seq"]
        cur.execute("SELECT seq, name, address FROM authorized_dealer WHERE seq = %s", (dealer_seq,))
        dealer = cur.fetchone() if dealer_seq else None
        if dealer is None:
            raise OrderError(422, "STORE_REQUIRED", "수령 매장을 선택해 주세요.")

        subtotal = sum(int(row["p_price"]) * row["quantity"] for row in items)
        discount, coupon_name = 0, None
        if data.coupon_id is not None:
            cur.execute("SELECT c.name, c.discount_type, c.discount_value FROM customer_coupon cc "
                        "JOIN coupon c ON c.coupon_id = cc.coupon_id WHERE cc.customer_id = %s AND cc.coupon_id = %s "
                        "AND cc.used_at IS NULL AND cc.expires_at >= %s FOR UPDATE",
                        (customer_id, data.coupon_id, now))
            coupon = cur.fetchone()
            if coupon is None:
                raise OrderError(409, "COUPON_UNAVAILABLE", "사용할 수 없는 쿠폰입니다.")
            discount, coupon_name = discount_of(coupon, subtotal), coupon["name"]
            cur.execute("UPDATE customer_coupon SET used_at = %s WHERE customer_id = %s AND coupon_id = %s",
                        (now, customer_id, data.coupon_id))

        order_number = _next_order_number(cur, now)
        cur.execute(
            "INSERT INTO shop_order (order_number, customer_id, orderer_name, orderer_phone, dealer_seq, "
            "store_name, store_address, payment_method, coupon_id, coupon_name, subtotal, discount, paid_amount, "
            "status, ordered_at, status_changed_at) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,'PAID',%s,%s)",
            (order_number, customer_id, data.orderer_name, data.orderer_phone, dealer["seq"], dealer["name"],
            dealer["address"], data.payment_method, data.coupon_id, coupon_name, subtotal, discount,
            subtotal - discount, now, now),
        )
        cur.executemany(
            "INSERT INTO shop_order_item (order_number, p_code, p_name, b_name, p_color, p_size, unit_price, quantity) "
            "VALUES (%s,%s,%s,%s,%s,%s,%s,%s)",
            [(order_number, row["p_code"], row["p_name"], row["b_name"], row["p_color"] or None,
            row["p_size"] or None, int(row["p_price"]), row["quantity"]) for row in items],
        )
        marks = ", ".join(["%s"] * len(items))
        cur.execute(f"DELETE FROM cart_item WHERE customer_id = %s AND cart_item_id IN ({marks})",
                    (customer_id, *[row["cart_item_id"] for row in items]))
    return order_number


# 주문내역 탭(전체/진행 중/수령 완료/취소) 조건. 값은 고정 문자열만 사용한다.
_STATUS_GROUPS = {
    "in_progress": "status NOT IN ('PICKED_UP', 'CANCELLED')",
    "completed": "status = 'PICKED_UP'",
    "cancelled": "status = 'CANCELLED'",
}


def list_orders(customer_id, group, limit, offset):
    where = _STATUS_GROUPS.get(group, "1 = 1")
    total = db.query_one(f"SELECT COUNT(*) AS total FROM shop_order WHERE customer_id = %s AND {where}",
                        (customer_id,))["total"]
    orders = db.query(f"SELECT {_ORDER_COLUMNS} FROM shop_order WHERE customer_id = %s AND {where} "
                    "ORDER BY ordered_at DESC, order_number DESC LIMIT %s OFFSET %s",
                    (customer_id, limit, offset))
    return orders, _items_by_order([row["order_number"] for row in orders]), total


def _items_by_order(order_numbers):
    if not order_numbers:
        return {}
    marks = ", ".join(["%s"] * len(order_numbers))
    rows = db.query(f"SELECT {_ITEM_COLUMNS} FROM shop_order_item i LEFT JOIN product p ON p.p_code = i.p_code "
                    f"WHERE i.order_number IN ({marks}) ORDER BY i.order_item_id", order_numbers)
    result = {}
    for row in rows:
        result.setdefault(row["order_number"], []).append(row)
    return result


def get_order(customer_id, order_number):
    """회원 API 는 주문번호만으로 찾지 않고 회원 조건을 함께 건다. (타인 주문은 404, None 은 본사 처리용)"""
    order = db.query_one(f"SELECT {_ORDER_COLUMNS} FROM shop_order WHERE order_number = %s "
                        "AND (%s IS NULL OR customer_id = %s)", (order_number, customer_id, customer_id))
    if order is None:
        raise OrderError(404, "ORDER_NOT_FOUND", "주문을 찾을 수 없습니다.")
    return order, _items_by_order([order_number]).get(order_number, [])


def _lock_order(cur, order_number, customer_id=None):
    sql = f"SELECT {_ORDER_COLUMNS} FROM shop_order WHERE order_number = %s"
    params = [order_number]
    if customer_id is not None:
        sql += " AND customer_id = %s"
        params.append(customer_id)
    cur.execute(sql + " FOR UPDATE", params)
    order = cur.fetchone()
    if order is None:
        raise OrderError(404, "ORDER_NOT_FOUND", "주문을 찾을 수 없습니다.")
    return order


def cancel_order(customer_id, order_number):
    now = datetime.now()
    with _transaction() as cur:
        order = _lock_order(cur, order_number, customer_id)
        if order["status"] not in CANCELLABLE:
            raise OrderError(409, "ORDER_NOT_CANCELLABLE", "본사에서 발송을 시작한 주문은 취소할 수 없습니다.")
        cur.execute("UPDATE shop_order SET status = 'CANCELLED', status_changed_at = %s, cancelled_at = %s, "
                    "pickup_code = NULL, pickup_code_expires = NULL WHERE order_number = %s", (now, now, order_number))
        if order["coupon_id"] is not None:
            # 아직 유효기간이 남은 쿠폰은 다시 사용할 수 있게 돌려준다.
            cur.execute("UPDATE customer_coupon SET used_at = NULL WHERE customer_id = %s AND coupon_id = %s "
                        "AND expires_at >= %s", (customer_id, order["coupon_id"], now))


def advance_order(order_number, status):
    """본사/매장 처리: 다음 단계로만 진행한다."""
    now = datetime.now()
    with _transaction() as cur:
        order = _lock_order(cur, order_number)
        current = order["status"]
        if current not in ORDER_FLOW or ORDER_FLOW.index(status) != ORDER_FLOW.index(current) + 1:
            raise OrderError(409, "INVALID_STATUS_TRANSITION", f"{current} 상태에서 {status}(으)로 바꿀 수 없습니다.")
        cur.execute("UPDATE shop_order SET status = %s, status_changed_at = %s, "
                    "ready_at = IF(%s = 'READY', %s, ready_at) WHERE order_number = %s",
                    (status, now, status, now, order_number))


def issue_pickup_code(customer_id, order_number):
    now = datetime.now()
    with _transaction() as cur:
        order = _lock_order(cur, order_number, customer_id)
        if order["status"] != "READY":
            raise OrderError(409, "ORDER_NOT_READY", "수령 준비가 완료된 주문만 수령 인증을 할 수 있습니다.")
        code = f"{secrets.randbelow(1_000_000):06d}"
        expires = now + timedelta(minutes=PICKUP_CODE_MINUTES)
        cur.execute("UPDATE shop_order SET pickup_code = %s, pickup_code_expires = %s WHERE order_number = %s",
                    (code, expires, order_number))
    return order, code, expires


def confirm_pickup(customer_id, order_number, code):
    """수령 완료. 쇼핑 구매내역(purchase)·누적결제금액(totalprice)에도 반영해 리뷰 작성/등급과 연결한다."""
    now = datetime.now()
    with _transaction() as cur:
        cur.execute(f"SELECT {_ORDER_COLUMNS}, pickup_code, pickup_code_expires FROM shop_order "
                    "WHERE order_number = %s AND customer_id = %s FOR UPDATE", (order_number, customer_id))
        order = cur.fetchone()
        if order is None:
            raise OrderError(404, "ORDER_NOT_FOUND", "주문을 찾을 수 없습니다.")
        if order["status"] != "READY":
            raise OrderError(409, "ORDER_NOT_READY", "수령 준비가 완료된 주문만 수령 처리할 수 있습니다.")
        if (not order["pickup_code"] or order["pickup_code_expires"] < now
                or not secrets.compare_digest(order["pickup_code"], code)):
            raise OrderError(422, "INVALID_PICKUP_CODE", "인증번호가 올바르지 않거나 만료되었습니다.")
        cur.execute("UPDATE shop_order SET status = 'PICKED_UP', status_changed_at = %s, picked_up_at = %s, "
                    "pickup_code = NULL, pickup_code_expires = NULL WHERE order_number = %s",
                    (now, now, order_number))
        cur.execute("UPDATE customer SET totalprice = totalprice + %s WHERE customer_id = %s",
                    (order["paid_amount"], customer_id))
        # purchase.head_office_id 는 실제 head_office FK 값이 필요하므로 설정된 경우에만 기록한다.
        office = os.getenv("ORDER_HEAD_OFFICE_ID")
        if office:
            cur.execute("SELECT p_code, unit_price, quantity FROM shop_order_item WHERE order_number = %s",
                        (order_number,))
            cur.executemany(
                "INSERT IGNORE INTO purchase (customer_customer_id, head_office_id, p_code, p_date, p_price) "
                "VALUES (%s, %s, %s, %s, %s)",
                [(customer_id, int(office), row["p_code"], now, row["unit_price"] * row["quantity"])
                for row in cur.fetchall()],
            )


# ---------- 교환/반품 ----------
_CLAIM_COLUMNS = (
    "claim_id, order_number, order_item_id, claim_type, reason, detail, requested_size, store_name, "
    "refund_amount, status, requested_at"
)


def refund_amount(order, item):
    """쿠폰 할인을 상품 금액 비율로 나눠 뺀 환불 예정 금액."""
    line = item["unit_price"] * item["quantity"]
    if not order["discount"] or not order["subtotal"]:
        return line
    return line - round(order["discount"] * line / order["subtotal"])


def find_item(items, order_item_id):
    item = next((row for row in items if row["order_item_id"] == order_item_id), None)
    if item is None:
        raise OrderError(404, "ORDER_ITEM_NOT_FOUND", "주문 상품을 찾을 수 없습니다.")
    return item


def has_open_claim(order_item_id):
    return db.query_one("SELECT 1 AS found FROM order_claim WHERE order_item_id = %s AND status <> 'REJECTED'",
                        (order_item_id,)) is not None


def create_claim(customer_id, data, photos):
    now = datetime.now()
    with _transaction() as cur:
        order = _lock_order(cur, data.order_number, customer_id)
        if order["status"] != "PICKED_UP":
            raise OrderError(409, "CLAIM_NOT_ALLOWED", "수령 완료된 주문만 교환·반품을 신청할 수 있습니다.")
        cur.execute("SELECT order_item_id, p_code, unit_price, quantity, p_size FROM shop_order_item "
                    "WHERE order_number = %s AND order_item_id = %s", (data.order_number, data.order_item_id))
        item = cur.fetchone()
        if item is None:
            raise OrderError(404, "ORDER_ITEM_NOT_FOUND", "주문 상품을 찾을 수 없습니다.")
        cur.execute("SELECT 1 AS found FROM order_claim WHERE order_item_id = %s AND status <> 'REJECTED'",
                    (data.order_item_id,))
        if cur.fetchone():
            raise OrderError(409, "CLAIM_ALREADY_EXISTS", "이미 교환·반품을 신청한 상품입니다.")
        cur.execute("SELECT name FROM authorized_dealer WHERE seq = %s", (data.dealer_seq,))
        dealer = cur.fetchone()
        if dealer is None:
            raise OrderError(404, "STORE_NOT_FOUND", "방문할 매장을 찾을 수 없습니다.")
        refund = refund_amount(order, item) if data.claim_type == "RETURN" else 0
        cur.execute(
            "INSERT INTO order_claim (order_number, order_item_id, customer_id, claim_type, reason, detail, "
            "requested_size, dealer_seq, store_name, refund_amount, status, requested_at, updated_at) "
            "VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,'RECEIVED',%s,%s)",
            (data.order_number, data.order_item_id, customer_id, data.claim_type, data.reason, data.detail,
            data.requested_size if data.claim_type == "EXCHANGE" else None, data.dealer_seq, dealer["name"],
            refund, now, now),
        )
        claim_id = cur.lastrowid
        if photos:
            cur.executemany("INSERT INTO order_claim_photo (claim_id, content_type, image) VALUES (%s, %s, %s)",
                            [(claim_id, content_type, image) for content_type, image in photos])
    return claim_id


def list_claims(customer_id, claim_type=None, claim_id=None):
    sql = f"SELECT {_CLAIM_COLUMNS} FROM order_claim WHERE customer_id = %s"
    params = [customer_id]
    if claim_type:
        sql += " AND claim_type = %s"
        params.append(claim_type)
    if claim_id is not None:
        sql += " AND claim_id = %s"
        params.append(claim_id)
    claims = db.query(sql + " ORDER BY requested_at DESC, claim_id DESC", params)
    if not claims:
        return [], {}, {}
    marks = ", ".join(["%s"] * len(claims))
    item_ids = [row["order_item_id"] for row in claims]
    items = db.query(f"SELECT {_ITEM_COLUMNS} FROM shop_order_item i LEFT JOIN product p ON p.p_code = i.p_code "
                    f"WHERE i.order_item_id IN ({marks})", item_ids)
    photos = {}
    for row in db.query(f"SELECT photo_id, claim_id FROM order_claim_photo WHERE claim_id IN ({marks}) "
                        "ORDER BY photo_id", [row["claim_id"] for row in claims]):
        photos.setdefault(row["claim_id"], []).append(row["photo_id"])
    return claims, {row["order_item_id"]: row for row in items}, photos


def get_claim_photo(customer_id, claim_id, photo_id):
    return db.query_one(
        "SELECT ph.content_type, ph.image FROM order_claim_photo ph JOIN order_claim c ON c.claim_id = ph.claim_id "
        "WHERE c.customer_id = %s AND ph.claim_id = %s AND ph.photo_id = %s", (customer_id, claim_id, photo_id))


def advance_claim(claim_id, status):
    """본사 처리: 다음 단계로만 진행하고, 완료 전에는 반려할 수 있다."""
    with _transaction() as cur:
        cur.execute("SELECT status FROM order_claim WHERE claim_id = %s FOR UPDATE", (claim_id,))
        row = cur.fetchone()
        if row is None:
            raise OrderError(404, "CLAIM_NOT_FOUND", "교환·반품 신청을 찾을 수 없습니다.")
        current = row["status"]
        allowed = (current in CLAIM_FLOW[:-1] and
                (status == "REJECTED" or (status in CLAIM_FLOW and CLAIM_FLOW.index(status) == CLAIM_FLOW.index(current) + 1)))
        if not allowed:
            raise OrderError(409, "INVALID_STATUS_TRANSITION", f"{current} 상태에서 {status}(으)로 바꿀 수 없습니다.")
        cur.execute("UPDATE order_claim SET status = %s, updated_at = %s WHERE claim_id = %s",
                    (status, datetime.now(), claim_id))
