"""My FitPick APIRouter, registered by the shared FastAPI application."""
from typing import Optional

import uvicorn
from fastapi import APIRouter, FastAPI, Request, Response
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from python import db
from python.fastapi.user import mypage_data as md

router = APIRouter(prefix="/api/v1", tags=["My FitPick"])


class ProfileUpdate(BaseModel):
    customer_id: str = Field(examples=["demo@example.com"])
    shoe_size: Optional[int] = Field(default=None, examples=[270])
    favorite_dealer_seq: Optional[int] = None


class PaymentUpdate(BaseModel):
    customer_id: str
    default: str = Field(examples=["카카오페이"])


class ProductRef(BaseModel):
    customer_id: str
    p_code: str = Field(examples=["SAMPLE-NIKE-AF1-07"])


@router.get("/mypage/summary", summary="마이페이지 요약")
def summary(customer_id: str): return md.get_summary(customer_id)

@router.get("/mypage/profile", summary="마이페이지 프로필")
def profile(customer_id: str): return md.get_profile(customer_id)

@router.put("/mypage/profile", summary="마이페이지 설정 변경")
def profile_update(body: ProfileUpdate): return md.update_profile(body.customer_id, body.shoe_size, body.favorite_dealer_seq)

@router.get("/mypage/payment", summary="결제수단 조회")
def payment(customer_id: str): return md.get_payment(customer_id)

@router.put("/mypage/payment", summary="기본 결제수단 변경")
def payment_update(body: PaymentUpdate): return md.set_default_payment(body.customer_id, body.default)

@router.get("/mypage/coupons", summary="사용자 쿠폰함")
def coupons(customer_id: str): return md.get_coupons(customer_id)

@router.get("/wishlist", summary="찜한 상품 조회")
def wishlist(customer_id: str): return md.get_wishlist(customer_id)

@router.post("/wishlist", status_code=201, summary="찜한 상품 추가")
def wishlist_add(body: ProductRef):
    md.add_wishlist(body.customer_id, body.p_code)
    return {"p_code": body.p_code, "liked": True}

@router.delete("/wishlist/{p_code}", summary="찜한 상품 삭제")
def wishlist_remove(p_code: str, customer_id: str):
    md.remove_wishlist(customer_id, p_code)
    return {"p_code": p_code, "liked": False}

@router.get("/recently-viewed", summary="최근 본 상품 조회")
def recently_viewed(customer_id: str): return md.get_recently_viewed(customer_id)

@router.post("/recently-viewed", status_code=201, summary="최근 본 상품 기록")
def recently_viewed_add(body: ProductRef):
    md.record_view(body.customer_id, body.p_code)
    return {"p_code": body.p_code}

@router.get("/products/{p_code}/image", summary="마이페이지 상품 이미지")
def product_image(p_code: str):
    image = md.get_product_image(p_code)
    return Response(status_code=404) if not image else Response(content=image, media_type="image/jpeg")


def create_standalone_app() -> FastAPI:
    """Compatibility entry point for user-only server runs."""
    standalone = FastAPI(title="FITPICK My FitPick API")
    standalone.include_router(router)
    return standalone


app = create_standalone_app()

@app.exception_handler(md.MyPageError)
async def mypage_error_handler(_: Request, error: md.MyPageError):
    return JSONResponse(status_code=error.status, content={"detail": str(error)})

@app.exception_handler(db.DBError)
async def db_error_handler(_: Request, error: db.DBError):
    return JSONResponse(status_code=503, content={"detail": "서버 오류가 발생했습니다."})

if __name__ == "__main__":
    uvicorn.run("python.fastapi.user.main:app", host="127.0.0.1", port=8000, reload=True)
