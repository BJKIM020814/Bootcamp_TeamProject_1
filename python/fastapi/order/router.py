"""Order router: cart, checkout, order history/detail, pickup QR and exchange/return claims.

회원 식별은 마이페이지 API 와 같이 customer_id(Firebase email)를 받는다.
수령 매장·상품 이미지·옵션은 Discover, 결제수단·쿠폰 발급·회원 행 생성은 마이페이지와 같은 로직을 재사용한다.
"""
import base64
import binascii
from contextlib import contextmanager
from datetime import timedelta
from typing import Literal, Optional
from urllib.parse import quote

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import Response

from . import repository
from .schemas import (
    CartItem, CartItemAdd, CartItemUpdate, CartPickupUpdate, CartResponse, CartSelectAll, CheckoutCoupon,
    CheckoutResponse, Claim, ClaimCreate, ClaimListResponse, ClaimOptions, ClaimStatusUpdate, CustomerRef,
    OrderCreate, OrderDetail, OrderItem, OrderListResponse, OrderStatusUpdate, OrderSummary, PickupCode,
    PickupConfirm, TimelineStep,
)
from ..discover import repository as discover_repository
from ..discover.schemas import PickupStore, PickupStoreListResponse
from ..user import mypage_data as md

router = APIRouter(prefix="/api/v1/order", tags=["Order"])

CLAIM_REASONS = ["사이즈가 작아요", "사이즈가 커요", "상품이 설명과 달라요", "상품에 문제가 있어요", "기타"]
MAX_PHOTOS = 3
MAX_PHOTO_BYTES = 5 * 1024 * 1024
_STATUS_LABELS = {
    "PAID": "결제 완료", "PREPARING": "본사 상품 준비", "SHIPPING": "발송 시작·매장 이동",
    "INSPECTING": "입고·검수", "READY": "수령 준비 완료", "PICKED_UP": "수령 완료", "CANCELLED": "주문 취소",
}
# orderHistoryPage stageIndex: 0=결제, 1=준비, 2=이동, 3=수령
_STAGE_INDEX = {"PAID": 0, "PREPARING": 1, "SHIPPING": 2, "INSPECTING": 2, "READY": 3, "PICKED_UP": 3, "CANCELLED": 0}
# orderDetailPage 타임라인 6단계
_TIMELINE = [("주문 접수", None), ("결제 완료", "PAID"), ("본사 상품 준비", "PREPARING"),
             ("발송 시작·매장 이동", "SHIPPING"), ("입고·검수", "INSPECTING"), ("수령 준비 완료", "READY")]
_CLAIM_LABELS = {"RECEIVED": "신청 접수", "CONFIRMED": "본사 확인", "VISIT": "방문", "DONE": "완료", "REJECTED": "반려"}
_CLAIM_STAGE = {"RECEIVED": 0, "CONFIRMED": 1, "VISIT": 2, "DONE": 3, "REJECTED": 3}
_IMAGE_TYPES = ((b"\xff\xd8\xff", "image/jpeg"), (b"\x89PNG\r\n\x1a\n", "image/png"), (b"RIFF", "image/webp"))


@contextmanager
def _errors():
    """업무 규칙 오류를 Discover 와 같은 {code, message} 형식의 HTTP 오류로 바꾼다."""
    try:
        yield
    except repository.OrderError as error:
        raise HTTPException(status_code=error.status, detail={"code": error.code, "message": error.message})
    except md.MyPageError as error:
        raise HTTPException(status_code=error.status, detail={"code": "INVALID_CUSTOMER", "message": str(error)})


def _customer(customer_id):
    # 회원은 기존 MySQL customer와 연결하지만 장바구니 스키마는 SQLite에서 관리한다.
    with _errors():
        md.ensure_customer(customer_id)


def _image_url(row):
    return f"/api/v1/discover/products/{row['p_code']}/image" if row.get("image_bytes") else None


def _option_label(color, size):
    return " · ".join(part for part in (color, f"{size}mm" if size else None) if part) or "옵션 정보 없음"


def _store(row):
    if row is None:
        return None
    return PickupStore(seq=row["seq"], name=row["name"], dealer_number=row["dealer_number"], manager=row["manager"],
                       address=row["address"], latitude=row["lat"], longitude=row["lng"])


def _cart_item(row):
    price = int(str(row["p_price"]).replace(",", ""))
    size, color = row["p_size"] or None, row["p_color"] or None
    return CartItem(cart_item_id=row["cart_item_id"], product_code=row["p_code"], brand=row["b_name"],
                    name=row["p_name"], color=color, size=size, option_label=_option_label(color, size),
                    price=price, quantity=row["quantity"], selected=bool(row["selected"]),
                    line_total=price * row["quantity"], image_url=_image_url(row))


def _order_item(row):
    return OrderItem(order_item_id=row["order_item_id"], product_code=row["p_code"], brand=row["b_name"],
                     name=row["p_name"], color=row["p_color"], size=row["p_size"],
                     option_label=_option_label(row["p_color"], row["p_size"]), price=row["unit_price"],
                     quantity=row["quantity"], line_total=row["unit_price"] * row["quantity"],
                     image_url=_image_url(row))


def _status_group(status):
    return {"PICKED_UP": "completed", "CANCELLED": "cancelled"}.get(status, "in_progress")


def _summary(order, items):
    status = order["status"]
    return dict(order_number=order["order_number"], ordered_at=order["ordered_at"], status=status,
                status_label=_STATUS_LABELS[status], status_group=_status_group(status),
                stage_index=_STAGE_INDEX[status], store_name=order["store_name"], paid_amount=order["paid_amount"],
                items=[_order_item(row) for row in items])


def _detail(customer_id, order_number):
    order, items = repository.get_order(customer_id, order_number)
    status = order["status"]
    reached = repository.ORDER_FLOW.index(status) if status in repository.ORDER_FLOW else -1
    timeline = []
    for label, step in _TIMELINE:
        step_index = repository.ORDER_FLOW.index(step) if step else -1
        timeline.append(TimelineStep(label=label, done=step_index <= reached, current=step_index == reached))
    ready_at = order["ready_at"]
    can_claim = status == "PICKED_UP" and any(not repository.has_open_claim(row["order_item_id"]) for row in items)
    return OrderDetail(
        **_summary(order, items), orderer_name=order["orderer_name"], orderer_phone=order["orderer_phone"],
        payment_method=order["payment_method"], subtotal=order["subtotal"], discount=order["discount"],
        coupon_name=order["coupon_name"], store_address=order["store_address"],
        pickup_store=_store(repository.get_dealer(order["dealer_seq"])), timeline=timeline,
        pickup_stage="completed" if status in ("READY", "PICKED_UP") else "preparing",
        picked_up=status == "PICKED_UP", ready_at=ready_at,
        pickup_due_at=ready_at + timedelta(days=repository.PICKUP_HOLD_DAYS) if ready_at else None,
        picked_up_at=order["picked_up_at"], cancelled_at=order["cancelled_at"],
        can_cancel=status in repository.CANCELLABLE, can_claim=can_claim,
    )


# ---------- 수령 매장 ----------
@router.get("/pickup-stores", response_model=PickupStoreListResponse, summary="수령 매장 목록 (Discover 수령 대리점과 동일)")
def pickup_stores(keyword: Optional[str] = Query(default=None, max_length=45)):
    stores = [_store(row) for row in discover_repository.list_pickup_stores(keyword)]
    return PickupStoreListResponse(items=stores, total=len(stores))


# ---------- 장바구니 (cartPage) ----------
@router.get("/cart", response_model=CartResponse, summary="장바구니 조회")
def cart(customer_id: str):
    _customer(customer_id)
    items = [_cart_item(row) for row in repository.list_cart(customer_id)]
    selected = [item for item in items if item.selected]
    return CartResponse(items=items, total_count=len(items), selected_count=len(selected),
                        selected_total=sum(item.line_total for item in selected),
                        pickup_store=_store(repository.get_cart_pickup(customer_id)))


@router.post("/cart/items", response_model=CartResponse, status_code=201, summary="장바구니 담기 (같은 상품은 수량 합산)")
def cart_add(body: CartItemAdd):
    _customer(body.customer_id)
    if not repository.product_exists(body.product_code):
        raise HTTPException(status_code=404, detail={"code": "PRODUCT_NOT_FOUND", "message": "상품을 찾을 수 없습니다."})
    repository.add_cart_item(body.customer_id, body.product_code, body.quantity)
    return cart(body.customer_id)


@router.patch("/cart/items/{cart_item_id}", response_model=CartResponse, summary="장바구니 수량·선택 변경")
def cart_update(cart_item_id: int, body: CartItemUpdate):
    _customer(body.customer_id)
    with _errors():
        repository.update_cart_item(body.customer_id, cart_item_id, body.quantity, body.selected)
    return cart(body.customer_id)


@router.put("/cart/selection", response_model=CartResponse, summary="장바구니 전체 선택/해제")
def cart_select_all(body: CartSelectAll):
    _customer(body.customer_id)
    repository.select_all_cart_items(body.customer_id, body.selected)
    return cart(body.customer_id)


@router.delete("/cart/items/{cart_item_id}", response_model=CartResponse, summary="장바구니 상품 삭제")
def cart_remove(cart_item_id: int, customer_id: str):
    _customer(customer_id)
    with _errors():
        repository.delete_cart_item(customer_id, cart_item_id)
    return cart(customer_id)


@router.delete("/cart/items", response_model=CartResponse, summary="장바구니 선택 상품 삭제")
def cart_remove_selected(customer_id: str):
    _customer(customer_id)
    repository.delete_selected_cart_items(customer_id)
    return cart(customer_id)


@router.put("/cart/pickup-store", response_model=CartResponse, summary="수령 매장 변경")
def cart_pickup(body: CartPickupUpdate):
    _customer(body.customer_id)
    with _errors():
        repository.set_cart_pickup(body.customer_id, body.dealer_seq)
    return cart(body.customer_id)


# ---------- 주문/결제 (checkoutPage → orderCompletePage) ----------
@router.get("/checkout", response_model=CheckoutResponse, summary="주문하기 화면 데이터 (선택 상품·결제수단·쿠폰·매장)")
def checkout(customer_id: str):
    _customer(customer_id)
    items = [_cart_item(row) for row in repository.list_cart(customer_id, selected_only=True)]
    subtotal = sum(item.line_total for item in items)
    md.get_coupons(customer_id)  # 마이페이지 쿠폰함과 같은 조건으로 받을 수 있는 쿠폰을 먼저 발급한다.
    coupons = [CheckoutCoupon(**row, discount_amount=repository.discount_of(row, subtotal))
               for row in repository.available_coupons(customer_id)]
    return CheckoutResponse(items=items, subtotal=subtotal, payment_methods=md.PAYMENT_METHODS,
                            default_payment=md.get_payment(customer_id)["default"], coupons=coupons,
                            pickup_store=_store(repository.get_cart_pickup(customer_id)))


@router.post("/orders", response_model=OrderDetail, status_code=201, summary="주문·모의 결제 (장바구니 선택 상품)")
def order_create(body: OrderCreate):
    _customer(body.customer_id)
    with _errors():
        order_number = repository.create_order(body.customer_id, body, md.PAYMENT_METHODS)
        return _detail(body.customer_id, order_number)


# ---------- 주문내역/상세 (orderHistoryPage, orderDetailPage) ----------
@router.get("/orders", response_model=OrderListResponse, summary="주문내역 (전체/진행 중/수령 완료/취소)")
def orders(
    customer_id: str,
    status: Literal["all", "in_progress", "completed", "cancelled"] = Query(default="all"),
    limit: int = Query(default=20, ge=1, le=100), offset: int = Query(default=0, ge=0),
):
    _customer(customer_id)
    rows, items, total = repository.list_orders(customer_id, status, limit, offset)
    return OrderListResponse(items=[OrderSummary(**_summary(row, items.get(row["order_number"], []))) for row in rows],
                             total=total, limit=limit, offset=offset)


@router.get("/orders/{order_number}", response_model=OrderDetail, summary="주문·준비 상태 상세")
def order_detail(order_number: str, customer_id: str):
    _customer(customer_id)
    with _errors():
        return _detail(customer_id, order_number)


@router.post("/orders/{order_number}/cancel", response_model=OrderDetail, summary="주문 취소 (발송 전까지, 쿠폰 복원)")
def order_cancel(order_number: str, body: CustomerRef):
    _customer(body.customer_id)
    with _errors():
        repository.cancel_order(body.customer_id, order_number)
        return _detail(body.customer_id, order_number)


# ---------- 매장 수령 (pickupQrPage) ----------
@router.post("/orders/{order_number}/pickup-code", response_model=PickupCode, summary="수령 인증 QR·일회성 번호 발급")
def pickup_code(order_number: str, body: CustomerRef):
    _customer(body.customer_id)
    with _errors():
        order, code, expires = repository.issue_pickup_code(body.customer_id, order_number)
    ready_at = order["ready_at"]
    return PickupCode(order_number=order_number, code=f"{code[:3]} {code[3:]}",
                      qr_payload=f"FITPICK-PICKUP:{order_number}:{code}", expires_at=expires, visit_from=ready_at,
                      visit_until=ready_at + timedelta(days=repository.PICKUP_HOLD_DAYS) if ready_at else None)


@router.post("/orders/{order_number}/pickup", response_model=OrderDetail, summary="수령 완료 처리 (인증번호 확인)")
def pickup_confirm(order_number: str, body: PickupConfirm):
    _customer(body.customer_id)
    with _errors():
        repository.confirm_pickup(body.customer_id, order_number, body.code.replace(" ", ""))
        return _detail(body.customer_id, order_number)


# ---------- 교환/반품 (exchangeRequestPage, returnRequestPage, exchangeHistoryPage) ----------
@router.get("/orders/{order_number}/items/{order_item_id}/claim-options", response_model=ClaimOptions,
            summary="교환·반품 신청 화면 선택 값 (사유·교환 사이즈·매장·환불액)")
def claim_options(order_number: str, order_item_id: int, customer_id: str):
    _customer(customer_id)
    with _errors():
        order, items = repository.get_order(customer_id, order_number)
        item = repository.find_item(items, order_item_id)
    notice = None
    if order["status"] != "PICKED_UP":
        notice = "수령 완료된 주문만 교환·반품을 신청할 수 있습니다."
    elif repository.has_open_claim(order_item_id):
        notice = "이미 교환·반품을 신청한 상품입니다."
    product = discover_repository.get_product(item["p_code"])
    sizes = discover_repository.get_options(product)[1] if product else []
    stores = [_store(row) for row in discover_repository.list_pickup_stores()]
    return ClaimOptions(order_number=order_number, item=_order_item(item), eligible=notice is None, notice=notice,
                        reasons=CLAIM_REASONS, available_sizes=sizes, stores=stores,
                        default_dealer_seq=order["dealer_seq"], refund_amount=repository.refund_amount(order, item),
                        max_photos=MAX_PHOTOS)


def _decode_photos(photos):
    decoded = []
    for value in photos:
        try:
            data = base64.b64decode(value.split(",", 1)[-1], validate=True)  # data URL 접두어 허용
        except (binascii.Error, ValueError):
            data = b""
        content_type = next((kind for magic, kind in _IMAGE_TYPES if data.startswith(magic)), None)
        if content_type == "image/webp" and data[8:12] != b"WEBP":
            content_type = None
        if not content_type or len(data) > MAX_PHOTO_BYTES:
            raise HTTPException(status_code=422, detail={"code": "INVALID_PHOTO",
                                                         "message": "사진은 5MB 이하 JPEG/PNG/WEBP 이미지만 첨부할 수 있습니다."})
        decoded.append((content_type, data))
    return decoded


def _claims(customer_id, claim_type=None, claim_id=None):
    rows, items, photos = repository.list_claims(customer_id, claim_type, claim_id)
    encoded = quote(customer_id)
    return [Claim(claim_id=row["claim_id"], claim_type=row["claim_type"],
                  claim_type_label="교환" if row["claim_type"] == "EXCHANGE" else "반품",
                  requested_at=row["requested_at"], order_number=row["order_number"],
                  item=_order_item(items[row["order_item_id"]]), store_name=row["store_name"], reason=row["reason"],
                  detail=row["detail"], requested_size=row["requested_size"], refund_amount=row["refund_amount"],
                  status=row["status"], status_label=_CLAIM_LABELS[row["status"]], stage_index=_CLAIM_STAGE[row["status"]],
                  photo_urls=[f"/api/v1/order/claims/{row['claim_id']}/photos/{photo_id}?customer_id={encoded}"
                              for photo_id in photos.get(row["claim_id"], [])])
            for row in rows if row["order_item_id"] in items]


@router.post("/claims", response_model=Claim, status_code=201, summary="교환·반품 신청 (사진 base64 최대 3장)")
def claim_create(body: ClaimCreate):
    _customer(body.customer_id)
    if body.reason not in CLAIM_REASONS:
        raise HTTPException(status_code=422, detail={"code": "INVALID_REASON", "message": "신청 사유를 선택해 주세요."})
    if body.claim_type == "EXCHANGE" and body.requested_size is None:
        raise HTTPException(status_code=422, detail={"code": "SIZE_REQUIRED", "message": "교환할 사이즈를 선택해 주세요."})
    photos = _decode_photos(body.photos)
    with _errors():
        claim_id = repository.create_claim(body.customer_id, body, photos)
    return _claims(body.customer_id, claim_id=claim_id)[0]


@router.get("/claims", response_model=ClaimListResponse, summary="교환·반품 내역")
def claims(customer_id: str, claim_type: Optional[Literal["EXCHANGE", "RETURN"]] = Query(default=None)):
    _customer(customer_id)
    items = _claims(customer_id, claim_type)
    return ClaimListResponse(items=items, total=len(items))


@router.get("/claims/{claim_id}", response_model=Claim, summary="교환·반품 처리 상태 상세")
def claim_detail(claim_id: int, customer_id: str):
    _customer(customer_id)
    items = _claims(customer_id, claim_id=claim_id)
    if not items:
        raise HTTPException(status_code=404, detail={"code": "CLAIM_NOT_FOUND", "message": "교환·반품 신청을 찾을 수 없습니다."})
    return items[0]


@router.get("/claims/{claim_id}/photos/{photo_id}", summary="교환·반품 첨부 사진")
def claim_photo(claim_id: int, photo_id: int, customer_id: str):
    row = repository.get_claim_photo(customer_id, claim_id, photo_id)
    if row is None:
        raise HTTPException(status_code=404, detail={"code": "PHOTO_NOT_FOUND", "message": "첨부 사진을 찾을 수 없습니다."})
    return Response(content=row["image"], media_type=row["content_type"])


# ---------- 본사/매장 처리 (앱 화면 진행 상태를 바꾸는 운영·시연용) ----------
@router.patch("/admin/orders/{order_number}/status", response_model=OrderSummary, tags=["Order (본사)"],
              summary="주문 진행 단계 변경 (한 단계씩)")
def admin_order_status(order_number: str, body: OrderStatusUpdate):
    with _errors():
        repository.advance_order(order_number, body.status)
        return OrderSummary(**_summary(*repository.get_order(None, order_number)))


@router.patch("/admin/claims/{claim_id}/status", summary="교환·반품 처리 단계 변경", tags=["Order (본사)"])
def admin_claim_status(claim_id: int, body: ClaimStatusUpdate):
    with _errors():
        repository.advance_claim(claim_id, body.status)
    return {"claim_id": claim_id, "status": body.status, "status_label": _CLAIM_LABELS[body.status]}
