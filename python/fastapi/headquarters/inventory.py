"""Head-office inventory reads from Firebase metadata and MySQL product catalog."""

from fastapi import APIRouter, Depends, HTTPException
from google.cloud.firestore_v1.base_query import FieldFilter
from ..accounts import get_accounts
from ..dependencies import current_headquarters_employee
from .schemas import StockItem, StockPage
from python import db

router = APIRouter(prefix='/api/v1/headquarters/inventory', tags=['본사 · 재고관리'])


@router.get('', response_model=StockPage, summary='본사 상품별 재고 및 발주 필요 여부 조회', description='최소수량은 office_inventory에서, 품명은 MySQL product의 상품코드에서 조회합니다. 검증된 현재고 원장이 없으면 current_quantity와 발주 여부를 null로 반환합니다.')
def inventory(_employee=Depends(current_headquarters_employee), accounts=Depends(get_accounts)):
    client = accounts.client
    docs = list(client.collection('office_inventory').stream())
    items = []
    for doc in docs:
        data = doc.to_dict() or {}
        code = data.get('productId')
        if not isinstance(code, str) or not code:
            continue
        product = db.query_one('SELECT p_code,p_name,b_name FROM product WHERE p_code=%s', (code,))
        if product is None:
            continue
        minimum = data.get('minimumQuantity')
        current = data.get('currentQuantity')
        if isinstance(current, bool) or not isinstance(current, int) or current < 0:
            current = None
        if isinstance(minimum, bool) or not isinstance(minimum, int) or minimum < 0:
            minimum = None
        items.append(StockItem(product_code=product['p_code'], product_name=product['p_name'], brand=product['b_name'],
                               minimum_quantity=minimum, current_quantity=current,
                               reorder_required=(current < minimum) if current is not None and minimum is not None else None,
                               quantity_source='office_inventory.currentQuantity' if current is not None else '미설정'))
    return StockPage(items=items, total=len(items))


@router.post('/{product_code}/adjustments', status_code=501, summary='재고 수량 조정', description='현재 Firebase에는 검증된 현재고·입출고 원장과 상품별 발송 연결키가 없어 원자적 재고 조정을 안전하게 저장할 수 없습니다.')
def adjust_inventory(product_code: str, _employee=Depends(current_headquarters_employee)):
    raise HTTPException(501, detail={'code': 'INVENTORY_LEDGER_REQUIRED', 'message': '현재고 기준 수량 및 상품코드가 포함된 입출고 원장 스키마를 먼저 확정해야 합니다.'})
