-- Insurance company → scheme (coverage_plan) → scheme_offer hierarchy
-- Idempotent: safe after partial apply (insurance_company + coverage_plan columns may already exist)

-- ==================== insurance_company ====================
CREATE TABLE IF NOT EXISTS `insurance_company` (
  `id` VARCHAR(36) NOT NULL,
  `human_friendly_id` VARCHAR(32) NULL,
  `tenant_id` VARCHAR(36) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `code` VARCHAR(64) NOT NULL,
  `contact_json` JSON NULL,
  `is_active` BOOLEAN NOT NULL DEFAULT true,
  `notes` VARCHAR(255) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  `deleted_at` DATETIME(3) NULL,
  `version` INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'insurance_company'
    AND INDEX_NAME = 'insurance_company_tenant_id_code_key'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE UNIQUE INDEX `insurance_company_tenant_id_code_key` ON `insurance_company`(`tenant_id`, `code`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'insurance_company'
    AND INDEX_NAME = 'insurance_company_tenant_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `insurance_company_tenant_id_idx` ON `insurance_company`(`tenant_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'insurance_company'
    AND INDEX_NAME = 'insurance_company_name_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `insurance_company_name_idx` ON `insurance_company`(`name`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'insurance_company'
    AND INDEX_NAME = 'insurance_company_is_active_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `insurance_company_is_active_idx` ON `insurance_company`(`is_active`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'insurance_company'
    AND INDEX_NAME = 'insurance_company_deleted_at_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `insurance_company_deleted_at_idx` ON `insurance_company`(`deleted_at`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'insurance_company'
    AND INDEX_NAME = 'insurance_company_human_friendly_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `insurance_company_human_friendly_id_idx` ON `insurance_company`(`human_friendly_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'insurance_company'
    AND CONSTRAINT_NAME = 'insurance_company_tenant_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `insurance_company` ADD CONSTRAINT `insurance_company_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ==================== Evolve coverage_plan ====================
SET @col_exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'coverage_plan'
    AND COLUMN_NAME = 'insurance_company_id'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE `coverage_plan` ADD COLUMN `insurance_company_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'coverage_plan'
    AND COLUMN_NAME = 'code'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE `coverage_plan` ADD COLUMN `code` VARCHAR(64) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'coverage_plan'
    AND COLUMN_NAME = 'status'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE `coverage_plan` ADD COLUMN `status` ENUM(''ACTIVE'', ''RETIRED'') NOT NULL DEFAULT ''ACTIVE''',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'coverage_plan'
    AND COLUMN_NAME = 'effective_from'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE `coverage_plan` ADD COLUMN `effective_from` DATETIME(3) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'coverage_plan'
    AND COLUMN_NAME = 'effective_to'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE `coverage_plan` ADD COLUMN `effective_to` DATETIME(3) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'coverage_plan'
    AND COLUMN_NAME = 'default_copay_type'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE `coverage_plan` ADD COLUMN `default_copay_type` ENUM(''NONE'', ''FIXED'', ''PERCENT'') NOT NULL DEFAULT ''NONE''',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'coverage_plan'
    AND COLUMN_NAME = 'default_copay_value'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE `coverage_plan` ADD COLUMN `default_copay_value` DECIMAL(12, 2) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'coverage_plan'
    AND INDEX_NAME = 'coverage_plan_insurance_company_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `coverage_plan_insurance_company_id_idx` ON `coverage_plan`(`insurance_company_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'coverage_plan'
    AND INDEX_NAME = 'coverage_plan_code_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `coverage_plan_code_idx` ON `coverage_plan`(`code`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'coverage_plan'
    AND INDEX_NAME = 'coverage_plan_status_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `coverage_plan_status_idx` ON `coverage_plan`(`status`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'coverage_plan'
    AND INDEX_NAME = 'coverage_plan_effective_from_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `coverage_plan_effective_from_idx` ON `coverage_plan`(`effective_from`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'coverage_plan'
    AND INDEX_NAME = 'coverage_plan_effective_to_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `coverage_plan_effective_to_idx` ON `coverage_plan`(`effective_to`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'coverage_plan'
    AND INDEX_NAME = 'coverage_plan_tenant_id_insurance_company_id_status_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `coverage_plan_tenant_id_insurance_company_id_status_idx` ON `coverage_plan`(`tenant_id`, `insurance_company_id`, `status`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'coverage_plan'
    AND CONSTRAINT_NAME = 'coverage_plan_insurance_company_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `coverage_plan` ADD CONSTRAINT `coverage_plan_insurance_company_id_fkey` FOREIGN KEY (`insurance_company_id`) REFERENCES `insurance_company`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Backfill companies from distinct provider_name values (no cp.id in subquery)
INSERT INTO `insurance_company` (`id`, `tenant_id`, `name`, `code`, `is_active`, `created_at`, `updated_at`, `version`)
SELECT
  UUID(),
  cp.tenant_id,
  COALESCE(NULLIF(TRIM(cp.provider_name), ''), CONCAT('Insurer-', LEFT(cp.tenant_id, 8))),
  UPPER(LEFT(REPLACE(REPLACE(COALESCE(NULLIF(TRIM(cp.provider_name), ''), CONCAT('INS-', LEFT(cp.tenant_id, 8))), ' ', '-'), '/', '-'), 64)),
  true,
  CURRENT_TIMESTAMP(3),
  CURRENT_TIMESTAMP(3),
  1
FROM (
  SELECT DISTINCT tenant_id, provider_name
  FROM coverage_plan
  WHERE deleted_at IS NULL
) cp
WHERE NOT EXISTS (
  SELECT 1 FROM insurance_company ic
  WHERE ic.tenant_id = cp.tenant_id
    AND ic.code = UPPER(LEFT(REPLACE(REPLACE(COALESCE(NULLIF(TRIM(cp.provider_name), ''), CONCAT('INS-', LEFT(cp.tenant_id, 8))), ' ', '-'), '/', '-'), 64))
    AND ic.deleted_at IS NULL
);

UPDATE coverage_plan cp
INNER JOIN insurance_company ic
  ON ic.tenant_id = cp.tenant_id
 AND ic.deleted_at IS NULL
 AND (
   (cp.provider_name IS NOT NULL AND TRIM(cp.provider_name) <> '' AND ic.name = TRIM(cp.provider_name))
   OR (
     COALESCE(TRIM(cp.provider_name), '') = ''
     AND ic.code = UPPER(CONCAT('INS-', LEFT(cp.tenant_id, 8)))
   )
 )
SET cp.insurance_company_id = ic.id
WHERE cp.insurance_company_id IS NULL
  AND cp.deleted_at IS NULL;

-- ==================== scheme_offer ====================
CREATE TABLE IF NOT EXISTS `scheme_offer` (
  `id` VARCHAR(36) NOT NULL,
  `human_friendly_id` VARCHAR(32) NULL,
  `tenant_id` VARCHAR(36) NOT NULL,
  `coverage_plan_id` VARCHAR(36) NOT NULL,
  `catalog_type` ENUM('DRUG', 'LAB_TEST', 'LAB_PANEL', 'RADIOLOGY_TEST', 'CONSULTATION', 'SERVICE') NOT NULL,
  `catalog_item_id` VARCHAR(36) NOT NULL,
  `billing_entity` ENUM('FACILITY', 'PHARMACY') NOT NULL DEFAULT 'FACILITY',
  `unit_price` DECIMAL(12, 2) NULL,
  `currency` VARCHAR(10) NULL,
  `coverage_percentage` INTEGER NULL,
  `copay_type` ENUM('NONE', 'FIXED', 'PERCENT') NOT NULL DEFAULT 'NONE',
  `copay_value` DECIMAL(12, 2) NULL,
  `requires_pre_auth` BOOLEAN NOT NULL DEFAULT false,
  `is_excluded` BOOLEAN NOT NULL DEFAULT false,
  `limit_amount` DECIMAL(12, 2) NULL,
  `limit_period` ENUM('VISIT', 'YEAR', 'ITEM') NULL,
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

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'scheme_offer'
    AND INDEX_NAME = 'scheme_offer_tenant_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `scheme_offer_tenant_id_idx` ON `scheme_offer`(`tenant_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'scheme_offer'
    AND INDEX_NAME = 'scheme_offer_coverage_plan_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `scheme_offer_coverage_plan_id_idx` ON `scheme_offer`(`coverage_plan_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'scheme_offer'
    AND INDEX_NAME = 'scheme_offer_catalog_type_catalog_item_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `scheme_offer_catalog_type_catalog_item_id_idx` ON `scheme_offer`(`catalog_type`, `catalog_item_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'scheme_offer'
    AND INDEX_NAME = 'scheme_offer_billing_entity_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `scheme_offer_billing_entity_idx` ON `scheme_offer`(`billing_entity`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'scheme_offer'
    AND INDEX_NAME = 'scheme_offer_is_excluded_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `scheme_offer_is_excluded_idx` ON `scheme_offer`(`is_excluded`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'scheme_offer'
    AND INDEX_NAME = 'scheme_offer_requires_pre_auth_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `scheme_offer_requires_pre_auth_idx` ON `scheme_offer`(`requires_pre_auth`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'scheme_offer'
    AND INDEX_NAME = 'scheme_offer_effective_from_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `scheme_offer_effective_from_idx` ON `scheme_offer`(`effective_from`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'scheme_offer'
    AND INDEX_NAME = 'scheme_offer_effective_to_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `scheme_offer_effective_to_idx` ON `scheme_offer`(`effective_to`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'scheme_offer'
    AND INDEX_NAME = 'scheme_offer_is_active_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `scheme_offer_is_active_idx` ON `scheme_offer`(`is_active`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'scheme_offer'
    AND INDEX_NAME = 'scheme_offer_deleted_at_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `scheme_offer_deleted_at_idx` ON `scheme_offer`(`deleted_at`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'scheme_offer'
    AND INDEX_NAME = 'scheme_offer_human_friendly_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `scheme_offer_human_friendly_id_idx` ON `scheme_offer`(`human_friendly_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'scheme_offer'
    AND INDEX_NAME = 'scheme_offer_lookup_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `scheme_offer_lookup_idx` ON `scheme_offer`(`coverage_plan_id`, `catalog_type`, `catalog_item_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'scheme_offer'
    AND CONSTRAINT_NAME = 'scheme_offer_tenant_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `scheme_offer` ADD CONSTRAINT `scheme_offer_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'scheme_offer'
    AND CONSTRAINT_NAME = 'scheme_offer_coverage_plan_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `scheme_offer` ADD CONSTRAINT `scheme_offer_coverage_plan_id_fkey` FOREIGN KEY (`coverage_plan_id`) REFERENCES `coverage_plan`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ==================== price_book_entry.insurance_company_id ====================
SET @col_exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'price_book_entry'
    AND COLUMN_NAME = 'insurance_company_id'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE `price_book_entry` ADD COLUMN `insurance_company_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'price_book_entry'
    AND INDEX_NAME = 'price_book_entry_insurance_company_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `price_book_entry_insurance_company_id_idx` ON `price_book_entry`(`insurance_company_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'price_book_entry'
    AND CONSTRAINT_NAME = 'price_book_entry_insurance_company_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `price_book_entry` ADD CONSTRAINT `price_book_entry_insurance_company_id_fkey` FOREIGN KEY (`insurance_company_id`) REFERENCES `insurance_company`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ==================== insurer_integration.insurance_company_id ====================
SET @col_exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'insurer_integration'
    AND COLUMN_NAME = 'insurance_company_id'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE `insurer_integration` ADD COLUMN `insurance_company_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'insurer_integration'
    AND INDEX_NAME = 'insurer_integration_insurance_company_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `insurer_integration_insurance_company_id_idx` ON `insurer_integration`(`insurance_company_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'insurer_integration'
    AND CONSTRAINT_NAME = 'insurer_integration_insurance_company_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `insurer_integration` ADD CONSTRAINT `insurer_integration_insurance_company_id_fkey` FOREIGN KEY (`insurance_company_id`) REFERENCES `insurance_company`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ==================== invoice_item offer + company ====================
SET @col_exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'invoice_item'
    AND COLUMN_NAME = 'scheme_offer_id'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE `invoice_item` ADD COLUMN `scheme_offer_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'invoice_item'
    AND COLUMN_NAME = 'insurance_company_id'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE `invoice_item` ADD COLUMN `insurance_company_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'invoice_item'
    AND INDEX_NAME = 'invoice_item_scheme_offer_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `invoice_item_scheme_offer_id_idx` ON `invoice_item`(`scheme_offer_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'invoice_item'
    AND INDEX_NAME = 'invoice_item_insurance_company_id_idx'
);
SET @sql := IF(@idx_exists = 0,
  'CREATE INDEX `invoice_item_insurance_company_id_idx` ON `invoice_item`(`insurance_company_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'invoice_item'
    AND CONSTRAINT_NAME = 'invoice_item_scheme_offer_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `invoice_item` ADD CONSTRAINT `invoice_item_scheme_offer_id_fkey` FOREIGN KEY (`scheme_offer_id`) REFERENCES `scheme_offer`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'invoice_item'
    AND CONSTRAINT_NAME = 'invoice_item_insurance_company_id_fkey'
);
SET @sql := IF(@fk_exists = 0,
  'ALTER TABLE `invoice_item` ADD CONSTRAINT `invoice_item_insurance_company_id_fkey` FOREIGN KEY (`insurance_company_id`) REFERENCES `insurance_company`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
