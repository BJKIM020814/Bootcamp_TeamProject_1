# 회원 원본 데이터는 Firestore account에 두고, 비밀번호 검증은 서버에서만 수행한다.
"""기존 account 문서 ID를 유지. 신규 이메일은 결정적 ID로 중복 가입 방지."""
import hashlib
import os
from functools import lru_cache
from google.cloud import firestore
from google.cloud.firestore_v1.base_query import FieldFilter
from google.api_core.exceptions import AlreadyExists
from pwdlib import PasswordHash
from pwdlib.exceptions import UnknownHashError
from fastapi import HTTPException

passwords = PasswordHash.recommended()


def profile(account):
    # 비밀번호를 제외한 공개 회원 필드만 응답으로 내보내기 위한 허용 목록이다.
    return {key: account.get(key, '') for key in
            ('email', 'name', 'phoneNumber', 'gender', 'address', 'signupPath')}


class Accounts:
    def __init__(self, client):
        self.client = client

    def find(self, email):
        # 기존 문서 ID가 이메일과 달라도 email 필드로 찾는다. 중복 문서는 임의 선택하지 않는다.
        docs = list(self.client.collection('account').where(filter=FieldFilter('email', '==', email)).limit(2).stream())
        if len(docs) > 1:
            raise HTTPException(409, '동일 이메일의 account 문서가 여러 개입니다. 관리자 확인이 필요합니다.')
        return docs[0] if docs else None

    def create(self, data):
        # 이메일 기반 고정 문서 ID와 create 연산으로 같은 API를 통한 동시 중복 가입을 막는다.
        email = str(data['email'])
        if self.find(email):
            raise HTTPException(409, '이미 가입된 이메일입니다.')
        ref = self.client.collection('account').document('api-' + hashlib.sha256(email.encode()).hexdigest())
        account = {key: data[key] for key in ('email', 'name', 'phoneNumber', 'gender', 'address', 'signupPath')}
        account['password'] = passwords.hash(data['password'])
        # 기존 필드 password 유지, 원문은 저장하지 않는다.
        try:
            ref.create(account)
        except AlreadyExists as exc:
            raise HTTPException(409, '이미 가입된 이메일입니다.') from exc
        return account

    def authenticate(self, email, password):
        # Argon2 해시를 검증한다. 평문 테스트 계정은 명시적 개발 옵션이 켜진 경우에만 변환한다.
        doc = self.find(email)
        account = doc.to_dict() if doc else None
        encoded = (account or {}).get('password', '')
        valid = False
        if isinstance(encoded, str) and encoded.startswith('$argon2'):
            try:
                valid = passwords.verify(password, encoded)
            except (ValueError, UnknownHashError):
                # 잘못된 해시도 인증 실패로 처리. 외부 DB 예외는 이 블록에 없다.
                valid = False
        elif doc and os.getenv('ALLOW_LEGACY_PASSWORD_LOGIN', 'false').lower() == 'true':
            import secrets
            valid = isinstance(encoded, str) and secrets.compare_digest(encoded.encode(), password.encode())
            if valid:
                # 읽은 password와 같은 버전에만 마이그레이션.
                doc.reference.update({'password': passwords.hash(password)},
                                     option=self.client.write_option(last_update_time=doc.update_time))
        if not valid:
            raise HTTPException(401, '이메일 또는 비밀번호가 올바르지 않습니다.')
        return account


@lru_cache
def get_accounts():
    # Google ADC 또는 서비스 계정 환경변수로 Python SDK 인증을 준비한다. CLI 로그인과는 별개다.
    return Accounts(firestore.Client(
        project=os.getenv('FIREBASE_PROJECT_ID', 'shoe-20260930'),
        database=os.getenv('FIREBASE_DATABASE_ID', '(default)')))
