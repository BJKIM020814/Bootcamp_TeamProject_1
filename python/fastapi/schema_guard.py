"""DB 구조를 읽기 전용으로 검증하고 지원하지 않는 저장을 실행 전에 거절한다."""
from fastapi import HTTPException
from python import db


def require_schema(table, fields, *, auto_increment=None, text_lengths=None):
    rows = db.query(
        'SELECT COLUMN_NAME AS name,EXTRA AS extra,CHARACTER_MAXIMUM_LENGTH AS max_length '
        'FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=%s',
        (table,),
    )
    columns = {row['name']: row for row in rows}
    problems = [f'{table}.{name}: 누락' for name in sorted(set(fields) - columns.keys())]
    if auto_increment and 'auto_increment' not in columns.get(auto_increment, {}).get('extra', ''):
        problems.append(f'{table}.{auto_increment}: 자동 번호 생성 필요')
    for field, needed in (text_lengths or {}).items():
        maximum = columns.get(field, {}).get('max_length')
        if maximum is not None and maximum < needed:
            problems.append(f'{table}.{field}: 현재 {maximum}자, 최소 {needed}자 필요')
    if problems:
        # Flutter clients surface `detail.message`; include the specific schema mismatch there
        # so unrelated screens no longer all show the same unhelpful generic warning.
        visible_problems = problems[:4]
        summary = '; '.join(visible_problems)
        if len(problems) > len(visible_problems):
            summary += f'; 외 {len(problems) - len(visible_problems)}개 항목'
        raise HTTPException(409, detail={
            'code': 'SCHEMA_CONTRACT_MISMATCH',
            'message': f'{table} 테이블 구조를 먼저 수정해야 합니다: {summary}. '
                       '수정 SQL: python/fastapi/sql/restore_legacy_commerce_schema.sql',
            'missing_requirements': problems,
        })
