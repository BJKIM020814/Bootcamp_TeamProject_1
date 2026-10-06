# 기존 MySQL 확인 및 필요한 확장

스크린샷보다 현재 `python/user_data.py`, `python/shoes_data.py`의 컬럼명을 우선했다.
실제 DDL 파일이 저장소에 없으므로 운영 DB에 아래 SQL을 자동 실행하지 않는다.
먼저 `python -m python.fastapi.check_schema`와 `SHOW CREATE TABLE review; SHOW CREATE TABLE contact;`
로 기존 구조를 읽기 전용으로 확인한다. 고객 문의는 레거시 `contact`를 변경하지 않고 별도 테이블을 사용한다.

- 연결 키: `Firebase account.email = customer.customer_id` (기존 코드에서는 문자열 이메일).
- 상품 키: `product.p_code = review.product_p_code = purchase.p_code`.
- 기존 코드와 달리 구매 테이블이 `product_product_id` 등으로 되어 있다면 `commerce.py`의 두 구매 쿼리를 실제 키에 맞춰 변경해야 한다.
- `review.review_seq`는 단독 UNIQUE 또는 PRIMARY KEY인 INT AUTO_INCREMENT여야 한다.
- `review.context`는 VARCHAR(2000) 이상, `review.r_fit`은 한글 3글자 이상, `rating`은 숫자여야 한다.
- 고객 문의는 `customer_support_inquiry`, 연속 문의·답변은 `inquiry_message`가 담당한다. `inquiry_message.parent_message_id`가 직전 메시지를 연결한다.
- 문의 테이블 DDL: [`support_inquiry.sql`](support_inquiry.sql). 기존 레거시 `contact` 데이터/키는 변경하지 않는다.
- 시간은 UTC로 저장한다. 기존 데이터가 한국시간이면 별도 변환을 결정해야 한다.
- customer/product/purchase/review/contact는 InnoDB 및 utf8mb4여야 한다.
- `SUPPORT_HEAD_OFFICE_ID`는 `head_office.id` 값이며, 비어 있으면 유일한 `고객지원본부` 행을 사용한다.

다음은 조건별 변경 **예시**다. 같은 컬럼/인덱스가 이미 있으면 재실행하면 안 된다.

```sql
-- review_seq가 이미 단독 UNIQUE 키일 때만
ALTER TABLE review MODIFY review_seq INT NOT NULL AUTO_INCREMENT;
-- review_seq에 단독 키가 없고 기존 값이 전체 테이블에서 중복되지 않을 때만
-- ALTER TABLE review ADD UNIQUE KEY uq_review_seq (review_seq);
-- ALTER TABLE review MODIFY review_seq INT NOT NULL AUTO_INCREMENT;
ALTER TABLE review MODIFY context VARCHAR(2000) NOT NULL;
```

중복 리뷰 방지는 API가 `customer` 행을 FOR UPDATE 잠근 트랜잭션 안에서 처리한다.
외부 시스템도 리뷰를 생성하면 DB의 `(customer_customer_id, product_p_code)` UNIQUE 인덱스를
추가하는 것이 필요하다. 기존 중복 리뷰부터 확인하고 정리한 후 적용한다.
