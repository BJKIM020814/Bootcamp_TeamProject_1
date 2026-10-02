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
    # Customer sessions do not imply staff access. A staff document must explicitly bind
    # the authenticated email; unknown or ambiguous mappings are denied by default.
    docs = list(accounts.client.collection('employee').where(
        filter=FieldFilter('email', '==', email)
    ).limit(2).stream())
    if len(docs) != 1:
        raise HTTPException(403, '본사 직원 계정 연결이 확인되지 않았습니다.')
    employee = docs[0].to_dict() or {}
    employee_id = employee.get('employeeId')
    position = employee.get('position')
    department = employee.get('department')
    if not all(isinstance(value, str) and value.strip() for value in (employee_id, position, department)):
        raise HTTPException(403, '본사 직원 권한 정보를 확인할 수 없습니다.')
    return HeadquartersEmployee(employee_id=employee_id, position=position, department=department)
