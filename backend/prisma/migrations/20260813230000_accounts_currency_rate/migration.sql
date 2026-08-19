-- Currencies & exchange rates for Accounts & Finance → Setup & Controls

CREATE TABLE IF NOT EXISTS `accounts_currency_rate` (
  `id` VARCHAR(36) NOT NULL,
  `human_friendly_id` VARCHAR(32) NULL,
  `tenant_id` VARCHAR(36) NOT NULL,
  `facility_id` VARCHAR(36) NULL,
  `currency_code` VARCHAR(3) NOT NULL,
  `currency_name` VARCHAR(120) NOT NULL,
  `symbol` VARCHAR(8) NOT NULL,
  `decimal_places` INTEGER NOT NULL DEFAULT 2,
  `is_base_currency` BOOLEAN NOT NULL DEFAULT false,
  `rate_type` ENUM('SPOT', 'DAILY', 'MONTHLY', 'BUDGET', 'CONTRACT') NOT NULL DEFAULT 'SPOT',
  `exchange_rate` DECIMAL(18, 8) NOT NULL,
  `effective_date` DATETIME(3) NOT NULL,
  `source` VARCHAR(120) NULL,
  `buy_rate` DECIMAL(18, 8) NULL,
  `sell_rate` DECIMAL(18, 8) NULL,
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

-- One rate per tenant + facility + currency + rate type + effective date.
-- MariaDB 10.4 has no functional unique indexes, so a NULL facility_id follows
-- InnoDB NULL semantics (multiple NULLs allowed); the service guards that case.
SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'accounts_currency_rate'
    AND INDEX_NAME = 'currency_rate_scope_effective_key'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE UNIQUE INDEX `currency_rate_scope_effective_key` ON `accounts_currency_rate`(`tenant_id`, `facility_id`, `currency_code`, `rate_type`, `effective_date`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'accounts_currency_rate'
    AND INDEX_NAME = 'accounts_currency_rate_tenant_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `accounts_currency_rate_tenant_id_idx` ON `accounts_currency_rate`(`tenant_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'accounts_currency_rate'
    AND INDEX_NAME = 'accounts_currency_rate_facility_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `accounts_currency_rate_facility_id_idx` ON `accounts_currency_rate`(`facility_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'accounts_currency_rate'
    AND INDEX_NAME = 'accounts_currency_rate_currency_code_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `accounts_currency_rate_currency_code_idx` ON `accounts_currency_rate`(`currency_code`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'accounts_currency_rate'
    AND INDEX_NAME = 'accounts_currency_rate_rate_type_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `accounts_currency_rate_rate_type_idx` ON `accounts_currency_rate`(`rate_type`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'accounts_currency_rate'
    AND INDEX_NAME = 'accounts_currency_rate_status_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `accounts_currency_rate_status_idx` ON `accounts_currency_rate`(`status`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'accounts_currency_rate'
    AND INDEX_NAME = 'accounts_currency_rate_effective_date_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `accounts_currency_rate_effective_date_idx` ON `accounts_currency_rate`(`effective_date`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'accounts_currency_rate'
    AND INDEX_NAME = 'accounts_currency_rate_is_base_currency_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `accounts_currency_rate_is_base_currency_idx` ON `accounts_currency_rate`(`is_base_currency`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'accounts_currency_rate'
    AND INDEX_NAME = 'accounts_currency_rate_deleted_at_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `accounts_currency_rate_deleted_at_idx` ON `accounts_currency_rate`(`deleted_at`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'accounts_currency_rate'
    AND INDEX_NAME = 'accounts_currency_rate_human_friendly_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `accounts_currency_rate_human_friendly_id_idx` ON `accounts_currency_rate`(`human_friendly_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'accounts_currency_rate'
    AND CONSTRAINT_NAME = 'accounts_currency_rate_tenant_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `accounts_currency_rate` ADD CONSTRAINT `accounts_currency_rate_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'accounts_currency_rate'
    AND CONSTRAINT_NAME = 'accounts_currency_rate_facility_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `accounts_currency_rate` ADD CONSTRAINT `accounts_currency_rate_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'accounts_currency_rate'
    AND CONSTRAINT_NAME = 'accounts_currency_rate_updated_by_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `accounts_currency_rate` ADD CONSTRAINT `accounts_currency_rate_updated_by_fkey` FOREIGN KEY (`updated_by`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
