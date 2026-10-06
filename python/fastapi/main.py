# 실행: .venv/bin/uvicorn python.fastapi.main:app --host 0.0.0.0 --port 8000
# 서버 시작 지점: 앱 초기화, CORS, 페이지 라우터, 공통 DB 오류 응답을 등록한다.
"""All-in-one API entry point for customer Discover/My FitPick and headquarters routes."""
from contextlib import asynccontextmanager
import os
import sqlite3
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, HTMLResponse
from google.api_core.exceptions import GoogleAPICallError
from google.auth.exceptions import DefaultCredentialsError, RefreshError
from python.db import DBError
from . import customer_support, login, notifications, review_management, review_write, signup
from .accounts import FirebaseCredentialsConfigurationError, get_accounts
from .dependencies import get_local
from . import app_settings
from .discover.router import router as discover_router
from .user.main import router as user_router
from .user.main import mypage_error_handler
from .user.mypage_data import MyPageError
from .headquarters import routers as headquarters_routers


@asynccontextmanager
async def lifespan(app):
    # 서버가 요청을 받기 전에 SQLite 테이블을 준비한다. 외부 Firebase/MySQL에 쓰지는 않는다.
    get_local().initialize()
    yield


app = FastAPI(title='FITPICK 페이지 API', version='1.0.0', lifespan=lifespan)
origins = [v.strip() for v in os.getenv('API_CORS_ORIGINS', '').split(',') if v.strip()]
app.add_middleware(CORSMiddleware, allow_origins=origins,
                   allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1|192\.168\.\d{1,3}\.\d{1,3})(:\d+)?$",
                   allow_methods=['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
                   allow_headers=['Authorization', 'Content-Type'])
for module in (login, signup, review_write, review_management, notifications, app_settings, customer_support):
    app.include_router(module.router, prefix='/api')


# 최신 main의 상품/마이페이지 API도 같은 서버에 등록한다.
app.include_router(discover_router)
app.include_router(user_router)
for headquarters_router in headquarters_routers:
    app.include_router(headquarters_router)


# 한 서버의 OpenAPI 문서에 반드시 노출되어야 하는 대표 경로다.
# 이 목록은 실제 요청을 만들지 않고 라우터 결합 상태만 확인하므로 테스트 중 데이터를 변경하지 않는다.
_SWAGGER_REQUIRED_PATHS = (
    '/api/login',
    '/api/signup',
    '/api/reviews',
    '/api/notifications',
    '/api/settings',
    '/api/support/faqs',
    '/api/v1/discover/products',
    '/api/v1/mypage/summary',
    '/api/v1/test/status',
    '/api/v1/test/firebase',
    '/api/v1/headquarters/orders',
    '/api/v1/headquarters/inventory',
    '/api/v1/headquarters/approvals',
    '/api/v1/headquarters/sales/summary',
    '/api/v1/headquarters/branches',
    '/api/v1/headquarters/contracts',
    '/api/v1/headquarters/members',
    '/api/v1/headquarters/reviews',
    '/api/v1/headquarters/inquiries',
)


def swagger_route_status():
    """Return the route-registration result used by `/test` and smoke tests."""
    registered_paths = set(app.openapi()['paths'])
    missing_paths = [path for path in _SWAGGER_REQUIRED_PATHS if path not in registered_paths]
    return {
        'ok': not missing_paths,
        'required_paths': list(_SWAGGER_REQUIRED_PATHS),
        'missing_paths': missing_paths,
    }


async def unavailable(request: Request, exc: Exception):
    # DB 오류/접속정보를 응답에 노출하지 않는다.
    # 저장소 연결/인증/스키마 오류를 503으로 통일하고 상세 접속정보는 클라이언트에 보내지 않는다.
    return JSONResponse(status_code=503, content={'detail': '데이터 저장소 연결 또는 스키마 설정을 확인해 주세요.', 'code': 'DISCOVER_DB_UNAVAILABLE', 'message': '데이터 저장소 연결 또는 스키마 설정을 확인해 주세요.'})


async def firebase_credentials_unavailable(request: Request, exc: Exception):
    # 실제 경로나 키 내용은 응답에 담지 않는다. 팀원이 고칠 수 있는 설정 종류만 알려 준다.
    return JSONResponse(status_code=503, content={
        'detail': 'Firebase 서비스 계정 설정을 확인해 주세요.',
        'code': 'FIREBASE_CREDENTIALS_UNAVAILABLE',
        'message': 'Firebase 서비스 계정 설정을 확인해 주세요.',
    })


app.add_exception_handler(FirebaseCredentialsConfigurationError, firebase_credentials_unavailable)
app.add_exception_handler(MyPageError, mypage_error_handler)
for error in (DBError, sqlite3.Error, GoogleAPICallError, DefaultCredentialsError, RefreshError):
    app.add_exception_handler(error, unavailable)


@app.get('/health', tags=['상태'])
def health():
    # 서버 프로세스가 응답하는지만 확인한다. 외부 DB의 정상 여부를 보장하지 않는다.
    return {'status': 'ok'}  # 프로세스 상태. 외부 DB 연결 성공을 의미하지 않음.


@app.get("/api/v1/test/status", tags=["System"], summary="Discover·My FitPick DB 읽기 상태 확인")
def test_status():
    """No-write integration check for the browser test page and smoke tests."""
    from python import db
    return {
        'swagger': swagger_route_status(),
        'database': db.query_one("SELECT DATABASE() AS name")['name'],
        'discover_product_count': db.query_one("SELECT COUNT(*) AS count FROM product")['count'],
        'mypage_tables': [row['name'] for row in db.query(
            "SELECT table_name AS name FROM information_schema.tables "
            "WHERE table_schema = DATABASE() "
            "AND table_name IN ('customer_setting', 'wishlist', 'recently_viewed') "
            "ORDER BY table_name"
        )],
    }


@app.get('/api/v1/test/firebase', tags=['System'], summary='Firebase 서비스 계정 읽기 연결 확인')
def firebase_connection_status():
    """Read one account document at most; this endpoint never creates or changes Firebase data."""
    accounts = get_accounts()
    # stream()을 한 건만 소비해 서비스 계정의 Firestore 읽기 권한과 대상 프로젝트를 실제 검증한다.
    next(accounts.client.collection('account').limit(1).stream(), None)
    return {
        'ok': True,
        'project_id': os.getenv('FIREBASE_PROJECT_ID', 'shoe-20260930'),
        'database_id': os.getenv('FIREBASE_DATABASE_ID', '(default)'),
        'account_collection_readable': True,
    }


@app.get("/test", response_class=HTMLResponse, include_in_schema=False)
def test_page():
    """Small browser page that checks all domain wiring without changing data."""
    return """<!doctype html><title>FITPICK API Test</title><body><h1>FITPICK API Test</h1><p id='result'>Checking…</p><p><a href='/docs'>Swagger docs</a></p><script>fetch('/api/v1/test/status').then(async r=>{const v=await r.json();if(!r.ok||!v.swagger.ok)throw new Error(JSON.stringify(v));return v;}).then(v=>document.querySelector('#result').textContent='PASS: '+JSON.stringify(v)).catch(e=>document.querySelector('#result').textContent='FAIL: '+e.message);</script></body>"""




if __name__ == '__main__':
    import uvicorn
    uvicorn.run('python.fastapi.main:app', host=os.getenv('API_HOST', '0.0.0.0'),
                port=int(os.getenv('API_PORT', '8000')), reload=True)
