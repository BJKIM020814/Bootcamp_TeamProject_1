"""Single FitPick FastAPI app. Domain routers are registered with include_router()."""
import os

import uvicorn
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from python.db import DBError
from python.fastapi.discover.router import router as discover_router

app = FastAPI(title="FITPICK API", version="1.0.0", description="Flutter Discover 화면용 API")
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\\d+)?$",
    allow_credentials=False,
    allow_methods=["GET"],
    allow_headers=["*"],
)
app.include_router(discover_router)


@app.exception_handler(DBError)
async def database_error_handler(_: Request, __: DBError):
    """Return a safe error without exposing DB host, account or password."""
    return JSONResponse(status_code=503, content={"code": "DISCOVER_DB_UNAVAILABLE", "message": "상품 데이터를 일시적으로 조회할 수 없습니다."})


@app.get("/health", tags=["System"], summary="API·DB 연결 상태 확인")
def health():
    from python import db
    db.query_one("SELECT 1 AS ok")
    return {"status": "ok"}


if __name__ == "__main__":
    uvicorn.run("python.fastapi.main:app", host=os.getenv("API_HOST", "127.0.0.1"), port=int(os.getenv("API_PORT", "8000")), reload=True)
