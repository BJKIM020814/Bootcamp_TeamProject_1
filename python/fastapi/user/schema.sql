-- 마이페이지(MY FITPICK) 백엔드용 신규 테이블
-- 이름/전화번호/비밀번호는 Firebase account 가 관리하므로 여기에 두지 않는다.
-- customer_id 는 Firebase account 의 email 과 같은 값이다. (기존 customer 테이블과 동일)
-- 기존 테이블과 조인되므로 charset/collation 을 customer/product 와 동일하게 맞춘다.
-- 실행: python init_tables.py  (이미 있으면 건너뜀)

CREATE TABLE IF NOT EXISTS customer_setting (
    customer_id        VARCHAR(45) NOT NULL PRIMARY KEY,
    shoe_size          INT NOT NULL DEFAULT 270,
    default_payment    VARCHAR(20) NOT NULL DEFAULT '신용 / 체크카드',
    favorite_dealer_seq INT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

CREATE TABLE IF NOT EXISTS wishlist (
    customer_id VARCHAR(45) NOT NULL,
    p_code      VARCHAR(45) NOT NULL,
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (customer_id, p_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

CREATE TABLE IF NOT EXISTS recently_viewed (
    customer_id VARCHAR(45) NOT NULL,
    p_code      VARCHAR(45) NOT NULL,
    viewed_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (customer_id, p_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

-- 쿠폰 종류. condition_type: SIGNUP(가입 시 발급) / FIRST_REVIEW(첫 리뷰 후 발급) / EVENT(행사 기간 발급)
CREATE TABLE IF NOT EXISTS coupon (
    coupon_id      INT NOT NULL PRIMARY KEY,
    name           VARCHAR(45) NOT NULL,
    discount_type  VARCHAR(10) NOT NULL,          -- PERCENT / AMOUNT
    discount_value INT NOT NULL,
    description    VARCHAR(100) NOT NULL,
    condition_type VARCHAR(12) NOT NULL,
    valid_days     INT NULL,                      -- 발급일로부터 유효일수 (SIGNUP, FIRST_REVIEW)
    event_start    DATETIME NULL,                 -- EVENT 기간
    event_end      DATETIME NULL,
    locked_badge   VARCHAR(45) NOT NULL           -- 아직 못 받았을 때 표시할 문구
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

-- 회원에게 발급된 쿠폰. used_at 이 NULL 이고 expires_at 이 지나지 않았으면 사용 가능.
CREATE TABLE IF NOT EXISTS customer_coupon (
    customer_id VARCHAR(45) NOT NULL,
    coupon_id   INT NOT NULL,
    issued_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at  DATETIME NOT NULL,
    used_at     DATETIME NULL,
    PRIMARY KEY (customer_id, coupon_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

INSERT IGNORE INTO coupon (coupon_id, name, discount_type, discount_value, description, condition_type, valid_days, event_start, event_end, locked_badge) VALUES
 (1, '회원가입 10%', 'PERCENT', 10, '신규 회원 웰컴 쿠폰', 'SIGNUP', 30, NULL, NULL, '가입 시 발급'),
 (2, '첫 리뷰 ₩10,000', 'AMOUNT', 10000, '첫 구매 리뷰 저장 후 발급', 'FIRST_REVIEW', 30, NULL, NULL, '첫 리뷰 작성 후 사용 가능'),
 (3, '가을 행사 30%', 'PERCENT', 30, '가을 행사 한정 쿠폰', 'EVENT', NULL, '2026-09-20 00:00:00', '2026-10-15 23:59:59', '행사 기간 한정');
