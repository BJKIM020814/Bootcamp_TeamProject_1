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
    assert '본사 · 주문관리' in spec['paths']['/api/v1/headquarters/orders']['get']['tags']


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


def test_orders_empty_result_and_product_code_binding(client, monkeypatch):
    calls = []
    def query(sql, params=None):
        calls.append((sql, params))
        return []
    monkeypatch.setattr(db, 'query', query)
    monkeypatch.setattr(db, 'query_one', lambda sql, params=None: {'total': 0})
    response = client.get('/api/v1/headquarters/orders')
    assert response.status_code == 200
    assert response.json()['items'] == []
    assert 'quantity' in response.json()['unavailable_fields']
    assert all('p.p_code=pu.p_code' in sql for sql, _ in calls)


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
