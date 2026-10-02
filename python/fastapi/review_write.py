# 리뷰 대상 상품은 구매 내역에서 조회하며 실제 등록 시에도 구매 여부를 다시 확인한다.
"""2. 리뷰작성: 구매한 상품 선택 → 리뷰 등록."""
from fastapi import APIRouter, Depends, Query
from .commerce import get_commerce
from .dependencies import current_email
from .schemas import ReviewCreate, ReviewOut, ReviewableOut, Page

router = APIRouter(tags=['2. 리뷰작성'])


@router.get('/reviewable-products', response_model=Page[ReviewableOut])
def reviewable(limit: int = Query(20, ge=1, le=100), offset: int = Query(0, ge=0),
               email=Depends(current_email), commerce=Depends(get_commerce)):
    # 내 구매 상품 중 아직 리뷰를 쓰지 않은 상품을 프론트 선택 목록으로 제공한다.
    return commerce.reviewable(email, limit, offset)


@router.post('/reviews', status_code=201, response_model=ReviewOut)
def write_review(data: ReviewCreate, email=Depends(current_email), commerce=Depends(get_commerce)):
    # 상품 코드/내용/별점/핏을 받아 구매와 중복을 트랜잭션에서 확인하고 저장한다.
    return commerce.create_review(email, data)
