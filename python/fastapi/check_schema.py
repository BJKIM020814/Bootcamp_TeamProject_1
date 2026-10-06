# 실행 명령: python -m python.fastapi.check_schema (조회 전용, 테이블 변경 없음).
"""읽기 전용 MySQL 구조 검사: python -m python.fastapi.check_schema"""
from python import db

EXPECTED = {
    'customer': {'customer_id', 'password', 'phone', 'name', 'gender', 'address', 'age', 'totalprice'},
    'product': {'p_code', 'p_name', 'b_name'},
    'purchase': {'customer_customer_id', 'p_code'},
    'review': {'customer_customer_id', 'product_p_code', 'review_seq', 'r_date', 'image', 'context', 'r_fit', 'rating', 'likecount'},
    'customer_support_inquiry': {'inquiry_id', 'customer_id', 'head_office_id', 'content', 'response',
                                 'created_at', 'responded_at', 'process'},
    'inquiry_message': {'message_id', 'customer_id', 'head_office_id', 'c_seq', 'turn_index',
                        'parent_message_id', 'author_role', 'author_id', 'content', 'created_at'},
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
            'purchase': ['customer_customer_id', 'p_code'],
            'review': ['customer_customer_id', 'product_p_code'],
            'customer_support_inquiry': ['customer_id', 'head_office_id'],
            'inquiry_message': ['customer_id', 'head_office_id', 'author_id'],
        }
        for key in string_keys[table]:
            if key in columns and columns[key]['data_type'] not in {'char', 'varchar', 'text'}:
                problems.append(f'{table}.{key}: 문자열 연결 키가 필요 (현재 {columns[key]["data_type"]})')
        if table == 'review' and 'context' in columns:
            length = columns['context']['max_length']
            if length is not None and length < 2000:
                problems.append('review.context: 2000자 저장 공간 필요')
        if table == 'customer_support_inquiry' and 'responded_at' in columns and columns['responded_at']['nullable'] != 'YES':
            problems.append('customer_support_inquiry.responded_at: 미답변 상태를 위해 NULL 허용 필요')
        identity = {'review': 'review_seq', 'customer_support_inquiry': 'inquiry_id',
                    'inquiry_message': 'message_id'}.get(table)
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
