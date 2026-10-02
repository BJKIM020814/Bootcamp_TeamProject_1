"""Discover API response schemas exposed in Swagger."""
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class ApiError(BaseModel):
    """Safe API error body. Internal connection details are intentionally omitted."""

    code: str = Field(examples=["DISCOVER_DB_UNAVAILABLE"])
    message: str = Field(examples=["상품 데이터를 일시적으로 조회할 수 없습니다."])


class ProductSummary(BaseModel):
    """List/card data. Product code identifies the registered color/size option."""

    product_code: str = Field(examples=["SAMPLE-NIKE-AF1-07"])
    name: str = Field(examples=["에어 포스 1 '07"])
    brand: str = Field(examples=["나이키"])
    price: int = Field(examples=[119000])
    sku: str = Field(examples=["SAMPLE-NIKE-AF1-07"])
    gender: str = Field(examples=["공용"])
    size: int | None = Field(default=None, examples=[270])
    color: str | None = Field(default=None, examples=["화이트 / 화이트"])
    image_url: str | None = Field(default=None, examples=["/api/v1/discover/products/SAMPLE-NIKE-AF1-07/image"])


class ProductListResponse(BaseModel):
    """Paginated product search response."""

    items: list[ProductSummary]
    total: int = Field(ge=0, examples=[3])
    limit: int = Field(ge=1, examples=[20])
    offset: int = Field(ge=0, examples=[0])


class ProductDetail(ProductSummary):
    """Product detail with only options actually registered in MySQL."""

    available_colors: list[str] = Field(default_factory=list)
    available_sizes: list[int] = Field(default_factory=list)
    option_notice: str | None = Field(default=None)


class ReviewItem(BaseModel):
    customer_id: str
    created_at: datetime
    content: str
    fit: str
    rating: float
    like_count: int


class ReviewListResponse(BaseModel):
    items: list[ReviewItem]
    total: int = Field(ge=0)


class DiscoverFilters(BaseModel):
    """Available filters are derived from stored product fields, never mock data."""

    brands: list[str]
    genders: list[str]
    purposes: list[str] = Field(
        default_factory=list,
        description="product 테이블에 용도 컬럼이 없어 현재 제공하지 않습니다.",
    )


class PickupStore(BaseModel):
    """Pickup point only. It must not be interpreted as dealer sales inventory."""

    seq: int
    name: str
    dealer_number: str
    manager: str
    address: str
    latitude: float
    longitude: float


class PickupStoreListResponse(BaseModel):
    items: list[PickupStore]
    total: int = Field(ge=0)
