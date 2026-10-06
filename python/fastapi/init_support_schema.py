"""Read-only check for the original-contact migration; never creates parallel tables."""
from python import db


def main():
    columns = {row["name"] for row in db.query(
        "SELECT COLUMN_NAME AS name FROM information_schema.COLUMNS "
        "WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=%s", ("contact",)
    )}
    required = {"c_seq", "contact_post", "thread_root_seq", "parent_c_seq", "author_role", "author_id"}
    missing = sorted(required - columns)
    if missing:
        print("Migration required. Review and run python/fastapi/sql/restore_legacy_commerce_schema.sql")
        print("Missing contact columns:", ", ".join(missing))
        raise SystemExit(1)
    print("OK: original contact table supports multi-inquiry/thread storage")


if __name__ == "__main__":
    try:
        main()
    except db.DBError:
        print("MySQL 연결 또는 기존 customer/head_office 관계를 확인해 주세요.")
        raise SystemExit(1)
