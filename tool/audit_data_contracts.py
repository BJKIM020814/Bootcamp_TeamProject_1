"""Read-only inventory. Run: DB_HOST=127.0.0.1 python3 -m tool.audit_data_contracts.

Prints only schema metadata, counts and aggregate relationship errors, never PII,
passwords, tokens or database credentials. No application login/mutation API is called.
"""
import hashlib
import json
from collections import Counter
from python import db
from python.fastapi.accounts import get_accounts, firebase_app
from firebase_admin import auth


def audit():
    report = {'mysql': {}, 'firestore': {}}
    # 실제 서버가 쓰기 쿼리를 거부하도록 읽기 전용 트랜잭션 안에서 조사한다.
    with db.connection() as conn:
        with conn.cursor() as cur:
            cur.execute('START TRANSACTION READ ONLY')
            cur.execute('SELECT TABLE_NAME AS name FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() ORDER BY TABLE_NAME')
            tables = cur.fetchall()
            values = {}
            for row in tables:
                name = row['name']
                cur.execute('SELECT COLUMN_NAME AS name,COLUMN_TYPE AS type,IS_NULLABLE AS nullable,COLUMN_KEY AS key_type,EXTRA AS extra '
                            'FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=%s ORDER BY ORDINAL_POSITION', (name,))
                columns = cur.fetchall()
                cur.execute('SELECT INDEX_NAME AS name,NON_UNIQUE AS non_unique,COLUMN_NAME AS column_name,SEQ_IN_INDEX AS position '
                            'FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=%s ORDER BY INDEX_NAME,SEQ_IN_INDEX', (name,))
                indexes = cur.fetchall()
                cur.execute('SELECT COLUMN_NAME AS column_name,REFERENCED_TABLE_NAME AS target_table,REFERENCED_COLUMN_NAME AS target_column '
                            'FROM information_schema.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=%s '
                            'AND REFERENCED_TABLE_NAME IS NOT NULL ORDER BY CONSTRAINT_NAME,ORDINAL_POSITION', (name,))
                foreign_keys = cur.fetchall()
                cur.execute('SELECT * FROM `' + name.replace('`', '``') + '`')
                records = cur.fetchall()
                values[name] = records
                # 내용은 공개하지 않고 변경 전후 비교 가능한 지문만 출력한다.
                encoded = sorted(json.dumps(r, sort_keys=True, default=str) for r in records)
                fingerprint = hashlib.sha256(json.dumps(encoded).encode()).hexdigest()
                report['mysql'][name] = {'rows': len(records), 'columns': columns, 'indexes': indexes,
                                         'foreign_keys': foreign_keys, 'fingerprint': fingerprint}
            conn.rollback()
    client = get_accounts().client
    firestore_values = {}
    for collection in client.collections():
        docs = [doc.to_dict() or {} for doc in collection.stream()]
        firestore_values[collection.id] = docs
        keys = sorted({k for doc in docs for k in doc})
        report['firestore'][collection.id] = {
            'rows': len(docs),
            'fields': {k: {'present': sum(k in d for d in docs), 'null': sum(k in d and d[k] is None for d in docs)} for k in keys},
        }
    users = {u.uid for u in auth.list_users(app=firebase_app()).iterate_all()}
    accounts = firestore_values.get('account', [])
    by_email = {r['email']: r for r in accounts if isinstance(r.get('email'), str)}
    customers = {r['customer_id']: r for r in values.get('customer', [])}
    shared = by_email.keys() & customers.keys()
    report['identity'] = {
        'auth_users': len(users), 'auth_link_missing': sum(a.get('firebaseUid') not in users for a in accounts),
        'shared_accounts': len(shared), 'missing_mysql': len(by_email.keys() - customers.keys()),
        'missing_firestore': len(customers.keys() - by_email.keys()),
        'duplicate_emails_case_insensitive': sum(n - 1 for n in Counter(a['email'].casefold() for a in accounts if isinstance(a.get('email'), str)).values() if n > 1),
        'profile_mismatches': {f: sum(by_email[e].get(f) not in (None, '') and str(by_email[e][f]) != str(customers[e][m]) for e in shared)
                               for f, m in [('name','name'), ('phoneNumber','phone'), ('gender','gender'), ('address','address')]},
        'customer_password_nonempty': sum(bool(r.get('password')) for r in customers.values()),
        'account_legacy_password_fields': sum('password' in a for a in accounts),
        'account_missing_shoe_size': sum(a.get('shoeSize') is None for a in accounts),
    }
    product_codes = {r['p_code'] for r in values.get('product', [])}
    staff = firestore_values.get('employee', [])
    office_ids = {str(r['id']) for r in values.get('head_office', [])}
    report['employee_relations'] = {
        'missing_auth_link': sum(a.get('firebaseUid') not in users for a in staff),
        'unknown_head_office_id': sum(str(a.get('employeeId')) not in office_ids for a in staff),
        'password_fields': sum('password' in a for a in staff),
    }
    setting_ids = {r['customer_id'] for r in values.get('customer_setting', [])}
    report['mysql_relations'] = {
        'customer_without_settings': len(customers.keys() - setting_ids),
        'purchase_unknown_product': sum(r.get('p_code') not in product_codes for r in values.get('purchase', [])),
        'return_unknown_product': sum(r.get('p_id') not in product_codes for r in values.get('p_return', [])),
        'duplicate_owner_review_id': sum(n - 1 for n in Counter((r['customer_customer_id'], r['review_seq']) for r in values.get('review', [])).values() if n > 1),
    }
    report['product_relations'] = {
        col: {'missing_product_id': sum('productId' not in d for d in firestore_values.get(col, [])),
              'unknown_product_id': sum('productId' in d and d['productId'] not in product_codes for d in firestore_values.get(col, []))}
        for col in ['office_inventory', 'distributor_inventory', 'registration', 'order', 'recieve', 'quotation', 'send']
    }
    return report


if __name__ == '__main__':
    try:
        print(json.dumps(audit(), ensure_ascii=False, indent=2))
    except Exception as exc:
        # 예외 원문에는 접속 정보가 포함될 수 있으므로 종류만 공개한다.
        print(json.dumps({'error': type(exc).__name__, 'message': 'DB 또는 Firebase 연결 설정을 확인하세요.'}))
        raise SystemExit(1)
