# 공통 환경 설정: 저장소 루트의 .env를 읽고 SQLite 경로와 세션 유효 시간을 제공한다.
import os
from pathlib import Path
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[2]
load_dotenv(ROOT / '.env')


def sqlite_path():
    # 환경변수가 없으면 백엔드 data 폴더에 DB 파일을 만들며, 배포 시 파일을 보존해야 한다.
    return Path(os.getenv('API_SQLITE_PATH', str(ROOT / 'python/fastapi/data/app.sqlite3')))


def session_seconds():
    # 세션 만료 시간을 초 단위로 읽는다. 기본값 3600은 1시간이다.
    return int(os.getenv('API_SESSION_SECONDS', '3600'))
