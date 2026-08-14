-- Accounts & Finance -> Setup & Controls -> Opening Balances.
--
-- One row is one line of one import batch. The line references the records
-- other modules own (`chart_account`, `department`, `user`) instead of copying
-- them, and it is never hard-deleted: `deleted_at` keeps imported history
-- auditable after a batch is superseded.
--
-- Guarded with information_schema + PREPARE because the fleet spans MariaDB
-- builds without `CREATE INDEX IF NOT EXISTS`.

CREATE TABLE IF NOT EXISTS `opening_balance_entry` (
  `id` VARCHAR(36) NOT NULL,
  `human_friendly_id` VARCHAR(32) NULL,
  `tenant_id` VARCHAR(36) NOT NULL,
  `facility_id` VARCHAR(36) NULL,
  `batch_no` VARCHAR(64) NOT NULL,
  `effective_date` DATETIME(3) NOT NULL,
  `account_id` VARCHAR(36) NULL,
  `party_label` VARCHAR(160) NULL,
  `reference` VARCHAR(120) NULL,
  `description` VARCHAR(500) NULL,
  `debit` DECIMAL(18, 2) NOT NULL DEFAULT 0,
  `credit` DECIMAL(18, 2) NOT NULL DEFAULT 0,
  `currency` VARCHAR(10) NOT NULL,
  `department_id` VARCHAR(36) NULL,
  `source_file` VARCHAR(255) NULL,
  `validation_status` ENUM('PENDING', 'VALID', 'WARNING', 'INVALID') NOT NULL DEFAULT 'PENDING',
  `error_message` VARCHAR(500) NULL,
  `approved_by` VARCHAR(36) NULL,
  `approved_at` DATETIME(3) NULL,
  `journal_entry_no` VARCHAR(64) NULL,
  `posting_status` ENUM('NOT_POSTED', 'POSTED', 'FAILED', 'REVERSED') NOT NULL DEFAULT 'NOT_POSTED',
  `posted_at` DATETIME(3) NULL,
  `created_by` VARCHAR(36) NULL,
  `updated_by` VARCHAR(36) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  `deleted_at` DATETIME(3) NULL,
  `version` INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- The public reference is unique per tenant, so a deep link can never resolve
-- to two rows.
SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'opening_balance_entry'
    AND INDEX_NAME = 'opening_balance_entry_public_id_key'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE UNIQUE INDEX `opening_balance_entry_public_id_key` ON `opening_balance_entry`(`tenant_id`, `human_friendly_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'opening_balance_entry'
    AND INDEX_NAME = 'opening_balance_entry_tenant_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `opening_balance_entry_tenant_id_idx` ON `opening_balance_entry`(`tenant_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'opening_balance_entry'
    AND INDEX_NAME = 'opening_balance_entry_facility_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `opening_balance_entry_facility_id_idx` ON `opening_balance_entry`(`facility_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'opening_balance_entry'
    AND INDEX_NAME = 'opening_balance_entry_batch_no_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `opening_balance_entry_batch_no_idx` ON `opening_balance_entry`(`batch_no`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'opening_balance_entry'
    AND INDEX_NAME = 'opening_balance_entry_effective_date_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `opening_balance_entry_effective_date_idx` ON `opening_balance_entry`(`effective_date`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'opening_balance_entry'
    AND INDEX_NAME = 'opening_balance_entry_account_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `opening_balance_entry_account_id_idx` ON `opening_balance_entry`(`account_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'opening_balance_entry'
    AND INDEX_NAME = 'opening_balance_entry_department_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `opening_balance_entry_department_id_idx` ON `opening_balance_entry`(`department_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'opening_balance_entry'
    AND INDEX_NAME = 'opening_balance_entry_currency_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `opening_balance_entry_currency_idx` ON `opening_balance_entry`(`currency`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'opening_balance_entry'
    AND INDEX_NAME = 'opening_balance_entry_validation_status_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `opening_balance_entry_validation_status_idx` ON `opening_balance_entry`(`validation_status`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'opening_balance_entry'
    AND INDEX_NAME = 'opening_balance_entry_posting_status_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `opening_balance_entry_posting_status_idx` ON `opening_balance_entry`(`posting_status`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'opening_balance_entry'
    AND INDEX_NAME = 'opening_balance_entry_journal_entry_no_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `opening_balance_entry_journal_entry_no_idx` ON `opening_balance_entry`(`journal_entry_no`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'opening_balance_entry'
    AND INDEX_NAME = 'opening_balance_entry_deleted_at_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `opening_balance_entry_deleted_at_idx` ON `opening_balance_entry`(`deleted_at`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'opening_balance_entry'
    AND INDEX_NAME = 'opening_balance_entry_human_friendly_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `opening_balance_entry_human_friendly_id_idx` ON `opening_balance_entry`(`human_friendly_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
