-- 주문(Order) 페이지 백엔드용 신규 테이블 (lib/order 화면 기준)
-- 장바구니 → 주문/결제 → 본사 준비·발송 → 매장 수령(QR) → 교환/반품 흐름을 저장한다.
-- customer_id 는 Firebase account 의 email 과 같은 값이다. (기존 customer 테이블과 동일)
-- 상품/대리점 정보는 주문 시점 값을 스냅샷으로 남겨, 이후 상품 수정·삭제와 무관하게 주문내역이 유지된다.
-- `order` 는 MySQL 예약어라 shop_order 를 사용한다.
-- 실행: python -m python.fastapi.order.init_tables  (이미 있으면 건너뜀)

CREATE TABLE IF NOT EXISTS cart_item (
    cart_item_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    customer_id  VARCHAR(45) NOT NULL,
    p_code       VARCHAR(45) NOT NULL,
    quantity     INT NOT NULL DEFAULT 1,
    selected     TINYINT(1) NOT NULL DEFAULT 1,
    added_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_cart_item (customer_id, p_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

-- 장바구니에서 선택한 수령 매장. 없으면 마이페이지 단골 매장(customer_setting.favorite_dealer_seq)을 쓴다.
CREATE TABLE IF NOT EXISTS cart_pickup (
    customer_id VARCHAR(45) NOT NULL PRIMARY KEY,
    dealer_seq  INT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

-- status: PAID / PREPARING / SHIPPING / INSPECTING / READY / PICKED_UP / CANCELLED
CREATE TABLE IF NOT EXISTS shop_order (
    order_number        VARCHAR(20) NOT NULL PRIMARY KEY,   -- FP260908-005
    customer_id         VARCHAR(45) NOT NULL,
    orderer_name        VARCHAR(45) NOT NULL,
    orderer_phone       VARCHAR(20) NOT NULL,
    dealer_seq          INT NOT NULL,
    store_name          VARCHAR(45) NOT NULL,
    store_address       VARCHAR(100) NOT NULL,
    payment_method      VARCHAR(20) NOT NULL,
    coupon_id           INT NULL,
    coupon_name         VARCHAR(45) NULL,
    subtotal            INT NOT NULL,
    discount            INT NOT NULL DEFAULT 0,
    paid_amount         INT NOT NULL,
    status              VARCHAR(12) NOT NULL DEFAULT 'PAID',
    ordered_at          DATETIME NOT NULL,
    status_changed_at   DATETIME NOT NULL,
    ready_at            DATETIME NULL,
    picked_up_at        DATETIME NULL,
    cancelled_at        DATETIME NULL,
    pickup_code         CHAR(6) NULL,                       -- 수령 인증용 일회성 번호
    pickup_code_expires DATETIME NULL,
    KEY idx_shop_order_customer (customer_id, ordered_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

CREATE TABLE IF NOT EXISTS shop_order_item (
    order_item_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    order_number  VARCHAR(20) NOT NULL,
    p_code        VARCHAR(45) NOT NULL,
    p_name        VARCHAR(100) NOT NULL,
    b_name        VARCHAR(45) NOT NULL,
    p_color       VARCHAR(100) NULL,
    p_size        INT NULL,
    unit_price    INT NOT NULL,
    quantity      INT NOT NULL,
    KEY idx_shop_order_item_order (order_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

-- claim_type: EXCHANGE / RETURN, status: RECEIVED(신청 접수) / CONFIRMED(본사 확인) / VISIT(방문) / DONE(완료) / REJECTED(반려)
CREATE TABLE IF NOT EXISTS order_claim (
    claim_id       INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    order_number   VARCHAR(20) NOT NULL,
    order_item_id  INT NOT NULL,
    customer_id    VARCHAR(45) NOT NULL,
    claim_type     VARCHAR(10) NOT NULL,
    reason         VARCHAR(45) NOT NULL,
    detail         VARCHAR(500) NOT NULL,
    requested_size INT NULL,                                -- 교환일 때만
    dealer_seq     INT NOT NULL,
    store_name     VARCHAR(45) NOT NULL,
    refund_amount  INT NOT NULL DEFAULT 0,                  -- 반품일 때만 (쿠폰 할인 비례 차감)
    status         VARCHAR(12) NOT NULL DEFAULT 'RECEIVED',
    requested_at   DATETIME NOT NULL,
    updated_at     DATETIME NOT NULL,
    KEY idx_order_claim_customer (customer_id, requested_at),
    KEY idx_order_claim_item (order_item_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

CREATE TABLE IF NOT EXISTS order_claim_photo (
    photo_id     INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    claim_id     INT NOT NULL,
    content_type VARCHAR(20) NOT NULL,
    image        MEDIUMBLOB NOT NULL,
    KEY idx_order_claim_photo_claim (claim_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
