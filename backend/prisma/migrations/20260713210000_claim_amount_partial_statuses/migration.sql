-- Claim amounts from insurer share + partial statuses + insurer auth reference

-- Expand claim status enum
ALTER TABLE `insurance_claim` MODIFY COLUMN `status` ENUM('SUBMITTED', 'APPROVED', 'PARTIAL', 'REJECTED', 'PAID', 'CANCELLED') NOT NULL;

-- Expand authorization status enum
ALTER TABLE `pre_authorization` MODIFY COLUMN `status` ENUM('PENDING', 'APPROVED', 'PARTIAL', 'DENIED', 'EXPIRED', 'CANCELLED') NOT NULL;

-- insurance_claim.claim_amount + insurance_company_id
SET @col_exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'insurance_claim'
    AND COLUMN_NAME = 'claim_amount'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE `insurance_claim` ADD COLUMN `claim_amount` DECIMAL(12, 2) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'insurance_claim'
    AND COLUMN_NAME = 'insurance_company_id'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE `insurance_claim` ADD COLUMN `insurance_company_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'insurance_claim'
    AND INDEX_NAME = 'insurance_claim_insurance_company_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `insurance_claim_insurance_company_id_idx` ON `insurance_claim`(`insurance_company_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'insurance_claim'
    AND CONSTRAINT_NAME = 'insurance_claim_insurance_company_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `insurance_claim` ADD CONSTRAINT `insurance_claim_insurance_company_id_fkey` FOREIGN KEY (`insurance_company_id`) REFERENCES `insurance_company`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Backfill claim company + amount from invoice insurer shares
UPDATE insurance_claim ic
LEFT JOIN coverage_plan cp ON cp.id = ic.coverage_plan_id
SET ic.insurance_company_id = COALESCE(ic.insurance_company_id, cp.insurance_company_id)
WHERE ic.deleted_at IS NULL
  AND ic.insurance_company_id IS NULL
  AND cp.insurance_company_id IS NOT NULL;

UPDATE insurance_claim ic
SET ic.claim_amount = (
  SELECT COALESCE(SUM(ii.insurer_share), 0)
  FROM invoice_item ii
  WHERE ii.invoice_id = ic.invoice_id
    AND ii.deleted_at IS NULL
    AND ii.insurer_share IS NOT NULL
)
WHERE ic.deleted_at IS NULL
  AND ic.claim_amount IS NULL;

-- pre_authorization.insurer_reference
SET @col_exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'pre_authorization'
    AND COLUMN_NAME = 'insurer_reference'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE `pre_authorization` ADD COLUMN `insurer_reference` VARCHAR(120) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
