# 실제 SQLite와 대체 Firebase/MySQL 저장소로 인증, 회원 격리, 구매 검증, 부분 실패를 확인한다.
from types import SimpleNamespace
import time
import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from python.fastapi.main import app
from python.fastapi.accounts import get_accounts, passwords, Accounts
from python.fastapi.commerce import get_commerce, Commerce
from python.fastapi.dependencies import get_local
from python.fastapi.local_store import LocalStore
from python import db


class MemoryAccounts:
    def __init__(self):
        self.rows = {}

    def create(self, data):
        if data['email'] in self.rows:
            raise HTTPException(409, 'duplicate')
        row = dict(data, password=passwords.hash(data['password']))
        self.rows[data['email']] = row
        return row

    def authenticate(self, email, password):
        row = self.rows.get(email)
        if not row or not passwords.verify(password, row['password']):
            raise HTTPException(401, 'bad credentials')
        return row

    def find(self, email):
        row = self.rows.get(email)
        return SimpleNamespace(to_dict=lambda: row) if row else None


class MemoryCommerce:
    def __init__(self):
        self.customers = set()
        self.fail = False
        self.rows = {}

    def sync_customer(self, email, age=None):
        if self.fail:
            raise db.DBError('private database password')
        self.customers.add(email)

    def reviews(self, email, limit, offset):
        rows = [v for v in self.rows.values() if v['owner'] == email]
        return {'items': rows[offset:offset + limit], 'total': len(rows), 'limit': limit, 'offset': offset}

    def review(self, email, review_id):
        row = self.rows.get(review_id)
        if not row or row['owner'] != email:
            raise HTTPException(404)
        return row

    def create_contact(self, email, data):
        return {'id': 1, 'content': data.content, 'process': 0, 'createdAt': '2026-10-02T00:00:00', 'response': '', 'respondedAt': None}


@pytest.fixture
def api(tmp_path, monkeypatch):
    local = LocalStore(tmp_path / 'state.sqlite3')
    accounts = MemoryAccounts()
    commerce = MemoryCommerce()
    app.dependency_overrides[get_local] = lambda: local
    app.dependency_overrides[get_accounts] = lambda: accounts
    app.dependency_overrides[get_commerce] = lambda: commerce
    monkeypatch.setattr('python.fastapi.main.get_local', lambda: local)
    with TestClient(app) as client:
        yield client, local, accounts, commerce
    app.dependency_overrides.clear()


def signup(client, email='one@example.com'):
    return client.post('/api/signup', json={'email': email, 'password': 'password with spaces ',
        'name': '사용자', 'phoneNumber': '010-1234-5678', 'address': '서울', 'agreed': True})


def auth(client, email='one@example.com'):
    response = signup(client, email)
    assert response.status_code == 201
    return {'Authorization': 'Bearer ' + response.json()['accessToken']}


def test_signup_login_me_logout(api):
    client, local, accounts, commerce = api
    headers = auth(client)
    assert 'one@example.com' in commerce.customers
    assert accounts.rows['one@example.com']['password'].startswith('$argon2')
    me = client.get('/api/login/me', headers=headers)
    assert 'password' not in me.json()
    assert me.json()['name'] == '사용자'
    assert client.post('/api/login', json={'email': 'one@example.com', 'password': 'bad'}).status_code == 401
    assert client.post('/api/login', json={'email': 'one@example.com', 'password': 'password with spaces '}).status_code == 200
    assert client.post('/api/login/logout', headers=headers).status_code == 204
    assert client.get('/api/settings', headers=headers).status_code == 401
    assert signup(client).status_code == 409


def test_signup_partial_failure_and_retry(api):
    client, local, accounts, commerce = api
    commerce.fail = True
    result = signup(client)
    assert result.status_code == 201
    assert result.json()['customerSynced'] is False
    headers = {'Authorization': 'Bearer ' + result.json()['accessToken']}
    failure = client.post('/api/signup/sync', headers=headers)
    assert failure.status_code == 503
    assert 'private' not in failure.text
    commerce.fail = False
    assert client.post('/api/signup/sync', headers=headers).json()['customerSynced'] is True
    assert client.post('/api/signup/sync', headers=headers).status_code == 200


@pytest.mark.parametrize('method,path', [('GET', '/reviews'), ('GET', '/reviewable-products'),
    ('GET', '/notifications'), ('PATCH', '/notifications/read-all'), ('GET', '/settings'),
    ('GET', '/support/contacts'), ('GET', '/login/me')])
def test_login_required(api, method, path):
    assert api[0].request(method, '/api' + path).status_code == 401


def test_settings_persist_and_isolated(api):
    client, local, _, _ = api
    one, two = auth(client), auth(client, 'two@example.com')
    assert client.patch('/api/settings', headers=one, json={'marketingNotification': True}).status_code == 200
    assert client.get('/api/settings', headers=one).json()['marketingNotification'] is True
    assert client.get('/api/settings', headers=two).json()['marketingNotification'] is False
    assert client.patch('/api/settings', headers=one, json={'marketingNotification': None}).status_code == 422
    restarted = LocalStore(local.path)
    assert restarted.settings('one@example.com')['marketingNotification'] is True


def test_notifications_ownership_and_preferences(api):
    client, local, _, _ = api
    one, two = auth(client), auth(client, 'two@example.com')
    assert local.add_notification('one@example.com', 'marketing', '제목', '내용') is None
    notification = local.add_notification('one@example.com', 'order', '주문', '완료')
    assert client.get('/api/notifications', headers=two).json()['total'] == 0
    assert client.patch(f'/api/notifications/{notification}/read', headers=two).status_code == 404
    assert client.get('/api/notifications', headers=one).json()['unreadCount'] == 1
    assert client.patch(f'/api/notifications/{notification}/read', headers=one).status_code == 200
    assert client.get('/api/notifications', headers=one).json()['unreadCount'] == 0
    assert client.post('/api/support/contacts', headers=one, json={'content': '문의드립니다'}).status_code == 201
    assert client.patch('/api/notifications/read-all', headers=one).json()['updatedCount'] == 1


def test_expired_sessions(api):
    client, local, _, _ = api
    headers = auth(client)
    with local.connection() as conn:
        conn.execute('UPDATE api_sessions SET expires_at=?', (int(time.time()) - 1,))
    assert client.get('/api/settings', headers=headers).status_code == 401


def test_review_ownership(api):
    client, _, _, commerce = api
    one, two = auth(client), auth(client, 'two@example.com')
    commerce.rows[42] = {'id': 42, 'owner': 'one@example.com', 'productCode': 'A', 'productName': '신발', 'brand': '브랜드', 'content': '아주 편안한 신발입니다', 'rating': 5, 'fit': '정사이즈', 'createdAt': '2026-10-02T00:00:00', 'likeCount': 0}
    assert client.get('/api/reviews/42', headers=one).status_code == 200
    assert client.get('/api/reviews/42', headers=two).status_code == 404
    assert client.get('/api/reviews', headers=two).json()['total'] == 0


@pytest.mark.parametrize('payload', [
    {'productCode': 'A', 'content': '짧아요', 'rating': 5},
    {'productCode': 'A', 'content': '아주 편안하고 좋은 신발입니다', 'rating': 6},
    {'productCode': 'A', 'content': '아주 편안하고 좋은 신발입니다', 'rating': 5, 'email': 'victim@example.com'},
])
def test_invalid_review_payload(api, payload):
    headers = auth(api[0])
    assert api[0].post('/api/reviews', headers=headers, json=payload).status_code == 422


def test_pagination_validation(api):
    headers = auth(api[0])
    assert api[0].get('/api/reviews?offset=-1', headers=headers).status_code == 422
    assert api[0].get('/api/notifications?limit=1000', headers=headers).status_code == 422


def test_sql_ownership_and_binding(monkeypatch):
    calls = []
    def query_one(sql, params):
        calls.append((sql, params))
        return None
    monkeypatch.setattr(db, 'query_one', query_one)
    with pytest.raises(HTTPException) as exc:
        Commerce().review("user' OR 1=1 --", 17)
    assert exc.value.status_code == 404
    sql, params = calls[0]
    assert 'r.customer_customer_id=%s AND r.review_seq=%s' in sql
    assert "OR 1=1" not in sql
    assert params == ("user' OR 1=1 --", 17)


def test_purchase_guard_and_duplicate_transaction(monkeypatch):
    from contextlib import contextmanager
    from python.fastapi.schemas import ReviewCreate
    class Cursor:
        lastrowid = 7
        def __init__(self, answers):
            self.answers = iter(answers)
            self.statements = []
        def execute(self, sql, params):
            self.statements.append((sql, params))
        def fetchone(self):
            return next(self.answers)
    for answers, code in [([{'customer_id': 'u'}, None], 403),
                          ([{'customer_id': 'u'}, {'purchase': 1}, {'review': 1}], 409)]:
        cursor = Cursor(answers)
        @contextmanager
        def tx():
            yield cursor
        commerce = Commerce()
        monkeypatch.setattr(commerce, 'transaction', tx)
        with pytest.raises(HTTPException) as exc:
            commerce.create_review('u', ReviewCreate(productCode='A', content='아주 편안한 신발입니다', rating=5))
        assert exc.value.status_code == code
        assert 'FOR UPDATE' in cursor.statements[0][0]
        assert not any('INSERT' in sql for sql, _ in cursor.statements)


def test_real_password_authentication_and_legacy_default(monkeypatch):
    accounts = Accounts(None)
    row = {'email': 'one@example.com', 'password': passwords.hash('password with spaces ')}
    monkeypatch.setattr(accounts, 'find', lambda email: SimpleNamespace(to_dict=lambda: row))
    assert accounts.authenticate('one@example.com', 'password with spaces ') is row
    with pytest.raises(HTTPException):
        accounts.authenticate('one@example.com', 'password with spaces')
    row['password'] = 'plaintext'
    monkeypatch.delenv('ALLOW_LEGACY_PASSWORD_LOGIN', raising=False)
    with pytest.raises(HTTPException):
        accounts.authenticate('one@example.com', 'plaintext')


def test_review_create_success_sql(monkeypatch):
    from contextlib import contextmanager
    from python.fastapi.schemas import ReviewCreate
    answers = iter([{'customer_id': 'member'}, {'purchase': 1}, None])
    statements = []
    class Cursor:
        lastrowid = 13
        def execute(self, sql, params):
            statements.append((sql, params))
        def fetchone(self):
            return next(answers)
    @contextmanager
    def tx():
        yield Cursor()
    commerce = Commerce()
    monkeypatch.setattr(commerce, 'transaction', tx)
    monkeypatch.setattr(commerce, 'review', lambda email, review_id: {'id': review_id})
    data = ReviewCreate(productCode='A', content='실제 구매 후 착용한 신발입니다', rating=4)
    assert commerce.create_review('member', data) == {'id': 13}
    sql, params = statements[-1]
    assert sql.startswith('INSERT INTO review')
    assert params == ('member', 'A', b'', data.content, '정사이즈', 4)


def test_transaction_rolls_back_on_business_error(monkeypatch):
    from contextlib import contextmanager
    class Connection:
        committed = False
        rolled_back = False
        @contextmanager
        def cursor(self):
            yield object()
        def commit(self):
            self.committed = True
        def rollback(self):
            self.rolled_back = True
    conn = Connection()
    @contextmanager
    def connection():
        yield conn
    monkeypatch.setattr(db, 'connection', connection)
    with pytest.raises(HTTPException):
        with Commerce().transaction():
            raise HTTPException(403)
    assert conn.rolled_back and not conn.committed


def test_contact_requires_valid_office_configuration(monkeypatch):
    from python.fastapi.schemas import ContactCreate
    commerce = Commerce()
    monkeypatch.delenv('SUPPORT_HEAD_OFFICE_ID', raising=False)
    with pytest.raises(HTTPException) as exc:
        commerce.create_contact('member', ContactCreate(content='문의'))
    assert exc.value.status_code == 503
    monkeypatch.setenv('SUPPORT_HEAD_OFFICE_ID', 'invalid')
    with pytest.raises(HTTPException) as exc:
        commerce.create_contact('member', ContactCreate(content='문의'))
    assert exc.value.status_code == 503


def test_openapi_contains_frontend_response_contract(api):
    schema = api[0].get('/openapi.json').json()
    response = schema['paths']['/api/reviews']['post']['responses']['201']
    assert response['content']['application/json']['schema']['$ref'].endswith('ReviewOut')
    assert 'NotificationPage' in schema['components']['schemas']
