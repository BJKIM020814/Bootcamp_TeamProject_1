"""권한·읽기 부작용·스키마 불일치·Auth 이관 회귀 테스트. 실DB는 사용하지 않는다."""
import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from python import db
from python.fastapi.main import app
from python.fastapi.dependencies import current_email, get_local
from python.fastapi.local_store import LocalStore
from python.fastapi.schema_guard import require_schema
from python.fastapi.user import mypage_data as md
from python.fastapi.accounts import Accounts
from python.fastapi.discover import router as discover


@pytest.fixture
def client(tmp_path, monkeypatch):
    # 앱 시작 단계까지 임시 SQLite를 써서 개발 서버의 세션 저장소에 영향이 없게 한다.
    local = LocalStore(tmp_path / 'audit-test.sqlite3')
    monkeypatch.setattr('python.fastapi.main.get_local', lambda: local)
    app.dependency_overrides[get_local] = lambda: local
    try:
        with TestClient(app) as c:
            yield c
    finally:
        app.dependency_overrides.clear()


@pytest.mark.parametrize('path', ['mypage/summary', 'mypage/payment', 'mypage/coupons', 'wishlist', 'recently-viewed'])
def test_mypage_requires_session_and_owner(client, path):
    url = '/api/v1/' + path + '?customer_id=other@example.com'
    assert client.get(url).status_code == 401
    app.dependency_overrides[current_email] = lambda: 'self@example.com'
    assert client.get(url).status_code == 403


def test_mypage_write_rejects_another_customer(client, monkeypatch):
    app.dependency_overrides[current_email] = lambda: 'self@example.com'
    monkeypatch.setattr(db, 'execute', lambda *_: pytest.fail('must reject before DB write'))
    assert client.put('/api/v1/mypage/payment', json={
        'customer_id': 'other@example.com', 'default': '카카오페이'}).status_code == 403


def test_unified_app_preserves_business_error(client, monkeypatch):
    app.dependency_overrides[current_email] = lambda: 'self@example.com'
    monkeypatch.setattr(db, 'query_one', lambda *_: None)
    response = client.get('/api/v1/mypage/summary?customer_id=self@example.com')
    assert response.status_code == 409


def test_profile_read_does_not_create_blank_customer(monkeypatch):
    def query(sql, params):
        if sql.startswith('SELECT customer_id'):
            return {'customer_id': 'self@example.com'}
        return {'shoe_size': None, 'default_payment': None, 'favorite_store': None, 'total_price': 0}
    monkeypatch.setattr(db, 'query_one', query)
    monkeypatch.setattr(db, 'execute', lambda *_: pytest.fail('GET must not write'))
    assert md.get_profile('self@example.com')['shoe_size'] is None


def test_coupon_get_does_not_issue(monkeypatch):
    monkeypatch.setattr(md, 'ensure_customer', lambda *_: None)
    monkeypatch.setattr(db, 'query', lambda *_: [])
    monkeypatch.setattr(db, 'execute', lambda *_: pytest.fail('GET must not issue coupons'))
    assert md.get_coupons('self@example.com') == []


def test_schema_guard_blocks_unsupported_write(monkeypatch):
    monkeypatch.setattr(db, 'query', lambda *_: [
        {'name': 'review_seq', 'extra': '', 'max_length': None},
        {'name': 'context', 'extra': '', 'max_length': 45}])
    with pytest.raises(HTTPException) as error:
        require_schema('review', ['review_seq', 'context'], auto_increment='review_seq', text_lengths={'context': 46})
    assert error.value.status_code == 409
    assert len(error.value.detail['missing_requirements']) == 2


def test_existing_auth_user_cannot_use_legacy_password(monkeypatch):
    accounts = Accounts(None)
    monkeypatch.setattr(accounts, 'find', lambda *_: object())
    monkeypatch.setattr(accounts, 'authenticate', lambda *_: {'email': 'self@example.com'})
    monkeypatch.setattr('python.fastapi.accounts.firebase_app', lambda: None)
    monkeypatch.setattr('python.fastapi.accounts.firebase_auth.get_user_by_email', lambda *a, **k: object())
    with pytest.raises(HTTPException) as error:
        accounts.migrate_legacy_password('self@example.com', 'old-password')
    assert error.value.status_code == 401


def test_migrated_account_changes_password_through_auth(monkeypatch):
    calls = []
    monkeypatch.setattr('python.fastapi.accounts.sign_in_with_password', lambda *_: {'localId': 'uid'})
    monkeypatch.setattr('python.fastapi.accounts.firebase_app', lambda: None)
    monkeypatch.setattr('python.fastapi.accounts.firebase_auth.update_user', lambda uid, **kw: calls.append(uid))
    Accounts(None).change_password('self@example.com', 'current-password', 'new-password')
    assert calls == ['uid']


def test_variant_codes_remain_bound_to_color_size(monkeypatch):
    rows = [dict(p_code=code, p_name='shoe', b_name='brand', p_price='1,000', p_sku='sku',
                 p_gender='공용', p_size=size, p_color=color, image_bytes=0)
            for code, color, size in [('A', 'white', 250), ('B', 'black', 270)]]
    monkeypatch.setattr(discover.repository, 'get_product', lambda *_: rows[0])
    monkeypatch.setattr(discover.repository, 'get_variants', lambda *_: rows)
    result = discover.product_detail('A')
    assert [(v.product_code, v.color, v.size) for v in result.variants] == [('A', 'white', 250), ('B', 'black', 270)]
    assert result.price == 1000
