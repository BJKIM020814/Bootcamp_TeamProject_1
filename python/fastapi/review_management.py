# 모든 리뷰 요청의 소유자는 본문 이메일 대신 로그인 토큰에서 가져온다.
"""1. 리뷰관리: 내 리뷰 목록/상세/수정/삭제."""
from fastapi import APIRouter, Depends, Query
from .commerce import get_commerce
from .dependencies import current_email
from .schemas import ReviewFields, ReviewOut, Page
from .schema_guard import require_schema

router = APIRouter(prefix='/reviews', tags=['1. 리뷰관리'])


@router.get('', response_model=Page[ReviewOut])
def list_reviews(limit: int = Query(20, ge=1, le=100), offset: int = Query(0, ge=0),
                 email=Depends(current_email), commerce=Depends(get_commerce)):
    # limit/offset으로 내 리뷰를 페이지 단위로 가져온다. 상품명과 브랜드도 함께 반환한다.
    return commerce.reviews(email, limit, offset)


@router.get('/{review_id}', response_model=ReviewOut)
def get_review(review_id: int, email=Depends(current_email), commerce=Depends(get_commerce)):
    # 내 소유의 리뷰 상세만 반환한다. 타인의 리뷰와 없는 리뷰는 모두 404로 처리한다.
    return commerce.review(email, review_id)


@router.put('/{review_id}', response_model=ReviewOut)
def update_review(review_id: int, data: ReviewFields, email=Depends(current_email), commerce=Depends(get_commerce)):
    # 별점/내용/핏만 수정하고 리뷰의 소유자와 대상 상품은 바꾸지 않는다.
    require_schema('review', ['review_seq', 'context'], text_lengths={'context': len(data.content)})
    return commerce.update_review(email, review_id, data)


@router.delete('/{review_id}', status_code=204)
def delete_review(review_id: int, email=Depends(current_email), commerce=Depends(get_commerce)):
    # 내 리뷰를 삭제한 뒤 204를 반환한다. 204 성공 응답에는 본문이 없다.
    commerce.delete_review(email, review_id)
