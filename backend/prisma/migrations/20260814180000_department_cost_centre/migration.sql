-- Accounts & Finance -> Setup & Controls -> Departments & Cost Centres.
--
-- The department stays owned by tenant/facility setup. These columns add the
-- finance projection (cost centre, default posting accounts, ownership,
-- effective window, lifecycle) instead of creating a second source of truth.
--
-- `is_active` is retained and mirrored from `status`, so every pre-finance
-- consumer (units, wards, staff, rosters, referrals, ABAC policies) keeps
-- working unchanged.
--
-- Guarded with information_schema + PREPARE because the fleet spans MariaDB
-- builds without `ADD COLUMN IF NOT EXISTS`, and Prisma cannot run DELIMITER.


SET @exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'department'
    AND COLUMN_NAME = 'code'
);
SET @sql := IF(@exists = 0,
  'ALTER TABLE `department` ADD COLUMN `code` VARCHAR(32) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'department'
    AND COLUMN_NAME = 'cost_centre_code'
);
SET @sql := IF(@exists = 0,
  'ALTER TABLE `department` ADD COLUMN `cost_centre_code` VARCHAR(32) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'department'
    AND COLUMN_NAME = 'cost_centre_name'
);
SET @sql := IF(@exists = 0,
  'ALTER TABLE `department` ADD COLUMN `cost_centre_name` VARCHAR(160) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'department'
    AND COLUMN_NAME = 'parent_id'
);
SET @sql := IF(@exists = 0,
  'ALTER TABLE `department` ADD COLUMN `parent_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'department'
    AND COLUMN_NAME = 'manager_id'
);
SET @sql := IF(@exists = 0,
  'ALTER TABLE `department` ADD COLUMN `manager_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'department'
    AND COLUMN_NAME = 'default_revenue_account_id'
);
SET @sql := IF(@exists = 0,
  'ALTER TABLE `department` ADD COLUMN `default_revenue_account_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'department'
    AND COLUMN_NAME = 'default_expense_account_id'
);
SET @sql := IF(@exists = 0,
  'ALTER TABLE `department` ADD COLUMN `default_expense_account_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'department'
    AND COLUMN_NAME = 'budget_owner_id'
);
SET @sql := IF(@exists = 0,
  'ALTER TABLE `department` ADD COLUMN `budget_owner_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'department'
    AND COLUMN_NAME = 'effective_from'
);
SET @sql := IF(@exists = 0,
  'ALTER TABLE `department` ADD COLUMN `effective_from` DATETIME(3) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'department'
    AND COLUMN_NAME = 'effective_to'
);
SET @sql := IF(@exists = 0,
  'ALTER TABLE `department` ADD COLUMN `effective_to` DATETIME(3) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'department'
    AND COLUMN_NAME = 'status'
);
SET @sql := IF(@exists = 0,
  'ALTER TABLE `department` ADD COLUMN `status` ENUM(''DRAFT'', ''ACTIVE'', ''INACTIVE'', ''ARCHIVED'') NOT NULL DEFAULT ''ACTIVE''',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'department'
    AND COLUMN_NAME = 'archived_at'
);
SET @sql := IF(@exists = 0,
  'ALTER TABLE `department` ADD COLUMN `archived_at` DATETIME(3) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'department'
    AND COLUMN_NAME = 'updated_by'
);
SET @sql := IF(@exists = 0,
  'ALTER TABLE `department` ADD COLUMN `updated_by` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;


-- Existing rows carry their lifecycle in `is_active`; seed `status` from it so
-- the two agree from the first read.
UPDATE `department` SET `status` = 'INACTIVE' WHERE `is_active` = false;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'department'
    AND INDEX_NAME = 'department_code_idx'
);
SET @sql := IF(@exists = 0,
  'CREATE INDEX `department_code_idx` ON `department`(`code`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'department'
    AND INDEX_NAME = 'department_cost_centre_code_idx'
);
SET @sql := IF(@exists = 0,
  'CREATE INDEX `department_cost_centre_code_idx` ON `department`(`cost_centre_code`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'department'
    AND INDEX_NAME = 'department_parent_id_idx'
);
SET @sql := IF(@exists = 0,
  'CREATE INDEX `department_parent_id_idx` ON `department`(`parent_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'department'
    AND INDEX_NAME = 'department_manager_id_idx'
);
SET @sql := IF(@exists = 0,
  'CREATE INDEX `department_manager_id_idx` ON `department`(`manager_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'department'
    AND INDEX_NAME = 'department_budget_owner_id_idx'
);
SET @sql := IF(@exists = 0,
  'CREATE INDEX `department_budget_owner_id_idx` ON `department`(`budget_owner_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'department'
    AND INDEX_NAME = 'department_default_revenue_account_id_idx'
);
SET @sql := IF(@exists = 0,
  'CREATE INDEX `department_default_revenue_account_id_idx` ON `department`(`default_revenue_account_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'department'
    AND INDEX_NAME = 'department_default_expense_account_id_idx'
);
SET @sql := IF(@exists = 0,
  'CREATE INDEX `department_default_expense_account_id_idx` ON `department`(`default_expense_account_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'department'
    AND INDEX_NAME = 'department_status_idx'
);
SET @sql := IF(@exists = 0,
  'CREATE INDEX `department_status_idx` ON `department`(`status`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'department'
    AND INDEX_NAME = 'department_effective_from_idx'
);
SET @sql := IF(@exists = 0,
  'CREATE INDEX `department_effective_from_idx` ON `department`(`effective_from`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'department'
    AND CONSTRAINT_NAME = 'department_parent_id_fkey'
);
SET @sql := IF(@exists = 0,
  'ALTER TABLE `department` ADD CONSTRAINT `department_parent_id_fkey` FOREIGN KEY (`parent_id`) REFERENCES `department`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'department'
    AND CONSTRAINT_NAME = 'department_manager_id_fkey'
);
SET @sql := IF(@exists = 0,
  'ALTER TABLE `department` ADD CONSTRAINT `department_manager_id_fkey` FOREIGN KEY (`manager_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'department'
    AND CONSTRAINT_NAME = 'department_budget_owner_id_fkey'
);
SET @sql := IF(@exists = 0,
  'ALTER TABLE `department` ADD CONSTRAINT `department_budget_owner_id_fkey` FOREIGN KEY (`budget_owner_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'department'
    AND CONSTRAINT_NAME = 'department_updated_by_fkey'
);
SET @sql := IF(@exists = 0,
  'ALTER TABLE `department` ADD CONSTRAINT `department_updated_by_fkey` FOREIGN KEY (`updated_by`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'department'
    AND CONSTRAINT_NAME = 'department_default_revenue_account_id_fkey'
);
SET @sql := IF(@exists = 0,
  'ALTER TABLE `department` ADD CONSTRAINT `department_default_revenue_account_id_fkey` FOREIGN KEY (`default_revenue_account_id`) REFERENCES `chart_account`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'department'
    AND CONSTRAINT_NAME = 'department_default_expense_account_id_fkey'
);
SET @sql := IF(@exists = 0,
  'ALTER TABLE `department` ADD CONSTRAINT `department_default_expense_account_id_fkey` FOREIGN KEY (`default_expense_account_id`) REFERENCES `chart_account`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
