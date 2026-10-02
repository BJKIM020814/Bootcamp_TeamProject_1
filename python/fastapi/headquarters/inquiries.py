"""Head-office inquiry list backed by MySQL contact rows."""

from fastapi import APIRouter, Depends, Query
from python import db
from ..dependencies import current_headquarters_employee

router = APIRouter(prefix='/api/v1/headquarters/inquiries', tags=['본사 · 문의관리'])


@router.get('', summary='고객 문의 목록 조회', description='MySQL contact의 실제 문의와 답변 상태를 조회합니다.')
def list_inquiries(answered: bool | None = None, limit: int = Query(50, ge=1, le=100),
                   offset: int = Query(0, ge=0), _employee=Depends(current_headquarters_employee)):
    where = ''
    params: list[object] = []
    if answered is not None:
        where = ' WHERE c.c_status=%s'
        params.append(1 if answered else 0)
    total = db.query_one('SELECT COUNT(*) AS total FROM contact c' + where, params)['total']
    rows = db.query(
        'SELECT customer_customer_id AS customer_id,head_office_id,c_seq,'
        'contact_post,c_date,c_answer,c_answerdate,c_status,comment_seq,level '
        'FROM contact' + where + ' ORDER BY c_date DESC LIMIT %s OFFSET %s',
        [*params, limit, offset])
    return {'items': rows, 'total': total, 'limit': limit, 'offset': offset}
