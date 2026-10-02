"""schema.sql 의 테이블을 DB 에 생성한다. (실행: python init_tables.py)

CREATE TABLE IF NOT EXISTS / INSERT IGNORE 라서 여러 번 실행해도 안전하다. 기존 테이블은 건드리지 않는다.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
import db  # noqa: E402


def main():
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "schema.sql")
    with open(path, encoding="utf-8") as f:
        # 주석 줄을 먼저 제거한 뒤 세미콜론으로 문장 분리
        text = "\n".join(l for l in f.read().splitlines() if not l.strip().startswith("--"))
    for stmt in filter(None, (s.strip() for s in text.split(";"))):
        db.execute(stmt)
        print("OK:", " ".join(stmt.split()[:6]))


if __name__ == "__main__":
    try:
        main()
    except db.DBError as e:
        print(f"[실패] {e}")
        raise SystemExit(1)
