"""Order API request/response schemas exposed in Swagger."""
from datetime import datetime
from typing import Annotated, Literal, Optional

from pydantic import BaseModel, Field

# 수령 매장은 Discover 의 수령 대리점과 같은 응답 형식을 쓴다.
from ..discover.schemas import PickupStore

OrderStatus = Literal["PAID", "PREPARING", "SHIPPING", "INSPECTING", "READY", "PICKED_UP", "CANCELLED"]
ClaimType = Literal["EXCHANGE", "RETURN"]
ClaimStatus = Literal["RECEIVED", "CONFIRMED", "VISIT", "DONE", "REJECTED"]
CustomerId = Annotated[str, Field(min_length=3, max_length=45, examples=["demo@example.com"])]


# ---------- 장바구니 ----------
class CartItem(BaseModel):
    """cartController.CartItem 과 같은 항목. 가격·옵션은 product 테이블의 현재 값이다."""

    cart_item_id: int
    product_code: str = Field(examples=["SAMPLE-NIKE-AF1-07"])
    brand: str = Field(examples=["나이키"])
    name: str = Field(examples=["에어 포스 1 '07"])
    color: Optional[str] = Field(default=None, examples=["화이트 / 화이트"])
    size: Optional[int] = Field(default=None, examples=[270])
    option_label: str = Field(examples=["화이트 / 화이트 · 270mm"])
    price: int = Field(examples=[119000])
    quantity: int = Field(ge=1, examples=[1])
    selected: bool
    line_total: int
    image_url: Optional[str] = Field(default=None, examples=["/api/v1/discover/products/SAMPLE-NIKE-AF1-07/image"])


class CartResponse(BaseModel):
    items: list[CartItem]
    total_count: int = Field(ge=0)
    selected_count: int = Field(ge=0)
    selected_total: int = Field(ge=0)
    pickup_store: Optional[PickupStore] = Field(default=None, description="선택한 수령 매장. 없으면 단골 매장, 그것도 없으면 null")


class CartItemAdd(BaseModel):
    customer_id: CustomerId
    product_code: str = Field(min_length=1, max_length=45, examples=["SAMPLE-NIKE-AF1-07"])
    quantity: int = Field(default=1, ge=1, le=10)


class CartItemUpdate(BaseModel):
    customer_id: CustomerId
    quantity: Optional[int] = Field(default=None, ge=1, le=10)
    selected: Optional[bool] = None


class CartSelectAll(BaseModel):
    customer_id: CustomerId
    selected: bool


class CartPickupUpdate(BaseModel):
    customer_id: CustomerId
    dealer_seq: int = Field(ge=1, examples=[1])


# ---------- 주문/결제 ----------
class CheckoutCoupon(BaseModel):
    """지금 사용할 수 있는 쿠폰과 현재 상품 금액 기준 할인액."""

    coupon_id: int
    name: str = Field(examples=["회원가입 10%"])
    discount_type: Literal["PERCENT", "AMOUNT"]
    discount_value: int
    discount_amount: int = Field(ge=0, examples=[11900])
    expires_at: datetime


class CheckoutResponse(BaseModel):
    """주문하기 화면 초기 데이터. 주문자 이름/연락처는 Firebase account 가 관리하므로 포함하지 않는다."""

    items: list[CartItem]
    subtotal: int = Field(ge=0)
    payment_methods: list[str] = Field(examples=[["신용 / 체크카드", "카카오페이", "네이버페이"]])
    default_payment: str = Field(examples=["신용 / 체크카드"])
    coupons: list[CheckoutCoupon]
    pickup_store: Optional[PickupStore] = None


class OrderCreate(BaseModel):
    """장바구니에서 선택된(selected) 상품으로 주문한다. 가격은 서버가 다시 계산한다."""

    customer_id: CustomerId
    orderer_name: str = Field(min_length=1, max_length=45, examples=["홍길동"])
    orderer_phone: str = Field(pattern=r"^[0-9\-]{9,20}$", examples=["010-1234-5678"])
    payment_method: str = Field(examples=["신용 / 체크카드"])
    coupon_id: Optional[int] = Field(default=None, examples=[1])
    dealer_seq: Optional[int] = Field(default=None, ge=1, description="생략하면 장바구니에서 선택한 수령 매장")
    agreed: bool = Field(description="'상품·수령 매장과 주문 내용을 확인했습니다.' 동의 여부")


class OrderItem(BaseModel):
    order_item_id: int
    product_code: str
    brand: str
    name: str
    color: Optional[str] = None
    size: Optional[int] = None
    option_label: str
    price: int
    quantity: int
    line_total: int
    image_url: Optional[str] = None


class OrderSummary(BaseModel):
    """주문내역 카드. stage_index: 0=결제, 1=준비, 2=이동, 3=수령 (orderHistoryPage 기준)"""

    order_number: str = Field(examples=["FP260908-005"])
    ordered_at: datetime
    status: OrderStatus
    status_label: str = Field(examples=["본사 상품 준비"])
    status_group: Literal["in_progress", "completed", "cancelled"]
    stage_index: int = Field(ge=0, le=3)
    store_name: str
    paid_amount: int
    items: list[OrderItem]


class OrderListResponse(BaseModel):
    items: list[OrderSummary]
    total: int = Field(ge=0)
    limit: int
    offset: int


class TimelineStep(BaseModel):
    label: str = Field(examples=["결제 완료"])
    done: bool
    current: bool


class OrderDetail(OrderSummary):
    """주문 완료·주문 상세·수령 QR 화면 데이터."""

    orderer_name: str
    orderer_phone: str
    payment_method: str
    subtotal: int
    discount: int
    coupon_name: Optional[str] = None
    store_address: str
    pickup_store: Optional[PickupStore] = Field(default=None, description="대리점 현재 정보(좌표 포함). 삭제된 매장이면 null")
    timeline: list[TimelineStep]
    pickup_stage: Literal["preparing", "completed"] = Field(description="Flutter PickupStage 값")
    picked_up: bool
    ready_at: Optional[datetime] = None
    pickup_due_at: Optional[datetime] = Field(default=None, description="수령 준비 완료 후 보관 마감일")
    picked_up_at: Optional[datetime] = None
    cancelled_at: Optional[datetime] = None
    can_cancel: bool
    can_claim: bool


class CustomerRef(BaseModel):
    customer_id: CustomerId


class PickupCode(BaseModel):
    """수령 인증 QR. 서버가 발급한 일회성 번호로, 만료되면 다시 발급받는다."""

    order_number: str
    code: str = Field(examples=["123 456"])
    qr_payload: str = Field(examples=["FITPICK-PICKUP:FP260908-005:123456"])
    expires_at: datetime
    visit_from: Optional[datetime] = None
    visit_until: Optional[datetime] = None


class PickupConfirm(BaseModel):
    customer_id: CustomerId
    code: str = Field(pattern=r"^\d{3} ?\d{3}$", examples=["123 456"])


class OrderStatusUpdate(BaseModel):
    """본사/매장 처리용. 한 단계씩만 앞으로 진행할 수 있다."""

    status: Literal["PREPARING", "SHIPPING", "INSPECTING", "READY"]


# ---------- 교환/반품 ----------
class ClaimOptions(BaseModel):
    """교환·반품 신청 화면 선택 값."""

    order_number: str
    item: OrderItem
    eligible: bool
    notice: Optional[str] = Field(default=None, examples=["수령 완료된 주문만 교환·반품을 신청할 수 있습니다."])
    reasons: list[str]
    available_sizes: list[int] = Field(description="같은 SKU 로 등록된 사이즈 (교환용)")
    stores: list[PickupStore]
    default_dealer_seq: int
    refund_amount: int = Field(description="반품 시 환불 예정 금액 (쿠폰 할인 비례 차감)")
    max_photos: int


class ClaimCreate(BaseModel):
    customer_id: CustomerId
    order_number: str = Field(max_length=20)
    order_item_id: int
    claim_type: ClaimType
    reason: str = Field(examples=["사이즈가 작아요"])
    detail: str = Field(min_length=5, max_length=500)
    dealer_seq: int = Field(ge=1)
    requested_size: Optional[int] = Field(default=None, ge=220, le=310, description="교환일 때 필수")
    photos: list[str] = Field(default_factory=list, max_length=3, description="base64 이미지(JPEG/PNG/WEBP), 최대 3장·각 5MB")


class Claim(BaseModel):
    """교환내역 카드. stage_index: 0=신청 접수, 1=본사 확인, 2=방문, 3=완료 (exchangeHistoryPage 기준)"""

    claim_id: int
    claim_type: ClaimType
    claim_type_label: str = Field(examples=["교환"])
    requested_at: datetime
    order_number: str
    item: OrderItem
    store_name: str
    reason: str
    detail: str
    requested_size: Optional[int] = None
    refund_amount: int
    status: ClaimStatus
    status_label: str
    stage_index: int = Field(ge=0, le=3)
    photo_urls: list[str]


class ClaimListResponse(BaseModel):
    items: list[Claim]
    total: int = Field(ge=0)


class ClaimStatusUpdate(BaseModel):
    """본사 처리용. 한 단계씩만 진행하며, 완료 전에는 반려할 수 있다."""

    status: Literal["CONFIRMED", "VISIT", "DONE", "REJECTED"]
