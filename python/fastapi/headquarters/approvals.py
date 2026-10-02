"""Procurement approval workflow persisted in Firestore.

The existing ERD has no approval collection. This API owns a new `procurement_approval`
collection but deliberately does not create supplier orders: quotations have no productId,
so they cannot be safely matched to a product option code.
"""

from datetime import datetime, timezone
from typing import Literal, Optional
from uuid import uuid4
from fastapi import APIRouter, Depends, HTTPException
from google.cloud import firestore
from google.cloud.firestore_v1.base_query import FieldFilter
from pydantic import BaseModel, ConfigDict, Field
from ..accounts import get_accounts
from ..dependencies import HeadquartersEmployee, current_headquarters_employee
from python import db

router = APIRouter(prefix='/api/v1/headquarters/approvals', tags=['본사 · 결재관리'])


class ApprovalCreate(BaseModel):
    model_config = ConfigDict(extra='forbid', str_strip_whitespace=True)
    product_code: str = Field(min_length=1, max_length=45)
    quantity: int = Field(gt=0, le=100000)
    quotation_seq: int = Field(gt=0)
    manufacturer_id: str = Field(min_length=1, max_length=100)
    reason: str = Field(min_length=1, max_length=1000)


class DecisionInput(BaseModel):
    model_config = ConfigDict(extra='forbid', str_strip_whitespace=True)
    decision: Literal['approve', 'reject']
    comment: Optional[str] = Field(default=None, max_length=1000)


def _role(employee: HeadquartersEmployee) -> str:
    position = employee.position.strip().replace(' ', '').lower()
    if position in {'팀장', '팀장급'}:
        return 'team_leader'
    if position in {'이사', '임원', '이사급'}:
        return 'director'
    raise HTTPException(403, '현재 직급에 결재 권한이 없습니다.')


@router.get('', summary='품의 목록 조회', description='기존 ERD에 품의 컬렉션이 없어 본 API의 procurement_approval 문서만 조회합니다.')
def list_approvals(_employee=Depends(current_headquarters_employee), accounts=Depends(get_accounts)):
    docs = accounts.client.collection('procurement_approval').order_by('created_at', direction=firestore.Query.DESCENDING).stream()
    return {'items': [dict(doc.to_dict() or {}, id=doc.id) for doc in docs]}


@router.post('', status_code=201, summary='발주 품의 생성', description='실제 상품코드, 기존 견적 seq와 제조사 ID를 요구합니다. 팀장 승인 단계로 생성됩니다.')
def create_approval(data: ApprovalCreate, employee=Depends(current_headquarters_employee), accounts=Depends(get_accounts)):
    if employee.position.strip().replace(' ', '') not in {'팀장', '팀장급'}:
        raise HTTPException(403, '팀장 직급만 품의를 상신할 수 있습니다.')
    if db.query_one('SELECT p_code FROM product WHERE p_code=%s', (data.product_code,)) is None:
        raise HTTPException(404, '상품코드를 찾을 수 없습니다.')
    inventory = accounts.client.collection('office_inventory').where(
        filter=FieldFilter('productId', '==', data.product_code)).limit(1).stream()
    if next(inventory, None) is None:
        raise HTTPException(409, '본사 재고 기준에 등록된 상품이 아닙니다.')
    quote_docs = list(accounts.client.collection('quotation').where(
        filter=FieldFilter('seq', '==', data.quotation_seq)).limit(2).stream())
    if len(quote_docs) != 1:
        raise HTTPException(409, '견적 seq가 없거나 중복되어 품의를 연결할 수 없습니다.')
    quote = quote_docs[0].to_dict() or {}
    if quote.get('manufacturerId') and quote['manufacturerId'] != data.manufacturer_id:
        raise HTTPException(409, '요청 제조사와 견적서 제조사가 다릅니다.')
    if quote.get('productId') != data.product_code:
        raise HTTPException(409, '견적서에 요청 상품코드가 연결되어 있지 않습니다. 견적 데이터 보완이 필요합니다.')
    ref = accounts.client.collection('procurement_approval').document(uuid4().hex)
    now = datetime.now(timezone.utc)
    payload = {'product_code': data.product_code, 'quantity': data.quantity,
               'quotation_seq': data.quotation_seq, 'manufacturer_id': data.manufacturer_id,
               'reason': data.reason, 'stage': 'team_leader', 'status': 'pending',
               'created_by': employee.employee_id, 'created_at': now, 'history': []}
    ref.create(payload)
    return dict(payload, id=ref.id)


@router.patch('/{approval_id}/decision', summary='팀장/이사 승인 또는 반려', description='직급은 세션 이메일로 연결된 Firestore 직원 문서에서 재조회합니다. 순서와 단일 처리를 트랜잭션으로 검증합니다.')
def decide(approval_id: str, data: DecisionInput, employee=Depends(current_headquarters_employee), accounts=Depends(get_accounts)):
    role = _role(employee)
    ref = accounts.client.collection('procurement_approval').document(approval_id)
    transaction = accounts.client.transaction()

    @firestore.transactional
    def apply(tx):
        snapshot = ref.get(transaction=tx)
        if not snapshot.exists:
            raise HTTPException(404, '품의를 찾을 수 없습니다.')
        record = snapshot.to_dict() or {}
        expected_stage = 'team_leader' if role == 'team_leader' else 'director'
        if record.get('status') != 'pending' or record.get('stage') != expected_stage:
            raise HTTPException(409, '현재 단계에서 처리할 수 없는 품의입니다.')
        now = datetime.now(timezone.utc)
        history = list(record.get('history') or [])
        history.append({'stage': expected_stage, 'employee_id': employee.employee_id,
                        'decision': data.decision, 'comment': data.comment, 'processed_at': now})
        if data.decision == 'reject':
            record.update({'status': 'rejected', 'stage': 'rejected'})
        elif role == 'team_leader':
            record.update({'stage': 'director'})
        else:
            # Manufacturer order creation is intentionally gated on product-linked quotation schema.
            raise HTTPException(409, '견적서와 상품코드 관계가 확인되지 않아 최종 발주를 생성할 수 없습니다.')
        record['history'] = history
        tx.update(ref, record)
        return dict(record, id=approval_id)

    return apply(transaction)
