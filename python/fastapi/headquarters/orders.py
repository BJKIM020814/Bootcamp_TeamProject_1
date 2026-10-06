"""Read customer order lines from the initial ERD purchase table."""

from fastapi import APIRouter, Depends, Query
from python import db
from ..dependencies import current_headquarters_employee
from .schemas import OrderItem, OrderPage

router = APIRouter(prefix='/api/v1/headquarters/orders', tags=['본사 · 주문관리'])
_UNAVAILABLE = ['shippingStatus']

_ORDER_FROM = ('FROM purchase pu JOIN product p ON p.p_code=pu.p_code '
               'LEFT JOIN authorized_dealer ad ON ad.seq=pu.dealer_seq')
_ORDER_COLUMNS = ('pu.customer_customer_id AS customer_id,pu.head_office_id,pu.p_code AS product_code,'
                  'p.p_name AS product_name,p.b_name AS brand,pu.p_date AS purchased_at,'
                  '(pu.p_price*pu.quantity-IF(pu.subtotal>0,ROUND(pu.discount*pu.p_price*pu.quantity/pu.subtotal),0)) '
                  'AS paid_amount,pu.quantity,pu.order_status AS pickup_status,pu.dealer_seq AS dealer_id,'
                  'ad.name AS dealer_name,ad.address AS dealer_address,'
                  'pu.payment_method,pu.coupon_name,pu.order_code AS order_number,pu.purchase_id AS order_item_id,'
                  'pu.order_status AS order_status,'
                  'EXISTS(SELECT 1 FROM order_claim oc WHERE oc.order_item_id=pu.purchase_id '
                  "AND oc.claim_type='RETURN' AND oc.status='DONE') AS refunded")


def _order_item(row):
    values = dict(row)
    refunded = bool(values.pop('refunded'))
    values['payment_info'] = {
        'method': values.pop('payment_method'),
        'coupon': values.pop('coupon_name'),
    }
    return OrderItem(**values, refund_excluded_amount=0 if refunded else values['paid_amount'],
                     refunded=refunded)


@router.get('', response_model=OrderPage, summary='고객 주문 목록 조회', description='초기 ERD의 purchase 행을 조회합니다. order_code가 여러 상품 행을 하나의 주문으로 묶습니다.')
def list_orders(limit: int = Query(50, ge=1, le=100), offset: int = Query(0, ge=0), _employee=Depends(current_headquarters_employee)):
    rows = db.query('SELECT ' + _ORDER_COLUMNS + ' ' + _ORDER_FROM +
                    ' ORDER BY pu.p_date DESC,pu.purchase_id DESC LIMIT %s OFFSET %s',
                    (limit, offset))
    total = db.query_one('SELECT COUNT(*) AS total ' + _ORDER_FROM)['total']
    items = [_order_item(row) for row in rows]
    return OrderPage(items=items, total=total, limit=limit, offset=offset, unavailable_fields=_UNAVAILABLE)


@router.get('/{customer_id}/{head_office_id}/{product_code}', response_model=OrderItem, summary='기존 구매행 조회', description='기존 고객·본사·상품 키와 일치하는 최신 purchase 행을 조회합니다.')
def order_detail(customer_id: str, head_office_id: str, product_code: str, _employee=Depends(current_headquarters_employee)):
    row = db.query_one('SELECT ' + _ORDER_COLUMNS + ' ' + _ORDER_FROM +
                       ' WHERE pu.customer_customer_id=%s AND pu.head_office_id=%s AND pu.p_code=%s '
                       'ORDER BY pu.p_date DESC,pu.purchase_id DESC LIMIT 1',
                       (customer_id, head_office_id, product_code))
    if row is None:
        from fastapi import HTTPException
        raise HTTPException(404, '주문을 찾을 수 없습니다.')
    return _order_item(row)


@router.get('/by-number/{order_number}', response_model=list[OrderItem], summary='주문번호로 주문 상세 조회',
            description='purchase.order_code로 연결된 전체 상품 행을 반환합니다.')
def order_by_number(order_number: str, _employee=Depends(current_headquarters_employee)):
    rows = db.query('SELECT ' + _ORDER_COLUMNS + ' ' + _ORDER_FROM +
                    ' WHERE pu.order_code=%s ORDER BY pu.purchase_id', (order_number,))
    if not rows:
        from fastapi import HTTPException
        raise HTTPException(404, '주문을 찾을 수 없습니다.')
    return [_order_item(row) for row in rows]
