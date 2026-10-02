# 실행: .venv/bin/uvicorn python.fastapi.main:app --host 0.0.0.0 --port 8000
# 서버 시작 지점: 앱 초기화, CORS, 페이지 라우터, 공통 DB 오류 응답을 등록한다.
from contextlib import asynccontextmanager
import os
import sqlite3
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from google.api_core.exceptions import GoogleAPICallError
from google.auth.exceptions import DefaultCredentialsError, RefreshError
from python.db import DBError
from . import customer_support, login, notifications, review_management, review_write, signup
from .dependencies import get_local
from . import app_settings


@asynccontextmanager
async def lifespan(app):
    # 서버가 요청을 받기 전에 SQLite 테이블을 준비한다. 외부 Firebase/MySQL에 쓰지는 않는다.
    get_local().initialize()
    yield


app = FastAPI(title='FITPICK 페이지 API', version='1.0.0', lifespan=lifespan)
origins = [v.strip() for v in os.getenv('API_CORS_ORIGINS', '').split(',') if v.strip()]
app.add_middleware(CORSMiddleware, allow_origins=origins,
                   allow_methods=['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
                   allow_headers=['Authorization', 'Content-Type'])
for module in (login, signup, review_write, review_management, notifications, app_settings, customer_support):
    app.include_router(module.router, prefix='/api')


async def unavailable(request: Request, exc: Exception):
    # DB 오류/접속정보를 응답에 노출하지 않는다.
    # 저장소 연결/인증/스키마 오류를 503으로 통일하고 상세 접속정보는 클라이언트에 보내지 않는다.
    return JSONResponse(status_code=503, content={'detail': '데이터 저장소 연결 또는 스키마 설정을 확인해 주세요.'})


for error in (DBError, sqlite3.Error, GoogleAPICallError, DefaultCredentialsError, RefreshError):
    app.add_exception_handler(error, unavailable)


@app.get('/health', tags=['상태'])
def health():
    # 서버 프로세스가 응답하는지만 확인한다. 외부 DB의 정상 여부를 보장하지 않는다.
    return {'status': 'ok'}  # 프로세스 상태. 외부 DB 연결 성공을 의미하지 않음.
