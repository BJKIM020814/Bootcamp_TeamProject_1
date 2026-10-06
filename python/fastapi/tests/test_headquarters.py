"""Headquarters API contract tests use isolated in-memory dependencies and never mutate live data."""

from datetime import datetime
from types import SimpleNamespace

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient

from python import db
from python.fastapi.dependencies import current_headquarters_employee, HeadquartersEmployee
from python.fastapi.main import app, swagger_route_status


@pytest.fixture
def client():
    app.dependency_overrides[current_headquarters_employee] = lambda: HeadquartersEmployee('EMP-T', '팀장', '상품관리부')
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


def test_headquarters_routes_are_registered_in_openapi():
    status = swagger_route_status()
    assert status['ok'] is True
    spec = app.openapi()
    assert '/api/v1/headquarters/orders' in spec['paths']
    assert 'patch' in spec['paths']['/api/v1/headquarters/inquiries/answer']
    assert '본사 · 주문관리' in spec['paths']['/api/v1/headquarters/orders']['get']['tags']


def test_headquarters_inquiry_answer_route_appends_staff_reply(client, monkeypatch):
    from python.fastapi.commerce import Commerce
    monkeypatch.setattr('python.fastapi.headquarters.inquiries.contact_schema', lambda: None)
    monkeypatch.setattr(Commerce, 'reply_to_inquiry',
                        lambda self, customer_id, head_office_id, c_seq, answer, employee_id: {
                            'id': 13, 'authorRole': 'employee', 'authorId': employee_id,
                            'content': answer, 'createdAt': datetime(2026, 10, 6), 'turnIndex': 3})
    response = client.patch(
        '/api/v1/headquarters/inquiries/answer',
        params={'customer_id': 'member@example.com', 'head_office_id': 'HQ004', 'c_seq': 9},
        json={'c_answer': '확인 후 안내드리겠습니다.'})
    assert response.status_code == 200
    assert response.json()['message']['authorRole'] == 'employee'
    assert response.json()['message']['turnIndex'] == 3


def test_headquarters_requires_authenticated_employee_mapping():
    app.dependency_overrides.pop(current_headquarters_employee, None)
    class Local:
        def session_email(self, token):
            return 'member@example.com'
    from python.fastapi.dependencies import current_email, get_local
    app.dependency_overrides[current_email] = lambda: 'member@example.com'
    class Accounts:
        client = SimpleNamespace(collection=lambda name: SimpleNamespace(
            where=lambda **kwargs: SimpleNamespace(limit=lambda count: SimpleNamespace(stream=lambda: []))))
    from python.fastapi.accounts import get_accounts
    app.dependency_overrides[get_accounts] = lambda: Accounts()
    with TestClient(app) as test_client:
        response = test_client.get('/api/v1/headquarters/orders')
    assert response.status_code == 403
    app.dependency_overrides.pop(current_email, None)
    app.dependency_overrides.pop(get_accounts, None)


def test_orders_empty_result_uses_canonical_order_tables(client, monkeypatch):
    calls = []
    def query(sql, params=None):
        calls.append((sql, params))
        return []
    monkeypatch.setattr(db, 'query', query)
    monkeypatch.setattr(db, 'query_one', lambda sql, params=None: {'total': 0})
    response = client.get('/api/v1/headquarters/orders')
    assert response.status_code == 200
    assert response.json()['items'] == []
    assert 'quantity' not in response.json()['unavailable_fields']
    assert all('purchase' in sql for sql, _ in calls)
    assert all('purchase_order_item' not in sql for sql, _ in calls)


def test_orders_return_checkout_row_and_order_identifier(client, monkeypatch):
    def query(sql, params=None):
        assert 'FROM purchase pu JOIN product' in sql
        return [{
            'customer_id': 'member@example.com', 'head_office_id': 'HQ004',
            'product_code': 'P1002', 'product_name': '러닝화', 'brand': 'FITPICK',
            'purchased_at': datetime(2026, 10, 6), 'paid_amount': 10000,
            'quantity': 1, 'pickup_status': 'PAID', 'dealer_id': 1,
            'payment_method': '카드', 'coupon_name': None,
            'order_number': 'FP123', 'order_item_id': 9,
            'order_status': 'PAID', 'refunded': 0,
        }]
    monkeypatch.setattr(db, 'query', query)
    monkeypatch.setattr(db, 'query_one', lambda *args, **kwargs: {'total': 1})
    response = client.get('/api/v1/headquarters/orders')
    assert response.status_code == 200
    assert response.json()['total'] == 1
    item = response.json()['items'][0]
    assert item['order_number'] == 'FP123'
    assert item['order_status'] == 'PAID'
    assert item['quantity'] == 1


def test_order_detail_invalid_id_returns_404(client, monkeypatch):
    monkeypatch.setattr(db, 'query_one', lambda *args, **kwargs: None)
    response = client.get('/api/v1/headquarters/orders/nobody/HQ-1/NOT-A-CODE')
    assert response.status_code == 404


def test_sales_requires_valid_range_and_excludes_refunds(client, monkeypatch):
    calls = []
    def query_one(sql, params=None):
        calls.append((sql, params))
        if 'purchase_count' in sql:
            return {'purchase_count': 0, 'net_sales': 0}
        return {'count': 0}
    monkeypatch.setattr(db, 'query_one', query_one)
    monkeypatch.setattr(db, 'query', lambda *args, **kwargs: [])
    invalid = client.get('/api/v1/headquarters/sales/summary', params={
        'start': '2026-10-02T10:00:00', 'end': '2026-10-02T09:00:00'})
    assert invalid.status_code == 422
    response = client.get('/api/v1/headquarters/sales/summary', params={
        'start': '2026-10-01T00:00:00', 'end': '2026-10-03T00:00:00'})
    assert response.status_code == 200
    assert response.json()['net_sales'] == 0
    assert response.json()['unavailable_dimensions']
    assert all('pr.refund=1' in sql for sql, _ in calls)


def test_branch_sales_and_inventory_write_fail_closed(client):
    branch = client.get('/api/v1/headquarters/sales/by-branch')
    adjustment = client.post('/api/v1/headquarters/inventory/SH-001/adjustments')
    assert branch.status_code == 409
    assert adjustment.status_code == 501


def test_approval_role_does_not_trust_client_employee_id(monkeypatch):
    from python.fastapi.headquarters.approvals import _role
    assert _role(HeadquartersEmployee('EMP-T', '팀장', '상품관리부')) == 'team_leader'
    with pytest.raises(HTTPException) as error:
        _role(HeadquartersEmployee('EMP-X', '대리', '상품관리부'))
    assert error.value.status_code == 403
