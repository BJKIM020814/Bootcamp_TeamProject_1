"""Response contracts for FITPICK headquarters pages."""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict


class Output(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class OrderItem(Output):
    customer_id: str
    head_office_id: str
    product_code: str
    product_name: str
    brand: str
    purchased_at: datetime
    paid_amount: int
    refund_excluded_amount: int
    refunded: bool
    # The legacy purchase table does not contain these relations/status fields.
    quantity: Optional[int] = None
    pickup_status: Optional[str] = None
    dealer_id: Optional[int] = None
    payment_info: Optional[dict] = None
    # 주문 테이블 기준 식별자/진행 상태. 레거시 purchase 행에는 존재하지 않는다.
    order_number: Optional[str] = None
    order_item_id: Optional[int] = None
    order_status: Optional[str] = None


class OrderPage(Output):
    items: list[OrderItem]
    total: int
    limit: int
    offset: int
    unavailable_fields: list[str]


class StockItem(Output):
    product_code: str
    product_name: str
    brand: str
    minimum_quantity: Optional[int] = None
    current_quantity: Optional[int] = None
    reorder_required: Optional[bool] = None
    quantity_source: str


class StockPage(Output):
    items: list[StockItem]
    total: int


class SalesSummary(Output):
    period_from: datetime
    period_to: datetime
    purchase_count: int
    net_sales: int
    excluded_refund_count: int
    grouping: str
    items: list[dict]
    unavailable_dimensions: list[str]


class BranchItem(Output):
    id: int
    name: str
    dealer_number: str
    manager: str
    address: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class BranchPage(Output):
    items: list[BranchItem]
    total: int
    naver_map_configured: bool


class ContractItem(Output):
    head_office_id: str
    model_id: int
    model_name: str
    management: str
    contract_sequence: int
    contract_date: datetime
    start_date: datetime
    end_date: datetime
    contract_fee: int
    option: str
    termination_sequence: Optional[int] = None
    termination_date: Optional[datetime] = None
    termination_fee: Optional[str] = None


class ContractPage(Output):
    items: list[ContractItem]
    total: int
