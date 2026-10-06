# MySQL 데이터 계층: 기존 python/db.py 연결을 사용하며 모든 사용자 값은 파라미터로 바인딩한다.
"""기존 python/db.py 연결 재사용. 기존 코드의 실제 컬럼명을 우선한다."""
from contextlib import contextmanager
import os
import pymysql
from fastapi import HTTPException
from python import db


class Commerce:
    @contextmanager
    def transaction(self):
        # 쓰기 작업을 묶는다. SQL 오류뿐 아니라 구매/권한 검증 실패에도 롤백하고 연결을 닫는다.
        with db.connection() as conn:
            try:
                with conn.cursor() as cursor:
                    yield cursor
                conn.commit()
            except pymysql.MySQLError as exc:
                conn.rollback()
                raise db.DBError('MySQL transaction failed') from exc
            except Exception:
                conn.rollback()
                raise

    def sync_customer(self, account, age=None):
        """Mirror canonical Firestore profile fields into the MySQL customer row.

        Firebase Authentication owns passwords. MySQL is the commerce mirror and never
        receives the Firebase password or a password hash.
        """
        if isinstance(account, str):
            # Compatibility for old callers; new signup/login pass the whole profile.
            account = {'email': account, 'age': age}
        email = account['email']
        profile_age = account.get('age', age)
        db.execute("INSERT INTO customer (customer_id,password,phone,name,gender,address,age,totalprice) "
                   "VALUES (%s,'',%s,%s,%s,%s,%s,0) "
                   "ON DUPLICATE KEY UPDATE password='',phone=VALUES(phone),name=VALUES(name),"
                   "gender=VALUES(gender),address=VALUES(address),"
                   "age=IF(%s IS NULL,age,VALUES(age))",
                   (email, account.get('phoneNumber', ''), account.get('name', ''),
                    account.get('gender', ''), account.get('address', ''),
                    0 if profile_age is None else profile_age, profile_age))

    @staticmethod
    def review_select():
        # MySQL 컬럼명을 프론트에서 쓰는 camelCase 응답 필드로 변환하는 공통 SELECT 목록이다.
        return ('r.review_seq AS id,r.product_p_code AS productCode,r.context AS content,'
                'r.rating,r.r_fit AS fit,r.r_date AS createdAt,r.likecount AS likeCount,'
                'p.p_name AS productName,p.b_name AS brand')

    def reviews(self, email, limit, offset):
        # 리뷰에 상품명을 조인하되 회원 소유자 조건을 유지한다. 이미지 BLOB은 목록에서 제외한다.
        rows = db.query(f'SELECT {self.review_select()} FROM review r '
                        'JOIN product p ON p.p_code=r.product_p_code '
                        'WHERE r.customer_customer_id=%s ORDER BY r.r_date DESC,r.review_seq DESC LIMIT %s OFFSET %s',
                        (email, limit, offset))
        total = db.query_one('SELECT COUNT(*) AS total FROM review WHERE customer_customer_id=%s', (email,))['total']
        return {'items': rows, 'total': total, 'limit': limit, 'offset': offset}

    def review(self, email, review_id):
        # 단일 리뷰 조회도 ID만으로 찾지 않고 이메일까지 조건에 포함한다.
        row = db.query_one(f'SELECT {self.review_select()} FROM review r JOIN product p ON p.p_code=r.product_p_code '
                           'WHERE r.customer_customer_id=%s AND r.review_seq=%s', (email, review_id))
        if not row:
            raise HTTPException(404, '리뷰를 찾을 수 없습니다.')
        return row

    def reviewable(self, email, limit, offset):
        # 현재 purchase의 p_code는 python/user_data.py와 동일한 상품 연결 키.
        # EXISTS로 구매 여부를 확인하므로 동일 상품을 여러 번 구매해도 목록에 중복되지 않는다.
        predicate = ('FROM product p WHERE EXISTS (SELECT 1 FROM purchase pu '
                     'WHERE pu.customer_customer_id=%s AND pu.p_code=p.p_code) '
                     'AND NOT EXISTS (SELECT 1 FROM review r WHERE r.customer_customer_id=%s AND r.product_p_code=p.p_code)')
        rows = db.query('SELECT p.p_code AS productCode,p.p_name AS productName,p.b_name AS brand '
                        + predicate + ' ORDER BY p.p_code LIMIT %s OFFSET %s', (email, email, limit, offset))
        total = db.query_one('SELECT COUNT(*) AS total ' + predicate, (email, email))['total']
        return {'items': rows, 'total': total, 'limit': limit, 'offset': offset}

    def create_review(self, email, data):
        # 회원 행을 먼저 잠가 같은 회원의 동시 리뷰 요청을 직렬화한 뒤 구매/중복을 검사한다.
        with self.transaction() as cur:
            # 회원 행 잠금으로 같은 회원의 동시 중복 등록을 직렬화.
            cur.execute('SELECT customer_id FROM customer WHERE customer_id=%s FOR UPDATE', (email,))
            if not cur.fetchone():
                raise HTTPException(409, '먼저 POST /api/signup/sync로 쇼핑 회원정보를 연결해 주세요.')
            cur.execute('SELECT 1 FROM purchase WHERE customer_customer_id=%s AND p_code=%s LIMIT 1',
                        (email, data.productCode))
            if not cur.fetchone():
                raise HTTPException(403, '구매한 상품만 리뷰를 작성할 수 있습니다.')
            cur.execute('SELECT 1 FROM review WHERE customer_customer_id=%s AND product_p_code=%s LIMIT 1',
                        (email, data.productCode))
            if cur.fetchone():
                raise HTTPException(409, '이미 리뷰를 작성한 상품입니다.')
            cur.execute('INSERT INTO review (customer_customer_id,product_p_code,r_date,image,context,r_fit,rating,likecount) '
                        'VALUES (%s,%s,UTC_TIMESTAMP(),%s,%s,%s,%s,0)',
                        (email, data.productCode, b'', data.content, data.fit, data.rating))
            review_id = cur.lastrowid
        return self.review(email, review_id)

    def update_review(self, email, review_id, data):
        # 소유자 조건으로 행을 잠근 후 수정한다. 같은 내용을 보내도 존재하는 리뷰라면 성공한다.
        with self.transaction() as cur:
            cur.execute('SELECT 1 FROM review WHERE customer_customer_id=%s AND review_seq=%s FOR UPDATE', (email, review_id))
            if not cur.fetchone():
                raise HTTPException(404, '리뷰를 찾을 수 없습니다.')
            cur.execute('UPDATE review SET context=%s,rating=%s,r_fit=%s WHERE customer_customer_id=%s AND review_seq=%s',
                        (data.content, data.rating, data.fit, email, review_id))
        return self.review(email, review_id)

    def delete_review(self, email, review_id):
        # 영향받은 행이 없으면 미존재/타인 소유를 구분하지 않고 404를 반환한다.
        affected = db.execute('DELETE FROM review WHERE customer_customer_id=%s AND review_seq=%s', (email, review_id))
        if not affected:
            raise HTTPException(404, '리뷰를 찾을 수 없습니다.')

    def contacts(self, email, limit, offset):
        # 소유자의 문의만 조회한다. contact_seq는 개별 문의 식별을 위해 추가가 필요한 키다.
        rows = db.query('SELECT contact_seq AS id,context AS content,c_date AS createdAt,response,r_date AS respondedAt,process '
                        'FROM contact WHERE customer_customer_id=%s ORDER BY c_date DESC,contact_seq DESC LIMIT %s OFFSET %s',
                        (email, limit, offset))
        total = db.query_one('SELECT COUNT(*) AS total FROM contact WHERE customer_customer_id=%s', (email,))['total']
        return {'items': rows, 'total': total, 'limit': limit, 'offset': offset}

    def contact(self, email, contact_id):
        # 응답 내용/응답일/처리상태는 본사 시스템이 MySQL에 기록한 실제 값을 그대로 읽는다.
        row = db.query_one('SELECT contact_seq AS id,context AS content,c_date AS createdAt,response,r_date AS respondedAt,process '
                           'FROM contact WHERE customer_customer_id=%s AND contact_seq=%s', (email, contact_id))
        if not row:
            raise HTTPException(404, '문의를 찾을 수 없습니다.')
        return row

    def create_contact(self, email, data):
        # 직원 FK는 실제 존재하는 본사 ID를 환경변수로 지정해야 함.
        # 담당 본사 ID는 환경설정에서 받는다. 클라이언트가 직원 FK나 다른 회원을 지정할 수 없다.
        office = os.getenv('SUPPORT_HEAD_OFFICE_ID')
        if not office:
            raise HTTPException(503, '고객센터 담당 본사 ID 설정이 필요합니다.')
        try:
            office_id = int(office)
        except ValueError as exc:
            raise HTTPException(503, '고객센터 담당 본사 ID는 정수여야 합니다.') from exc
        with self.transaction() as cur:
            cur.execute('SELECT 1 FROM customer WHERE customer_id=%s', (email,))
            if not cur.fetchone():
                raise HTTPException(409, '먼저 POST /api/signup/sync로 쇼핑 회원정보를 연결해 주세요.')
            cur.execute('INSERT INTO contact (context,c_date,response,r_date,process,customer_customer_id,head_office_id) '
                        'VALUES (%s,UTC_TIMESTAMP(),%s,NULL,0,%s,%s)', (data.content, '', email, office_id))
            contact_id = cur.lastrowid
        return self.contact(email, contact_id)


def get_commerce():
    # FastAPI Depends에서 MySQL 작업 객체를 주입하기 위한 공통 진입점이다.
    return Commerce()
