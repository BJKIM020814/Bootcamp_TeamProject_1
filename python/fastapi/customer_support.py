# FAQ는 공개 안내이고, 문의 내역 및 등록은 인증된 회원만 사용할 수 있다.
"""5. 고객센터: FAQ 및 MySQL contact 문의."""
import logging
from fastapi import APIRouter, Depends, Query
from .commerce import get_commerce
from .dependencies import current_email, get_local
from .schemas import ContactCreate, ContactMessageCreate, ContactMessageOut, ContactOut, Page

router = APIRouter(prefix='/support', tags=['5. 고객센터'])


def contact_schema():
    # 기존 contact만 사용한다. 마이그레이션 전에는 409로 중단해 새 저장소를 만들지 않는다.
    from fastapi import HTTPException
    from python import db
    rows = db.query('SELECT COLUMN_NAME AS name,EXTRA AS extra,CHARACTER_MAXIMUM_LENGTH AS max_length '
                    'FROM information_schema.COLUMNS '
                    'WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=%s', ('contact',))
    columns = {row['name']: row for row in rows}
    required = {'customer_customer_id', 'head_office_id', 'c_seq', 'contact_post', 'c_date',
                'c_answer', 'c_answerdate', 'c_status', 'comment_seq', 'level',
                'thread_root_seq', 'parent_c_seq', 'author_role', 'author_id'}
    missing = sorted(required - columns.keys())
    short_fields = [name for name, needed in (('contact_post', 2000), ('c_answer', 10000))
                    if columns.get(name, {}).get('max_length') is not None
                    and columns[name]['max_length'] < needed]
    sequence_ready = 'auto_increment' in columns.get('c_seq', {}).get('extra', '')
    if missing or not sequence_ready or short_fields:
        raise HTTPException(409, detail={
            'code': 'CONTACT_SCHEMA_MIGRATION_REQUIRED',
            'message': 'contact 원본 테이블 확장 SQL을 먼저 적용해 주세요.',
            'missing_columns': missing,
            'c_seq_auto_increment': sequence_ready,
            'text_columns_too_short': short_fields,
        })


@router.get('/faqs')
def faqs():
    # 기존 고객센터 화면의 안내 문구를 반환하며 로그인 없이도 조회할 수 있다.
    return {'items': [
        {'id': 'orders', 'question': '주문 내역은 어디에서 확인하나요?', 'answer': '마이페이지의 주문 내역 메뉴에서 확인할 수 있습니다.'},
        {'id': 'returns', 'question': '교환과 반품은 어떻게 신청하나요?', 'answer': '주문 상세 화면에서 교환 또는 반품을 신청할 수 있습니다.'}]}


@router.get('/contacts', response_model=Page[ContactOut])
def contacts(limit: int = Query(20, ge=1, le=100), offset: int = Query(0, ge=0),
             email=Depends(current_email), commerce=Depends(get_commerce)):
    # 내 문의 목록을 최신순으로 조회한다. 본사에서 등록한 답변과 처리 상태도 포함된다.
    contact_schema()
    return commerce.contacts(email, limit, offset)


@router.get('/contacts/{contact_id}', response_model=ContactOut)
def contact(contact_id: int, email=Depends(current_email), commerce=Depends(get_commerce)):
    # 문의 ID와 토큰 소유자 이메일을 함께 조건으로 사용하여 내 문의 상세만 반환한다.
    contact_schema()
    return commerce.contact(email, contact_id)


@router.post('/contacts', status_code=201, response_model=ContactOut)
def create_contact(data: ContactCreate, email=Depends(current_email), commerce=Depends(get_commerce), local=Depends(get_local)):
    # 문의가 MySQL에 저장된 뒤 SQLite 접수 알림을 추가한다. 알림 장애로 문의를 다시 생성하지 않는다.
    contact_schema()
    contact_schema()
    result = commerce.create_contact(email, data)
    try:
        local.add_notification(email, 'support', '문의가 접수되었습니다.', f"문의번호 {result['id']}의 답변을 기다려 주세요.")
    except Exception:
        # 문의는 이미 커밋됨. 부가 알림 장애로 생성 API를 실패시키지 않는다.
        logging.getLogger(__name__).warning('Support notification deferred')
    return result


@router.post('/contacts/{contact_id}/messages', status_code=201, response_model=ContactMessageOut,
             summary='기존 문의에 고객 메시지 추가',
             description='회원 소유 문의인지 확인하고 직전 메시지에 연결하여 후속 내용을 추가합니다.')
def reply_contact(contact_id: int, data: ContactMessageCreate,
                  email=Depends(current_email), commerce=Depends(get_commerce)):
    contact_schema()
    return commerce.append_customer_message(email, contact_id, data.content)
