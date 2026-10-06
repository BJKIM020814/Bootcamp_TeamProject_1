"""Create the non-destructive customer support inquiry table from its SQL file."""
from pathlib import Path

from python import db


def main():
    path = Path(__file__).resolve().parent / "sql" / "support_inquiry.sql"
    statements = [part.strip() for part in path.read_text(encoding="utf-8").split(";") if part.strip()]
    for statement in statements:
        db.execute(statement)

    # CREATE IF NOT EXISTS does not add columns when the table was created by an earlier script run.
    columns = {row["name"] for row in db.query(
        "SELECT COLUMN_NAME AS name FROM information_schema.COLUMNS "
        "WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=%s", ("customer_support_inquiry",)
    )}
    for name, definition in (
        ("legacy_customer_id", "VARCHAR(45) NULL"),
        ("legacy_head_office_id", "VARCHAR(45) NULL"),
        ("legacy_c_seq", "INT NULL"),
    ):
        if name not in columns:
            db.execute(f"ALTER TABLE customer_support_inquiry ADD COLUMN {name} {definition}")
    index = db.query_one(
        "SELECT 1 AS found FROM information_schema.STATISTICS "
        "WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=%s AND INDEX_NAME=%s LIMIT 1",
        ("customer_support_inquiry", "uq_support_inquiry_legacy_contact"),
    )
    if not index:
        db.execute(
            "CREATE UNIQUE INDEX uq_support_inquiry_legacy_contact "
            "ON customer_support_inquiry (legacy_customer_id,legacy_head_office_id,legacy_c_seq)"
        )

    # Keep old contact records visible in the new API without deleting or editing their source rows.
    db.execute(
        "INSERT IGNORE INTO customer_support_inquiry "
        "(customer_id,head_office_id,content,response,created_at,responded_at,process,"
        "legacy_customer_id,legacy_head_office_id,legacy_c_seq) "
        "SELECT c.customer_customer_id,c.head_office_id,c.contact_post,NULLIF(c.c_answer,''),c.c_date,"
        "IF(c.c_status=1,c.c_answerdate,NULL),c.c_status,c.customer_customer_id,c.head_office_id,c.c_seq "
        "FROM contact c"
    )
    print("OK: customer_support_inquiry schema is ready; legacy inquiries were copied idempotently")


if __name__ == "__main__":
    try:
        main()
    except db.DBError:
        print("MySQL 연결 또는 기존 customer/head_office 관계를 확인해 주세요.")
        raise SystemExit(1)
