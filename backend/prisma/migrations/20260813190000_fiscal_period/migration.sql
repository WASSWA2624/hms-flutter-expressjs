-- Fiscal years & periods for Accounts & Finance → Setup & Controls

CREATE TABLE IF NOT EXISTS `fiscal_period` (
  `id` VARCHAR(36) NOT NULL,
  `human_friendly_id` VARCHAR(32) NULL,
  `tenant_id` VARCHAR(36) NOT NULL,
  `facility_id` VARCHAR(36) NULL,
  `fiscal_year` VARCHAR(32) NOT NULL,
  `period_no` INTEGER NOT NULL,
  `period_name` VARCHAR(120) NOT NULL,
  `start_date` DATETIME(3) NOT NULL,
  `end_date` DATETIME(3) NOT NULL,
  `module` VARCHAR(32) NOT NULL DEFAULT 'ALL',
  `open_date` DATETIME(3) NULL,
  `soft_close_date` DATETIME(3) NULL,
  `close_date` DATETIME(3) NULL,
  `lock_date` DATETIME(3) NULL,
  `reopened_at` DATETIME(3) NULL,
  `reopened_by` VARCHAR(36) NULL,
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

-- One period number per tenant + facility + fiscal year + module.
-- MariaDB 10.4 has no functional unique indexes, so a NULL facility_id follows
-- InnoDB NULL semantics (multiple NULLs allowed); the service guards that case.
SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'fiscal_period'
    AND INDEX_NAME = 'fiscal_period_scope_period_key'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE UNIQUE INDEX `fiscal_period_scope_period_key` ON `fiscal_period`(`tenant_id`, `facility_id`, `fiscal_year`, `period_no`, `module`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'fiscal_period'
    AND INDEX_NAME = 'fiscal_period_tenant_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `fiscal_period_tenant_id_idx` ON `fiscal_period`(`tenant_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'fiscal_period'
    AND INDEX_NAME = 'fiscal_period_facility_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `fiscal_period_facility_id_idx` ON `fiscal_period`(`facility_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'fiscal_period'
    AND INDEX_NAME = 'fiscal_period_fiscal_year_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `fiscal_period_fiscal_year_idx` ON `fiscal_period`(`fiscal_year`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'fiscal_period'
    AND INDEX_NAME = 'fiscal_period_status_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `fiscal_period_status_idx` ON `fiscal_period`(`status`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'fiscal_period'
    AND INDEX_NAME = 'fiscal_period_start_date_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `fiscal_period_start_date_idx` ON `fiscal_period`(`start_date`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'fiscal_period'
    AND INDEX_NAME = 'fiscal_period_end_date_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `fiscal_period_end_date_idx` ON `fiscal_period`(`end_date`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'fiscal_period'
    AND INDEX_NAME = 'fiscal_period_module_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `fiscal_period_module_idx` ON `fiscal_period`(`module`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'fiscal_period'
    AND INDEX_NAME = 'fiscal_period_deleted_at_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `fiscal_period_deleted_at_idx` ON `fiscal_period`(`deleted_at`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'fiscal_period'
    AND INDEX_NAME = 'fiscal_period_human_friendly_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `fiscal_period_human_friendly_id_idx` ON `fiscal_period`(`human_friendly_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'fiscal_period'
    AND CONSTRAINT_NAME = 'fiscal_period_tenant_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `fiscal_period` ADD CONSTRAINT `fiscal_period_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'fiscal_period'
    AND CONSTRAINT_NAME = 'fiscal_period_facility_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `fiscal_period` ADD CONSTRAINT `fiscal_period_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'fiscal_period'
    AND CONSTRAINT_NAME = 'fiscal_period_reopened_by_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `fiscal_period` ADD CONSTRAINT `fiscal_period_reopened_by_fkey` FOREIGN KEY (`reopened_by`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
