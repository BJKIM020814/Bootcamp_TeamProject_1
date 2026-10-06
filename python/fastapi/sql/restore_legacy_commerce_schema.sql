-- FITPICK canonical legacy tables migration (MySQL 8).
-- Run once after backup and review. It alters purchase/contact/review in place; it does not drop data.
-- It migrates currently-created purchase_order rows into purchase. It does NOT drop those newer
-- tables, so rollback/audit remains possible until the team explicitly approves cleanup.

USE shoes;

-- Preflight: verify there are no incoming foreign keys before changing the two primary keys.
SELECT TABLE_NAME, COLUMN_NAME, CONSTRAINT_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE REFERENCED_TABLE_SCHEMA = DATABASE()
  AND REFERENCED_TABLE_NAME IN ('purchase', 'contact');

-- Review preflight: review_seq must contain unique, non-null values before becoming the row key.
-- Resolve any rows returned by the duplicate query before proceeding; no review rows are deleted here.
SELECT review_seq, COUNT(*) AS duplicate_count
FROM review
GROUP BY review_seq
HAVING review_seq IS NULL OR COUNT(*) > 1;

-- Existing purchase key (customer, head office) allows one row only. Give each purchase line its
-- own key and retain the original customer/head-office/product columns and rows.
ALTER TABLE purchase
    ADD COLUMN purchase_id BIGINT NOT NULL AUTO_INCREMENT FIRST,
    ADD COLUMN order_code VARCHAR(21) NULL AFTER purchase_id,
    ADD COLUMN quantity INT NOT NULL DEFAULT 1 AFTER p_price,
    ADD COLUMN order_status VARCHAR(20) NOT NULL DEFAULT 'PICKED_UP' AFTER quantity,
    ADD COLUMN orderer_name VARCHAR(45) NOT NULL DEFAULT '' AFTER order_status,
    ADD COLUMN orderer_phone VARCHAR(20) NOT NULL DEFAULT '' AFTER orderer_name,
    ADD COLUMN dealer_seq INT NULL AFTER orderer_phone,
    ADD COLUMN store_name VARCHAR(45) NOT NULL DEFAULT '' AFTER dealer_seq,
    ADD COLUMN store_address VARCHAR(255) NOT NULL DEFAULT '' AFTER store_name,
    ADD COLUMN payment_method VARCHAR(45) NOT NULL DEFAULT '기존 구매' AFTER store_address,
    ADD COLUMN coupon_id INT NULL AFTER payment_method,
    ADD COLUMN coupon_name VARCHAR(100) NULL AFTER coupon_id,
    ADD COLUMN subtotal INT NOT NULL DEFAULT 0 AFTER coupon_name,
    ADD COLUMN discount INT NOT NULL DEFAULT 0 AFTER subtotal,
    ADD COLUMN order_total INT NOT NULL DEFAULT 0 AFTER discount,
    ADD COLUMN status_changed_at DATETIME NULL AFTER order_total,
    ADD COLUMN ready_at DATETIME NULL AFTER status_changed_at,
    ADD COLUMN picked_up_at DATETIME NULL AFTER ready_at,
    ADD COLUMN cancelled_at DATETIME NULL AFTER picked_up_at,
    ADD COLUMN pickup_code CHAR(6) NULL AFTER cancelled_at,
    ADD COLUMN pickup_code_expires DATETIME NULL AFTER pickup_code,
    DROP PRIMARY KEY,
    ADD PRIMARY KEY (purchase_id),
    ADD KEY idx_purchase_customer_date (customer_customer_id, p_date, purchase_id),
    ADD KEY idx_purchase_order_code (order_code),
    ADD KEY idx_purchase_dealer_status (dealer_seq, order_status);

-- Backfill old purchase rows as completed, one-line legacy orders; preserve their original values.
UPDATE purchase
SET order_code = CONCAT('L', LPAD(purchase_id, 20, '0')),
    subtotal = p_price,
    order_total = p_price,
    status_changed_at = p_date,
    picked_up_at = p_date
WHERE order_code IS NULL;

ALTER TABLE purchase MODIFY COLUMN order_code VARCHAR(21) NOT NULL;

-- Import orders made by the interim purchase_order implementation into the original purchase table.
-- The order code is the idempotency key; each original product row becomes one purchase line.
INSERT INTO purchase
    (order_code, customer_customer_id, head_office_id, p_code, p_date, p_price, quantity, order_status,
     orderer_name, orderer_phone, dealer_seq, store_name, store_address, payment_method, coupon_id,
     coupon_name, subtotal, discount, order_total, status_changed_at, ready_at, picked_up_at,
     cancelled_at, pickup_code, pickup_code_expires)
SELECT d.order_code, po.customer_id, po.head_office_id, oi.p_code, po.ordered_at, oi.unit_price,
       oi.quantity, po.status, d.orderer_name, d.orderer_phone, d.dealer_seq, d.store_name, d.store_address,
       d.payment_method, d.coupon_id, d.coupon_name, d.subtotal, d.discount, po.total_amount,
       d.status_changed_at, d.ready_at, d.picked_up_at, d.cancelled_at, d.pickup_code, d.pickup_code_expires
FROM purchase_order po
JOIN purchase_order_detail d ON d.order_id = po.order_id
JOIN purchase_order_item oi ON oi.order_id = po.order_id
WHERE NOT EXISTS (
    SELECT 1 FROM purchase p WHERE p.order_code = d.order_code AND p.p_code = oi.p_code
);

-- Existing claims pointed at the interim purchase_order_item rows. Repoint them to each canonical
-- purchase line before the API starts treating purchase.purchase_id as order_item_id.
SET @claim_item_fk = (
    SELECT CONSTRAINT_NAME FROM information_schema.KEY_COLUMN_USAGE
    WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='order_claim'
      AND COLUMN_NAME='order_item_id' AND REFERENCED_TABLE_NAME='purchase_order_item'
    LIMIT 1
);
SET @drop_claim_fk = IF(@claim_item_fk IS NULL, 'SELECT 1',
    CONCAT('ALTER TABLE order_claim DROP FOREIGN KEY `', REPLACE(@claim_item_fk, '`', '``'), '`'));
PREPARE drop_claim_fk_stmt FROM @drop_claim_fk;
EXECUTE drop_claim_fk_stmt;
DEALLOCATE PREPARE drop_claim_fk_stmt;

SET @claim_migration_sql = IF(
    (SELECT COUNT(*) FROM information_schema.TABLES
     WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='order_claim') = 1,
    'UPDATE order_claim c JOIN purchase_order_detail d ON d.order_code=c.order_code '
    'JOIN purchase_order_item oi ON oi.order_id=d.order_id AND oi.order_item_id=c.order_item_id '
    'JOIN purchase p ON p.order_code=d.order_code AND p.p_code=oi.p_code '
    'SET c.order_item_id=p.purchase_id',
    'SELECT 1'
);
PREPARE migrate_claims_stmt FROM @claim_migration_sql;
EXECUTE migrate_claims_stmt;
DEALLOCATE PREPARE migrate_claims_stmt;

-- Install a new FK only when the claim table exists in this project database.
SET @claim_table_exists = (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='order_claim');
SET @add_claim_fk = IF(@claim_table_exists=0, 'SELECT 1',
    CONCAT('ALTER TABLE order_claim ADD CONSTRAINT fk_order_claim_purchase_line ',
    'FOREIGN KEY (order_item_id) REFERENCES purchase (purchase_id) ON UPDATE CASCADE ON DELETE RESTRICT'));
PREPARE add_claim_fk_stmt FROM @add_claim_fk;
EXECUTE add_claim_fk_stmt;
DEALLOCATE PREPARE add_claim_fk_stmt;

-- contact already holds inquiry identity and reply summary. Widen its original text fields and give
-- each message a c_seq so repeated inquiries and unlimited replies can coexist without a new table.
ALTER TABLE contact
    MODIFY COLUMN c_seq INT NOT NULL AUTO_INCREMENT,
    MODIFY COLUMN contact_post TEXT NOT NULL,
    MODIFY COLUMN c_answer TEXT NOT NULL,
    ADD COLUMN thread_root_seq INT NULL AFTER c_seq,
    ADD COLUMN parent_c_seq INT NULL AFTER thread_root_seq,
    ADD COLUMN author_role VARCHAR(10) NOT NULL DEFAULT 'customer' AFTER parent_c_seq,
    ADD COLUMN author_id VARCHAR(255) NOT NULL DEFAULT '' AFTER author_role,
    ADD COLUMN source_inquiry_id BIGINT NULL AFTER author_id,
    ADD COLUMN source_message_id BIGINT NULL AFTER source_inquiry_id,
    DROP PRIMARY KEY,
    ADD PRIMARY KEY (c_seq),
    ADD KEY idx_contact_owner_thread (customer_customer_id, head_office_id, thread_root_seq, c_seq),
    ADD KEY idx_contact_parent (parent_c_seq),
    ADD UNIQUE KEY uq_contact_source_inquiry (source_inquiry_id),
    ADD UNIQUE KEY uq_contact_source_message (source_message_id);

-- Existing contact rows are each treated as a root thread, retaining c_seq and all original values.
UPDATE contact
SET thread_root_seq = c_seq,
    parent_c_seq = NULL,
    author_role = 'customer',
    author_id = customer_customer_id
WHERE thread_root_seq IS NULL;

ALTER TABLE contact MODIFY COLUMN thread_root_seq INT NOT NULL;

-- Keep old mobile inquiry IDs addressable without duplicating records already copied from contact.
UPDATE contact c
JOIN customer_support_inquiry i
  ON i.customer_id=c.customer_customer_id AND i.head_office_id=c.head_office_id
 AND i.legacy_c_seq=c.c_seq
SET c.source_inquiry_id=i.inquiry_id
WHERE c.source_inquiry_id IS NULL;

-- Migrate only interim inquiries that do not already map to an original contact row.
INSERT INTO contact
    (customer_customer_id,head_office_id,thread_root_seq,parent_c_seq,author_role,author_id,
     contact_post,c_date,c_answer,c_answerdate,c_status,comment_seq,level,source_inquiry_id)
SELECT i.customer_id,i.head_office_id,0,NULL,'customer',i.customer_id,
       i.content,i.created_at,COALESCE(i.response,''),COALESCE(i.responded_at,i.created_at),i.process,0,0,i.inquiry_id
FROM customer_support_inquiry i
WHERE NOT EXISTS (SELECT 1 FROM contact c WHERE c.source_inquiry_id=i.inquiry_id);

UPDATE contact SET thread_root_seq=c_seq
WHERE thread_root_seq=0 AND parent_c_seq IS NULL;

-- Migrate interim threaded messages into contact rows, preserving source IDs for idempotence/audit.
-- The interim API's turn 0 repeats the inquiry body, so map it to the root instead of duplicating it.
UPDATE contact root
JOIN customer_support_inquiry i ON i.inquiry_id=root.source_inquiry_id
JOIN inquiry_message first_message
  ON first_message.customer_id=i.customer_id AND first_message.head_office_id=i.head_office_id
 AND first_message.c_seq=COALESCE(i.legacy_c_seq,i.inquiry_id)
 AND first_message.turn_index=0 AND first_message.author_role='customer'
SET root.source_message_id=first_message.message_id
WHERE root.thread_root_seq=root.c_seq AND root.source_message_id IS NULL;

INSERT INTO contact
    (customer_customer_id,head_office_id,thread_root_seq,parent_c_seq,author_role,author_id,
     contact_post,c_date,c_answer,c_answerdate,c_status,comment_seq,level,source_message_id)
SELECT m.customer_id,m.head_office_id,root.c_seq,root.c_seq,m.author_role,m.author_id,
       m.content,m.created_at,'',m.created_at,0,0,0,m.message_id
FROM inquiry_message m
JOIN customer_support_inquiry i
  ON i.customer_id=m.customer_id AND i.head_office_id=m.head_office_id
 AND COALESCE(i.legacy_c_seq,i.inquiry_id)=m.c_seq
JOIN contact root ON root.source_inquiry_id=i.inquiry_id AND root.thread_root_seq=root.c_seq
WHERE m.turn_index>0
  AND NOT EXISTS (SELECT 1 FROM contact c WHERE c.source_message_id=m.message_id)
ORDER BY m.turn_index,m.message_id;

-- Restore each message's explicit previous-message pointer after all message IDs are mapped.
UPDATE contact child
JOIN inquiry_message m ON m.message_id=child.source_message_id
JOIN contact parent ON parent.source_message_id=m.parent_message_id
SET child.parent_c_seq=parent.c_seq
WHERE child.source_message_id IS NOT NULL;

-- The legacy review table's composite primary key is not compatible with the API's review ID.
-- Promote the existing review_seq values without changing review contents, while preserving the
-- one-review-per-customer-and-product uniqueness rule.
ALTER TABLE review
    DROP PRIMARY KEY,
    ADD PRIMARY KEY (review_seq),
    MODIFY COLUMN review_seq INT NOT NULL AUTO_INCREMENT,
    MODIFY COLUMN context VARCHAR(2000) NOT NULL,
    ADD UNIQUE KEY uq_review_customer_product (customer_customer_id, product_p_code);

-- After API/PAD validation, keep these interim tables for a release cycle and compare row counts.
-- Do not DROP purchase_order, purchase_order_detail, purchase_order_item,
-- customer_support_inquiry, or inquiry_message in this migration.

-- Verify canonical rows and uniqueness after migration.
SELECT COUNT(*) AS purchase_lines, COUNT(DISTINCT order_code) AS orders FROM purchase;
SELECT COUNT(*) AS inquiry_messages, COUNT(DISTINCT thread_root_seq) AS inquiry_threads FROM contact;
