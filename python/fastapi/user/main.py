"""My FitPick APIRouter, registered by the shared FastAPI application."""
from typing import Optional

import uvicorn
from fastapi import APIRouter, Depends, FastAPI, HTTPException, Request, Response
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from python import db
from python.fastapi.user import mypage_data as md
from python.fastapi.dependencies import current_email

router = APIRouter(prefix="/api/v1", tags=["My FitPick"])


def require_owner(customer_id: str, email: str):
    # 구형 클라이언트의 customer_id는 유지하되 서버 세션과 일치해야 한다.
    if customer_id != email:
        raise HTTPException(403, '본인 회원정보만 사용할 수 있습니다.')
    return email


class ProfileUpdate(BaseModel):
    customer_id: str = Field(examples=["demo@example.com"])
    shoe_size: Optional[int] = Field(default=None, examples=[270])
    favorite_dealer_seq: Optional[int] = None


class PaymentUpdate(BaseModel):
    customer_id: str
    default: str = Field(examples=["카카오페이"])


class ProductRef(BaseModel):
    customer_id: str
    p_code: str = Field(examples=["P2001-240"])


@router.get("/mypage/summary", summary="마이페이지 요약")
def summary(customer_id: str, email=Depends(current_email)):
    return md.get_summary(require_owner(customer_id, email))

@router.get("/mypage/profile", summary="마이페이지 프로필")
def profile(customer_id: str, email=Depends(current_email)):
    return md.get_profile(require_owner(customer_id, email))

@router.put("/mypage/profile", summary="마이페이지 설정 변경")
def profile_update(body: ProfileUpdate, email=Depends(current_email)):
    require_owner(body.customer_id, email)
    if body.shoe_size is not None:
        raise HTTPException(409, '신발 사이즈는 PATCH /api/login/me의 shoeSize로 저장해 주세요.')
    return md.update_profile(email, favorite_dealer_seq=body.favorite_dealer_seq)

@router.get("/mypage/payment", summary="결제수단 조회")
def payment(customer_id: str, email=Depends(current_email)):
    return md.get_payment(require_owner(customer_id, email))

@router.put("/mypage/payment", summary="기본 결제수단 변경")
def payment_update(body: PaymentUpdate, email=Depends(current_email)):
    return md.set_default_payment(require_owner(body.customer_id, email), body.default)

@router.get("/mypage/coupons", summary="사용자 쿠폰함")
def coupons(customer_id: str, email=Depends(current_email)):
    return md.get_coupons(require_owner(customer_id, email))

@router.post('/mypage/coupons/issue', summary='조건 충족 쿠폰 발급')
def issue_coupons(email=Depends(current_email)):
    return md.get_coupons(email, issue=True)

@router.get("/wishlist", summary="찜한 상품 조회")
def wishlist(customer_id: str, email=Depends(current_email)):
    return md.get_wishlist(require_owner(customer_id, email))

@router.post("/wishlist", status_code=201, summary="찜한 상품 추가")
def wishlist_add(body: ProductRef, email=Depends(current_email)):
    md.add_wishlist(require_owner(body.customer_id, email), body.p_code)
    return {"p_code": body.p_code, "liked": True}

@router.delete("/wishlist/{p_code}", summary="찜한 상품 삭제")
def wishlist_remove(p_code: str, customer_id: str, email=Depends(current_email)):
    md.remove_wishlist(require_owner(customer_id, email), p_code)
    return {"p_code": p_code, "liked": False}

@router.get("/recently-viewed", summary="최근 본 상품 조회")
def recently_viewed(customer_id: str, email=Depends(current_email)):
    return md.get_recently_viewed(require_owner(customer_id, email))

@router.post("/recently-viewed", status_code=201, summary="최근 본 상품 기록")
def recently_viewed_add(body: ProductRef, email=Depends(current_email)):
    md.record_view(require_owner(body.customer_id, email), body.p_code)
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
