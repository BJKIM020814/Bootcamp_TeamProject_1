"""회원(customer) 테이블 데이터 접근 함수

회원가입/로그인/회원정보(비밀번호, 전화번호, 이름, 성별, 주소)는 Firebase Firestore 의
account 컬렉션이 관리한다. 여기(MySQL customer)는 쇼핑 쪽 데이터(나이, 누적결제금액, 구매내역)만 다룬다.
customer_id 는 Firebase account 의 email 과 같은 값을 쓴다.

customer 테이블의 password/phone/name/gender/address 컬럼은 NOT NULL 이라 지우지 않고 남겨 두되,
코드에서는 읽지도 쓰지도 않는다. (INSERT 시에만 빈 문자열을 채운다)
모든 쿼리는 db.py 의 파라미터 바인딩(%s)을 사용한다.
"""
import db

# MySQL 에서 관리하는 customer 컬럼
_CUSTOMER_COLS = "customer_id, age, totalprice"


def get_customer(customer_id):
    """회원 1명 조회 (없으면 None)."""
    return db.query_one(
        f"SELECT {_CUSTOMER_COLS} FROM customer WHERE customer_id = %s", (customer_id,)
    )


def get_customers(limit=50, offset=0):
    """회원 목록 조회."""
    return db.query(
        f"SELECT {_CUSTOMER_COLS} FROM customer ORDER BY customer_id LIMIT %s OFFSET %s",
        (limit, offset),
    )


def exists_customer(customer_id):
    """쇼핑몰 회원 행 존재 확인. (아이디/비밀번호 중복·로그인 확인은 Firebase account 에서)"""
    return db.query_one(
        "SELECT 1 AS found FROM customer WHERE customer_id = %s", (customer_id,)
    ) is not None


def add_customer(customer_id, age):
    """Firebase 가입 직후 쇼핑 쪽 회원 행 생성. totalprice 는 0으로 시작.

    customer_id 는 Firebase account 의 email. 나머지 NOT NULL 컬럼은 빈 문자열로 채운다.
    """
    return db.execute(
        "INSERT INTO customer (customer_id, password, phone, name, gender, address, "
        "age, totalprice) VALUES (%s, '', '', '', '', '', %s, 0)",
        (customer_id, age),
    )


# 수정 가능한 컬럼 (컬럼명은 바인딩이 안 되므로 허용 목록으로만 사용)
_UPDATABLE = {"age"}


def update_customer(customer_id, **fields):
    """회원 정보 수정. 예: update_customer('a@b.com', age=30)"""
    fields = {k: v for k, v in fields.items() if k in _UPDATABLE}
    if not fields:
        return 0
    sets = ", ".join(f"{k} = %s" for k in fields)
    return db.execute(
        f"UPDATE customer SET {sets} WHERE customer_id = %s",
        (*fields.values(), customer_id),
    )


def get_purchases(customer_id):
    """회원의 구매 내역 (최신순)."""
    return db.query(
        "SELECT customer_customer_id, head_office_id, p_code, p_date, p_price "
        "FROM purchase WHERE customer_customer_id = %s ORDER BY p_date DESC",
        (customer_id,),
    )


def delete_customer(customer_id):
    """회원 탈퇴(삭제). 연결된 구매/리뷰 등이 있으면 FK 때문에 실패(DBError)."""
    return db.execute("DELETE FROM customer WHERE customer_id = %s", (customer_id,))
