-- Chart of accounts (GL account codes) for Accounts workspace

CREATE TABLE IF NOT EXISTS `chart_account` (
  `id` VARCHAR(36) NOT NULL,
  `human_friendly_id` VARCHAR(32) NULL,
  `tenant_id` VARCHAR(36) NOT NULL,
  `facility_id` VARCHAR(36) NULL,
  `code` VARCHAR(64) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `account_type` ENUM('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE') NOT NULL,
  `parent_id` VARCHAR(36) NULL,
  `currency` VARCHAR(10) NOT NULL,
  `effective_from` DATETIME(3) NULL,
  `is_active` BOOLEAN NOT NULL DEFAULT true,
  `notes` VARCHAR(255) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  `deleted_at` DATETIME(3) NULL,
  `version` INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Unique per tenant + facility + code.
-- MariaDB 10.4 does not support functional unique indexes (IFNULL(...)), so
-- NULL facility_id uniqueness follows InnoDB NULL semantics (multiple NULLs allowed).
SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'chart_account'
    AND INDEX_NAME = 'chart_account_tenant_id_facility_id_code_key'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE UNIQUE INDEX `chart_account_tenant_id_facility_id_code_key` ON `chart_account`(`tenant_id`, `facility_id`, `code`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'chart_account'
    AND INDEX_NAME = 'chart_account_tenant_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `chart_account_tenant_id_idx` ON `chart_account`(`tenant_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'chart_account'
    AND INDEX_NAME = 'chart_account_facility_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `chart_account_facility_id_idx` ON `chart_account`(`facility_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'chart_account'
    AND INDEX_NAME = 'chart_account_code_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `chart_account_code_idx` ON `chart_account`(`code`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'chart_account'
    AND INDEX_NAME = 'chart_account_account_type_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `chart_account_account_type_idx` ON `chart_account`(`account_type`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'chart_account'
    AND INDEX_NAME = 'chart_account_parent_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `chart_account_parent_id_idx` ON `chart_account`(`parent_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'chart_account'
    AND INDEX_NAME = 'chart_account_is_active_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `chart_account_is_active_idx` ON `chart_account`(`is_active`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'chart_account'
    AND INDEX_NAME = 'chart_account_deleted_at_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `chart_account_deleted_at_idx` ON `chart_account`(`deleted_at`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'chart_account'
    AND INDEX_NAME = 'chart_account_human_friendly_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `chart_account_human_friendly_id_idx` ON `chart_account`(`human_friendly_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'chart_account'
    AND INDEX_NAME = 'chart_account_effective_from_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `chart_account_effective_from_idx` ON `chart_account`(`effective_from`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'chart_account'
    AND CONSTRAINT_NAME = 'chart_account_tenant_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `chart_account` ADD CONSTRAINT `chart_account_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'chart_account'
    AND CONSTRAINT_NAME = 'chart_account_facility_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `chart_account` ADD CONSTRAINT `chart_account_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'chart_account'
    AND CONSTRAINT_NAME = 'chart_account_parent_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `chart_account` ADD CONSTRAINT `chart_account_parent_id_fkey` FOREIGN KEY (`parent_id`) REFERENCES `chart_account`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
