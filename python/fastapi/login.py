# 페이지 요청 흐름: Flutter 로그인 → Firestore 비밀번호 검증 → 서버 세션 토큰 반환.
"""6. 로그인: Firestore account 검증 → 만료/폐기 가능한 서버 세션."""
from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from google.cloud import firestore
from .accounts import get_accounts, profile
from .commerce import get_commerce
from .dependencies import get_local, current_email, bearer
from .firebase_identity import sign_in_with_password
from .schemas import LoginInput, SessionOut, AccountOut, PasswordChange, AccountProfilePatch

router = APIRouter(prefix='/login', tags=['6. 로그인'])


@router.post('', response_model=SessionOut)
def login(data: LoginInput, accounts=Depends(get_accounts), commerce=Depends(get_commerce), local=Depends(get_local)):
    # 모바일/PAD 모두 Firebase Authentication으로 로그인한다. 기존 Firestore 해시는 성공한 첫 로그인에서만 이관한다.
    email = str(data.email)
    try:
        identity = sign_in_with_password(email, data.password)
        doc = accounts.find(email)
        if not doc:
            raise HTTPException(409, 'Firebase 계정 프로필 연결이 필요합니다.')
        account = doc.to_dict() or {}
        if account.get('firebaseUid') and account['firebaseUid'] != identity['localId']:
            raise HTTPException(409, '계정 UID 연결이 일치하지 않습니다. 관리자 확인이 필요합니다.')
        if not account.get('firebaseUid') or 'password' in account:
            doc.reference.update({'firebaseUid': identity['localId'], 'password': firestore.DELETE_FIELD})
            account['firebaseUid'] = identity['localId']
    except HTTPException as error:
        if error.status_code != 401:
            raise
        account = accounts.migrate_legacy_password(email, data.password)
    # 로그인 시 Firebase 프로필을 MySQL customer에 재반영해 일시적 연결 실패 뒤에도 복구한다.
    commerce.sync_customer(account)
    token, expires = local.new_session(str(data.email))
    return {'accessToken': token, 'tokenType': 'bearer', 'expiresAt': expires, 'account': profile(account)}


@router.get('/me', response_model=AccountOut)
def me(email=Depends(current_email), accounts=Depends(get_accounts)):
    # 토큰 소유자의 현재 회원정보를 조회한다. 비밀번호는 응답하지 않는다.
    doc = accounts.find(email)
    if not doc:
        raise HTTPException(401, '회원정보를 찾을 수 없습니다.')
    return profile(doc.to_dict())


@router.patch('/me', response_model=AccountOut)
def update_me(data: AccountProfilePatch, email=Depends(current_email), accounts=Depends(get_accounts), commerce=Depends(get_commerce)):
    # Firestore를 원본으로 갱신한 뒤 동일 필드를 MySQL customer에도 반영한다.
    account = accounts.update_profile(
        email,
        name=data.name,
        phone_number=data.phoneNumber,
        shoe_size=data.shoeSize,
    )
    commerce.sync_customer(account)
    return profile(account)


@router.post('/logout', status_code=204)
def logout(email=Depends(current_email), credentials: HTTPAuthorizationCredentials = Depends(bearer), local=Depends(get_local)):
    # 현재 요청에 사용된 세션만 폐기한다. 동일 회원의 다른 기기 세션은 유지한다.
    local.logout(credentials.credentials)


@router.post('/password', status_code=204)
def change_password(data: PasswordChange, email=Depends(current_email), accounts=Depends(get_accounts)):
    # 기존 main의 비밀번호 변경 화면도 해시 기반 계정과 호환되도록 서버에서 처리한다.
    accounts.change_password(email, data.current, data.next)
