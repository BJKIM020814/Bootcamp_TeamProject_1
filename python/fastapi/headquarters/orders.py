"""Read customer purchases from the canonical MySQL purchase table."""

from fastapi import APIRouter, Depends, Query
from python import db
from ..dependencies import current_headquarters_employee
from .schemas import OrderItem, OrderPage

router = APIRouter(prefix='/api/v1/headquarters/orders', tags=['본사 · 주문관리'])
_UNAVAILABLE = ['quantity', 'pickupStatus', 'dealerId', 'paymentInfo', 'shippingStatus']


@router.get('', response_model=OrderPage, summary='고객 주문 목록 조회', description='purchase의 실제 주문행과 p_code 기준 상품 정보를 반환합니다. 레거시 스키마에 없는 값은 null이며 추정하지 않습니다.')
def list_orders(limit: int = Query(50, ge=1, le=100), offset: int = Query(0, ge=0), _employee=Depends(current_headquarters_employee)):
    predicate = ('FROM purchase pu JOIN product p ON p.p_code=pu.p_code '
                 'WHERE NOT EXISTS (SELECT 1 FROM p_return pr '
                 'WHERE pr.customer_customer_id=pu.customer_customer_id '
                 'AND pr.p_id=pu.p_code AND pr.refund=1)')
    rows = db.query('SELECT pu.customer_customer_id AS customer_id,pu.head_office_id,pu.p_code AS product_code,'
                    'p.p_name AS product_name,p.b_name AS brand,pu.p_date AS purchased_at,pu.p_price AS paid_amount '
                    + predicate + ' ORDER BY pu.p_date DESC,pu.p_code LIMIT %s OFFSET %s', (limit, offset))
    total = db.query_one('SELECT COUNT(*) AS total ' + predicate)['total']
    items = []
    # Resolve refund state by exact product code/customer relation; product names are display-only.
    for row in rows:
        refund = db.query_one('SELECT 1 AS refunded FROM p_return '
                              'WHERE customer_customer_id=%s AND p_id=%s AND refund=1 LIMIT 1',
                              (row['customer_id'], row['product_code']))
        items.append(OrderItem(**row, refund_excluded_amount=0 if refund else row['paid_amount'], refunded=bool(refund)))
    return OrderPage(items=items, total=total, limit=limit, offset=offset, unavailable_fields=_UNAVAILABLE)


@router.get('/{customer_id}/{head_office_id}/{product_code}', response_model=OrderItem, summary='주문 상세 조회', description='purchase 복합키로 주문을 찾고 상품은 상품코드로 조회합니다.')
def order_detail(customer_id: str, head_office_id: str, product_code: str, _employee=Depends(current_headquarters_employee)):
    row = db.query_one('SELECT pu.customer_customer_id AS customer_id,pu.head_office_id,pu.p_code AS product_code,'
                       'p.p_name AS product_name,p.b_name AS brand,pu.p_date AS purchased_at,pu.p_price AS paid_amount '
                       'FROM purchase pu JOIN product p ON p.p_code=pu.p_code '
                       'WHERE pu.customer_customer_id=%s AND pu.head_office_id=%s AND pu.p_code=%s',
                       (customer_id, head_office_id, product_code))
    if row is None:
        from fastapi import HTTPException
        raise HTTPException(404, '주문을 찾을 수 없습니다.')
    refund = db.query_one('SELECT 1 AS refunded FROM p_return '
                          'WHERE customer_customer_id=%s AND p_id=%s AND refund=1 LIMIT 1',
                          (customer_id, product_code))
    return OrderItem(**row, refund_excluded_amount=0 if refund else row['paid_amount'], refunded=bool(refund))
