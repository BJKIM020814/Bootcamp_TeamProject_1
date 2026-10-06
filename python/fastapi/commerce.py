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
        # 다건 문의와 inquiry_message 대화 스레드를 회원 소유 조건으로 조회한다.
        rows = db.query('SELECT inquiry_id AS id,customer_id,head_office_id,COALESCE(legacy_c_seq,inquiry_id) AS c_seq,'
                        'content,created_at AS createdAt,response,responded_at AS respondedAt,process '
                        'FROM customer_support_inquiry WHERE customer_id=%s '
                        'ORDER BY created_at DESC,inquiry_id DESC LIMIT %s OFFSET %s',
                        (email, limit, offset))
        total = db.query_one('SELECT COUNT(*) AS total FROM customer_support_inquiry WHERE customer_id=%s',
                             (email,))['total']
        for row in rows:
            row['messages'] = self.inquiry_messages(row)
        return {'items': rows, 'total': total, 'limit': limit, 'offset': offset}

    def contact(self, email, contact_id):
        # 문의 전체 대화와 마지막 답변 요약을 회원 소유 조건으로 가져온다.
        row = db.query_one('SELECT inquiry_id AS id,customer_id,head_office_id,'
                           'COALESCE(legacy_c_seq,inquiry_id) AS c_seq,content,created_at AS createdAt,response,'
                           'responded_at AS respondedAt,process FROM customer_support_inquiry '
                           'WHERE customer_id=%s AND inquiry_id=%s', (email, contact_id))
        if not row:
            raise HTTPException(404, '문의를 찾을 수 없습니다.')
        row['messages'] = self.inquiry_messages(row)
        return row

    @staticmethod
    def inquiry_messages(inquiry):
        """메시지가 아직 이전 단건 답변 형식인 문의도 읽기 시 대화 형태로 호환한다."""
        messages = db.query(
            'SELECT message_id AS id,author_role AS authorRole,author_id AS authorId,content,'
            'created_at AS createdAt,turn_index AS turnIndex FROM inquiry_message '
            'WHERE customer_id=%s AND head_office_id=%s AND c_seq=%s ORDER BY turn_index,message_id',
            (inquiry['customer_id'], inquiry['head_office_id'], inquiry['c_seq']))
        if messages:
            return messages
        # 이전 문의는 원문/마지막 답변을 가상 메시지로 보여 주며 조회만으로 DB를 수정하지 않는다.
        result = [{'id': None, 'authorRole': 'customer', 'authorId': inquiry['customer_id'],
                   'content': inquiry['content'], 'createdAt': inquiry['createdAt'], 'turnIndex': 0}]
        response = inquiry.get('response')
        if response:
            result.append({'id': None, 'authorRole': 'employee', 'authorId': inquiry['head_office_id'],
                           'content': response, 'createdAt': inquiry.get('respondedAt') or inquiry['createdAt'],
                           'turnIndex': 1})
        return result

    def append_customer_message(self, email, inquiry_id, content):
        """회원 후속 메시지를 직전 메시지에 연결하고 답변 대기 상태로 되돌린다."""
        with self.transaction() as cur:
            cur.execute('SELECT * FROM customer_support_inquiry WHERE customer_id=%s AND inquiry_id=%s FOR UPDATE',
                        (email, inquiry_id))
            inquiry = cur.fetchone()
            if not inquiry:
                raise HTTPException(404, '문의를 찾을 수 없습니다.')
            seq = inquiry.get('legacy_c_seq') or inquiry['inquiry_id']
            last = self._last_inquiry_message(cur, inquiry, seq)
            if last is None:
                cur.execute('INSERT INTO inquiry_message '
                            '(customer_id,head_office_id,c_seq,turn_index,parent_message_id,author_role,author_id,content) '
                            'VALUES (%s,%s,%s,0,NULL,\'customer\',%s,%s)',
                            (email, inquiry['head_office_id'], seq, email, inquiry['content']))
                last = {'message_id': cur.lastrowid, 'turn_index': 0}
            cur.execute('INSERT INTO inquiry_message '
                        '(customer_id,head_office_id,c_seq,turn_index,parent_message_id,author_role,author_id,content) '
                        'VALUES (%s,%s,%s,%s,%s,\'customer\',%s,%s)',
                        (email, inquiry['head_office_id'], seq, last['turn_index'] + 1,
                         last['message_id'], email, content))
            message_id = cur.lastrowid
            cur.execute('UPDATE customer_support_inquiry SET process=0 WHERE inquiry_id=%s',
                        (inquiry['inquiry_id'],))
            if inquiry.get('legacy_c_seq') is not None:
                cur.execute('UPDATE contact SET c_status=0 WHERE customer_customer_id=%s '
                            'AND head_office_id=%s AND c_seq=%s',
                            (email, inquiry['head_office_id'], seq))
        return db.query_one('SELECT message_id AS id,author_role AS authorRole,author_id AS authorId,content,'
                            'created_at AS createdAt,turn_index AS turnIndex FROM inquiry_message WHERE message_id=%s',
                            (message_id,))

    @staticmethod
    def _last_inquiry_message(cur, inquiry, seq):
        cur.execute('SELECT message_id,turn_index FROM inquiry_message WHERE customer_id=%s '
                    'AND head_office_id=%s AND c_seq=%s ORDER BY turn_index DESC,message_id DESC LIMIT 1 FOR UPDATE',
                    (inquiry['customer_id'], inquiry['head_office_id'], seq))
        return cur.fetchone()

    def reply_to_inquiry(self, customer_id, head_office_id, c_seq, answer, employee_id):
        """본사 답변을 대화 끝에 추가하고 구형 contact의 마지막 답변 필드도 동기화한다."""
        with self.transaction() as cur:
            cur.execute(
                'SELECT * FROM customer_support_inquiry WHERE customer_id=%s AND head_office_id=%s '
                'AND ((legacy_c_seq=%s AND legacy_c_seq IS NOT NULL) '
                'OR (inquiry_id=%s AND legacy_c_seq IS NULL)) FOR UPDATE',
                (customer_id, head_office_id, c_seq, c_seq))
            inquiry = cur.fetchone()
            if not inquiry:
                raise HTTPException(404, '문의를 찾을 수 없습니다.')
            seq = inquiry.get('legacy_c_seq') or inquiry['inquiry_id']
            last = self._last_inquiry_message(cur, inquiry, seq)
            if last is None:
                cur.execute('INSERT INTO inquiry_message '
                            '(customer_id,head_office_id,c_seq,turn_index,parent_message_id,author_role,author_id,content) '
                            'VALUES (%s,%s,%s,0,NULL,\'customer\',%s,%s)',
                            (customer_id, head_office_id, seq, customer_id, inquiry['content']))
                last = {'message_id': cur.lastrowid, 'turn_index': 0}
            cur.execute('INSERT INTO inquiry_message '
                        '(customer_id,head_office_id,c_seq,turn_index,parent_message_id,author_role,author_id,content) '
                        'VALUES (%s,%s,%s,%s,%s,\'employee\',%s,%s)',
                        (customer_id, head_office_id, seq, last['turn_index'] + 1,
                         last['message_id'], employee_id, answer))
            message_id = cur.lastrowid
            cur.execute('UPDATE customer_support_inquiry SET response=%s,responded_at=UTC_TIMESTAMP(),process=1 '
                        'WHERE inquiry_id=%s', (answer, inquiry['inquiry_id']))
            if inquiry.get('legacy_c_seq') is not None:
                cur.execute('UPDATE contact SET c_answer=%s,c_answerdate=UTC_TIMESTAMP(),c_status=1 '
                            'WHERE customer_customer_id=%s AND head_office_id=%s AND c_seq=%s',
                            (answer, customer_id, head_office_id, seq))
        return db.query_one('SELECT message_id AS id,author_role AS authorRole,author_id AS authorId,content,'
                            'created_at AS createdAt,turn_index AS turnIndex FROM inquiry_message WHERE message_id=%s',
                            (message_id,))

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
            cur.execute('INSERT INTO customer_support_inquiry '
                        '(customer_id,head_office_id,content,created_at,process) '
                        'VALUES (%s,%s,%s,UTC_TIMESTAMP(),0)', (email, office_id, data.content))
            contact_id = cur.lastrowid
            cur.execute('INSERT INTO inquiry_message '
                        '(customer_id,head_office_id,c_seq,turn_index,parent_message_id,author_role,author_id,content) '
                        'VALUES (%s,%s,%s,0,NULL,\'customer\',%s,%s)',
                        (email, office_id, contact_id, email, data.content))
        return self.contact(email, contact_id)


def get_commerce():
    # FastAPI Depends에서 MySQL 작업 객체를 주입하기 위한 공통 진입점이다.
    return Commerce()
