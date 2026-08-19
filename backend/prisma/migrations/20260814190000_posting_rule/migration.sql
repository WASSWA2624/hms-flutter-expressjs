-- Posting rules for Accounts & Finance → Setup & Controls → Posting Rules

CREATE TABLE IF NOT EXISTS `posting_rule` (
  `id` VARCHAR(36) NOT NULL,
  `human_friendly_id` VARCHAR(32) NULL,
  `tenant_id` VARCHAR(36) NOT NULL,
  `facility_id` VARCHAR(36) NULL,
  `rule_code` VARCHAR(32) NOT NULL,
  `rule_name` VARCHAR(160) NOT NULL,
  `source_module` VARCHAR(64) NOT NULL,
  `event_type` VARCHAR(64) NOT NULL,
  `debit_account_rule` VARCHAR(120) NOT NULL,
  `credit_account_rule` VARCHAR(120) NOT NULL,
  `tax_rule` VARCHAR(120) NULL,
  `department_rule` VARCHAR(120) NULL,
  `cost_centre_rule` VARCHAR(120) NULL,
  `priority` INTEGER NOT NULL DEFAULT 100,
  `effective_from` DATETIME(3) NULL,
  `effective_to` DATETIME(3) NULL,
  `test_status` ENUM('NOT_TESTED', 'PASSED', 'FAILED') NOT NULL DEFAULT 'NOT_TESTED',
  `tested_at` DATETIME(3) NULL,
  `status` ENUM('DRAFT', 'ACTIVE', 'INACTIVE', 'ARCHIVED') NOT NULL DEFAULT 'DRAFT',
  `notes` VARCHAR(500) NULL,
  `created_by` VARCHAR(36) NULL,
  `updated_by` VARCHAR(36) NULL,
  `reopened_at` DATETIME(3) NULL,
  `reopened_by` VARCHAR(36) NULL,
  `archived_at` DATETIME(3) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  `deleted_at` DATETIME(3) NULL,
  `version` INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB;

-- One rule code per tenant. The service also guards overlapping effective
-- windows for the same source module, event type, and priority.
SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'posting_rule'
    AND INDEX_NAME = 'posting_rule_code_key'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE UNIQUE INDEX `posting_rule_code_key` ON `posting_rule`(`tenant_id`, `rule_code`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'posting_rule'
    AND INDEX_NAME = 'posting_rule_tenant_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `posting_rule_tenant_id_idx` ON `posting_rule`(`tenant_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'posting_rule'
    AND INDEX_NAME = 'posting_rule_facility_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `posting_rule_facility_id_idx` ON `posting_rule`(`facility_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'posting_rule'
    AND INDEX_NAME = 'posting_rule_source_module_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `posting_rule_source_module_idx` ON `posting_rule`(`source_module`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'posting_rule'
    AND INDEX_NAME = 'posting_rule_event_type_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `posting_rule_event_type_idx` ON `posting_rule`(`event_type`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'posting_rule'
    AND INDEX_NAME = 'posting_rule_status_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `posting_rule_status_idx` ON `posting_rule`(`status`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'posting_rule'
    AND INDEX_NAME = 'posting_rule_test_status_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `posting_rule_test_status_idx` ON `posting_rule`(`test_status`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'posting_rule'
    AND INDEX_NAME = 'posting_rule_priority_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `posting_rule_priority_idx` ON `posting_rule`(`priority`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'posting_rule'
    AND INDEX_NAME = 'posting_rule_effective_from_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `posting_rule_effective_from_idx` ON `posting_rule`(`effective_from`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'posting_rule'
    AND INDEX_NAME = 'posting_rule_effective_to_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `posting_rule_effective_to_idx` ON `posting_rule`(`effective_to`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'posting_rule'
    AND INDEX_NAME = 'posting_rule_deleted_at_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `posting_rule_deleted_at_idx` ON `posting_rule`(`deleted_at`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'posting_rule'
    AND INDEX_NAME = 'posting_rule_human_friendly_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `posting_rule_human_friendly_id_idx` ON `posting_rule`(`human_friendly_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'posting_rule'
    AND CONSTRAINT_NAME = 'posting_rule_tenant_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `posting_rule` ADD CONSTRAINT `posting_rule_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'posting_rule'
    AND CONSTRAINT_NAME = 'posting_rule_facility_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `posting_rule` ADD CONSTRAINT `posting_rule_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'posting_rule'
    AND CONSTRAINT_NAME = 'posting_rule_reopened_by_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `posting_rule` ADD CONSTRAINT `posting_rule_reopened_by_fkey` FOREIGN KEY (`reopened_by`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
