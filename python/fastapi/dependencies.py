# 인증 의존성: 각 페이지 API가 토큰으로 회원 이메일을 확인할 때 공통으로 사용한다.
from functools import lru_cache
from dataclasses import dataclass
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from google.cloud.firestore_v1.base_query import FieldFilter
from .accounts import get_accounts
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


@dataclass(frozen=True)
class HeadquartersEmployee:
    """Employee identity resolved from Firestore, never accepted from request data."""
    employee_id: str
    position: str
    department: str


def current_headquarters_employee(email=Depends(current_email), accounts=Depends(get_accounts)):
    # 고객/관리자 모두 Firebase Auth 계정에서 발급된 로그인만 사용한다. 직원 권한은 UID가 원본이다.
    # 구형 직원 문서의 email 연결은 전환 기간에만 보조로 허용하며, 모호한 매핑은 항상 거부한다.
    account_doc = accounts.find(email) if hasattr(accounts, 'find') else None
    account = account_doc.to_dict() if account_doc else {}
    firebase_uid = account.get('firebaseUid') if isinstance(account, dict) else None
    employee_collection = accounts.client.collection('employee')
    docs = []
    if isinstance(firebase_uid, str) and firebase_uid:
        direct = employee_collection.document(firebase_uid).get()
        if direct.exists:
            docs.append(direct)
        docs.extend(employee_collection.where(
            filter=FieldFilter('firebaseUid', '==', firebase_uid)
        ).limit(2).stream())
    linked_by_email = False
    if not docs:
        linked_by_email = True
        docs.extend(employee_collection.where(
            filter=FieldFilter('email', '==', email)
        ).limit(2).stream())
    # 같은 문서를 document ID와 필드 검색에서 두 번 가져온 경우는 한 건으로 계산한다.
    docs = list({doc.id: doc for doc in docs}.values())
    if len(docs) != 1:
        raise HTTPException(403, '본사 직원 계정 연결이 확인되지 않았습니다.')
    employee = docs[0].to_dict() or {}
    if linked_by_email and isinstance(firebase_uid, str) and firebase_uid:
        # 기존 employee.email 연결을 UID 연결로 승격한다. 이후 이메일 변경에도 권한 기준은 Auth UID다.
        docs[0].reference.update({'firebaseUid': firebase_uid})
        employee['firebaseUid'] = firebase_uid
    employee_id = employee.get('employeeId')
    position = employee.get('position')
    department = employee.get('department')
    if not all(isinstance(value, str) and value.strip() for value in (employee_id, position, department)):
        raise HTTPException(403, '본사 직원 권한 정보를 확인할 수 없습니다.')
    return HeadquartersEmployee(employee_id=employee_id, position=position, department=department)
