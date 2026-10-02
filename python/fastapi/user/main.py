"""FITPICK 마이페이지(MY FITPICK) FastAPI 서버

실행(이 폴더에서):  uvicorn main:app --reload --port 8000   (python/fastapi/user)
API 문서:          http://127.0.0.1:8000/docs

화면 매핑
 01 마이페이지      GET  /mypage/summary
 02 내 정보 변경    GET/PUT /mypage/profile   (이름·전화번호·비밀번호는 Firebase account)
 03 결제수단        GET/PUT /mypage/payment
 05 쿠폰            GET  /mypage/coupons
 06 찜한 상품       GET/POST /wishlist, DELETE /wishlist/{p_code}
 07 최근 본 상품    GET/POST /recently-viewed
 (상품 이미지)      GET  /products/{p_code}/image

customer_id 는 Firebase account 의 email 이다. (Firebase ID 토큰 검증은 아직 붙이지 않았다.)
"""
import os
import sys

# python/ 폴더(두 단계 위)의 db.py 를 재사용한다. 상위 폴더 이름이 fastapi 라서 fastapi 폴더에
# __init__.py 를 두면 진짜 fastapi 패키지를 가리므로 만들지 않는다.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from typing import Optional  # noqa: E402

import db  # noqa: E402
import mypage_data as md  # noqa: E402
from fastapi import FastAPI, Request, Response  # noqa: E402
from fastapi.middleware.cors import CORSMiddleware  # noqa: E402
from fastapi.responses import JSONResponse  # noqa: E402
from pydantic import BaseModel  # noqa: E402

app = FastAPI(title="FITPICK 마이페이지 API")

# Flutter Web 에서 호출할 수 있도록 허용. 배포 시에는 origin 을 좁힐 것.
app.add_middleware(
    CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"]
)


@app.exception_handler(md.MyPageError)
async def mypage_error_handler(_: Request, e: md.MyPageError):
    return JSONResponse(status_code=e.status, content={"detail": str(e)})


@app.exception_handler(db.DBError)
async def db_error_handler(_: Request, e: db.DBError):
    print(f"[DBError] {e}")  # 상세 내용은 서버 로그에만 남기고 클라이언트에는 숨긴다
    return JSONResponse(status_code=500, content={"detail": "서버 오류가 발생했습니다."})


# ---------- 요청 모델 ----------
class ProfileUpdate(BaseModel):
    customer_id: str
    shoe_size: Optional[int] = None
    favorite_dealer_seq: Optional[int] = None


class PaymentUpdate(BaseModel):
    customer_id: str
    default: str


class ProductRef(BaseModel):
    customer_id: str
    p_code: str


@app.get("/health")
def health():
    return {"ok": True, "db": db.query_one("SELECT DATABASE() AS name")["name"]}


# ---------- 01 마이페이지 / 02 내 정보 ----------
@app.get("/mypage/summary")
def summary(customer_id: str):
    return md.get_summary(customer_id)


@app.get("/mypage/profile")
def profile(customer_id: str):
    return md.get_profile(customer_id)


@app.put("/mypage/profile")
def profile_update(body: ProfileUpdate):
    return md.update_profile(body.customer_id, body.shoe_size, body.favorite_dealer_seq)


# ---------- 03 결제수단 ----------
@app.get("/mypage/payment")
def payment(customer_id: str):
    return md.get_payment(customer_id)


@app.put("/mypage/payment")
def payment_update(body: PaymentUpdate):
    return md.set_default_payment(body.customer_id, body.default)


# ---------- 05 쿠폰 ----------
@app.get("/mypage/coupons")
def coupons(customer_id: str):
    return md.get_coupons(customer_id)


# ---------- 06 찜한 상품 ----------
@app.get("/wishlist")
def wishlist(customer_id: str):
    return md.get_wishlist(customer_id)


@app.post("/wishlist", status_code=201)
def wishlist_add(body: ProductRef):
    md.add_wishlist(body.customer_id, body.p_code)
    return {"p_code": body.p_code, "liked": True}


@app.delete("/wishlist/{p_code}")
def wishlist_remove(p_code: str, customer_id: str):
    md.remove_wishlist(customer_id, p_code)
    return {"p_code": p_code, "liked": False}


# ---------- 07 최근 본 상품 ----------
@app.get("/recently-viewed")
def recently_viewed(customer_id: str):
    return md.get_recently_viewed(customer_id)


@app.post("/recently-viewed", status_code=201)
def recently_viewed_add(body: ProductRef):
    """상품 상세 화면을 열 때 호출한다."""
    md.record_view(body.customer_id, body.p_code)
    return {"p_code": body.p_code}


# ---------- 상품 이미지 ----------
@app.get("/products/{p_code}/image")
def product_image(p_code: str):
    data = md.get_product_image(p_code)
    if not data:
        return Response(status_code=404)
    return Response(content=data, media_type="image/jpeg")
