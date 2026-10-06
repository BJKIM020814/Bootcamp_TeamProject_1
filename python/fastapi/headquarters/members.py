"""Head-office member list backed by the canonical MySQL customer table."""

from fastapi import APIRouter, Depends, Query
from python import db
from ..dependencies import current_headquarters_employee

router = APIRouter(prefix='/api/v1/headquarters/members', tags=['본사 · 회원관리'])


@router.get('', summary='회원 목록 조회', description='MySQL customer를 기준으로 누적 결제와 구매 건수를 표시합니다. 비밀번호는 응답하지 않습니다.')
def list_members(keyword: str | None = Query(None, max_length=100),
                 limit: int = Query(50, ge=1, le=100), offset: int = Query(0, ge=0),
                 _employee=Depends(current_headquarters_employee)):
    where = ''
    params: list[object] = []
    if keyword and keyword.strip():
        where = ' WHERE c.customer_id LIKE %s OR c.name LIKE %s OR c.phone LIKE %s'
        term = f'%{keyword.strip()}%'
        params.extend((term, term, term))
    total = db.query_one('SELECT COUNT(*) AS total FROM customer c' + where, params)['total']
    rows = db.query(
        'SELECT c.customer_id,c.name,c.phone,c.gender,c.age,c.totalprice,'
        'COUNT(DISTINCT pu.order_code) AS purchase_count FROM customer c '
        'LEFT JOIN purchase pu ON pu.customer_customer_id=c.customer_id' + where +
        ' GROUP BY c.customer_id,c.name,c.phone,c.gender,c.age,c.totalprice '
        'ORDER BY c.customer_id LIMIT %s OFFSET %s', [*params, limit, offset])
    return {'items': rows, 'total': total, 'limit': limit, 'offset': offset}
