"""Head-office review list backed by MySQL review/product rows."""

from fastapi import APIRouter, Depends, Query
from python import db
from ..dependencies import current_headquarters_employee

router = APIRouter(prefix='/api/v1/headquarters/reviews', tags=['본사 · 리뷰관리'])


@router.get('', summary='리뷰 목록 조회', description='MySQL review와 상품코드로 product를 연결합니다. 리뷰 이미지 바이너리는 반환하지 않습니다.')
def list_reviews(limit: int = Query(50, ge=1, le=100), offset: int = Query(0, ge=0),
                 _employee=Depends(current_headquarters_employee)):
    total = db.query_one('SELECT COUNT(*) AS total FROM review')['total']
    rows = db.query(
        'SELECT r.customer_customer_id AS customer_id,r.product_p_code AS product_code,'
        'r.review_seq,r.r_date,r.context,r.r_fit,r.rating,r.likecount,'
        'p.p_name AS product_name,p.b_name AS brand FROM review r '
        'LEFT JOIN product p ON p.p_code=r.product_p_code '
        'ORDER BY r.r_date DESC,r.review_seq DESC LIMIT %s OFFSET %s', (limit, offset))
    return {'items': rows, 'total': total, 'limit': limit, 'offset': offset}
