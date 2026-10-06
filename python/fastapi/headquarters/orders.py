"""Read customer orders from purchase_order and its order-item relations."""

from fastapi import APIRouter, Depends, Query
from python import db
from ..dependencies import current_headquarters_employee
from .schemas import OrderItem, OrderPage

router = APIRouter(prefix='/api/v1/headquarters/orders', tags=['본사 · 주문관리'])
_UNAVAILABLE = ['shippingStatus']

# 한 행은 주문의 상품 한 줄이다. 레거시 purchase는 고객+본사 복합 PK라
# 주문 시점에 상품 여러 개/반복 주문을 안전하게 저장할 수 없어 주문 원본으로 쓰지 않는다.
_ORDER_FROM = ('FROM purchase_order po '
               'JOIN purchase_order_detail d ON d.order_id=po.order_id '
               'JOIN purchase_order_item oi ON oi.order_id=po.order_id '
               'JOIN product p ON p.p_code=oi.p_code')
_ORDER_COLUMNS = ('po.customer_id AS customer_id,po.head_office_id,oi.p_code AS product_code,'
                  'p.p_name AS product_name,p.b_name AS brand,po.ordered_at AS purchased_at,'
                  '(oi.unit_price*oi.quantity-IF(d.subtotal>0,ROUND(d.discount*oi.unit_price*oi.quantity/d.subtotal),0)) '
                  'AS paid_amount,oi.quantity,po.status AS pickup_status,d.dealer_seq AS dealer_id,'
                  'd.payment_method,d.coupon_name,'
                  'd.order_code AS order_number,oi.order_item_id,po.status AS order_status,'
                  'EXISTS(SELECT 1 FROM order_claim oc WHERE oc.order_item_id=oi.order_item_id '
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


@router.get('', response_model=OrderPage, summary='고객 주문 목록 조회', description='결제 직후 저장되는 purchase_order 및 주문상품을 조회합니다. 한 행은 주문의 상품 한 줄입니다.')
def list_orders(limit: int = Query(50, ge=1, le=100), offset: int = Query(0, ge=0), _employee=Depends(current_headquarters_employee)):
    rows = db.query('SELECT ' + _ORDER_COLUMNS + ' ' + _ORDER_FROM +
                    ' ORDER BY po.ordered_at DESC,po.order_id DESC,oi.order_item_id LIMIT %s OFFSET %s',
                    (limit, offset))
    total = db.query_one('SELECT COUNT(*) AS total ' + _ORDER_FROM)['total']
    items = [_order_item(row) for row in rows]
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


@router.get('/by-number/{order_number}', response_model=list[OrderItem], summary='주문번호로 주문 상세 조회',
            description='purchase_order 주문번호와 주문상품 ID로 전체 상품 줄을 반환합니다.')
def order_by_number(order_number: str, _employee=Depends(current_headquarters_employee)):
    rows = db.query('SELECT ' + _ORDER_COLUMNS + ' ' + _ORDER_FROM +
                    ' WHERE d.order_code=%s ORDER BY oi.order_item_id', (order_number,))
    if not rows:
        from fastapi import HTTPException
        raise HTTPException(404, '주문을 찾을 수 없습니다.')
    return [_order_item(row) for row in rows]
