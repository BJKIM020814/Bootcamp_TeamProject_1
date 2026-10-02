"""신발(product) / 리뷰(review) 테이블 데이터 접근 함수

모든 쿼리는 db.py 의 파라미터 바인딩(%s)을 사용한다.
p_image(blob)는 용량이 커서 목록 조회에서는 제외하고, get_product_image()로 따로 가져온다.
"""
import db

# 이미지(blob)를 제외한 product 컬럼
_PRODUCT_COLS = "p_code, p_name, b_name, p_price, p_sku, p_gender, p_size, p_color"
# 이미지(blob)를 제외한 review 컬럼
_REVIEW_COLS = (
    "customer_customer_id, product_p_code, review_seq, r_date, "
    "context, r_fit, rating, likecount"
)


# ---------- 신발(product) ----------
def get_products(brand=None, gender=None, keyword=None, limit=50, offset=0):
    """신발 목록 조회. 브랜드/성별/이름 검색 조건은 선택."""
    sql = f"SELECT {_PRODUCT_COLS} FROM product WHERE 1=1"
    params = []
    if brand:
        sql += " AND b_name = %s"
        params.append(brand)
    if gender:
        sql += " AND p_gender = %s"
        params.append(gender)
    if keyword:
        sql += " AND p_name LIKE %s"
        params.append(f"%{keyword}%")  # 와일드카드도 값으로 바인딩
    sql += " ORDER BY p_code LIMIT %s OFFSET %s"
    params += [limit, offset]
    return db.query(sql, params)


def get_product(p_code):
    """신발 1건 조회 (없으면 None)."""
    return db.query_one(
        f"SELECT {_PRODUCT_COLS} FROM product WHERE p_code = %s", (p_code,)
    )


def get_products_by_codes(p_codes):
    """상품코드 여러 개로 신발 정보를 한 번에 조회. {p_code: 신발정보} dict 로 반환.

    p_code 는 우리 앱이 직접 만드는 상품코드(제조사 코드와 별개)이고, Firebase 의
    office_inventory / distributor_inventory 등의 productId 와 같은 값이다.
    Firebase 에는 재고 수량만 있으므로, 재고 목록의 productId 들을 넘기면
    이름/브랜드/가격 등 나머지 정보를 여기서 가져올 수 있다. 없는 코드는 결과에서 빠진다.
    """
    p_codes = list(dict.fromkeys(p_codes))  # 중복 제거, 순서 유지
    if not p_codes:
        return {}
    marks = ", ".join(["%s"] * len(p_codes))  # 값만 바인딩, 자리표시자 개수만 조립
    rows = db.query(
        f"SELECT {_PRODUCT_COLS} FROM product WHERE p_code IN ({marks})", p_codes
    )
    return {row["p_code"]: row for row in rows}


def get_product_image(p_code):
    """신발 이미지(bytes) 조회 (없으면 None)."""
    row = db.query_one("SELECT p_image FROM product WHERE p_code = %s", (p_code,))
    return row["p_image"] if row else None


def add_product(p_code, p_name, b_name, p_price, p_image, p_sku, p_gender, p_size, p_color):
    """신발 등록. p_image 는 bytes."""
    return db.execute(
        "INSERT INTO product (p_code, p_name, b_name, p_price, p_image, p_sku, "
        "p_gender, p_size, p_color) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)",
        (p_code, p_name, b_name, p_price, p_image, p_sku, p_gender, p_size, p_color),
    )


# 수정 가능한 컬럼 (컬럼명은 바인딩이 안 되므로 허용 목록으로만 사용)
_UPDATABLE = {"p_name", "b_name", "p_price", "p_image", "p_sku", "p_gender", "p_size", "p_color"}


def update_product(p_code, **fields):
    """신발 정보 수정. 예: update_product('A1', p_price='99000')"""
    fields = {k: v for k, v in fields.items() if k in _UPDATABLE}
    if not fields:
        return 0
    sets = ", ".join(f"{k} = %s" for k in fields)
    return db.execute(
        f"UPDATE product SET {sets} WHERE p_code = %s", (*fields.values(), p_code)
    )


def delete_product(p_code):
    """신발 삭제. 리뷰가 연결돼 있으면 FK 때문에 실패(DBError)."""
    return db.execute("DELETE FROM product WHERE p_code = %s", (p_code,))


# ---------- 리뷰(review) ----------
def get_reviews(p_code, limit=50, offset=0):
    """특정 신발의 리뷰 목록 (최신순)."""
    return db.query(
        f"SELECT {_REVIEW_COLS} FROM review WHERE product_p_code = %s "
        "ORDER BY r_date DESC LIMIT %s OFFSET %s",
        (p_code, limit, offset),
    )


def get_avg_rating(p_code):
    """특정 신발의 평균 별점과 리뷰 수."""
    return db.query_one(
        "SELECT AVG(rating) AS avg_rating, COUNT(*) AS review_count "
        "FROM review WHERE product_p_code = %s",
        (p_code,),
    )
