"""DB 연결 확인용 테스트 (실행: python test_db.py)"""
import db


def main():
    # 1) 연결 및 기본 쿼리 확인
    row = db.query_one("SELECT 1 AS ok, DATABASE() AS db_name")
    print(f"[연결 성공] 현재 DB: {row['db_name']}")

    # 2) 테이블 목록 확인
    tables = [list(r.values())[0] for r in db.query("SHOW TABLES")]
    print(f"[테이블 {len(tables)}개] {tables}")

    # 3) 파라미터 바인딩 동작 확인 (값이 SQL이 아닌 데이터로 처리되는지)
    row = db.query_one("SELECT %s AS echo", ("'; DROP TABLE x; --",))
    print(f"[바인딩 확인] {row['echo']}")


if __name__ == "__main__":
    try:
        main()
    except db.DBError as e:
        print(f"[실패] {e}")
        raise SystemExit(1)
