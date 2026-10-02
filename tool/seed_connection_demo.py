"""Explicit development-only account seed; never overwrite existing accounts.

Run with FITPICK_DEMO_PASSWORD set. Only identifiable demo account/customer
and employee documents are created. No purchases or operational data are changed.
"""
import os
from python import db
from python.fastapi.accounts import get_accounts
from python.fastapi.commerce import Commerce


def main():
    password = os.getenv('FITPICK_DEMO_PASSWORD', '')
    if len(password) < 12:
        raise SystemExit('Set FITPICK_DEMO_PASSWORD to at least 12 characters.')
    accounts = get_accounts()
    for role in ('customer', 'hq'):
        email = f'fitpick.{role}.demo@example.com'
        existing = accounts.find(email)
        if existing:
            # Verify ownership of the intended demo identity before touching mappings.
            account = accounts.authenticate(email, password)
            if account.get('signupPath') != '이메일' or not account.get('name', '').startswith('[DEMO]'):
                raise SystemExit('Existing account is not a demo account; no overwrite allowed.')
        else:
            accounts.create({'email': email, 'password': password,
                'name': f'[DEMO] {role}', 'phoneNumber': '010-0000-0000',
                'gender': '선택 안 함', 'address': '[DEMO] 개발 테스트 전용', 'signupPath': '이메일'})
        Commerce().sync_customer(email, age=25)
        print(role, 'demo account/customer ready')
    ref = accounts.client.collection('employee').document('FITPICK-DEMO-HQ')
    data = {'employeeId': 'FITPICK-DEMO-HQ', 'email': 'fitpick.hq.demo@example.com',
            'position': '팀장', 'department': '상품관리부', 'demo': True}
    snapshot = ref.get()
    if snapshot.exists:
        if snapshot.to_dict() != data:
            raise SystemExit('Existing employee document differs; refusing to overwrite.')
    else:
        ref.create(data)
    print('hq employee email mapping ready')


if __name__ == '__main__':
    main()
