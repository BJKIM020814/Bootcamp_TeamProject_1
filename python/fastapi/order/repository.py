"""Storage queries for Order: SQLite cart and MySQL catalogue/checkout data.

주문 시 가격·할인은 클라이언트 값을 믿지 않고 product/coupon 테이블로 다시 계산한다.
주문 생성·취소·수령·신청처럼 여러 행을 바꾸는 작업은 하나의 트랜잭션으로 묶는다.
수령 대리점은 판매 재고가 아닌 수령 장소이므로 대리점 재고는 조회하지 않는다. (Discover 와 동일)
"""
import os
import secrets
import uuid
import logging
from contextlib import contextmanager
from datetime import datetime, timedelta

import pymysql
from python import db
from ..dependencies import get_local
from ..discover import repository as discover_repository
from ..accounts import get_accounts
from . import inventory as stock_inventory

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
    # 장바구니에는 Discover에서 주문 가능한 정상 이미지·옵션 상품만 들어가게 한다.
    return discover_repository.get_product(product_code) is not None


def add_cart_item(customer_id, product_code, quantity):
    """같은 상품을 다시 담으면 수량을 더하고 선택 상태로 만든다."""
    with get_local().connection() as conn:
        conn.execute(
            "INSERT INTO cart_items (customer_id, p_code, quantity, selected) VALUES (?, ?, ?, 1) "
            "ON CONFLICT(customer_id, p_code) DO UPDATE SET "
            "quantity = MIN(cart_items.quantity + excluded.quantity, ?), selected = 1",
            (customer_id, product_code, quantity, MAX_QUANTITY),
        )


def update_cart_item(customer_id, cart_item_id, quantity=None, selected=None, product_code=None):
    has_updates = quantity is not None or selected is not None or product_code is not None
    if product_code is not None:
        product = discover_repository.get_product(product_code)
        if product is None or not product.get("p_size") or product["p_size"] <= 0:
            raise OrderError(404, "PRODUCT_OPTION_NOT_FOUND", "선택한 색상·사이즈 옵션을 찾을 수 없습니다.")
    with get_local().connection() as conn:
        cursor = conn.execute("SELECT 1 FROM cart_items WHERE customer_id = ? AND cart_item_id = ?",
                              (customer_id, cart_item_id))
        if cursor.fetchone() is None:
            raise OrderError(404, "CART_ITEM_NOT_FOUND", "장바구니 상품을 찾을 수 없습니다.")
        if product_code is not None:
            duplicate = conn.execute(
                "SELECT 1 FROM cart_items WHERE customer_id = ? AND p_code = ? AND cart_item_id <> ?",
                (customer_id, product_code, cart_item_id),
            ).fetchone()
            if duplicate:
                raise OrderError(409, "CART_OPTION_ALREADY_EXISTS", "변경할 옵션이 장바구니에 이미 있습니다.")
        if has_updates:
            assignments, sqlite_params = [], []
            if quantity is not None:
                assignments.append("quantity = ?")
                sqlite_params.append(quantity)
            if selected is not None:
                assignments.append("selected = ?")
                sqlite_params.append(int(selected))
            if product_code is not None:
                assignments.append("p_code = ?")
                sqlite_params.append(product_code)
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
# 초기 ERD의 purchase가 주문 헤더와 상품 행을 함께 저장한다. 여러 행은 order_code로 묶는다.
_ORDER_SELECT = (
    "po.purchase_id AS order_id, po.order_code AS order_number, "
    "po.customer_customer_id AS customer_id, po.orderer_name, po.orderer_phone, "
    "po.dealer_seq, po.store_name, po.store_address, po.payment_method, po.coupon_id, po.coupon_name, "
    "po.subtotal, po.discount, po.order_total AS paid_amount, po.order_status AS status, po.p_date AS ordered_at, "
    "po.status_changed_at, po.ready_at, po.picked_up_at, po.cancelled_at, po.pickup_code, "
    "po.pickup_code_expires, po.head_office_id"
)
_ORDER_FROM = "purchase"
_ITEM_COLUMNS = (
    "i.purchase_id AS order_item_id, i.order_code AS order_number, i.p_code, p.p_name, p.b_name, p.p_color, p.p_size, "
    "i.p_price AS unit_price, i.quantity, OCTET_LENGTH(p.p_image) AS image_bytes"
)


def _resolve_head_office(cur):
    """주문 기준 본사는 명시 설정을 우선하고, 없으면 유일한 물류본부 행을 사용한다."""
    configured = os.getenv("ORDER_HEAD_OFFICE_ID")
    if configured:
        cur.execute("SELECT id FROM head_office WHERE id = %s", (configured,))
        row = cur.fetchone()
        if row:
            return row["id"]
        raise OrderError(503, "ORDER_HEAD_OFFICE_INVALID", "ORDER_HEAD_OFFICE_ID가 head_office에 등록되어 있지 않습니다.")
    cur.execute("SELECT id FROM head_office WHERE division = %s ORDER BY id LIMIT 2", ("물류본부",))
    rows = cur.fetchall()
    if len(rows) == 1:
        return rows[0]["id"]
    raise OrderError(503, "ORDER_HEAD_OFFICE_REQUIRED", "주문을 처리할 물류본부(head_office)를 확인할 수 없습니다.")


def create_order(customer_id, data, payment_methods):
    if not data.agreed:
        raise OrderError(422, "AGREEMENT_REQUIRED", "주문 내용 확인에 동의해 주세요.")
    if data.payment_method not in payment_methods:
        raise OrderError(422, "INVALID_PAYMENT_METHOD", "지원하지 않는 결제수단입니다.")
    now = datetime.now()
    with get_local().connection() as conn:
        cart_rows = [dict(row) for row in conn.execute(
            "SELECT cart_item_id, p_code, quantity FROM cart_items "
            "WHERE customer_id = ? AND selected = 1 ORDER BY cart_item_id", (customer_id,)
        ).fetchall()]
    if not cart_rows:
        raise OrderError(409, "CART_EMPTY", "주문할 상품을 장바구니에서 선택해 주세요.")

    order_number = f"FP{uuid.uuid4().hex[:18].upper()}"
    inventory_client = None
    reservation_created = False
    try:
        with _transaction() as cur:
            # SQLite 장바구니의 선택 상품코드와 MySQL 상품행을 대조해 가격·옵션을 서버에서 다시 읽는다.
            codes = [row["p_code"] for row in cart_rows]
            marks = ", ".join(["%s"] * len(codes))
            cur.execute("SELECT p_code, p_name, b_name, p_price, p_color, p_size "
                        f"FROM product WHERE p_code IN ({marks}) FOR UPDATE", codes)
            product_rows = {row["p_code"]: row for row in cur.fetchall()}
            items = [{**product_rows[row["p_code"]], **row} for row in cart_rows if row["p_code"] in product_rows]
            if len(items) != len(cart_rows):
                raise OrderError(409, "CART_PRODUCT_UNAVAILABLE", "장바구니에 현재 판매되지 않는 상품이 포함되어 있습니다.")

            # 선택 지점은 주문 생성 시 실제 authorized_dealer를 검증하고 purchase에 고정한다.
            cur.execute("SELECT seq,name,address FROM authorized_dealer WHERE seq=%s FOR UPDATE",
                        (data.dealer_seq,))
            dealer = cur.fetchone()
            if dealer is None:
                raise OrderError(422, "INVALID_PICKUP_STORE", "선택한 수령 대리점을 찾을 수 없습니다.")

            subtotal = sum(int(str(row["p_price"]).replace(",", "")) * row["quantity"] for row in items)
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

            head_office_id = _resolve_head_office(cur)
            # Firebase 모델 재고는 Firestore transaction으로 선점한다. DB 주문 실패 시 아래에서 보상 복구한다.
            inventory_client = get_accounts().client
            stock_inventory.reserve_stock(inventory_client, order_number, items)
            reservation_created = True
            cur.executemany(
                "INSERT INTO purchase (order_code,customer_customer_id,head_office_id,p_code,p_date,p_price,quantity,"
                "order_status,orderer_name,orderer_phone,dealer_seq,store_name,store_address,payment_method,coupon_id,"
                "coupon_name,subtotal,discount,order_total,status_changed_at) "
                "VALUES (%s,%s,%s,%s,%s,%s,%s,'PAID',%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)",
                [(order_number, customer_id, head_office_id, row["p_code"], now,
                  int(str(row["p_price"]).replace(",", "")), row["quantity"], data.orderer_name,
                  data.orderer_phone, dealer["seq"], dealer["name"], dealer["address"], data.payment_method,
                  data.coupon_id, coupon_name, subtotal, discount, subtotal - discount, now)
                 for row in items],
            )
    except stock_inventory.StockError as exc:
        raise OrderError(exc.status, exc.code, exc.message) from exc
    except Exception:
        if reservation_created and inventory_client is not None:
            try:
                stock_inventory.release_stock(inventory_client, order_number)
            except stock_inventory.StockError:
                logging.getLogger(__name__).exception("Order failed and stock reservation needs reconciliation")
                raise OrderError(503, "INVENTORY_RECONCILIATION_REQUIRED",
                                 "주문 저장은 실패했지만 재고 예약 복구가 지연되고 있습니다. 관리자 확인이 필요합니다.")
        raise

    try:
        stock_inventory.commit_stock(inventory_client, order_number)
    except stock_inventory.StockError:
        # MySQL 주문은 이미 확정됐다. 예약 상태 갱신 실패만 기록하고 재고 차감은 유지한다.
        logging.getLogger(__name__).exception("Order saved but stock reservation finalization is pending")
    # MySQL 주문 커밋이 완료된 뒤에만 SQLite 장바구니를 비운다.
    with get_local().connection() as conn:
        marks = ",".join(["?"] * len(cart_rows))
        conn.execute(f"DELETE FROM cart_items WHERE customer_id = ? AND cart_item_id IN ({marks})",
                     (customer_id, *[row["cart_item_id"] for row in cart_rows]))
    return order_number


# 주문내역 탭(전체/진행 중/수령 완료/취소) 조건. 값은 고정 문자열만 사용한다.
_STATUS_GROUPS = {
    "in_progress": "status NOT IN ('PICKED_UP', 'CANCELLED')",
    "completed": "status = 'PICKED_UP'",
    "cancelled": "status = 'CANCELLED'",
}


def list_orders(customer_id, group, limit, offset):
    where = _STATUS_GROUPS.get(group, "1 = 1").replace("status", "po.order_status")
    owner = "po.customer_customer_id = %s"
    representative = "po.purchase_id=(SELECT MIN(p2.purchase_id) FROM purchase p2 WHERE p2.order_code=po.order_code)"
    total = db.query_one(f"SELECT COUNT(DISTINCT po.order_code) AS total FROM {_ORDER_FROM} po "
                        f"WHERE {owner} AND {where}",
                        (customer_id,))["total"]
    orders = db.query(f"SELECT {_ORDER_SELECT} FROM {_ORDER_FROM} po WHERE {owner} AND {where} AND {representative} "
                    "ORDER BY po.p_date DESC, po.purchase_id DESC LIMIT %s OFFSET %s",
                    (customer_id, limit, offset))
    return orders, _items_by_order([row["order_number"] for row in orders]), total


def _items_by_order(order_numbers):
    if not order_numbers:
        return {}
    marks = ", ".join(["%s"] * len(order_numbers))
    rows = db.query(f"SELECT {_ITEM_COLUMNS} FROM purchase i LEFT JOIN product p ON p.p_code=i.p_code "
                    f"WHERE i.order_code IN ({marks}) ORDER BY i.purchase_id", order_numbers)
    result = {}
    for row in rows:
        result.setdefault(row["order_number"], []).append(row)
    return result


def get_order(customer_id, order_number):
    """회원 API 는 주문번호만으로 찾지 않고 회원 조건을 함께 건다. (타인 주문은 404, None 은 본사 처리용)"""
    order = db.query_one(f"SELECT {_ORDER_SELECT} FROM {_ORDER_FROM} po WHERE po.order_code = %s "
                        "AND (%s IS NULL OR po.customer_customer_id = %s) ORDER BY po.purchase_id LIMIT 1",
                        (order_number, customer_id, customer_id))
    if order is None:
        raise OrderError(404, "ORDER_NOT_FOUND", "주문을 찾을 수 없습니다.")
    return order, _items_by_order([order_number]).get(order_number, [])


def _lock_order(cur, order_number, customer_id=None):
    sql = "SELECT purchase_id FROM purchase WHERE order_code = %s"
    params = [order_number]
    if customer_id is not None:
        sql += " AND customer_customer_id = %s"
        params.append(customer_id)
    cur.execute(sql + " ORDER BY purchase_id FOR UPDATE", params)
    if not cur.fetchall():
        raise OrderError(404, "ORDER_NOT_FOUND", "주문을 찾을 수 없습니다.")
    sql = f"SELECT {_ORDER_SELECT} FROM purchase po WHERE po.order_code=%s"
    if customer_id is not None:
        sql += " AND po.customer_customer_id=%s"
        params = [order_number, customer_id]
    else:
        params = [order_number]
    cur.execute(sql + " ORDER BY po.purchase_id LIMIT 1", params)
    return cur.fetchone()


def cancel_order(customer_id, order_number):
    now = datetime.now()
    with _transaction() as cur:
        order = _lock_order(cur, order_number, customer_id)
        if order["status"] == "CANCELLED":
            # 재고 복구가 앞선 요청에서 실패했을 수 있어 아래에서 안전하게 재시도한다.
            pass
        elif order["status"] not in CANCELLABLE:
            raise OrderError(409, "ORDER_NOT_CANCELLABLE", "본사에서 발송을 시작한 주문은 취소할 수 없습니다.")
        else:
            cur.execute("UPDATE purchase SET order_status='CANCELLED',status_changed_at=%s,cancelled_at=%s,"
                        "pickup_code=NULL,pickup_code_expires=NULL WHERE order_code=%s",
                        (now, now, order_number))
            if order["coupon_id"] is not None:
                # 아직 유효기간이 남은 쿠폰은 다시 사용할 수 있게 돌려준다.
                cur.execute("UPDATE customer_coupon SET used_at = NULL WHERE customer_id = %s AND coupon_id = %s "
                            "AND expires_at >= %s", (customer_id, order["coupon_id"], now))
    # 취소가 확정된 주문은 본사 모델 재고로 되돌린다. 실패 시 동일 취소 API 재호출로 복구를 재시도할 수 있다.
    try:
        stock_inventory.restore_cancelled_order_stock(get_accounts().client, order_number)
    except stock_inventory.StockError as exc:
        raise OrderError(503, exc.code, exc.message) from exc


def advance_order(order_number, status):
    """본사/매장 처리: 다음 단계로만 진행한다."""
    now = datetime.now()
    with _transaction() as cur:
        order = _lock_order(cur, order_number)
        current = order["status"]
        if current not in ORDER_FLOW or ORDER_FLOW.index(status) != ORDER_FLOW.index(current) + 1:
            raise OrderError(409, "INVALID_STATUS_TRANSITION", f"{current} 상태에서 {status}(으)로 바꿀 수 없습니다.")
        if status == "SHIPPING" and order["dealer_seq"] is None:
            raise OrderError(409, "PICKUP_STORE_REQUIRED", "발송 전에 주문의 수령 대리점을 지정해야 합니다.")
        cur.execute("UPDATE purchase SET order_status=%s,status_changed_at=%s,"
                    "ready_at=IF(%s='READY',%s,ready_at) WHERE order_code=%s",
                    (status, now, status, now, order_number))
    # API 계층이 주문 상태 변경 알림을 고객 서버 저장소에 기록할 수 있도록 소유자 정보를 돌려준다.
    return order


def issue_pickup_code(customer_id, order_number):
    now = datetime.now()
    with _transaction() as cur:
        order = _lock_order(cur, order_number, customer_id)
        if order["status"] != "READY":
            raise OrderError(409, "ORDER_NOT_READY", "수령 준비가 완료된 주문만 수령 인증을 할 수 있습니다.")
        code = f"{secrets.randbelow(1_000_000):06d}"
        expires = now + timedelta(minutes=PICKUP_CODE_MINUTES)
        cur.execute("UPDATE purchase SET pickup_code=%s,pickup_code_expires=%s WHERE order_code=%s",
                    (code, expires, order_number))
    return order, code, expires


def confirm_pickup(customer_id, order_number, code):
    """수령 완료. 쇼핑 구매내역(purchase)·누적결제금액(totalprice)에도 반영해 리뷰 작성/등급과 연결한다."""
    now = datetime.now()
    with _transaction() as cur:
        order = _lock_order(cur, order_number, customer_id)
        if order["status"] != "READY":
            raise OrderError(409, "ORDER_NOT_READY", "수령 준비가 완료된 주문만 수령 처리할 수 있습니다.")
        if (not order["pickup_code"] or order["pickup_code_expires"] < now
                or not secrets.compare_digest(order["pickup_code"], code)):
            raise OrderError(422, "INVALID_PICKUP_CODE", "인증번호가 올바르지 않거나 만료되었습니다.")
        cur.execute("UPDATE purchase SET order_status='PICKED_UP',status_changed_at=%s,picked_up_at=%s,"
                    "pickup_code=NULL,pickup_code_expires=NULL WHERE order_code=%s",
                    (now, now, order_number))
        cur.execute("UPDATE customer SET totalprice = totalprice + %s WHERE customer_id = %s",
                    (order["paid_amount"], customer_id))
        # purchase는 주문 접수 순간부터 기준 원본이다. 수령 시 별도 purchase 행을 중복 생성하지 않는다.
    return order


# ---------- 교환/반품 ----------
_CLAIM_COLUMNS = (
    "claim_id, order_code AS order_number, order_item_id, claim_type, reason, detail, requested_size, store_name, "
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
        cur.execute("SELECT i.purchase_id AS order_item_id,i.p_code,i.p_price AS unit_price,i.quantity,p.p_size "
                    "FROM purchase i LEFT JOIN product p ON p.p_code=i.p_code "
                    "WHERE i.order_code=%s AND i.purchase_id=%s",
                    (data.order_number, data.order_item_id))
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
            "INSERT INTO order_claim (order_code, order_item_id, customer_id, claim_type, reason, detail, "
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
    items = db.query(f"SELECT {_ITEM_COLUMNS} FROM purchase i LEFT JOIN product p ON p.p_code=i.p_code "
                    f"WHERE i.purchase_id IN ({marks})", item_ids)
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
        cur.execute("SELECT status,customer_id,order_code,claim_type FROM order_claim WHERE claim_id = %s FOR UPDATE",
                    (claim_id,))
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
        result = dict(row)
        result["status"] = status
    return result
