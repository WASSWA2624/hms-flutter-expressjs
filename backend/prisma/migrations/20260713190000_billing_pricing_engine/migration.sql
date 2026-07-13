-- Billing & pricing engine (idempotent; safe for fresh DBs and partial applies)

-- Ensure price_book_entry exists (may already exist from a prior partial apply)
CREATE TABLE IF NOT EXISTS `price_book_entry` (
  `id` VARCHAR(36) NOT NULL,
  `human_friendly_id` VARCHAR(32) NULL,
  `tenant_id` VARCHAR(36) NOT NULL,
  `facility_id` VARCHAR(36) NULL,
  `catalog_type` ENUM('DRUG', 'LAB_TEST', 'LAB_PANEL', 'RADIOLOGY_TEST', 'CONSULTATION', 'SERVICE') NOT NULL,
  `catalog_item_id` VARCHAR(36) NOT NULL,
  `payment_mode` ENUM('SELF_PAY', 'INSURANCE') NOT NULL,
  `coverage_plan_id` VARCHAR(36) NULL,
  `insurer_key` VARCHAR(120) NULL,
  `billing_entity` ENUM('FACILITY', 'PHARMACY') NOT NULL DEFAULT 'FACILITY',
  `unit_price` DECIMAL(12, 2) NOT NULL,
  `currency` VARCHAR(10) NOT NULL,
  `effective_from` DATETIME(3) NULL,
  `effective_to` DATETIME(3) NULL,
  `is_active` BOOLEAN NOT NULL DEFAULT true,
  `notes` VARCHAR(255) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  `deleted_at` DATETIME(3) NULL,
  `version` INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Ensure coverage_plan provider index
SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'coverage_plan'
    AND INDEX_NAME = 'coverage_plan_provider_name_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `coverage_plan_provider_name_idx` ON `coverage_plan`(`provider_name`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Short lookup index on price_book_entry
SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'price_book_entry'
    AND INDEX_NAME = 'price_book_entry_lookup_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `price_book_entry_lookup_idx` ON `price_book_entry`(`tenant_id`, `facility_id`, `catalog_type`, `catalog_item_id`, `payment_mode`, `billing_entity`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- price_book_entry FKs (ignore if already present)
SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'price_book_entry'
    AND CONSTRAINT_NAME = 'price_book_entry_tenant_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `price_book_entry` ADD CONSTRAINT `price_book_entry_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'price_book_entry'
    AND CONSTRAINT_NAME = 'price_book_entry_facility_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `price_book_entry` ADD CONSTRAINT `price_book_entry_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'price_book_entry'
    AND CONSTRAINT_NAME = 'price_book_entry_coverage_plan_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `price_book_entry` ADD CONSTRAINT `price_book_entry_coverage_plan_id_fkey` FOREIGN KEY (`coverage_plan_id`) REFERENCES `coverage_plan`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS `patient_insurance_enrollment` (
  `id` VARCHAR(36) NOT NULL,
  `human_friendly_id` VARCHAR(32) NULL,
  `tenant_id` VARCHAR(36) NOT NULL,
  `facility_id` VARCHAR(36) NULL,
  `patient_id` VARCHAR(36) NOT NULL,
  `coverage_plan_id` VARCHAR(36) NOT NULL,
  `member_id` VARCHAR(120) NOT NULL,
  `status` ENUM('ACTIVE', 'EXPIRED', 'SUSPENDED', 'PENDING') NOT NULL DEFAULT 'PENDING',
  `valid_from` DATETIME(3) NULL,
  `valid_to` DATETIME(3) NULL,
  `copay_type` ENUM('NONE', 'FIXED', 'PERCENT') NOT NULL DEFAULT 'NONE',
  `copay_value` DECIMAL(12, 2) NULL,
  `is_primary` BOOLEAN NOT NULL DEFAULT true,
  `notes` TEXT NULL,
  `verified_at` DATETIME(3) NULL,
  `last_verified_via` VARCHAR(40) NULL,
  `extension_json` JSON NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  `deleted_at` DATETIME(3) NULL,
  `version` INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'patient_insurance_enrollment'
    AND INDEX_NAME = 'patient_insurance_enrollment_tenant_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `patient_insurance_enrollment_tenant_id_idx` ON `patient_insurance_enrollment`(`tenant_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'patient_insurance_enrollment'
    AND INDEX_NAME = 'patient_insurance_enrollment_facility_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `patient_insurance_enrollment_facility_id_idx` ON `patient_insurance_enrollment`(`facility_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'patient_insurance_enrollment'
    AND INDEX_NAME = 'patient_insurance_enrollment_patient_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `patient_insurance_enrollment_patient_id_idx` ON `patient_insurance_enrollment`(`patient_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'patient_insurance_enrollment'
    AND INDEX_NAME = 'patient_insurance_enrollment_coverage_plan_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `patient_insurance_enrollment_coverage_plan_id_idx` ON `patient_insurance_enrollment`(`coverage_plan_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'patient_insurance_enrollment'
    AND INDEX_NAME = 'patient_insurance_enrollment_member_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `patient_insurance_enrollment_member_id_idx` ON `patient_insurance_enrollment`(`member_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'patient_insurance_enrollment'
    AND INDEX_NAME = 'patient_insurance_enrollment_status_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `patient_insurance_enrollment_status_idx` ON `patient_insurance_enrollment`(`status`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'patient_insurance_enrollment'
    AND INDEX_NAME = 'patient_insurance_enrollment_valid_from_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `patient_insurance_enrollment_valid_from_idx` ON `patient_insurance_enrollment`(`valid_from`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'patient_insurance_enrollment'
    AND INDEX_NAME = 'patient_insurance_enrollment_valid_to_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `patient_insurance_enrollment_valid_to_idx` ON `patient_insurance_enrollment`(`valid_to`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'patient_insurance_enrollment'
    AND INDEX_NAME = 'patient_insurance_enrollment_deleted_at_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `patient_insurance_enrollment_deleted_at_idx` ON `patient_insurance_enrollment`(`deleted_at`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'patient_insurance_enrollment'
    AND INDEX_NAME = 'patient_insurance_enrollment_human_friendly_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `patient_insurance_enrollment_human_friendly_id_idx` ON `patient_insurance_enrollment`(`human_friendly_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'patient_insurance_enrollment'
    AND INDEX_NAME = 'patient_insurance_enrollment_tenant_id_patient_id_status_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `patient_insurance_enrollment_tenant_id_patient_id_status_idx` ON `patient_insurance_enrollment`(`tenant_id`, `patient_id`, `status`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'patient_insurance_enrollment'
    AND CONSTRAINT_NAME = 'patient_insurance_enrollment_tenant_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `patient_insurance_enrollment` ADD CONSTRAINT `patient_insurance_enrollment_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'patient_insurance_enrollment'
    AND CONSTRAINT_NAME = 'patient_insurance_enrollment_facility_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `patient_insurance_enrollment` ADD CONSTRAINT `patient_insurance_enrollment_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'patient_insurance_enrollment'
    AND CONSTRAINT_NAME = 'patient_insurance_enrollment_patient_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `patient_insurance_enrollment` ADD CONSTRAINT `patient_insurance_enrollment_patient_id_fkey` FOREIGN KEY (`patient_id`) REFERENCES `patient`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'patient_insurance_enrollment'
    AND CONSTRAINT_NAME = 'patient_insurance_enrollment_coverage_plan_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `patient_insurance_enrollment` ADD CONSTRAINT `patient_insurance_enrollment_coverage_plan_id_fkey` FOREIGN KEY (`coverage_plan_id`) REFERENCES `coverage_plan`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS `insurer_integration` (
  `id` VARCHAR(36) NOT NULL,
  `human_friendly_id` VARCHAR(32) NULL,
  `tenant_id` VARCHAR(36) NOT NULL,
  `facility_id` VARCHAR(36) NULL,
  `coverage_plan_id` VARCHAR(36) NULL,
  `name` VARCHAR(120) NOT NULL,
  `adapter_type` ENUM('STUB', 'GENERIC_REST') NOT NULL DEFAULT 'STUB',
  `base_url` VARCHAR(500) NULL,
  `is_enabled` BOOLEAN NOT NULL DEFAULT false,
  `credentials_encrypted` TEXT NULL,
  `config_json` JSON NULL,
  `webhook_secret_hash` VARCHAR(255) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  `deleted_at` DATETIME(3) NULL,
  `version` INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'insurer_integration'
    AND INDEX_NAME = 'insurer_integration_tenant_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `insurer_integration_tenant_id_idx` ON `insurer_integration`(`tenant_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'insurer_integration'
    AND INDEX_NAME = 'insurer_integration_facility_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `insurer_integration_facility_id_idx` ON `insurer_integration`(`facility_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'insurer_integration'
    AND INDEX_NAME = 'insurer_integration_coverage_plan_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `insurer_integration_coverage_plan_id_idx` ON `insurer_integration`(`coverage_plan_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'insurer_integration'
    AND INDEX_NAME = 'insurer_integration_adapter_type_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `insurer_integration_adapter_type_idx` ON `insurer_integration`(`adapter_type`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'insurer_integration'
    AND INDEX_NAME = 'insurer_integration_is_enabled_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `insurer_integration_is_enabled_idx` ON `insurer_integration`(`is_enabled`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'insurer_integration'
    AND INDEX_NAME = 'insurer_integration_deleted_at_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `insurer_integration_deleted_at_idx` ON `insurer_integration`(`deleted_at`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'insurer_integration'
    AND INDEX_NAME = 'insurer_integration_human_friendly_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `insurer_integration_human_friendly_id_idx` ON `insurer_integration`(`human_friendly_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'insurer_integration'
    AND CONSTRAINT_NAME = 'insurer_integration_tenant_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `insurer_integration` ADD CONSTRAINT `insurer_integration_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'insurer_integration'
    AND CONSTRAINT_NAME = 'insurer_integration_facility_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `insurer_integration` ADD CONSTRAINT `insurer_integration_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'insurer_integration'
    AND CONSTRAINT_NAME = 'insurer_integration_coverage_plan_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `insurer_integration` ADD CONSTRAINT `insurer_integration_coverage_plan_id_fkey` FOREIGN KEY (`coverage_plan_id`) REFERENCES `coverage_plan`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Ensure invoice / payment / closeout billing_entity columns
SET @col_exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'invoice' AND COLUMN_NAME = 'billing_entity'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE `invoice` ADD COLUMN `billing_entity` ENUM(''FACILITY'', ''PHARMACY'') NOT NULL DEFAULT ''FACILITY''',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payment' AND COLUMN_NAME = 'billing_entity'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE `payment` ADD COLUMN `billing_entity` ENUM(''FACILITY'', ''PHARMACY'') NOT NULL DEFAULT ''FACILITY''',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'shift_close' AND COLUMN_NAME = 'billing_entity'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE `shift_close` ADD COLUMN `billing_entity` ENUM(''FACILITY'', ''PHARMACY'') NOT NULL DEFAULT ''FACILITY''',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'day_close' AND COLUMN_NAME = 'billing_entity'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE `day_close` ADD COLUMN `billing_entity` ENUM(''FACILITY'', ''PHARMACY'') NOT NULL DEFAULT ''FACILITY''',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Ensure invoice_item engine columns exist before FKs
SET @col_exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'invoice_item' AND COLUMN_NAME = 'price_book_entry_id'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE `invoice_item` ADD COLUMN `price_book_entry_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'invoice_item' AND COLUMN_NAME = 'coverage_plan_id'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE `invoice_item` ADD COLUMN `coverage_plan_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'invoice_item' AND COLUMN_NAME = 'catalog_type'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE `invoice_item` ADD COLUMN `catalog_type` ENUM(''DRUG'', ''LAB_TEST'', ''LAB_PANEL'', ''RADIOLOGY_TEST'', ''CONSULTATION'', ''SERVICE'') NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'invoice_item' AND COLUMN_NAME = 'catalog_item_id'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE `invoice_item` ADD COLUMN `catalog_item_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'invoice_item' AND COLUMN_NAME = 'payment_mode'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE `invoice_item` ADD COLUMN `payment_mode` ENUM(''SELF_PAY'', ''INSURANCE'') NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'invoice_item' AND COLUMN_NAME = 'billing_entity'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE `invoice_item` ADD COLUMN `billing_entity` ENUM(''FACILITY'', ''PHARMACY'') NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'invoice_item' AND COLUMN_NAME = 'price_source'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE `invoice_item` ADD COLUMN `price_source` VARCHAR(40) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'invoice_item' AND COLUMN_NAME = 'patient_share'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE `invoice_item` ADD COLUMN `patient_share` DECIMAL(12, 2) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'invoice_item' AND COLUMN_NAME = 'insurer_share'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE `invoice_item` ADD COLUMN `insurer_share` DECIMAL(12, 2) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'invoice_item' AND COLUMN_NAME = 'copay_amount'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE `invoice_item` ADD COLUMN `copay_amount` DECIMAL(12, 2) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- invoice_item FKs
SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'invoice_item'
    AND CONSTRAINT_NAME = 'invoice_item_price_book_entry_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `invoice_item` ADD CONSTRAINT `invoice_item_price_book_entry_id_fkey` FOREIGN KEY (`price_book_entry_id`) REFERENCES `price_book_entry`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'invoice_item'
    AND CONSTRAINT_NAME = 'invoice_item_coverage_plan_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `invoice_item` ADD CONSTRAINT `invoice_item_coverage_plan_id_fkey` FOREIGN KEY (`coverage_plan_id`) REFERENCES `coverage_plan`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
