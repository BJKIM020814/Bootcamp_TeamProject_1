"""Firebase Authentication password sign-in used by both mobile and PAD clients."""
import os

import httpx
from fastapi import HTTPException


_SIGN_IN_URL = 'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword'


def sign_in_with_password(email: str, password: str) -> dict:
    """Return Firebase Auth tokens for one email/password login without logging secrets."""
    api_key = os.getenv('FIREBASE_WEB_API_KEY', '').strip()
    if not api_key:
        raise HTTPException(503, 'Firebase 이메일 로그인 설정을 확인해 주세요.')
    try:
        response = httpx.post(
            _SIGN_IN_URL,
            params={'key': api_key},
            json={'email': email, 'password': password, 'returnSecureToken': True},
            timeout=10,
        )
    except httpx.HTTPError as exc:
        raise HTTPException(503, 'Firebase 로그인 서버에 연결할 수 없습니다.') from exc

    if response.status_code >= 500:
        raise HTTPException(503, 'Firebase 로그인 서버를 사용할 수 없습니다.')
    if response.status_code != 200:
        raise HTTPException(401, '이메일 또는 비밀번호가 올바르지 않습니다.')
    try:
        payload = response.json()
    except ValueError as exc:
        raise HTTPException(503, 'Firebase 로그인 응답 형식이 올바르지 않습니다.') from exc
    if not isinstance(payload, dict):
        raise HTTPException(503, 'Firebase 로그인 응답 형식이 올바르지 않습니다.')
    if not isinstance(payload.get('localId'), str) or not payload.get('localId'):
        raise HTTPException(503, 'Firebase 로그인 응답을 확인할 수 없습니다.')
    return payload
