# 인증 의존성: 각 페이지 API가 토큰으로 회원 이메일을 확인할 때 공통으로 사용한다.
from functools import lru_cache
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from .local_store import LocalStore

bearer = HTTPBearer(auto_error=False)


@lru_cache
def get_local():
    # 같은 서버 프로세스에서 공통 저장소 객체를 재사용한다. 연결은 각 작업에서 열고 닫는다.
    return LocalStore()


def current_email(credentials: HTTPAuthorizationCredentials = Depends(bearer), local: LocalStore = Depends(get_local)):
    # Authorization: Bearer 헤더의 토큰을 검증하고 유효한 세션의 이메일만 반환한다.
    email = local.session_email(credentials.credentials) if credentials else None
    if not email:
        raise HTTPException(401, '로그인이 필요하거나 세션이 만료되었습니다.', headers={'WWW-Authenticate': 'Bearer'})
    return email
