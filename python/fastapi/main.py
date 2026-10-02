"""Single FitPick FastAPI app. Domain routers are registered with include_router()."""
import os

import uvicorn
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, JSONResponse

from python.db import DBError
from python.fastapi.discover.router import router as discover_router
from python.fastapi.user.main import router as user_router

app = FastAPI(title="FITPICK API", version="1.0.0", description="Flutter Discover 화면용 API")
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1|192\.168\.20\.68)(:\d+)?$",
    allow_credentials=False,
    allow_methods=["GET"],
    allow_headers=["*"],
)
app.include_router(discover_router)
app.include_router(user_router)


@app.exception_handler(DBError)
async def database_error_handler(_: Request, __: DBError):
    """Return a safe error without exposing DB host, account or password."""
    return JSONResponse(status_code=503, content={"code": "DISCOVER_DB_UNAVAILABLE", "message": "상품 데이터를 일시적으로 조회할 수 없습니다."})


@app.get("/api/v1/test/status", tags=["System"], summary="Discover·My FitPick DB 읽기 상태 확인")
def test_status():
    """No-write integration check for the browser test page and smoke tests."""
    from python import db
    return {"database": db.query_one("SELECT DATABASE() AS name")["name"], "discover_product_count": db.query_one("SELECT COUNT(*) AS count FROM product")["count"], "mypage_tables": [row["name"] for row in db.query("SELECT table_name AS name FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name IN ('customer_setting', 'wishlist', 'recently_viewed') ORDER BY table_name")]}


@app.get("/test", response_class=HTMLResponse, include_in_schema=False)
def test_page():
    """Small browser page that checks all domain wiring without changing data."""
    return """<!doctype html><title>FITPICK API Test</title><body><h1>FITPICK API Test</h1><p id='result'>Checking…</p><p><a href='/docs'>Swagger docs</a></p><script>fetch('/api/v1/test/status').then(r=>r.json()).then(v=>document.querySelector('#result').textContent='PASS: '+JSON.stringify(v)).catch(e=>document.querySelector('#result').textContent='FAIL: '+e);</script></body>"""


@app.get("/health", tags=["System"], summary="API·DB 연결 상태 확인")
def health():
    from python import db
    db.query_one("SELECT 1 AS ok")
    return {"status": "ok"}


if __name__ == "__main__":
    uvicorn.run("python.fastapi.main:app", host=os.getenv("API_HOST", "127.0.0.1"), port=int(os.getenv("API_PORT", "8000")), reload=True)
