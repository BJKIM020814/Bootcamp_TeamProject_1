"""Refund-excluded purchase sales aggregates from MySQL."""

from datetime import datetime
from typing import Literal
from fastapi import APIRouter, Depends, HTTPException, Query
from python import db
from ..dependencies import current_headquarters_employee
from .schemas import SalesSummary

router = APIRouter(prefix='/api/v1/headquarters/sales', tags=['본사 · 판매관리'])
_BASE = ('FROM purchase pu WHERE pu.p_date >= %s AND pu.p_date < %s '
         'AND NOT EXISTS (SELECT 1 FROM p_return pr '
         'WHERE pr.customer_customer_id=pu.customer_customer_id '
         'AND pr.p_id=pu.p_code AND pr.refund=1)')


@router.get('/summary', response_model=SalesSummary, summary='기간별 매출 및 상품별 집계', description='선택 기간의 purchase 실결제액을 합산하고 refund=1 반품 건은 매출액에서 제외합니다. 수량 및 대리점 차원은 현재 스키마로 산출할 수 없습니다.')
def sales_summary(start: datetime, end: datetime, group_by: Literal['day', 'product'] = Query('day'), _employee=Depends(current_headquarters_employee)):
    if start >= end:
        raise HTTPException(422, 'start는 end보다 이전이어야 합니다.')
    line_paid = '(pu.p_price*pu.quantity-IF(pu.subtotal>0,ROUND(pu.discount*pu.p_price*pu.quantity/pu.subtotal),0))'
    total = db.query_one('SELECT COUNT(DISTINCT pu.order_code) AS purchase_count,'
                         f'COALESCE(SUM({line_paid}),0) AS net_sales ' + _BASE,
                         (start, end))
    refunded = db.query_one('SELECT COUNT(*) AS count FROM purchase pu WHERE pu.p_date >= %s AND pu.p_date < %s '
                            'AND EXISTS (SELECT 1 FROM p_return pr WHERE pr.customer_customer_id=pu.customer_customer_id '
                            'AND pr.p_id=pu.p_code AND pr.refund=1)', (start, end))['count']
    if group_by == 'day':
        rows = db.query('SELECT DATE(pu.p_date) AS period,COUNT(DISTINCT pu.order_code) AS purchase_count,'
                        f'SUM({line_paid}) AS net_sales '
                        + _BASE + ' GROUP BY DATE(pu.p_date) ORDER BY period', (start, end))
    else:
        rows = db.query('SELECT pu.p_code AS product_code,p.p_name AS product_name,COUNT(DISTINCT pu.order_code) AS purchase_count,'
                        f'SUM({line_paid}) AS net_sales FROM purchase pu JOIN product p ON p.p_code=pu.p_code '
                        'WHERE pu.p_date >= %s AND pu.p_date < %s AND NOT EXISTS (SELECT 1 FROM p_return pr '
                        'WHERE pr.customer_customer_id=pu.customer_customer_id AND pr.p_id=pu.p_code AND pr.refund=1) '
                        'GROUP BY pu.p_code,p.p_name ORDER BY pu.p_code', (start, end))
    return SalesSummary(period_from=start, period_to=end, purchase_count=total['purchase_count'], net_sales=total['net_sales'],
                        excluded_refund_count=refunded, grouping=group_by, items=rows,
                        unavailable_dimensions=['대리점별: purchase에 대리점 연결키가 없는 구형 행이 포함될 수 있음'])


@router.get('/by-branch', status_code=409, summary='대리점별 매출 집계', description='주문행과 수령 대리점을 연결하는 데이터베이스 키가 없어 집계할 수 없습니다.')
def sales_by_branch(_employee=Depends(current_headquarters_employee)):
    raise HTTPException(409, detail={'code': 'BRANCH_SALES_RELATION_REQUIRED', 'message': 'purchase 주문에 authorized_dealer.seq를 연결해야 대리점별 실제 매출을 집계할 수 있습니다.'})
