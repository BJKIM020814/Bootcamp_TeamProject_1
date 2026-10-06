# FAQ는 공개 안내이고, 문의 내역 및 등록은 인증된 회원만 사용할 수 있다.
"""5. 고객센터: FAQ 및 MySQL contact 문의."""
import logging
from fastapi import APIRouter, Depends, Query
from .commerce import get_commerce
from .dependencies import current_email, get_local
from .schemas import ContactCreate, ContactOut, Page
from .schema_guard import require_schema

router = APIRouter(prefix='/support', tags=['5. 고객센터'])


def contact_schema():
    # 본사 레거시 contact(c_seq/contact_post/c_answer)와 새 문의 계약을 혼동하지 않는다.
    require_schema('contact', ['contact_seq', 'context', 'response', 'r_date', 'process'])


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
    require_schema('contact', ['contact_seq', 'context'], auto_increment='contact_seq',
                   text_lengths={'context': len(data.content)})
    result = commerce.create_contact(email, data)
    try:
        local.add_notification(email, 'support', '문의가 접수되었습니다.', f"문의번호 {result['id']}의 답변을 기다려 주세요.")
    except Exception:
        # 문의는 이미 커밋됨. 부가 알림 장애로 생성 API를 실패시키지 않는다.
        logging.getLogger(__name__).warning('Support notification deferred')
    return result
