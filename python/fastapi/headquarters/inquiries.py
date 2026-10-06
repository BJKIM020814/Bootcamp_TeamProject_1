"""Head-office inquiry list and threaded replies backed by MySQL."""

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


@router.get('', summary='고객 문의 목록 및 대화 조회', description='문의와 inquiry_message의 연속 메시지를 본사 화면에 반환합니다.')
def list_inquiries(answered: bool | None = None, limit: int = Query(50, ge=1, le=100),
                   offset: int = Query(0, ge=0), _employee=Depends(current_headquarters_employee)):
    contact_schema()
    where = ''
    params: list[object] = []
    if answered is not None:
        where = ' WHERE i.process=%s'
        params.append(1 if answered else 0)
    total = db.query_one('SELECT COUNT(*) AS total FROM customer_support_inquiry i' + where, params)['total']
    rows = db.query(
        'SELECT i.customer_id,i.head_office_id,i.inquiry_id AS id,COALESCE(i.legacy_c_seq,i.inquiry_id) AS c_seq,'
        'i.content,i.content AS contact_post,i.created_at,i.created_at AS createdAt,i.created_at AS c_date,'
        'i.response,COALESCE(i.response,\'\') AS c_answer,i.responded_at,i.responded_at AS c_answerdate,'
        'i.process,i.process AS c_status,NULL AS comment_seq,NULL AS level '
        'FROM customer_support_inquiry i' + where +
        ' ORDER BY i.created_at DESC,i.inquiry_id DESC LIMIT %s OFFSET %s',
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
