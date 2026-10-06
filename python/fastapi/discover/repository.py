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


def _where(brand: Optional[str], gender: Optional[str], keyword: Optional[str]):
    clauses, params = ["1 = 1"], []
    if brand:
        clauses.append("b_name = %s")
        params.append(brand)
    if gender:
        clauses.append("p_gender = %s")
        params.append(gender)
    if keyword:
        clauses.append("(p_name LIKE %s OR b_name LIKE %s OR p_code LIKE %s)")
        value = f"%{keyword}%"
        params.extend([value, value, value])
    return " AND ".join(clauses), params


def list_products(brand=None, gender=None, keyword=None, limit=20, offset=0):
    where, params = _where(brand, gender, keyword)
    total = db.query_one(f"SELECT COUNT(*) AS total FROM product WHERE {where}", params)["total"]
    rows = db.query(
        f"SELECT {_PRODUCT_COLUMNS} FROM product WHERE {where} "
        "ORDER BY p_code LIMIT %s OFFSET %s",
        [*params, limit, offset],
    )
    return rows, total


def get_product(product_code):
    return db.query_one(
        f"SELECT {_PRODUCT_COLUMNS} FROM product WHERE p_code = %s", (product_code,)
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
    # 실제 등록 행만 변형으로 연결하고, 대상·브랜드·모델명이 같은 제품군만 묶는다.
    sku = product.get("p_sku") or ""
    sku_parts = sku.rsplit("-", 1)
    if len(sku_parts) != 2 or not sku_parts[1].isdigit() or int(sku_parts[1]) != product.get("p_size"):
        return [product]
    family_prefix = sku_parts[0]
    return db.query(
        f"SELECT {_PRODUCT_COLUMNS} FROM product "
        "WHERE p_sku LIKE %s AND b_name=%s AND p_name=%s AND p_gender=%s ORDER BY p_size, p_color, p_code",
        (f"{family_prefix}-%", product["b_name"], product["p_name"], product["p_gender"]),
    )


def get_image(product_code):
    row = db.query_one("SELECT p_image FROM product WHERE p_code = %s", (product_code,))
    return row["p_image"] if row else None


def list_banners():
    """Return only persisted banner identifiers; images are fetched from their BLOB rows."""
    return db.query("SELECT seq FROM banner_image ORDER BY seq")


def get_banner_image(seq):
    row = db.query_one("SELECT image FROM banner_image WHERE seq = %s", (seq,))
    return row["image"] if row else None


def list_reviews(product_code, limit, offset):
    total = db.query_one(
        "SELECT COUNT(*) AS total FROM review WHERE product_p_code = %s", (product_code,)
    )["total"]
    rows = db.query(
        "SELECT customer_customer_id, r_date, context, r_fit, rating, likecount "
        "FROM review WHERE product_p_code = %s ORDER BY r_date DESC LIMIT %s OFFSET %s",
        (product_code, limit, offset),
    )
    return rows, total


def filters():
    brands = [row["b_name"] for row in db.query("SELECT DISTINCT b_name FROM product ORDER BY b_name")]
    genders = [row["p_gender"] for row in db.query("SELECT DISTINCT p_gender FROM product ORDER BY p_gender")]
    return brands, genders


def list_pickup_stores(keyword=None):
    sql = "SELECT seq, name, dealer_number, manager, address, lat, lng FROM authorized_dealer"
    params = []
    if keyword:
        sql += " WHERE name LIKE %s OR address LIKE %s"
        value = f"%{keyword}%"
        params = [value, value]
    sql += " ORDER BY seq"
    return db.query(sql, params)
