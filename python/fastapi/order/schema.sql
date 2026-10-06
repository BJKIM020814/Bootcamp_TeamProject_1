-- 주문 원본은 초기 ERD의 purchase 테이블이다.
-- purchase/contact 확장과 기존 구매 주문 이관은 restore_legacy_commerce_schema.sql을 사용한다.
-- 이 파일은 주문 상품 행(purchase.purchase_id)에 종속되는 교환/반품 기능의 보조 테이블만 정의한다.

CREATE TABLE IF NOT EXISTS order_claim (
    claim_id BIGINT NOT NULL AUTO_INCREMENT,
    order_code VARCHAR(21) NOT NULL,
    order_item_id BIGINT NOT NULL,
    customer_id VARCHAR(45) NOT NULL,
    claim_type VARCHAR(10) NOT NULL,
    reason VARCHAR(45) NOT NULL,
    detail VARCHAR(500) NOT NULL,
    requested_size INT NULL,
    dealer_seq INT NOT NULL,
    store_name VARCHAR(45) NOT NULL,
    refund_amount INT NOT NULL DEFAULT 0,
    status VARCHAR(12) NOT NULL DEFAULT 'RECEIVED',
    requested_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (claim_id),
    KEY idx_order_claim_customer (customer_id, requested_at),
    KEY idx_order_claim_item (order_item_id),
    CONSTRAINT fk_order_claim_item
        FOREIGN KEY (order_item_id) REFERENCES purchase (purchase_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_order_claim_dealer
        FOREIGN KEY (dealer_seq) REFERENCES authorized_dealer (seq)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

CREATE TABLE IF NOT EXISTS order_claim_photo (
    photo_id BIGINT NOT NULL AUTO_INCREMENT,
    claim_id BIGINT NOT NULL,
    content_type VARCHAR(20) NOT NULL,
    image MEDIUMBLOB NOT NULL,
    PRIMARY KEY (photo_id),
    KEY idx_order_claim_photo_claim (claim_id),
    CONSTRAINT fk_order_claim_photo_claim
        FOREIGN KEY (claim_id) REFERENCES order_claim (claim_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
