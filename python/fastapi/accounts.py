# 회원 원본 데이터는 Firestore account에 두고, 비밀번호 검증은 서버에서만 수행한다.
"""기존 account 문서 ID를 유지. 신규 이메일은 결정적 ID로 중복 가입 방지."""
import hashlib
import json
import os
from functools import lru_cache
from pathlib import Path
import firebase_admin
from firebase_admin import auth as firebase_auth
from firebase_admin import firestore as admin_firestore
from firebase_admin.exceptions import FirebaseError
from google.cloud import firestore
from google.cloud.firestore_v1.base_query import FieldFilter
from google.api_core.exceptions import AlreadyExists
from pwdlib import PasswordHash
from pwdlib.exceptions import UnknownHashError
from fastapi import HTTPException
from .firebase_identity import sign_in_with_password

passwords = PasswordHash.recommended()


class FirebaseCredentialsConfigurationError(Exception):
    """Raised when the server cannot safely locate its Firebase service key."""


def _validate_service_account_environment():
    """Validate ADC service-account configuration without exposing its path or key."""
    configured_path = os.getenv('GOOGLE_APPLICATION_CREDENTIALS', '').strip()
    if not configured_path:
        raise FirebaseCredentialsConfigurationError(
            'GOOGLE_APPLICATION_CREDENTIALS 환경변수가 설정되지 않았습니다.'
        )

    credential_path = Path(configured_path).expanduser()
    if not credential_path.is_file():
        raise FirebaseCredentialsConfigurationError(
            'GOOGLE_APPLICATION_CREDENTIALS가 가리키는 서비스 계정 파일을 찾을 수 없습니다.'
        )

    try:
        with credential_path.open(encoding='utf-8') as credential_file:
            credential_project_id = json.load(credential_file).get('project_id')
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise FirebaseCredentialsConfigurationError(
            '서비스 계정 JSON 파일 형식을 확인해 주세요.'
        ) from exc

    expected_project_id = os.getenv('FIREBASE_PROJECT_ID', 'shoe-20260930')
    if credential_project_id != expected_project_id:
        raise FirebaseCredentialsConfigurationError(
            '서비스 계정의 Firebase 프로젝트가 현재 서버 설정과 일치하지 않습니다.'
        )


def profile(account):
    # 비밀번호를 제외한 공개 회원 필드만 응답으로 내보내기 위한 허용 목록이다.
    result = {key: account.get(key, '') for key in
              ('email', 'name', 'phoneNumber', 'gender', 'address', 'signupPath')}
    # 기존 account 문서에는 age가 없을 수 있으므로 빈 문자열 대신 null로 응답한다.
    result['age'] = account.get('age') if isinstance(account.get('age'), int) else None
    result['shoeSize'] = account.get('shoeSize') if isinstance(account.get('shoeSize'), int) else None
    return result


@lru_cache
def firebase_app():
    """Create one Admin SDK app; its credentials are validated before initialization."""
    _validate_service_account_environment()
    try:
        return firebase_admin.get_app('fitpick-api')
    except ValueError:
        try:
            return firebase_admin.initialize_app(
                options={'projectId': os.getenv('FIREBASE_PROJECT_ID', 'shoe-20260930')},
                name='fitpick-api',
            )
        except (ValueError, FirebaseError) as exc:
            raise FirebaseCredentialsConfigurationError(
                'Firebase Admin 인증 설정을 확인해 주세요.'
            ) from exc


class Accounts:
    """Firestore account profile repository; Firebase Auth remains the password authority."""

    def __init__(self, client):
        self.client = client

    def find(self, email):
        # 기존 문서 ID가 이메일과 달라도 email 필드로 찾는다. 중복 문서는 임의 선택하지 않는다.
        docs = list(self.client.collection('account').where(filter=FieldFilter('email', '==', email)).limit(2).stream())
        if len(docs) > 1:
            raise HTTPException(409, '동일 이메일의 account 문서가 여러 개입니다. 관리자 확인이 필요합니다.')
        return docs[0] if docs else None

    def create(self, data):
        # Firebase Authentication이 비밀번호 원본을 관리한다. Firestore에는 프로필만 보관한다.
        email = str(data['email'])
        if self.find(email):
            raise HTTPException(409, '이미 가입된 이메일입니다.')
        try:
            user = firebase_auth.create_user(
                email=email,
                password=data['password'],
                display_name=data['name'],
                app=firebase_app(),
            )
        except firebase_auth.EmailAlreadyExistsError as exc:
            raise HTTPException(409, '이미 가입된 이메일입니다.') from exc
        except FirebaseError as exc:
            raise HTTPException(503, 'Firebase 회원가입 서비스를 사용할 수 없습니다.') from exc

        account = {key: data[key] for key in (
            'email', 'name', 'phoneNumber', 'gender', 'address', 'signupPath', 'age', 'shoeSize'
        ) if key in data}
        account['firebaseUid'] = user.uid
        ref = self.client.collection('account').document(user.uid)
        try:
            ref.create(account)
        except AlreadyExists as exc:
            firebase_auth.delete_user(user.uid, app=firebase_app())
            raise HTTPException(409, '이미 가입된 이메일입니다.') from exc
        except Exception:
            # 프로필 생성이 실패하면 방금 생성한 Auth 계정을 되돌려 고아 계정을 만들지 않는다.
            firebase_auth.delete_user(user.uid, app=firebase_app())
            raise
        return account

    def authenticate(self, email, password):
        """Verify a legacy Firestore password only to perform one-time Firebase Auth migration."""
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

    def migrate_legacy_password(self, email, password):
        """Migrate an account after a successful old-password login; Argon hashes cannot be imported."""
        doc = self.find(email)
        account = self.authenticate(email, password)
        try:
            firebase_auth.get_user_by_email(email, app=firebase_app())
        except firebase_auth.UserNotFoundError:
            try:
                user = firebase_auth.create_user(
                    email=email,
                    password=password,
                    display_name=account.get('name') or None,
                    app=firebase_app(),
                )
            except FirebaseError as exc:
                raise HTTPException(503, 'Firebase 계정 이관을 완료할 수 없습니다.') from exc
        except FirebaseError as exc:
            raise HTTPException(503, 'Firebase 계정 이관을 완료할 수 없습니다.') from exc
        else:
            # Auth에 이미 존재하면 이전 Firestore 비밀번호로 인증을 우회할 수 없다.
            raise HTTPException(401, '이메일 또는 비밀번호가 올바르지 않습니다.')
        doc.reference.update({
            'firebaseUid': user.uid,
            'password': firestore.DELETE_FIELD,
        })
        account.pop('password', None)
        account['firebaseUid'] = user.uid
        return account


    def change_password(self, email, current, next_password):
        # 이관이 완료된 계정은 Firestore password가 없으므로 Auth에서 현재 값을 검증한다.
        try:
            identity = sign_in_with_password(email, current)
            uid = identity['localId']
        except HTTPException as exc:
            if exc.status_code != 401:
                raise
            uid = self.migrate_legacy_password(email, current)['firebaseUid']
        try:
            firebase_auth.update_user(uid, password=next_password, app=firebase_app())
        except FirebaseError as exc:
            raise HTTPException(503, 'Firebase 비밀번호를 변경할 수 없습니다.') from exc

    def update_profile(self, email, *, name, phone_number, shoe_size):
        """Update the canonical Firestore profile. MySQL mirroring is performed by the caller."""
        doc = self.find(email)
        if not doc:
            raise HTTPException(401, '회원정보를 찾을 수 없습니다.')
        doc.reference.update({
            'name': name,
            'phoneNumber': phone_number,
            'shoeSize': shoe_size,
        })
        account = doc.to_dict() or {}
        account.update({
            'name': name,
            'phoneNumber': phone_number,
            'shoeSize': shoe_size,
        })
        return account


@lru_cache
def get_accounts():
    # Python SDK는 CLI 로그인과 별개다. 실제 서비스 계정 파일과 프로젝트 일치 여부를 먼저 검사한다.
    _validate_service_account_environment()
    firebase_app()
    return Accounts(admin_firestore.client(
        app=firebase_app(), database_id=os.getenv('FIREBASE_DATABASE_ID', '(default)')))
