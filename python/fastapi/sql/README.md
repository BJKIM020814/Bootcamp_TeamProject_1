# 기존 MySQL 확인 및 필요한 확장

스크린샷보다 현재 `python/user_data.py`, `python/shoes_data.py`의 컬럼명을 우선했다.
실제 DDL 파일이 저장소에 없으므로 운영 DB에 아래 SQL을 자동 실행하지 않는다.
먼저 데이터베이스 백업 후 `python -m python.fastapi.check_schema`와 `SHOW CREATE TABLE purchase; SHOW CREATE TABLE contact;`
로 기존 구조를 읽기 전용으로 확인한다. 주문·문의 원본은 초기 ERD의 `purchase`와 `contact`이며
`python/fastapi/sql/restore_legacy_commerce_schema.sql`을 검토해 기존 테이블을 확장한다.

- 연결 키: `Firebase account.email = customer.customer_id` (기존 코드에서는 문자열 이메일).
- 상품 키: `product.p_code = review.product_p_code = purchase.p_code`.
- 기존 코드와 달리 구매 테이블이 `product_product_id` 등으로 되어 있다면 `commerce.py`의 두 구매 쿼리를 실제 키에 맞춰 변경해야 한다.
- `review.review_seq`는 단독 UNIQUE 또는 PRIMARY KEY인 INT AUTO_INCREMENT여야 한다.
- `review.context`는 VARCHAR(2000) 이상, `review.r_fit`은 한글 3글자 이상, `rating`은 숫자여야 한다.
- 주문 헤더/상품행은 `purchase.order_code`로 묶으며 `purchase.purchase_id`는 상품행 키다.
- 문의 원문·후속 메시지·답변은 모두 `contact`에 저장하며 `thread_root_seq`와 `parent_c_seq`가 대화를 연결한다.
- 기존 `purchase_order*`, `customer_support_inquiry`, `inquiry_message` 테이블은 이관 검증 기간 동안 보존하며 새 코드에서는 쓰지 않는다.
- 시간은 UTC로 저장한다. 기존 데이터가 한국시간이면 별도 변환을 결정해야 한다.
- customer/product/purchase/review/contact는 InnoDB 및 utf8mb4여야 한다.
- `SUPPORT_HEAD_OFFICE_ID`는 `head_office.id` 값이며, 비어 있으면 유일한 `고객지원본부` 행을 사용한다.

이 프로젝트에서 확인한 기존 구조를 보완하는 전체 마이그레이션은
[`restore_legacy_commerce_schema.sql`](restore_legacy_commerce_schema.sql)이다. 이 스크립트는 초기 ERD의
`purchase`, `contact`, `review`를 확장하고, 중간 구현 테이블의 주문/문의 데이터를 원본 테이블로 옮기며
중간 테이블은 삭제하지 않는다. 기존 행을 삭제하지는 않지만 PK/FK 구조를 변경하므로 백업 후 1회 실행한다.
먼저 `USE shoes`가 맞는지 확인하고, 스크립트 첫 사전 점검의 참조 FK 목록과
`review.review_seq` 중복 목록이 비어 있는지 확인한다. 중복 목록이 나오면 적용을 중단하고 먼저 원인을
확인한다. 현재 DB에 직접 연결할 수 없는 경우 이 스크립트를 실행했다고 간주하면 안 된다.

API 스키마 오류 응답은 각 누락 컬럼·자동 증가·문자열 최대 길이를 `missing_requirements`로 반환하며,
화면에 보이는 `message`에도 첫 문제와 실행할 SQL 경로를 포함한다.

중복 리뷰 방지는 API가 `customer` 행을 FOR UPDATE 잠근 트랜잭션 안에서 처리한다.
외부 시스템도 리뷰를 생성하면 DB의 `(customer_customer_id, product_p_code)` UNIQUE 인덱스를
추가하는 것이 필요하다. 기존 중복 리뷰부터 확인하고 정리한 후 적용한다.
