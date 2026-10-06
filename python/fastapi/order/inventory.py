"""Firestore-backed model inventory reservations used by the checkout workflow."""

from collections import defaultdict

from google.cloud import firestore


class StockError(Exception):
    """A safe, user-facing inventory validation failure."""

    def __init__(self, status: int, code: str, message: str):
        super().__init__(message)
        self.status = status
        self.code = code
        self.message = message


def _allocate_inventory(documents, items):
    """Map SKU order lines to one model-level Firebase inventory record each."""
    by_code = {}
    for snapshot in documents:
        data = snapshot.to_dict() or {}
        codes = data.get('productCodes')
        if not isinstance(codes, list):
            codes = []
        product_id = data.get('productId')
        if isinstance(product_id, str):
            codes.append(product_id)
        for code in set(codes):
            previous = by_code.get(code)
            if previous is not None and previous.id != snapshot.id:
                raise StockError(409, 'AMBIGUOUS_INVENTORY', '상품이 여러 재고 모델에 연결되어 있습니다.')
            by_code[code] = snapshot

    quantities = defaultdict(int)
    for item in items:
        code, quantity = item.get('p_code'), item.get('quantity')
        if not isinstance(code, str) or isinstance(quantity, bool) or not isinstance(quantity, int) or quantity <= 0:
            raise StockError(409, 'INVALID_ORDER_QUANTITY', '주문 상품의 코드 또는 수량이 올바르지 않습니다.')
        snapshot = by_code.get(code)
        if snapshot is None:
            raise StockError(409, 'INVENTORY_NOT_CONFIGURED', '상품의 본사 재고 기준이 등록되어 있지 않습니다.')
        quantities[snapshot.id] += quantity

    by_id = {snapshot.id: snapshot for snapshot in documents}
    allocations = []
    for document_id, quantity in quantities.items():
        snapshot = by_id[document_id]
        data = snapshot.to_dict() or {}
        current = data.get('currentQuantity')
        if isinstance(current, bool) or not isinstance(current, int) or current < 0:
            raise StockError(409, 'INVENTORY_QUANTITY_MISSING', '상품의 현재 재고 수량이 올바르게 설정되지 않았습니다.')
        if current < quantity:
            raise StockError(409, 'INSUFFICIENT_STOCK', '선택한 상품의 재고가 주문 수량보다 부족합니다.')
        allocations.append({'document_id': document_id, 'quantity': quantity})
    return allocations


def reserve_stock(client, reservation_id, items):
    """Atomically decrement model stock and create an order-linked reservation."""
    inventory = client.collection('office_inventory')
    reservation_ref = client.collection('inventory_reservation').document(reservation_id)
    transaction = client.transaction()

    @firestore.transactional
    def reserve(tx):
        if reservation_ref.get(transaction=tx).exists:
            raise StockError(409, 'DUPLICATE_STOCK_RESERVATION', '주문 재고 예약이 이미 처리되었습니다.')
        documents = list(inventory.stream(transaction=tx))
        allocations = _allocate_inventory(documents, items)
        snapshots = {snapshot.id: snapshot for snapshot in documents}
        for allocation in allocations:
            snapshot = snapshots[allocation['document_id']]
            current = (snapshot.to_dict() or {})['currentQuantity']
            tx.update(snapshot.reference, {
                'currentQuantity': current - allocation['quantity'],
                'updatedAt': firestore.SERVER_TIMESTAMP,
            })
        tx.create(reservation_ref, {
            'orderId': reservation_id,
            'status': 'RESERVED',
            'allocations': allocations,
            'createdAt': firestore.SERVER_TIMESTAMP,
        })
        return allocations

    try:
        return reserve(transaction)
    except StockError:
        raise
    except Exception as exc:
        raise StockError(503, 'INVENTORY_SERVICE_UNAVAILABLE', '재고 확인 서비스에 연결할 수 없습니다. 잠시 후 다시 시도해 주세요.') from exc


def _change_reserved_stock(client, reservation_id, allowed_statuses, next_status):
    """Idempotently restore a reservation or mark it committed in Firestore."""
    reservation_ref = client.collection('inventory_reservation').document(reservation_id)
    transaction = client.transaction()

    @firestore.transactional
    def apply(tx):
        reservation_snapshot = reservation_ref.get(transaction=tx)
        if not reservation_snapshot.exists:
            return False
        reservation = reservation_snapshot.to_dict() or {}
        if reservation.get('status') == next_status:
            return True
        if reservation.get('status') not in allowed_statuses:
            return False

        allocations = reservation.get('allocations') or []
        stock_snapshots = []
        for allocation in allocations:
            doc_ref = client.collection('office_inventory').document(allocation['document_id'])
            snapshot = doc_ref.get(transaction=tx)
            if not snapshot.exists:
                raise StockError(503, 'INVENTORY_RESTORE_FAILED', '재고 복구 대상 문서를 찾을 수 없습니다.')
            stock_snapshots.append((snapshot, allocation))

        if next_status in {'RELEASED', 'RESTORED'}:
            for snapshot, allocation in stock_snapshots:
                data = snapshot.to_dict() or {}
                current = data.get('currentQuantity')
                amount = allocation.get('quantity')
                if (isinstance(current, bool) or not isinstance(current, int) or current < 0
                        or isinstance(amount, bool) or not isinstance(amount, int) or amount <= 0):
                    raise StockError(503, 'INVENTORY_RESTORE_FAILED', '재고 복구 수량이 올바르지 않습니다.')
                tx.update(snapshot.reference, {
                    'currentQuantity': current + amount,
                    'updatedAt': firestore.SERVER_TIMESTAMP,
                })

        tx.update(reservation_ref, {
            'status': next_status,
            'updatedAt': firestore.SERVER_TIMESTAMP,
        })
        return True

    try:
        return apply(transaction)
    except StockError:
        raise
    except Exception as exc:
        raise StockError(503, 'INVENTORY_RESTORE_FAILED', '재고 예약 상태를 갱신할 수 없습니다.') from exc


def commit_stock(client, reservation_id):
    return _change_reserved_stock(client, reservation_id, {'RESERVED'}, 'COMMITTED')


def release_stock(client, reservation_id):
    """Undo the reservation if the SQL order transaction failed."""
    return _change_reserved_stock(client, reservation_id, {'RESERVED'}, 'RELEASED')


def restore_cancelled_order_stock(client, reservation_id):
    """Restock a cancelled order once; allows retry after a previous restore failure."""
    return _change_reserved_stock(client, reservation_id, {'RESERVED', 'COMMITTED'}, 'RESTORED')
