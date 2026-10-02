"""Discover router: catalogue, selection options, reviews and pickup points."""
from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import Response

from . import repository
from .schemas import (
    DiscoverFilters, PickupStore, PickupStoreListResponse, ProductDetail,
    ProductListResponse, ProductSummary, ReviewItem, ReviewListResponse,
)

router = APIRouter(prefix="/api/v1/discover", tags=["Discover"])


def _image_url(row):
    return f"/api/v1/discover/products/{row['p_code']}/image" if row["image_bytes"] else None


def _summary(row):
    return ProductSummary(
        product_code=row["p_code"], name=row["p_name"], brand=row["b_name"],
        price=int(row["p_price"]), sku=row["p_sku"], gender=row["p_gender"],
        size=row["p_size"] or None, color=row["p_color"] or None, image_url=_image_url(row),
    )


@router.get("/products", response_model=ProductListResponse, summary="Discover 상품 목록·검색·대상·브랜드 필터")
def products(
    keyword: str | None = Query(default=None, max_length=45, description="상품명·브랜드·상품코드 검색"),
    brand: str | None = Query(default=None, max_length=45),
    gender: str | None = Query(default=None, max_length=45),
    limit: int = Query(default=20, ge=1, le=100), offset: int = Query(default=0, ge=0),
):
    rows, total = repository.list_products(brand, gender, keyword, limit, offset)
    return ProductListResponse(items=[_summary(row) for row in rows], total=total, limit=limit, offset=offset)


@router.get("/filters", response_model=DiscoverFilters, summary="현재 등록된 Discover 필터 값")
def available_filters():
    brands, genders = repository.filters()
    return DiscoverFilters(brands=brands, genders=genders)


@router.get("/products/{product_code}", response_model=ProductDetail, summary="상품 코드별 상세와 등록 옵션")
def product_detail(product_code: str):
    row = repository.get_product(product_code)
    if row is None:
        raise HTTPException(status_code=404, detail={"code": "PRODUCT_NOT_FOUND", "message": "상품을 찾을 수 없습니다."})
    colors, sizes = repository.get_options(row)
    summary = _summary(row)
    return ProductDetail(**summary.model_dump(), available_colors=colors, available_sizes=sizes,
        option_notice=None if colors or sizes else "현재 이 상품 코드에 등록된 색상·사이즈 옵션이 없습니다.")


@router.get("/products/{product_code}/image", summary="상품 이미지 바이너리")
def product_image(product_code: str):
    image = repository.get_image(product_code)
    if not image:
        raise HTTPException(status_code=404, detail={"code": "PRODUCT_IMAGE_NOT_FOUND", "message": "등록된 상품 이미지가 없습니다."})
    return Response(content=image, media_type="image/*")


@router.get("/products/{product_code}/reviews", response_model=ReviewListResponse, summary="상품 구매 리뷰")
def product_reviews(product_code: str, limit: int = Query(default=20, ge=1, le=100), offset: int = Query(default=0, ge=0)):
    if repository.get_product(product_code) is None:
        raise HTTPException(status_code=404, detail={"code": "PRODUCT_NOT_FOUND", "message": "상품을 찾을 수 없습니다."})
    rows, total = repository.list_reviews(product_code, limit, offset)
    return ReviewListResponse(items=[ReviewItem(customer_id=row["customer_customer_id"], created_at=row["r_date"], content=row["context"], fit=row["r_fit"], rating=row["rating"], like_count=row["likecount"]) for row in rows], total=total)


@router.get("/pickup-stores", response_model=PickupStoreListResponse, summary="본사 발송 상품 수령 대리점 조회")
def pickup_stores(keyword: str | None = Query(default=None, max_length=45)):
    rows = repository.list_pickup_stores(keyword)
    stores = [PickupStore(seq=row["seq"], name=row["name"], dealer_number=row["dealer_number"], manager=row["manager"], address=row["address"], latitude=row["lat"], longitude=row["lng"]) for row in rows]
    return PickupStoreListResponse(items=stores, total=len(stores))
