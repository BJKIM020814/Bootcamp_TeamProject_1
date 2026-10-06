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
                "CASE WHEN OCTET_LENGTH(r.image)>=16 THEN CONCAT('/api/v1/discover/reviews/',r.review_seq,'/image') ELSE NULL END AS imageUrl,"
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
                     "WHERE pu.customer_customer_id=%s AND pu.p_code=p.p_code AND pu.order_status='PICKED_UP') "
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
            cur.execute("SELECT 1 FROM purchase WHERE customer_customer_id=%s AND p_code=%s "
                        "AND order_status='PICKED_UP' LIMIT 1",
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
        # 초기 ERD의 contact가 문의와 대화의 유일한 원본이다. root만 목록에 표시한다.
        rows = db.query('SELECT c_seq AS id,customer_customer_id AS customer_id,head_office_id,c_seq,'
                        'contact_post AS content,c_date AS createdAt,c_answer AS response,'
                        'IF(c_status=1,c_answerdate,NULL) AS respondedAt,c_status AS process '
                        'FROM contact WHERE customer_customer_id=%s AND thread_root_seq=c_seq '
                        'ORDER BY c_date DESC,c_seq DESC LIMIT %s OFFSET %s', (email, limit, offset))
        total = db.query_one('SELECT COUNT(*) AS total FROM contact '
                             'WHERE customer_customer_id=%s AND thread_root_seq=c_seq', (email,))['total']
        for row in rows:
            row['messages'] = self.inquiry_messages(row)
        return {'items': rows, 'total': total, 'limit': limit, 'offset': offset}

    def contact(self, email, contact_id):
        # 문의 전체 대화와 마지막 답변 요약을 회원 소유 조건으로 가져온다.
        row = db.query_one('SELECT c_seq AS id,customer_customer_id AS customer_id,head_office_id,c_seq,'
                           'contact_post AS content,c_date AS createdAt,c_answer AS response,'
                           'IF(c_status=1,c_answerdate,NULL) AS respondedAt,c_status AS process '
                           'FROM contact WHERE customer_customer_id=%s AND thread_root_seq=c_seq AND c_seq=%s',
                           (email, contact_id))
        if not row:
            raise HTTPException(404, '문의를 찾을 수 없습니다.')
        row['messages'] = self.inquiry_messages(row)
        return row

    @staticmethod
    def inquiry_messages(inquiry):
        """초기 문의행과 그 뒤에 추가된 contact 메시지행을 순서대로 반환한다."""
        rows = db.query('SELECT c_seq AS id,author_role AS authorRole,author_id AS authorId,'
                        'contact_post AS content,c_date AS createdAt,c_seq '
                        'FROM contact WHERE customer_customer_id=%s AND head_office_id=%s '
                        'AND thread_root_seq=%s ORDER BY c_seq',
                        (inquiry['customer_id'], inquiry['head_office_id'], inquiry['c_seq']))
        messages = []
        for index, row in enumerate(rows):
            messages.append({key: row[key] for key in ('id', 'authorRole', 'authorId', 'content', 'createdAt')} |
                            {'turnIndex': index})
        # 구형 단건 답변은 기존 행의 c_answer로만 저장되어 있을 수 있다.
        if inquiry.get('response') and not any(row['authorRole'] == 'employee' for row in messages):
            messages.append({'id': None, 'authorRole': 'employee', 'authorId': inquiry['head_office_id'],
                             'content': inquiry['response'],
                             'createdAt': inquiry.get('respondedAt') or inquiry['createdAt'],
                             'turnIndex': len(messages)})
        return messages

    def append_customer_message(self, email, inquiry_id, content):
        """회원 후속 메시지를 직전 메시지에 연결하고 답변 대기 상태로 되돌린다."""
        with self.transaction() as cur:
            cur.execute('SELECT * FROM contact WHERE customer_customer_id=%s AND c_seq=%s '
                        'AND thread_root_seq=c_seq FOR UPDATE', (email, inquiry_id))
            inquiry = cur.fetchone()
            if not inquiry:
                raise HTTPException(404, '문의를 찾을 수 없습니다.')
            cur.execute('SELECT c_seq FROM contact WHERE thread_root_seq=%s '
                        'ORDER BY c_seq DESC LIMIT 1 FOR UPDATE', (inquiry['c_seq'],))
            last = cur.fetchone()
            cur.execute('SELECT COUNT(*) AS n FROM contact WHERE thread_root_seq=%s', (inquiry['c_seq'],))
            turn_index = cur.fetchone()['n']
            cur.execute('INSERT INTO contact '
                        '(customer_customer_id,head_office_id,thread_root_seq,parent_c_seq,author_role,author_id,'
                        'contact_post,c_date,c_answer,c_answerdate,c_status,comment_seq,level) '
                        'VALUES (%s,%s,%s,%s,\'customer\',%s,%s,UTC_TIMESTAMP(),\'\',UTC_TIMESTAMP(),0,0,0)',
                        (email, inquiry['head_office_id'], inquiry['c_seq'], last['c_seq'], email, content))
            message_id = cur.lastrowid
            cur.execute('UPDATE contact SET c_status=0 WHERE c_seq=%s', (inquiry['c_seq'],))
        return db.query_one('SELECT c_seq AS id,author_role AS authorRole,author_id AS authorId,'
                            'contact_post AS content,c_date AS createdAt,%s AS turnIndex '
                            'FROM contact WHERE c_seq=%s', (turn_index, message_id))

    def reply_to_inquiry(self, customer_id, head_office_id, c_seq, answer, employee_id):
        """본사 답변을 contact 대화행으로 추가하고 root 문의의 답변 요약도 갱신한다."""
        with self.transaction() as cur:
            cur.execute('SELECT * FROM contact WHERE customer_customer_id=%s AND head_office_id=%s '
                        'AND c_seq=%s AND thread_root_seq=c_seq FOR UPDATE',
                        (customer_id, head_office_id, c_seq))
            inquiry = cur.fetchone()
            if not inquiry:
                raise HTTPException(404, '문의를 찾을 수 없습니다.')
            cur.execute('SELECT c_seq FROM contact WHERE thread_root_seq=%s '
                        'ORDER BY c_seq DESC LIMIT 1 FOR UPDATE', (c_seq,))
            last = cur.fetchone()
            cur.execute('SELECT COUNT(*) AS n FROM contact WHERE thread_root_seq=%s', (c_seq,))
            turn_index = cur.fetchone()['n']
            cur.execute('INSERT INTO contact '
                        '(customer_customer_id,head_office_id,thread_root_seq,parent_c_seq,author_role,author_id,'
                        'contact_post,c_date,c_answer,c_answerdate,c_status,comment_seq,level) '
                        'VALUES (%s,%s,%s,%s,\'employee\',%s,%s,UTC_TIMESTAMP(),\'\',UTC_TIMESTAMP(),1,0,0)',
                        (customer_id, head_office_id, c_seq, last['c_seq'], employee_id, answer))
            message_id = cur.lastrowid
            cur.execute('UPDATE contact SET c_answer=%s,c_answerdate=UTC_TIMESTAMP(),c_status=1 '
                        'WHERE c_seq=%s', (answer, c_seq))
        return db.query_one('SELECT c_seq AS id,author_role AS authorRole,author_id AS authorId,'
                            'contact_post AS content,c_date AS createdAt,%s AS turnIndex '
                            'FROM contact WHERE c_seq=%s', (turn_index, message_id))

    @staticmethod
    def support_head_office():
        # 문자열 FK인 head_office.id를 사용한다. 미설정 시 유일한 고객지원본부를 선택한다.
        office = os.getenv('SUPPORT_HEAD_OFFICE_ID')
        if office:
            row = db.query_one('SELECT id FROM head_office WHERE id=%s', (office,))
            if row:
                return row['id']
            raise HTTPException(503, 'SUPPORT_HEAD_OFFICE_ID가 head_office에 등록되어 있지 않습니다.')
        rows = db.query('SELECT id FROM head_office WHERE division=%s ORDER BY id LIMIT 2', ('고객지원본부',))
        if len(rows) == 1:
            return rows[0]['id']
        raise HTTPException(503, '고객센터 담당 본사(고객지원본부)를 확인할 수 없습니다.')

    def create_contact(self, email, data):
        # 고객지원 본사 FK는 클라이언트 입력을 받지 않고 DB의 실제 문자열 ID로 결정한다.
        office_id = self.support_head_office()
        with self.transaction() as cur:
            cur.execute('SELECT 1 FROM customer WHERE customer_id=%s', (email,))
            if not cur.fetchone():
                raise HTTPException(409, '먼저 POST /api/signup/sync로 쇼핑 회원정보를 연결해 주세요.')
            cur.execute('INSERT INTO contact '
                        '(customer_customer_id,head_office_id,thread_root_seq,parent_c_seq,author_role,author_id,'
                        'contact_post,c_date,c_answer,c_answerdate,c_status,comment_seq,level) '
                        'VALUES (%s,%s,NULL,NULL,\'customer\',%s,%s,UTC_TIMESTAMP(),\'\',UTC_TIMESTAMP(),0,0,0)',
                        (email, office_id, email, data.content))
            contact_id = cur.lastrowid
            cur.execute('UPDATE contact SET thread_root_seq=c_seq WHERE c_seq=%s', (contact_id,))
        return self.contact(email, contact_id)


def get_commerce():
    # FastAPI Depends에서 MySQL 작업 객체를 주입하기 위한 공통 진입점이다.
    return Commerce()
