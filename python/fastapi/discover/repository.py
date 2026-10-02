"""Read-only MySQL queries for Discover.

The current schema stores one registered option in each product row. `p_code`
therefore remains the selection identifier; no sales stock lookup is made for
authorized dealers because they are pickup points, not retail inventory.
"""
from python import db

_PRODUCT_COLUMNS = (
    "p_code, p_name, b_name, p_price, p_sku, p_gender, p_size, p_color, "
    "OCTET_LENGTH(p_image) AS image_bytes"
)


def _where(brand: str | None, gender: str | None, keyword: str | None):
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
    """Use same SKU only when it is populated; do not infer options from names."""
    if not product["p_sku"]:
        return [], []
    rows = db.query(
        "SELECT DISTINCT p_color, p_size FROM product WHERE p_sku = %s", (product["p_sku"],)
    )
    colors = sorted({row["p_color"] for row in rows if row["p_color"]})
    sizes = sorted({row["p_size"] for row in rows if row["p_size"] and row["p_size"] > 0})
    return colors, sizes


def get_image(product_code):
    row = db.query_one("SELECT p_image FROM product WHERE p_code = %s", (product_code,))
    return row["p_image"] if row else None


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
