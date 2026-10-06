-- Mobile customer support inquiries. Keeps legacy `contact` rows and keys unchanged.
CREATE TABLE IF NOT EXISTS customer_support_inquiry (
    inquiry_id BIGINT NOT NULL AUTO_INCREMENT,
    customer_id VARCHAR(45) NOT NULL,
    head_office_id VARCHAR(45) NOT NULL,
    content TEXT NOT NULL,
    response TEXT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    responded_at DATETIME NULL,
    process TINYINT UNSIGNED NOT NULL DEFAULT 0,
    legacy_customer_id VARCHAR(45) NULL,
    legacy_head_office_id VARCHAR(45) NULL,
    legacy_c_seq INT NULL,
    PRIMARY KEY (inquiry_id),
    KEY idx_support_inquiry_customer (customer_id, created_at, inquiry_id),
    KEY idx_support_inquiry_office_process (head_office_id, process, created_at),
    UNIQUE KEY uq_support_inquiry_legacy_contact (legacy_customer_id, legacy_head_office_id, legacy_c_seq),
    CONSTRAINT fk_support_inquiry_customer
        FOREIGN KEY (customer_id) REFERENCES customer (customer_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_support_inquiry_head_office
        FOREIGN KEY (head_office_id) REFERENCES head_office (id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

-- 문의 원문·후속 고객 메시지·본사 답변을 한 줄 대화 체인으로 보존한다.
-- c_seq는 기존 contact.c_seq 또는 customer_support_inquiry.inquiry_id를 가리키는 업무 키다.
CREATE TABLE IF NOT EXISTS inquiry_message (
    message_id BIGINT NOT NULL AUTO_INCREMENT,
    customer_id VARCHAR(45) NOT NULL,
    head_office_id VARCHAR(45) NOT NULL,
    c_seq INT NOT NULL,
    turn_index INT NOT NULL,
    parent_message_id BIGINT NULL,
    author_role VARCHAR(10) NOT NULL,
    author_id VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (message_id),
    UNIQUE KEY uq_inquiry_turn (customer_id, head_office_id, c_seq, turn_index),
    UNIQUE KEY uq_inquiry_parent (parent_message_id),
    KEY idx_inquiry_message_thread (customer_id, head_office_id, c_seq, turn_index)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
