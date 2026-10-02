# 페이지 요청 흐름: Flutter 로그인 → Firestore 비밀번호 검증 → 서버 세션 토큰 반환.
"""6. 로그인: Firestore account 검증 → 만료/폐기 가능한 서버 세션."""
from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from .accounts import get_accounts, profile
from .dependencies import get_local, current_email, bearer
from .schemas import LoginInput, SessionOut, AccountOut, PasswordChange

router = APIRouter(prefix='/login', tags=['6. 로그인'])


@router.post('', response_model=SessionOut)
def login(data: LoginInput, accounts=Depends(get_accounts), local=Depends(get_local)):
    # 입력 비밀번호를 Firestore 해시와 비교한 후, 사용자가 다른 API에 보낼 Bearer 토큰을 발급한다.
    account = accounts.authenticate(str(data.email), data.password)
    token, expires = local.new_session(str(data.email))
    return {'accessToken': token, 'tokenType': 'bearer', 'expiresAt': expires, 'account': profile(account)}


@router.get('/me', response_model=AccountOut)
def me(email=Depends(current_email), accounts=Depends(get_accounts)):
    # 토큰 소유자의 현재 회원정보를 조회한다. 비밀번호는 응답하지 않는다.
    doc = accounts.find(email)
    if not doc:
        raise HTTPException(401, '회원정보를 찾을 수 없습니다.')
    return profile(doc.to_dict())


@router.post('/logout', status_code=204)
def logout(email=Depends(current_email), credentials: HTTPAuthorizationCredentials = Depends(bearer), local=Depends(get_local)):
    # 현재 요청에 사용된 세션만 폐기한다. 동일 회원의 다른 기기 세션은 유지한다.
    local.logout(credentials.credentials)


@router.post('/password', status_code=204)
def change_password(data: PasswordChange, email=Depends(current_email), accounts=Depends(get_accounts)):
    # 기존 main의 비밀번호 변경 화면도 해시 기반 계정과 호환되도록 서버에서 처리한다.
    accounts.change_password(email, data.current, data.next)
