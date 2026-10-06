-- 주문 기능 확장 스키마.
-- 기존 purchase_order / purchase_order_item 은 주문의 기준 테이블로 그대로 사용한다.
-- 이 스크립트는 기존 데이터를 삭제하거나 기존 컬럼을 변경하지 않는다.

-- purchase_order에 없는 주문자·수령점·결제·쿠폰·QR 메타데이터를 보관한다.
CREATE TABLE IF NOT EXISTS purchase_order_detail (
    order_id BIGINT NOT NULL,
    order_code VARCHAR(21) NOT NULL,
    orderer_name VARCHAR(45) NOT NULL,
    orderer_phone VARCHAR(20) NOT NULL,
    dealer_seq INT NOT NULL,
    store_name VARCHAR(45) NOT NULL,
    store_address VARCHAR(100) NOT NULL,
    payment_method VARCHAR(20) NOT NULL,
    coupon_id INT NULL,
    coupon_name VARCHAR(45) NULL,
    subtotal INT NOT NULL,
    discount INT NOT NULL DEFAULT 0,
    status_changed_at DATETIME NOT NULL,
    ready_at DATETIME NULL,
    picked_up_at DATETIME NULL,
    cancelled_at DATETIME NULL,
    pickup_code CHAR(6) NULL,
    pickup_code_expires DATETIME NULL,
    PRIMARY KEY (order_id),
    UNIQUE KEY uq_purchase_order_detail_code (order_code),
    KEY idx_purchase_order_detail_dealer (dealer_seq),
    CONSTRAINT fk_purchase_order_detail_order
        FOREIGN KEY (order_id) REFERENCES purchase_order (order_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_purchase_order_detail_dealer
        FOREIGN KEY (dealer_seq) REFERENCES authorized_dealer (seq)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

-- 교환/반품 신청은 주문상품 ID(purchase_order_item.order_item_id)를 연결한다.
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
        FOREIGN KEY (order_item_id) REFERENCES purchase_order_item (order_item_id)
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
