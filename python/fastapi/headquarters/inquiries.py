"""Head-office inquiry list and threaded replies backed by the original contact table."""

from pydantic import AliasChoices, Field
from fastapi import APIRouter, Depends, HTTPException, Query
from python import db
from ..commerce import Commerce
from ..customer_support import contact_schema
from ..dependencies import current_headquarters_employee
from ..schemas import Input

router = APIRouter(prefix='/api/v1/headquarters/inquiries', tags=['본사 · 문의관리'])


class InquiryAnswer(Input):
    # 기존 패드 요청의 answer/c_answer/content/response 명칭을 호환해 받는다.
    answer: str = Field(min_length=1, max_length=10000,
                        validation_alias=AliasChoices('answer', 'c_answer', 'content', 'response'))


@router.get('', summary='고객 문의 목록 및 대화 조회', description='초기 ERD contact 문의와 연결된 contact 메시지 행을 반환합니다.')
def list_inquiries(answered: bool | None = None, limit: int = Query(50, ge=1, le=100),
                   offset: int = Query(0, ge=0), _employee=Depends(current_headquarters_employee)):
    contact_schema()
    where = ' WHERE thread_root_seq=c_seq'
    params: list[object] = []
    if answered is not None:
        where += ' AND c_status=%s'
        params.append(1 if answered else 0)
    total = db.query_one('SELECT COUNT(*) AS total FROM contact' + where, params)['total']
    rows = db.query(
        'SELECT customer_customer_id AS customer_id,head_office_id,c_seq AS id,c_seq,contact_post AS content,'
        'contact_post,c_date AS created_at,c_date AS createdAt,c_date,c_answer AS response,c_answer,'
        'IF(c_status=1,c_answerdate,NULL) AS responded_at,IF(c_status=1,c_answerdate,NULL) AS respondedAt,'
        'c_status AS process,c_status AS c_status,comment_seq,level '
        'FROM contact' + where +
        ' ORDER BY c_date DESC,c_seq DESC LIMIT %s OFFSET %s',
        [*params, limit, offset])
    for row in rows:
        row['messages'] = Commerce.inquiry_messages(row)
    return {'items': rows, 'total': total, 'limit': limit, 'offset': offset}


@router.patch('/answer', summary='고객 문의에 답변 추가',
              description='메시지를 직전 대화에 연결하고 최신 답변 요약과 기존 contact 상태도 갱신합니다.')
def answer_inquiry(customer_id: str = Query(..., min_length=3, max_length=45),
                   head_office_id: str = Query(..., min_length=1, max_length=45),
                   c_seq: int = Query(..., ge=1), data: InquiryAnswer = ...,
                   employee=Depends(current_headquarters_employee)):
    contact_schema()
    if not data.answer.strip():
        raise HTTPException(422, '답변 내용을 입력해 주세요.')
    message = Commerce().reply_to_inquiry(customer_id, head_office_id, c_seq,
                                          data.answer.strip(), employee.employee_id)
    return {'ok': True, 'c_seq': c_seq, 'message': message}
