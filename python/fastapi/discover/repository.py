"""Read-only MySQL queries for Discover.

The current schema stores one registered option in each product row. `p_code`
therefore remains the selection identifier; no sales stock lookup is made for
authorized dealers because they are pickup points, not retail inventory.
"""
from typing import Optional
from python import db

_PRODUCT_COLUMNS = (
    "p_code, p_name, b_name, p_price, p_sku, p_gender, p_size, p_color, "
    "OCTET_LENGTH(p_image) AS image_bytes"
)
_LIST_PRODUCT_COLUMNS = (
    "p.p_code, p.p_name, p.b_name, p.p_price, p.p_sku, p.p_gender, p.p_size, p.p_color, "
    "OCTET_LENGTH(p.p_image) AS image_bytes"
)
# BLOB가 몇 바이트만 들어간 깨진 테스트 값은 사진으로 인정하지 않는다.
# 실제 이미지 signature(JPEG/PNG/WEBP)와 최소 크기를 모두 만족해야 Discover 노출 대상이다.
_VALID_IMAGE = "(OCTET_LENGTH(p_image) >= 1024 AND ("
_VALID_IMAGE += "LEFT(p_image,3)=0xFFD8FF OR LEFT(p_image,8)=0x89504E470D0A1A0A OR "
_VALID_IMAGE += "(LEFT(p_image,4)=0x52494646 AND SUBSTRING(p_image,9,4)=0x57454250)))"
def _where(brand: Optional[str], gender: Optional[str], keyword: Optional[str], purpose: Optional[str] = None):
    clauses, params = [_VALID_IMAGE], []
    if brand:
        clauses.append("b_name = %s")
        params.append(brand)
    if gender:
        clauses.append("p_gender = %s")
        params.append(gender)
    if purpose:
        clauses.append("p_usage = %s")
        params.append(purpose)
    if keyword:
        clauses.append("(p_name LIKE %s OR b_name LIKE %s OR p_code LIKE %s)")
        value = f"%{keyword}%"
        params.extend([value, value, value])
    return " AND ".join(clauses), params


def list_products(brand=None, gender=None, keyword=None, limit=20, offset=0, purpose=None):
    where, params = _where(brand, gender, keyword, purpose)
    # 상품 목록은 색상·사이즈별 SKU 행이 아니라 상품명/브랜드/대상별 모델 1개만 표시한다.
    total = db.query_one(
        "SELECT COUNT(*) AS total FROM ("
        f"SELECT p_name,b_name,p_gender FROM product WHERE {where} "
        "GROUP BY p_name,b_name,p_gender) AS product_models",
        params,
    )["total"]
    rows = db.query(
        f"SELECT {_LIST_PRODUCT_COLUMNS} FROM product p JOIN ("
        f"SELECT MIN(p_code) AS p_code FROM product WHERE {where} "
        "GROUP BY p_name,b_name,p_gender) AS product_models ON product_models.p_code=p.p_code "
        "ORDER BY p.p_name,p.b_name,p.p_gender LIMIT %s OFFSET %s",
        [*params, limit, offset],
    )
    return rows, total


def get_product(product_code):
    return db.query_one(
        f"SELECT {_PRODUCT_COLUMNS} FROM product WHERE p_code = %s AND {_VALID_IMAGE}", (product_code,)
    )


def get_options(product):
    """Return only persisted options in this model/target/color family.

    SKU records encode size as their final numeric segment (for example
    SKU-AR-001-270). Strip that segment only when it agrees with p_size; the
    remaining prefix identifies sibling records, not fabricated combinations.
    """
    rows = get_variants(product)
    colors = sorted({row["p_color"] for row in rows if row["p_color"]})
    sizes = sorted({row["p_size"] for row in rows if row["p_size"] and row["p_size"] > 0})
    return colors, sizes


def get_variants(product):
    # SKU 접두어가 색상마다 달라질 수 있으므로 실제 상품명·브랜드·대상이 같은 저장 행으로 묶는다.
    variants = db.query(
        f"SELECT {_PRODUCT_COLUMNS} FROM product "
        f"WHERE b_name=%s AND p_name=%s AND p_gender=%s AND p_size > 0 AND {_VALID_IMAGE} "
        "ORDER BY p_color,p_size,p_code",
        (product["b_name"], product["p_name"], product["p_gender"]),
    )
    return variants or [product]


def get_image(product_code):
    row = db.query_one(f"SELECT p_image FROM product WHERE p_code = %s AND {_VALID_IMAGE}", (product_code,))
    return row["p_image"] if row else None


def list_banners():
    """4~6번에 저장된 배너만 노출하고 이미지 BLOB은 별도 요청으로 가져온다."""
    return db.query(
        "SELECT seq FROM banner_image WHERE seq BETWEEN %s AND %s ORDER BY seq", (4, 6)
    )


def get_banner_image(seq):
    row = db.query_one("SELECT image FROM banner_image WHERE seq = %s", (seq,))
    return row["image"] if row else None


def list_reviews(product_code, limit, offset):
    # 리뷰는 특정 SKU가 아닌 같은 모델(상품명·브랜드·대상)에 귀속해 보여준다.
    # 화면이 대표 사이즈 SKU를 전달하더라도 다른 사이즈 SKU에 작성된 리뷰를 놓치지 않는다.
    model_join = (
        "review r "
        "JOIN product reviewed ON reviewed.p_code = r.product_p_code "
        "JOIN product selected ON selected.p_code = %s "
        "AND selected.p_name = reviewed.p_name "
        "AND selected.b_name = reviewed.b_name "
        "AND selected.p_gender = reviewed.p_gender"
    )
    total = db.query_one(
        f"SELECT COUNT(*) AS total FROM {model_join}", (product_code,)
    )["total"]
    rows = db.query(
        "SELECT review_seq, customer_customer_id, r_date, context, r_fit, rating, likecount, "
        "OCTET_LENGTH(image) AS image_bytes "
        f"FROM {model_join} ORDER BY r_date DESC LIMIT %s OFFSET %s",
        (product_code, limit, offset),
    )
    return rows, total


def get_review_image(review_id):
    row = db.query_one("SELECT image FROM review WHERE review_seq = %s", (review_id,))
    return row["image"] if row and row["image"] else None


def filters():
    brands = [row["b_name"] for row in db.query(
        f"SELECT DISTINCT b_name FROM product WHERE {_VALID_IMAGE} ORDER BY b_name")]
    genders = [row["p_gender"] for row in db.query(
        f"SELECT DISTINCT p_gender FROM product WHERE {_VALID_IMAGE} ORDER BY p_gender")]
    purposes = [row["p_usage"] for row in db.query(
        f"SELECT DISTINCT p_usage FROM product WHERE {_VALID_IMAGE} "
        "AND p_usage IS NOT NULL AND TRIM(p_usage) <> '' ORDER BY p_usage"
    )]
    return brands, genders, purposes


def list_pickup_stores(keyword=None):
    sql = "SELECT seq, name, dealer_number, manager, address, lat, lng FROM authorized_dealer"
    params = []
    if keyword:
        sql += " WHERE name LIKE %s OR address LIKE %s"
        value = f"%{keyword}%"
        params = [value, value]
    sql += " ORDER BY seq"
    return db.query(sql, params)
