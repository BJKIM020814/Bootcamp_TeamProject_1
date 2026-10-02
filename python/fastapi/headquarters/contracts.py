"""Contract list and detail backed by existing MySQL model/contract tables."""

from fastapi import APIRouter, Depends, HTTPException, Query
from python import db
from ..dependencies import current_headquarters_employee
from .schemas import ContractItem, ContractPage

router = APIRouter(prefix='/api/v1/headquarters/contracts', tags=['본사 · 계약관리'])
_FROM = ('FROM `contract` c JOIN contraction ct ON ct.c_seq=c.contraction_c_seq '
         'JOIN model m ON m.id=c.model_id LEFT JOIN termination t '
         'ON t.head_office_id=c.head_office_id AND t.model_id=c.model_id')
_SELECT = ('SELECT c.head_office_id,c.model_id,m.name AS model_name,m.management,'
           'c.contraction_c_seq AS contract_sequence,c.c_date AS contract_date,ct.start_date,ct.end_date,'
           'ct.contraction_fee AS contract_fee,ct.c_option AS `option`,t.t_seq AS termination_sequence,'
           't.t_date AS termination_date,t.termination_fee ')


@router.get('', response_model=ContractPage, summary='모델 계약 목록 조회')
def contracts(limit: int = Query(50, ge=1, le=100), offset: int = Query(0, ge=0), _employee=Depends(current_headquarters_employee)):
    rows = db.query(_SELECT + _FROM + ' ORDER BY c.c_date DESC LIMIT %s OFFSET %s', (limit, offset))
    total = db.query_one('SELECT COUNT(*) AS total ' + _FROM)['total']
    return ContractPage(items=rows, total=total)


@router.get('/{head_office_id}/{model_id}/{contract_sequence}', response_model=ContractItem, summary='모델 계약 상세 조회', description='종료금액은 기존 termination.termination_fee 저장값을 문자 그대로 반환하며 정책 계산은 하지 않습니다.')
def contract_detail(head_office_id: str, model_id: int, contract_sequence: int, _employee=Depends(current_headquarters_employee)):
    row = db.query_one(_SELECT + _FROM + ' WHERE c.head_office_id=%s AND c.model_id=%s AND c.contraction_c_seq=%s',
                       (head_office_id, model_id, contract_sequence))
    if row is None:
        raise HTTPException(404, '계약을 찾을 수 없습니다.')
    return row
