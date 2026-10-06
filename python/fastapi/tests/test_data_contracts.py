"""권한·읽기 부작용·스키마 불일치·Auth 이관 회귀 테스트. 실DB는 사용하지 않는다."""
from datetime import datetime

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
from python.fastapi.order import router as order


@pytest.fixture
def client(tmp_path, monkeypatch):
    # 앱 시작 단계까지 임시 SQLite를 써서 개발 서버의 세션 저장소에 영향이 없게 한다.
    local = LocalStore(tmp_path / 'audit-test.sqlite3')
    monkeypatch.setattr('python.fastapi.main.get_local', lambda: local)
    monkeypatch.setattr('python.fastapi.order.repository.get_local', lambda: local)
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


def test_recently_viewed_records_only_discover_visible_representative(monkeypatch):
    writes = []
    monkeypatch.setattr(md, 'ensure_customer', lambda *_: None)
    monkeypatch.setattr(db, 'query_one', lambda *_: {'p_code': 'P1002'})
    monkeypatch.setattr(db, 'execute', lambda sql, params: writes.append((sql, params)))

    md.record_view('self@example.com', 'P1002-270')

    insert = next(item for item in writes if item[0].startswith('INSERT INTO recently_viewed'))
    assert insert[1] == ('self@example.com', 'P1002')


def test_recently_viewed_rejects_product_without_discover_image(monkeypatch):
    from python.fastapi.user.mypage_data import MyPageError

    monkeypatch.setattr(md, 'ensure_customer', lambda *_: None)
    monkeypatch.setattr(db, 'query_one', lambda *_: {'p_code': None})
    monkeypatch.setattr(db, 'execute', lambda *_: pytest.fail('hidden product must not be saved'))

    with pytest.raises(MyPageError, match='Discover에 노출되지 않는 상품'):
        md.record_view('self@example.com', 'hidden-product')


def test_recently_viewed_query_filters_hidden_products_and_deduplicates_models(monkeypatch):
    monkeypatch.setattr(md, 'ensure_customer', lambda *_: None)
    captured = {}

    def query(sql, params):
        captured['sql'], captured['params'] = sql, params
        return []

    monkeypatch.setattr(db, 'query', query)
    assert md.get_recently_viewed('self@example.com') == []
    assert 'OCTET_LENGTH(p.p_image) >= 1024' in captured['sql']
    assert 'MIN(p_code) AS p_code' in captured['sql']
    assert 'GROUP BY visible.p_code' in captured['sql']


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
    assert 'review.context: 현재 45자' in error.value.detail['message']
    assert 'restore_legacy_commerce_schema.sql' in error.value.detail['message']


def test_purchase_history_query_declares_alias_once(monkeypatch):
    statements = []
    monkeypatch.setattr(db, 'query_one', lambda sql, params=None: {'total': 0})
    monkeypatch.setattr(db, 'query', lambda sql, params=None: statements.append(sql) or [])
    rows, grouped_items, total = order.repository.list_orders('member@example.com', 'all', 20, 0)
    assert (rows, grouped_items, total) == ([], {}, 0)
    assert 'FROM purchase po WHERE' in statements[0]
    assert 'FROM purchase po po' not in statements[0]


def test_order_status_change_adds_customer_notification(tmp_path, monkeypatch):
    from datetime import datetime
    from python.fastapi.local_store import LocalStore
    from python.fastapi.order.schemas import OrderStatusUpdate

    local = LocalStore(tmp_path / 'order-notification.sqlite3')
    local.initialize()
    monkeypatch.setattr(order, '_purchase_schema', lambda: None)
    monkeypatch.setattr(order.repository, 'advance_order', lambda *_: {
        'customer_id': 'buyer@example.com', 'store_name': '홍대점',
    })
    monkeypatch.setattr(order.repository, 'get_order', lambda *_: ({}, []))
    monkeypatch.setattr(order, '_summary', lambda *_: {
        'order_number': 'FPTEST', 'ordered_at': datetime.now(), 'status': 'SHIPPING',
        'status_label': '대리점으로 발송', 'status_group': 'in_progress', 'stage_index': 2,
        'store_name': '홍대점', 'paid_amount': 120000, 'items': [],
    })

    result = order.admin_order_status('FPTEST', OrderStatusUpdate(status='SHIPPING'), local)

    notifications = local.notifications('buyer@example.com', 20, 0)
    assert result.order_number == 'FPTEST'
    assert notifications['total'] == notifications['unreadCount'] == 1
    assert '홍대점' in notifications['items'][0]['body']


def test_pickup_completion_adds_customer_notification(tmp_path, monkeypatch):
    from python.fastapi.local_store import LocalStore
    from python.fastapi.order.schemas import PickupConfirm

    local = LocalStore(tmp_path / 'pickup-notification.sqlite3')
    local.initialize()
    monkeypatch.setattr(order, '_customer', lambda *_: None)
    monkeypatch.setattr(order.repository, 'confirm_pickup', lambda *_: {
        'customer_id': 'buyer@example.com', 'store_name': '홍대점',
    })
    monkeypatch.setattr(order, '_detail', lambda *_: {'order_number': 'FPTEST', 'picked_up': True})

    result = order.pickup_confirm('FPTEST', PickupConfirm(customer_id='buyer@example.com', code='123456'), local)

    notifications = local.notifications('buyer@example.com', 20, 0)
    assert result['picked_up'] is True
    assert notifications['total'] == notifications['unreadCount'] == 1
    assert notifications['items'][0]['title'] == '주문 수령이 완료되었습니다.'
    assert '홍대점' in notifications['items'][0]['body']


def test_order_creation_and_cancellation_add_notifications(tmp_path, monkeypatch):
    from types import SimpleNamespace
    from python.fastapi.local_store import LocalStore
    from python.fastapi.order.schemas import CustomerRef, OrderCreate

    local = LocalStore(tmp_path / 'order-events.sqlite3')
    local.initialize()
    monkeypatch.setattr(order, '_customer', lambda *_: None)
    monkeypatch.setattr(order, '_purchase_schema', lambda: None)
    monkeypatch.setattr(order.repository, 'create_order', lambda *_: 'FPTEST')
    monkeypatch.setattr(order.repository, 'cancel_order', lambda *_: None)
    monkeypatch.setattr(order, '_detail', lambda *_: SimpleNamespace(store_name='홍대점'))
    body = OrderCreate(customer_id='buyer@example.com', orderer_name='Buyer', orderer_phone='010-1234-5678',
                       payment_method='카드', dealer_seq=1, agreed=True)

    order.order_create(body, local)
    order.order_cancel('FPTEST', CustomerRef(customer_id='buyer@example.com'), local)

    items = local.notifications('buyer@example.com', 20, 0)['items']
    assert [item['title'] for item in items] == ['주문 취소가 처리되었습니다.', '주문이 접수되었습니다.']
    assert all('FPTEST' in item['body'] for item in items)


@pytest.mark.parametrize(('claim_type', 'expected_title'), [
    ('RETURN', '환불(반품) 신청이 접수되었습니다.'),
    ('EXCHANGE', '교환 신청이 접수되었습니다.'),
])
def test_claim_submission_adds_customer_notification(tmp_path, monkeypatch, claim_type, expected_title):
    from python.fastapi.local_store import LocalStore
    from python.fastapi.order.schemas import ClaimCreate

    local = LocalStore(tmp_path / f'{claim_type.lower()}-request-notification.sqlite3')
    local.initialize()
    monkeypatch.setattr(order, '_customer', lambda *_: None)
    monkeypatch.setattr(order, '_decode_photos', lambda *_: [])
    monkeypatch.setattr(order.repository, 'create_claim', lambda *_: 43)
    monkeypatch.setattr(order, '_claims', lambda *_args, **_kwargs: [object()])
    body = ClaimCreate(customer_id='buyer@example.com', order_number='FPTEST', order_item_id=7,
                       claim_type=claim_type, reason='기타', detail='요청 상세 내용입니다.', dealer_seq=1,
                       requested_size=250 if claim_type == 'EXCHANGE' else None)

    result = order.claim_create(body, local)

    notifications = local.notifications('buyer@example.com', 20, 0)
    assert result is not None
    assert notifications['items'][0]['title'] == expected_title
    assert 'FPTEST' in notifications['items'][0]['body']


@pytest.mark.parametrize(('claim_type', 'expected_title'), [
    ('RETURN', '환불 처리가 완료되었습니다.'),
    ('EXCHANGE', '교환 처리가 완료되었습니다.'),
])
def test_claim_completion_adds_type_specific_notification(tmp_path, monkeypatch, claim_type, expected_title):
    from python.fastapi.local_store import LocalStore
    from python.fastapi.order.schemas import ClaimStatusUpdate

    local = LocalStore(tmp_path / f'{claim_type.lower()}-notification.sqlite3')
    local.initialize()
    monkeypatch.setattr(order.repository, 'advance_claim', lambda *_: {
        'customer_id': 'buyer@example.com', 'order_number': 'FPTEST', 'claim_type': claim_type,
        'status': 'DONE',
    })

    result = order.admin_claim_status(42, ClaimStatusUpdate(status='DONE'), local)

    notifications = local.notifications('buyer@example.com', 20, 0)
    assert result['status'] == 'DONE'
    assert notifications['items'][0]['title'] == expected_title
    assert 'FPTEST' in notifications['items'][0]['body']


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


def test_variant_lookup_groups_persisted_options_across_color_sku_families(monkeypatch):
    product = dict(p_code='A', p_name='shoe', b_name='brand', p_price=1000,
                   p_sku='SKU-AR-001-250', p_gender='공용', p_size=250, p_color='white', image_bytes=0)
    rows = [product, dict(product, p_code='B', p_sku='SKU-AR-BLACK-270', p_size=270, p_color='black')]
    calls = []

    def query(sql, params):
        calls.append((sql, params))
        return rows

    monkeypatch.setattr(discover.repository.db, 'query', query)
    result = discover.repository.get_variants(product)
    assert [row['p_code'] for row in result] == ['A', 'B']
    assert calls[0][1] == ('brand', 'shoe', '공용')
    assert 'p_size > 0' in calls[0][0]


def test_product_reviews_include_reviews_on_sibling_size_skus(monkeypatch):
    statements = []
    monkeypatch.setattr(discover.repository.db, 'query_one',
                        lambda sql, params: statements.append((sql, params)) or {'total': 2})
    monkeypatch.setattr(discover.repository.db, 'query',
                        lambda sql, params: statements.append((sql, params)) or [])

    rows, total = discover.repository.list_reviews('P1013-250', 20, 0)

    assert rows == [] and total == 2
    assert len(statements) == 2
    for sql, params in statements:
        assert 'selected.p_name = reviewed.p_name' in sql
        assert 'selected.b_name = reviewed.b_name' in sql
        assert 'selected.p_gender = reviewed.p_gender' in sql
        assert params[0] == 'P1013-250'


def test_product_review_response_includes_image_url_only_when_blob_exists(monkeypatch):
    monkeypatch.setattr(discover.repository, 'get_product', lambda *_: {'p_code': 'A'})
    monkeypatch.setattr(discover.repository, 'list_reviews', lambda *_: ([
        {'review_seq': 12, 'customer_customer_id': 'member@example.com',
         'r_date': datetime(2026, 10, 1), 'context': 'review', 'r_fit': '정사이즈',
         'rating': 5, 'likecount': 0, 'image_bytes': 2048},
        {'review_seq': 13, 'customer_customer_id': 'member@example.com',
         'r_date': datetime(2026, 10, 1), 'context': 'review without image', 'r_fit': '정사이즈',
         'rating': 4, 'likecount': 0, 'image_bytes': None},
        {'review_seq': 14, 'customer_customer_id': 'member@example.com',
         'r_date': datetime(2026, 10, 1), 'context': 'broken header only', 'r_fit': '정사이즈',
         'rating': 3, 'likecount': 0, 'image_bytes': 10},
    ], 3))

    result = discover.product_reviews('A')

    assert result.items[0].image_url == '/api/v1/discover/reviews/12/image'
    assert result.items[1].image_url is None
    assert result.items[2].image_url is None


def test_review_image_endpoint_returns_image_content_type(monkeypatch):
    monkeypatch.setattr(discover.repository, 'get_review_image',
                        lambda review_id: b'\x89PNG\r\n\x1a\nexample')

    response = discover.review_image(12)

    assert response.media_type == 'image/png'
    assert response.body.startswith(b'\x89PNG')


def test_product_listing_groups_skus_by_display_name(monkeypatch):
    statements = []
    product = dict(p_code='P2001-240', p_name='shoe', b_name='brand', p_price='1000',
                   p_sku='SKU-SHOE-WH-240', p_gender='공용', p_size=240, p_color='white', image_bytes=0)
    monkeypatch.setattr(discover.repository.db, 'query_one', lambda sql, params=None: {'total': 1})
    monkeypatch.setattr(discover.repository.db, 'query', lambda sql, params=None: statements.append(sql) or [product])
    rows, total = discover.repository.list_products(limit=20)
    assert total == 1 and len(rows) == 1
    assert 'GROUP BY p_name,b_name,p_gender' in statements[0]
    assert all('OCTET_LENGTH(p_image) >= 1024' in sql for sql in statements)
    assert all('0xFFD8FF' in sql for sql in statements)


def test_purpose_filter_uses_product_usage_column(monkeypatch):
    statements = []
    monkeypatch.setattr(discover.repository.db, 'query_one', lambda *_: {'total': 0})
    monkeypatch.setattr(discover.repository.db, 'query',
                        lambda sql, params=None: statements.append((sql, params)) or [])
    discover.repository.list_products(purpose='데일리')
    assert all('p_usage = %s' in sql for sql, _ in statements)
    assert all('product_purpose' not in sql for sql, _ in statements)
    assert all('데일리' in params for _, params in statements)


def test_available_purposes_come_from_product_usage(monkeypatch):
    statements = []
    def query(sql, _params=None):
        statements.append(sql)
        if 'SELECT DISTINCT p_usage' in sql:
            return [{'p_usage': '데일리'}]
        return []
    monkeypatch.setattr(discover.repository.db, 'query', query)
    _, _, purposes = discover.repository.filters()
    assert purposes == ['데일리']
    assert any('FROM product' in sql and 'p_usage' in sql for sql in statements)
    assert all('product_purpose' not in sql for sql in statements)


def test_cart_storage_is_sqlite_and_does_not_require_mysql_order_tables(tmp_path, monkeypatch):
    local = LocalStore(tmp_path / 'cart.sqlite3')
    local.initialize()
    monkeypatch.setattr(order.repository, 'get_local', lambda: local)
    monkeypatch.setattr(order.repository.db, 'execute', lambda *_: pytest.fail('cart writes must use SQLite'))
    monkeypatch.setattr(order.repository.db, 'query_one', lambda *_: {'found': 1})

    order.repository.add_cart_item('buyer@example.com', 'P1001', 1)
    order.repository.add_cart_item('buyer@example.com', 'P1001', 2)
    order.repository.add_cart_item('other@example.com', 'P1001', 1)

    with local.connection() as conn:
        rows = [dict(row) for row in conn.execute(
            'SELECT customer_id, p_code, quantity, selected FROM cart_items ORDER BY customer_id'
        )]
    assert rows == [
        {'customer_id': 'buyer@example.com', 'p_code': 'P1001', 'quantity': 3, 'selected': 1},
        {'customer_id': 'other@example.com', 'p_code': 'P1001', 'quantity': 1, 'selected': 1},
    ]

    order.repository.select_all_cart_items('buyer@example.com', False)
    assert order.repository.delete_selected_cart_items('buyer@example.com') == 0
    assert order.repository.list_cart('buyer@example.com', selected_only=True) == []


def test_mock_checkout_writes_initial_purchase_schema_and_clears_sqlite_cart(tmp_path, monkeypatch):
    from contextlib import contextmanager
    from types import SimpleNamespace
    from python.fastapi.order.schemas import OrderCreate

    local = LocalStore(tmp_path / 'purchase-test.sqlite3')
    local.initialize()
    with local.connection() as conn:
        conn.execute(
            "INSERT INTO cart_items (customer_id,p_code,quantity,selected) VALUES (?,?,?,1)",
            ('buyer@example.com', 'P1002', 2),
        )

    class Cursor:
        def __init__(self):
            self.rows, self.lastrowid, self.statements = [], 73, []

        def execute(self, sql, params=None):
            self.statements.append((sql, params))
            if 'FROM product WHERE p_code IN' in sql:
                self.rows = [{'p_code': 'P1002', 'p_name': 'Runner', 'b_name': 'Brand',
                              'p_price': '129,000', 'p_color': 'White', 'p_size': 250}]
            elif 'FROM authorized_dealer' in sql:
                self.rows = [{'seq': 2, 'name': 'Central Store', 'address': 'Seoul'}]
            elif 'FROM head_office WHERE division' in sql:
                self.rows = [{'id': 'HQ003'}]
            else:
                self.rows = []

        def executemany(self, sql, rows):
            self.statements.append((sql, list(rows)))

        def fetchall(self):
            return self.rows

        def fetchone(self):
            return self.rows[0] if self.rows else None

    cursor = Cursor()

    @contextmanager
    def fake_transaction():
        yield cursor

    monkeypatch.setattr(order.repository, 'get_local', lambda: local)
    monkeypatch.setattr(order.repository, '_transaction', fake_transaction)
    inventory_events = []
    inventory_client = object()
    monkeypatch.setattr(order.repository, 'get_accounts', lambda: SimpleNamespace(client=inventory_client))

    def reserve_stock(client, order_number, items):
        assert client is inventory_client
        assert [(item['p_code'], item['quantity']) for item in items] == [('P1002', 2)]
        inventory_events.append(('reserve', order_number))

    monkeypatch.setattr(order.repository.stock_inventory, 'reserve_stock', reserve_stock)
    monkeypatch.setattr(order.repository.stock_inventory, 'commit_stock',
                        lambda client, order_number: inventory_events.append(('commit', order_number)))
    payload = OrderCreate(
        customer_id='buyer@example.com', orderer_name='Buyer', orderer_phone='010-1234-5678',
        payment_method='신용 / 체크카드', dealer_seq=2, agreed=True,
    )

    order_code = order.repository.create_order(
        'buyer@example.com', payload, ['신용 / 체크카드'],
    )

    sql = '\n'.join(statement for statement, _ in cursor.statements)
    assert order_code.startswith('FP') and len(order_code) == 20
    assert 'INSERT INTO purchase (' in sql
    assert 'purchase_order_item' not in sql
    assert 'authorized_dealer' in sql
    order_rows = next(rows for statement, rows in cursor.statements
                      if statement.startswith('INSERT INTO purchase ('))
    assert len(order_rows) == 1
    order_row = order_rows[0]
    assert order_row[1:4] == ('buyer@example.com', 'HQ003', 'P1002')
    assert order_row[6] == 2
    assert order_row[7:13] == ('Buyer', '010-1234-5678', 2, 'Central Store', 'Seoul', '신용 / 체크카드')
    assert order_row[15:18] == (258000, 0, 258000)
    assert order_row[18] is not None
    assert inventory_events == [('reserve', order_code), ('commit', order_code)]
    with local.connection() as conn:
        assert conn.execute('SELECT COUNT(*) FROM cart_items').fetchone()[0] == 0


def test_model_stock_allocation_aggregates_skus_and_rejects_shortage():
    from types import SimpleNamespace
    from python.fastapi.order.inventory import StockError, _allocate_inventory

    document = SimpleNamespace(
        id='MODEL-P2001-240',
        to_dict=lambda: {
            'productId': 'P2001-240',
            'productCodes': ['P2001-240', 'P2001-250', 'P2002-240'],
            'minimumQuantity': 100,
            'currentQuantity': 5,
        },
    )
    allocations = _allocate_inventory([
        document,
    ], [
        {'p_code': 'P2001-240', 'quantity': 1},
        {'p_code': 'P2001-250', 'quantity': 2},
    ])
    assert allocations == [{'document_id': 'MODEL-P2001-240', 'quantity': 3}]

    with pytest.raises(StockError) as error:
        _allocate_inventory([document], [{'p_code': 'P2002-240', 'quantity': 6}])
    assert error.value.code == 'INSUFFICIENT_STOCK'


def test_model_stock_allocation_requires_a_registered_inventory_document():
    from python.fastapi.order.inventory import StockError, _allocate_inventory

    with pytest.raises(StockError) as error:
        _allocate_inventory([], [{'p_code': 'P-NOT-MAPPED', 'quantity': 1}])
    assert error.value.code == 'INVENTORY_NOT_CONFIGURED'


def test_cart_api_no_longer_checks_mysql_order_schema(client, monkeypatch):
    monkeypatch.setattr(md, 'ensure_customer', lambda *_: None)

    def query_one(sql, _params=None):
        if 'FROM product' in sql:
            return {'found': 1}
        if 'favorite_dealer_seq' in sql:
            return {'favorite_dealer_seq': None}
        return None

    monkeypatch.setattr(db, 'query_one', query_one)
    monkeypatch.setattr(db, 'query', lambda *_: [{
        'p_code': 'P1001', 'p_name': 'Shoe', 'b_name': 'Brand', 'p_price': '129,000',
        'p_color': 'Black', 'p_size': 270, 'image_bytes': 0,
    }])

    response = client.post('/api/v1/order/cart/items', json={
        'customer_id': 'buyer@example.com', 'product_code': 'P1001', 'quantity': 1,
    })
    assert response.status_code == 201
    assert response.json()['items'][0]['product_code'] == 'P1001'
    assert response.json()['items'][0]['price'] == 129000


def test_home_banners_use_database_rows_and_binary_images(monkeypatch):
    statements = []
    monkeypatch.setattr(discover.repository.db, 'query',
                        lambda sql, params=None: statements.append((sql, params)) or
                        [{'seq': 4}, {'seq': 5}, {'seq': 6}])
    monkeypatch.setattr(discover.repository, 'get_banner_image',
                        lambda seq: b'\x89PNG\r\n\x1a\nimage-bytes' if seq == 4 else None)

    result = discover.banners()
    assert [item.seq for item in result.items] == [4, 5, 6]
    assert statements == [("SELECT seq FROM banner_image WHERE seq BETWEEN %s AND %s ORDER BY seq", (4, 6))]
    image = discover.banner_image(4)
    assert image.body == b'\x89PNG\r\n\x1a\nimage-bytes'
    assert image.media_type == 'image/png'
    with pytest.raises(HTTPException) as error:
        discover.banner_image(6)
    assert error.value.status_code == 404
