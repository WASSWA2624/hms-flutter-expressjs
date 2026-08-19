-- Accounts & Finance -> Setup & Controls -> Payment Methods.
--
-- Configures how each tender is accepted or paid out: settlement and clearing
-- accounts, fee rule, evidence and approval requirements, effective window,
-- and lifecycle.
--
-- `method_type` reuses the existing `PaymentMethodType` enum that
-- `payment.method` already stores, so this table configures the tender
-- taxonomy rather than becoming a second source of truth for it. No existing
-- payment row is read or rewritten by this migration.
--
-- Guarded with information_schema + PREPARE because the fleet spans MariaDB
-- builds without `CREATE INDEX IF NOT EXISTS`, and Prisma cannot run DELIMITER.

CREATE TABLE IF NOT EXISTS `payment_method` (
  `id` VARCHAR(36) NOT NULL,
  `human_friendly_id` VARCHAR(32) NULL,
  `tenant_id` VARCHAR(36) NOT NULL,
  `facility_id` VARCHAR(36) NULL,
  `method_code` VARCHAR(32) NOT NULL,
  `method_name` VARCHAR(160) NOT NULL,
  `method_type` ENUM(
    'CASH',
    'CREDIT_CARD',
    'DEBIT_CARD',
    'PREPAID_CARD',
    'GIFT_CARD',
    'VOUCHER',
    'BANK_CHECK',
    'MOBILE_MONEY',
    'BANK_TRANSFER',
    'INSURANCE',
    'OTHER'
  ) NOT NULL,
  `direction` ENUM('INCOMING', 'OUTGOING', 'BOTH') NOT NULL DEFAULT 'INCOMING',
  `provider` VARCHAR(120) NULL,
  `settlement_account_id` VARCHAR(36) NULL,
  `clearing_account_id` VARCHAR(36) NULL,
  `requires_external_reference` BOOLEAN NOT NULL DEFAULT false,
  `requires_approval` BOOLEAN NOT NULL DEFAULT false,
  `fee_rule` VARCHAR(120) NULL,
  `facility_scope` VARCHAR(120) NULL,
  `effective_from` DATETIME(3) NULL,
  `effective_to` DATETIME(3) NULL,
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


SET @exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payment_method'
    AND INDEX_NAME = 'payment_method_code_key'
);
SET @sql := IF(@exists = 0,
  'CREATE UNIQUE INDEX `payment_method_code_key` ON `payment_method`(`tenant_id`, `method_code`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payment_method'
    AND INDEX_NAME = 'payment_method_tenant_id_idx'
);
SET @sql := IF(@exists = 0,
  'CREATE INDEX `payment_method_tenant_id_idx` ON `payment_method`(`tenant_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payment_method'
    AND INDEX_NAME = 'payment_method_facility_id_idx'
);
SET @sql := IF(@exists = 0,
  'CREATE INDEX `payment_method_facility_id_idx` ON `payment_method`(`facility_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payment_method'
    AND INDEX_NAME = 'payment_method_method_type_idx'
);
SET @sql := IF(@exists = 0,
  'CREATE INDEX `payment_method_method_type_idx` ON `payment_method`(`method_type`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payment_method'
    AND INDEX_NAME = 'payment_method_direction_idx'
);
SET @sql := IF(@exists = 0,
  'CREATE INDEX `payment_method_direction_idx` ON `payment_method`(`direction`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payment_method'
    AND INDEX_NAME = 'payment_method_settlement_account_id_idx'
);
SET @sql := IF(@exists = 0,
  'CREATE INDEX `payment_method_settlement_account_id_idx` ON `payment_method`(`settlement_account_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payment_method'
    AND INDEX_NAME = 'payment_method_clearing_account_id_idx'
);
SET @sql := IF(@exists = 0,
  'CREATE INDEX `payment_method_clearing_account_id_idx` ON `payment_method`(`clearing_account_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payment_method'
    AND INDEX_NAME = 'payment_method_status_idx'
);
SET @sql := IF(@exists = 0,
  'CREATE INDEX `payment_method_status_idx` ON `payment_method`(`status`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payment_method'
    AND INDEX_NAME = 'payment_method_effective_from_idx'
);
SET @sql := IF(@exists = 0,
  'CREATE INDEX `payment_method_effective_from_idx` ON `payment_method`(`effective_from`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payment_method'
    AND INDEX_NAME = 'payment_method_effective_to_idx'
);
SET @sql := IF(@exists = 0,
  'CREATE INDEX `payment_method_effective_to_idx` ON `payment_method`(`effective_to`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payment_method'
    AND INDEX_NAME = 'payment_method_deleted_at_idx'
);
SET @sql := IF(@exists = 0,
  'CREATE INDEX `payment_method_deleted_at_idx` ON `payment_method`(`deleted_at`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payment_method'
    AND INDEX_NAME = 'payment_method_human_friendly_id_idx'
);
SET @sql := IF(@exists = 0,
  'CREATE INDEX `payment_method_human_friendly_id_idx` ON `payment_method`(`human_friendly_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;


SET @exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payment_method'
    AND CONSTRAINT_NAME = 'payment_method_tenant_id_fkey'
);
SET @sql := IF(@exists = 0,
  'ALTER TABLE `payment_method` ADD CONSTRAINT `payment_method_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payment_method'
    AND CONSTRAINT_NAME = 'payment_method_facility_id_fkey'
);
SET @sql := IF(@exists = 0,
  'ALTER TABLE `payment_method` ADD CONSTRAINT `payment_method_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payment_method'
    AND CONSTRAINT_NAME = 'payment_method_settlement_account_id_fkey'
);
SET @sql := IF(@exists = 0,
  'ALTER TABLE `payment_method` ADD CONSTRAINT `payment_method_settlement_account_id_fkey` FOREIGN KEY (`settlement_account_id`) REFERENCES `chart_account`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payment_method'
    AND CONSTRAINT_NAME = 'payment_method_clearing_account_id_fkey'
);
SET @sql := IF(@exists = 0,
  'ALTER TABLE `payment_method` ADD CONSTRAINT `payment_method_clearing_account_id_fkey` FOREIGN KEY (`clearing_account_id`) REFERENCES `chart_account`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payment_method'
    AND CONSTRAINT_NAME = 'payment_method_updated_by_fkey'
);
SET @sql := IF(@exists = 0,
  'ALTER TABLE `payment_method` ADD CONSTRAINT `payment_method_updated_by_fkey` FOREIGN KEY (`updated_by`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
