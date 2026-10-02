# 페이지 요청 흐름: 회원 입력 검증 → Firestore 저장 → MySQL 고객 연결 → 결과 반환.
"""7. 회원가입: Firebase가 기준, MySQL 연결은 실패해도 재시도 가능."""
import logging
from fastapi import APIRouter, Depends
from python.db import DBError
from .accounts import get_accounts, profile
from .commerce import get_commerce
from .dependencies import get_local, current_email
from .schemas import SignupInput, SignupOut

router = APIRouter(prefix='/signup', tags=['7. 회원가입'])


@router.post('', status_code=201, response_model=SignupOut)
def signup(data: SignupInput, accounts=Depends(get_accounts), commerce=Depends(get_commerce), local=Depends(get_local)):
    # Firebase 가입이 기준이다. MySQL 장애 시 가입을 취소하지 않고 customerSynced로 재시도를 안내한다.
    account = accounts.create(data.model_dump())
    synced = True
    try:
        commerce.sync_customer(str(data.email), data.age)
    except DBError:
        # 서로 다른 DB 간 원자적 트랜잭션은 불가. 가입 자체는 유지하고 명시적으로 재시도.
        logging.getLogger(__name__).warning('Shopping customer sync deferred')
        synced = False
    token, expires = local.new_session(str(data.email))
    return {'accessToken': token, 'tokenType': 'bearer', 'expiresAt': expires,
            'account': profile(account), 'customerSynced': synced,
            'nextAction': None if synced else 'POST /api/signup/sync'}


@router.post('/sync')
def sync(email=Depends(current_email), commerce=Depends(get_commerce)):
    # 토큰 소유자의 MySQL 고객 행을 연결한다. 기존 구매/누적금액은 유지하므로 재시도가 가능하다.
    commerce.sync_customer(email)
    return {'customerSynced': True}
