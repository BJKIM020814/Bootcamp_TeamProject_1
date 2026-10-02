# 서버 SQLite 데이터 계층: 앱 기기의 sqflite와 별개로 세션, 알림, 설정을 저장한다.
"""서버 SQLite 확장: 원본 SQLite ERD의 장바구니/쿠폰 테이블과 별개."""
import hashlib
import secrets
import sqlite3
import time
from contextlib import contextmanager
from datetime import datetime, timezone
from .config import sqlite_path, session_seconds


def now():
    # 새 알림의 시간을 UTC ISO 문자열로 저장하여 기기 시간대와 분리한다.
    return datetime.now(timezone.utc).isoformat()


class LocalStore:
    def __init__(self, path=None):
        # 운영에서는 설정 경로를, 테스트에서는 임시 DB 경로를 주입할 수 있다.
        self.path = path or sqlite_path()

    @contextmanager
    def connection(self):
        # 작업별로 연결을 열고 성공 시 커밋, 예외 시 롤백한다. 마지막에는 반드시 연결을 닫는다.
        from pathlib import Path
        Path(self.path).parent.mkdir(parents=True, exist_ok=True)
        conn = sqlite3.connect(self.path, timeout=10)
        conn.row_factory = sqlite3.Row
        try:
            with conn:
                yield conn
        finally:
            conn.close()

    def initialize(self):
        # 최초 실행 때 필요한 테이블/인덱스를 만들며 기존 데이터가 있으면 유지한다.
        with self.connection() as conn:
            conn.executescript('''
            CREATE TABLE IF NOT EXISTS api_sessions (
                token_hash TEXT PRIMARY KEY, email TEXT NOT NULL,
                expires_at INTEGER NOT NULL);
            CREATE TABLE IF NOT EXISTS app_settings (
                email TEXT PRIMARY KEY, order_notification INTEGER NOT NULL DEFAULT 1,
                marketing_notification INTEGER NOT NULL DEFAULT 0);
            CREATE TABLE IF NOT EXISTS notifications (
                notification_id INTEGER PRIMARY KEY AUTOINCREMENT,
                email TEXT NOT NULL, category TEXT NOT NULL,
                title TEXT NOT NULL, body TEXT NOT NULL, created_at TEXT NOT NULL,
                read_at TEXT);
            CREATE INDEX IF NOT EXISTS notifications_owner
                ON notifications(email, notification_id);
            ''')

    def new_session(self, email):
        # 추측하기 어려운 토큰을 발급하고 서버에는 해시와 만료 시간만 보관한다.
        token = secrets.token_urlsafe(32)
        expires = int(time.time()) + session_seconds()
        with self.connection() as conn:
            conn.execute('DELETE FROM api_sessions WHERE expires_at <= ?', (int(time.time()),))
            conn.execute('INSERT INTO api_sessions VALUES (?, ?, ?)',
                         (self.token_hash(token), email, expires))
        return token, expires

    @staticmethod
    def token_hash(token):
        # 토큰 원문이 SQLite에 남지 않도록 SHA-256 조회 키로 변환한다.
        return hashlib.sha256(token.encode()).hexdigest()

    def session_email(self, token):
        # 토큰 해시가 일치하고 현재 시각보다 만료가 늦은 세션에서만 이메일을 읽는다.
        with self.connection() as conn:
            row = conn.execute('SELECT email FROM api_sessions WHERE token_hash=? AND expires_at>?',
                               (self.token_hash(token), int(time.time()))).fetchone()
        return row['email'] if row else None

    def logout(self, token):
        # 세션 행을 제거하면 이후 같은 토큰으로 인증할 수 없다.
        with self.connection() as conn:
            conn.execute('DELETE FROM api_sessions WHERE token_hash=?', (self.token_hash(token),))

    def settings(self, email):
        # 회원별 기본 설정을 필요할 때 만들고 SQLite 정수 0/1을 JSON bool로 바꾼다.
        with self.connection() as conn:
            conn.execute('INSERT OR IGNORE INTO app_settings(email) VALUES (?)', (email,))
            row = conn.execute('SELECT * FROM app_settings WHERE email=?', (email,)).fetchone()
        return {'orderNotification': bool(row['order_notification']),
                'marketingNotification': bool(row['marketing_notification'])}

    def update_settings(self, email, fields):
        # 허용된 필드명만 DB 컬럼에 매핑하고 실제 설정 값/이메일은 파라미터로 전달한다.
        self.settings(email)
        columns = {'orderNotification': 'order_notification', 'marketingNotification': 'marketing_notification'}
        with self.connection() as conn:
            for key, value in fields.items():
                conn.execute(f'UPDATE app_settings SET {columns[key]}=? WHERE email=?', (int(value), email))
        return self.settings(email)

    def add_notification(self, email, category, title, body):
        # 주문/마케팅 설정에 따라 생성을 건너뛴다. 문의 접수 알림은 해당 두 설정과 별도로 생성한다.
        """서버 주문/문의 이벤트에서 호출. 클라이언트 임의 생성 API는 제공하지 않음."""
        settings = self.settings(email)
        if category == 'marketing' and not settings['marketingNotification']:
            return None
        if category == 'order' and not settings['orderNotification']:
            return None
        with self.connection() as conn:
            cursor = conn.execute('INSERT INTO notifications(email,category,title,body,created_at) VALUES (?,?,?,?,?)',
                                  (email, category, title, body, now()))
            return cursor.lastrowid

    def notifications(self, email, limit, offset):
        # 내 알림 목록, 전체 개수, 미읽음 개수를 계산한다. readAt이 없으면 미읽음 상태다.
        with self.connection() as conn:
            total = conn.execute('SELECT COUNT(*) FROM notifications WHERE email=?', (email,)).fetchone()[0]
            unread = conn.execute('SELECT COUNT(*) FROM notifications WHERE email=? AND read_at IS NULL', (email,)).fetchone()[0]
            rows = conn.execute('SELECT notification_id AS id,category,title,body,created_at AS createdAt,read_at AS readAt '
                                'FROM notifications WHERE email=? ORDER BY notification_id DESC LIMIT ? OFFSET ?',
                                (email, limit, offset)).fetchall()
        return {'items': [dict(row) for row in rows], 'total': total, 'unreadCount': unread, 'limit': limit, 'offset': offset}

    def read_notification(self, email, notification_id):
        # 소유자까지 확인하고 최초 읽은 시간만 보존한다. 반복 호출해도 읽은 시간이 바뀌지 않는다.
        with self.connection() as conn:
            row = conn.execute('SELECT 1 FROM notifications WHERE email=? AND notification_id=?', (email, notification_id)).fetchone()
            if row:
                conn.execute('UPDATE notifications SET read_at=COALESCE(read_at,?) WHERE email=? AND notification_id=?',
                             (now(), email, notification_id))
        return bool(row)

    def read_all(self, email):
        # 미읽음 항목만 업데이트하므로 이전에 읽은 알림의 시각은 그대로 남는다.
        with self.connection() as conn:
            return conn.execute('UPDATE notifications SET read_at=? WHERE email=? AND read_at IS NULL', (now(), email)).rowcount
