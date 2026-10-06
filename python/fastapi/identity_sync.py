"""Audit and optionally mirror canonical Firebase account profiles into MySQL customer.

Run without flags first. `--apply-mysql` never writes Firebase and never handles
passwords; it only mirrors account profile fields into the commerce customer table.
"""
from __future__ import annotations

import argparse

from firebase_admin import auth as firebase_auth

from python import db
from .accounts import firebase_app, get_accounts
from .commerce import Commerce


def audit(apply_mysql: bool) -> dict[str, int]:
    accounts = get_accounts()
    auth_uids = {user.uid for user in firebase_auth.list_users(app=firebase_app()).iterate_all()}
    report = {
        'firestore_accounts': 0,
        'firebase_auth_users': len(auth_uids),
        'auth_link_missing': 0,
        'legacy_password_migration_required': 0,
        'mysql_profiles_mirrored': 0,
    }
    for document in accounts.client.collection('account').stream():
        profile = document.to_dict() or {}
        if not isinstance(profile.get('email'), str):
            continue
        report['firestore_accounts'] += 1
        uid = profile.get('firebaseUid')
        if not isinstance(uid, str) or uid not in auth_uids:
            report['auth_link_missing'] += 1
        if 'password' in profile:
            # Firebase Auth cannot import an Argon2 hash. The next successful legacy login performs migration.
            report['legacy_password_migration_required'] += 1
        if apply_mysql:
            Commerce().sync_customer(profile)
            report['mysql_profiles_mirrored'] += 1
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description='Audit or mirror Firebase account profiles to MySQL customer.')
    parser.add_argument('--apply-mysql', action='store_true',
                        help='write canonical Firebase account profile values to MySQL customer rows')
    args = parser.parse_args()
    try:
        report = audit(args.apply_mysql)
    except db.DBError as exc:
        raise SystemExit('MySQL 연결 실패: Firebase 원본은 변경하지 않았습니다.') from exc
    for key, value in report.items():
        print(f'{key}={value}')


if __name__ == '__main__':
    main()
