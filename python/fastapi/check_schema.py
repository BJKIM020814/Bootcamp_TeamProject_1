# 실행 명령: python -m python.fastapi.check_schema (조회 전용, 테이블 변경 없음).
"""읽기 전용 MySQL 구조 검사: python -m python.fastapi.check_schema"""
from python import db

EXPECTED = {
    'customer': {'customer_id', 'password', 'phone', 'name', 'gender', 'address', 'age', 'totalprice'},
    'product': {'p_code', 'p_name', 'b_name'},
    'purchase': {'purchase_id', 'order_code', 'customer_customer_id', 'head_office_id', 'p_code', 'p_date',
                 'p_price', 'quantity', 'order_status', 'orderer_name', 'orderer_phone', 'dealer_seq',
                 'store_name', 'store_address', 'payment_method', 'coupon_id', 'coupon_name', 'subtotal',
                 'discount', 'order_total', 'status_changed_at', 'ready_at', 'picked_up_at', 'cancelled_at',
                 'pickup_code', 'pickup_code_expires'},
    'review': {'customer_customer_id', 'product_p_code', 'review_seq', 'r_date', 'image', 'context', 'r_fit', 'rating', 'likecount'},
    'contact': {'customer_customer_id', 'head_office_id', 'c_seq', 'contact_post', 'c_date', 'c_answer',
                'c_answerdate', 'c_status', 'comment_seq', 'level', 'thread_root_seq', 'parent_c_seq',
                'author_role', 'author_id'},
}


def check():
    # information_schema를 조회해 필수 컬럼, 문자열 연결 키, 자동 증가 키, 저장 길이를 검사한다.
    rows = db.query('SELECT TABLE_NAME AS table_name,COLUMN_NAME AS column_name,EXTRA AS extra,DATA_TYPE AS data_type,IS_NULLABLE AS nullable,CHARACTER_MAXIMUM_LENGTH AS max_length '
                    'FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE()')
    problems = []
    for table, required in EXPECTED.items():
        columns = {row['column_name']: row for row in rows if row['table_name'] == table}
        for column in sorted(required - columns.keys()):
            problems.append(f'{table}.{column}: 누락')
        string_keys = {
            'customer': ['customer_id'], 'product': ['p_code'],
            'purchase': ['customer_customer_id', 'head_office_id', 'p_code', 'order_code'],
            'review': ['customer_customer_id', 'product_p_code'],
            'contact': ['customer_customer_id', 'head_office_id', 'author_id'],
        }
        for key in string_keys[table]:
            if key in columns and columns[key]['data_type'] not in {'char', 'varchar', 'text'}:
                problems.append(f'{table}.{key}: 문자열 연결 키가 필요 (현재 {columns[key]["data_type"]})')
        if table == 'review' and 'context' in columns:
            length = columns['context']['max_length']
            if length is not None and length < 2000:
                problems.append('review.context: 2000자 저장 공간 필요')
        if table == 'contact':
            for field, needed in (('contact_post', 2000), ('c_answer', 10000)):
                length = columns.get(field, {}).get('max_length')
                if length is not None and length < needed:
                    problems.append(f'contact.{field}: 대화 내용 저장 공간 부족')
        identity = {'review': 'review_seq', 'purchase': 'purchase_id', 'contact': 'c_seq'}.get(table)
        if identity in columns and 'auto_increment' not in columns[identity]['extra']:
            problems.append(f'{table}.{identity}: AUTO_INCREMENT 필요')
    return problems


if __name__ == '__main__':
    try:
        problems = check()
    except db.DBError:
        print('MySQL 연결 실패: .env의 DB_* 설정과 서버 접근 권한을 확인하세요.')
        raise SystemExit(1)
    for problem in problems:
        print(problem)
    if problems:
        print('python/fastapi/sql/README.md의 스키마 조건을 확인하세요. 자동 변경하지 않습니다.')
        raise SystemExit(1)
    print('API에 필요한 MySQL 컬럼 및 자동 증가 키 확인 완료.')
