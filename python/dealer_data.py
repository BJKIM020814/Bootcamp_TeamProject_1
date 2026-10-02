"""대리점(authorized_dealer) 테이블 데이터 접근 함수

Firebase 의 distributor_inventory(대리점재고)는 지점명(branchName)과 재고 수량만 가진다.
지점명은 authorized_dealer.name 과 같은 값으로 연결해서 주소/위치/담당자 정보를 가져온다.
모든 쿼리는 db.py 의 파라미터 바인딩(%s)을 사용한다.
"""
import db

_DEALER_COLS = "seq, name, dealer_number, manager, address, lat, lng"


def get_dealers():
    """대리점 전체 목록."""
    return db.query(f"SELECT {_DEALER_COLS} FROM authorized_dealer ORDER BY seq")


def get_dealer(seq):
    """대리점 1곳 조회 (없으면 None)."""
    return db.query_one(
        f"SELECT {_DEALER_COLS} FROM authorized_dealer WHERE seq = %s", (seq,)
    )


def get_dealer_by_branch(branch_name):
    """Firebase 지점명(branchName)으로 대리점 조회 (없으면 None).

    name 은 DB 에서 유일하지 않을 수 있으므로, 같은 이름이 여럿이면 seq 가 가장 작은 곳을 돌려준다.
    """
    return db.query_one(
        f"SELECT {_DEALER_COLS} FROM authorized_dealer WHERE name = %s ORDER BY seq LIMIT 1",
        (branch_name,),
    )


def get_dealers_by_branches(branch_names):
    """지점명 여러 개로 한 번에 조회. {지점명: 대리점정보} dict 로 반환 (없는 지점명은 빠짐)."""
    branch_names = list(dict.fromkeys(branch_names))
    if not branch_names:
        return {}
    marks = ", ".join(["%s"] * len(branch_names))
    rows = db.query(
        f"SELECT {_DEALER_COLS} FROM authorized_dealer WHERE name IN ({marks}) ORDER BY seq",
        branch_names,
    )
    result = {}
    for row in rows:
        result.setdefault(row["name"], row)  # 같은 이름이면 seq 작은 쪽 유지
    return result
