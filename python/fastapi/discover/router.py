"""Discover router: catalogue, selection options, reviews and pickup points."""
from typing import Optional
from urllib.parse import quote
from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import Response

from . import repository
from .schemas import (
    BannerListResponse, BannerSummary, DiscoverFilters, PickupStore, PickupStoreListResponse, ProductDetail,
    ProductListResponse, ProductSummary, ReviewItem, ReviewListResponse,
)

router = APIRouter(prefix="/api/v1/discover", tags=["Discover"])


# 상품 행을 화면 응답으로 바꾸며 저장된 문자열 가격의 쉼표를 정수화한다.
def _image_url(row):
    return f"/api/v1/discover/products/{quote(row['p_code'], safe='')}/image" if row["image_bytes"] else None


def _summary(row):
    try:
        price = int(str(row['p_price']).replace(',', ''))
        if price < 0:
            raise ValueError()
    except (ValueError, TypeError) as exc:
        raise HTTPException(409, detail={'code': 'INVALID_PRODUCT_PRICE',
            'message': '등록된 상품 가격을 확인해 주세요.'}) from exc
    return ProductSummary(
        product_code=row["p_code"], name=row["p_name"], brand=row["b_name"],
        price=price, sku=row["p_sku"], gender=row["p_gender"],
        size=row["p_size"] or None, color=row["p_color"] or None, image_url=_image_url(row),
    )


# 목록은 DB에 등록된 행만 반환하고 검색/필터/페이지 범위를 저장소에 전달한다.
@router.get("/products", response_model=ProductListResponse, summary="Discover 상품 목록·검색·대상·브랜드 필터")
def products(
    keyword: Optional[str] = Query(default=None, max_length=45, description="상품명·브랜드·상품코드 검색"),
    brand: Optional[str] = Query(default=None, max_length=45),
    gender: Optional[str] = Query(default=None, max_length=45),
    limit: int = Query(default=20, ge=1, le=100), offset: int = Query(default=0, ge=0),
):
    rows, total = repository.list_products(brand, gender, keyword, limit, offset)
    return ProductListResponse(items=[_summary(row) for row in rows], total=total, limit=limit, offset=offset)


@router.get("/filters", response_model=DiscoverFilters, summary="현재 등록된 Discover 필터 값")
def available_filters():
    brands, genders = repository.filters()
    return DiscoverFilters(brands=brands, genders=genders)


@router.get("/banners", response_model=BannerListResponse, summary="DB에 등록된 홈 배너 목록")
def banners():
    rows = repository.list_banners()
    items = [BannerSummary(seq=row["seq"], image_url=f"/api/v1/discover/banners/{row['seq']}/image") for row in rows]
    return BannerListResponse(items=items, total=len(items))


@router.get("/banners/{banner_seq}/image", summary="홈 배너 이미지 BLOB")
def banner_image(banner_seq: int):
    image = repository.get_banner_image(banner_seq)
    if not image:
        raise HTTPException(status_code=404, detail={"code": "BANNER_IMAGE_NOT_FOUND", "message": "등록된 배너 이미지가 없습니다."})
    return Response(content=image, media_type="image/jpeg")


@router.get("/products/{product_code}", response_model=ProductDetail, summary="상품 코드별 상세와 등록 옵션")
def product_detail(product_code: str):
    row = repository.get_product(product_code)
    if row is None:
        raise HTTPException(status_code=404, detail={"code": "PRODUCT_NOT_FOUND", "message": "상품을 찾을 수 없습니다."})
    # 표시용 색상/사이즈뿐 아니라 실제 상품코드가 포함된 옵션 행도 반환한다.
    variants = [_summary(option) for option in repository.get_variants(row)]
    colors = sorted({v.color for v in variants if v.color})
    sizes = sorted({v.size for v in variants if v.size and v.size > 0})
    summary = _summary(row)
    return ProductDetail(**summary.model_dump(), available_colors=colors, available_sizes=sizes, variants=variants,
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
def pickup_stores(keyword: Optional[str] = Query(default=None, max_length=45)):
    rows = repository.list_pickup_stores(keyword)
    stores = [PickupStore(seq=row["seq"], name=row["name"], dealer_number=row["dealer_number"], manager=row["manager"], address=row["address"], latitude=row["lat"], longitude=row["lng"]) for row in rows]
    return PickupStoreListResponse(items=stores, total=len(stores))
