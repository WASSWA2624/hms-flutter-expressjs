-- Document numbering policy for Accounts & Finance → Setup & Controls
--
-- Configuration only. The running counter stays in `human_id_counter`; the
-- service derives next / last issued numbers from it so numbering keeps one
-- source of truth.

CREATE TABLE IF NOT EXISTS `document_number_sequence` (
  `id` VARCHAR(36) NOT NULL,
  `human_friendly_id` VARCHAR(32) NULL,
  `tenant_id` VARCHAR(36) NOT NULL,
  `facility_id` VARCHAR(36) NULL,
  `sequence_code` VARCHAR(32) NOT NULL,
  `document_type` ENUM(
    'INVOICE',
    'ACCOUNTS_INVOICE',
    'RECEIPT',
    'PAYMENT',
    'REFUND',
    'CREDIT_NOTE',
    'DEBIT_NOTE',
    'PURCHASE_ORDER',
    'GOODS_RECEIPT',
    'CLAIM'
  ) NOT NULL,
  `module` VARCHAR(32) NOT NULL DEFAULT 'ALL',
  `counter_model` VARCHAR(80) NOT NULL,
  `prefix` VARCHAR(16) NOT NULL,
  `suffix` VARCHAR(16) NULL,
  `date_pattern` VARCHAR(32) NULL,
  `minimum_length` INTEGER NOT NULL DEFAULT 7,
  `reset_frequency` ENUM('NEVER', 'DAILY', 'MONTHLY', 'QUARTERLY', 'YEARLY') NOT NULL DEFAULT 'NEVER',
  `gap_policy` ENUM('ALLOW_GAPS', 'NO_GAPS', 'RESERVE_AND_VOID') NOT NULL DEFAULT 'ALLOW_GAPS',
  `status` ENUM('DRAFT', 'ACTIVE', 'INACTIVE', 'ARCHIVED') NOT NULL DEFAULT 'DRAFT',
  `notes` VARCHAR(500) NULL,
  `created_by` VARCHAR(36) NULL,
  `updated_by` VARCHAR(36) NULL,
  `archived_at` DATETIME(3) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  `deleted_at` DATETIME(3) NULL,
  `version` INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB;

-- One admin-visible code per tenant.
SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'document_number_sequence'
    AND INDEX_NAME = 'document_number_sequence_code_key'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE UNIQUE INDEX `document_number_sequence_code_key` ON `document_number_sequence`(`tenant_id`, `sequence_code`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- One sequence per tenant + facility + document type + module.
-- MariaDB 10.4 has no functional unique indexes, so a NULL facility_id follows
-- InnoDB NULL semantics (multiple NULLs allowed); the service guards that case.
SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'document_number_sequence'
    AND INDEX_NAME = 'document_number_sequence_scope_key'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE UNIQUE INDEX `document_number_sequence_scope_key` ON `document_number_sequence`(`tenant_id`, `facility_id`, `document_type`, `module`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'document_number_sequence'
    AND INDEX_NAME = 'document_number_sequence_tenant_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `document_number_sequence_tenant_id_idx` ON `document_number_sequence`(`tenant_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'document_number_sequence'
    AND INDEX_NAME = 'document_number_sequence_facility_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `document_number_sequence_facility_id_idx` ON `document_number_sequence`(`facility_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'document_number_sequence'
    AND INDEX_NAME = 'document_number_sequence_document_type_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `document_number_sequence_document_type_idx` ON `document_number_sequence`(`document_type`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'document_number_sequence'
    AND INDEX_NAME = 'document_number_sequence_status_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `document_number_sequence_status_idx` ON `document_number_sequence`(`status`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'document_number_sequence'
    AND INDEX_NAME = 'document_number_sequence_module_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `document_number_sequence_module_idx` ON `document_number_sequence`(`module`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'document_number_sequence'
    AND INDEX_NAME = 'document_number_sequence_deleted_at_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `document_number_sequence_deleted_at_idx` ON `document_number_sequence`(`deleted_at`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'document_number_sequence'
    AND INDEX_NAME = 'document_number_sequence_human_friendly_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `document_number_sequence_human_friendly_id_idx` ON `document_number_sequence`(`human_friendly_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'document_number_sequence'
    AND CONSTRAINT_NAME = 'document_number_sequence_tenant_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `document_number_sequence` ADD CONSTRAINT `document_number_sequence_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'document_number_sequence'
    AND CONSTRAINT_NAME = 'document_number_sequence_facility_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `document_number_sequence` ADD CONSTRAINT `document_number_sequence_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
