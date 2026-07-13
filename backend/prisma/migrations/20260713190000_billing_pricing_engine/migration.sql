-- Billing & pricing engine: multi-tier price book, enrollments, billing entities, insurer adapters

ALTER TABLE `invoice`
  ADD COLUMN `billing_entity` ENUM('FACILITY', 'PHARMACY') NOT NULL DEFAULT 'FACILITY';

CREATE INDEX `invoice_billing_entity_idx` ON `invoice`(`billing_entity`);

ALTER TABLE `invoice_item`
  ADD COLUMN `catalog_type` ENUM('DRUG', 'LAB_TEST', 'LAB_PANEL', 'RADIOLOGY_TEST', 'CONSULTATION', 'SERVICE') NULL,
  ADD COLUMN `catalog_item_id` VARCHAR(36) NULL,
  ADD COLUMN `price_book_entry_id` VARCHAR(36) NULL,
  ADD COLUMN `payment_mode` ENUM('SELF_PAY', 'INSURANCE') NULL,
  ADD COLUMN `coverage_plan_id` VARCHAR(36) NULL,
  ADD COLUMN `billing_entity` ENUM('FACILITY', 'PHARMACY') NULL,
  ADD COLUMN `price_source` VARCHAR(20) NULL,
  ADD COLUMN `patient_share` DECIMAL(12, 2) NULL,
  ADD COLUMN `insurer_share` DECIMAL(12, 2) NULL,
  ADD COLUMN `copay_amount` DECIMAL(12, 2) NULL;

CREATE INDEX `invoice_item_catalog_type_catalog_item_id_idx` ON `invoice_item`(`catalog_type`, `catalog_item_id`);
CREATE INDEX `invoice_item_price_book_entry_id_idx` ON `invoice_item`(`price_book_entry_id`);
CREATE INDEX `invoice_item_coverage_plan_id_idx` ON `invoice_item`(`coverage_plan_id`);

ALTER TABLE `payment`
  ADD COLUMN `billing_entity` ENUM('FACILITY', 'PHARMACY') NOT NULL DEFAULT 'FACILITY';

CREATE INDEX `payment_billing_entity_idx` ON `payment`(`billing_entity`);

ALTER TABLE `shift_close`
  ADD COLUMN `billing_entity` ENUM('FACILITY', 'PHARMACY') NOT NULL DEFAULT 'FACILITY';

CREATE INDEX `shift_close_billing_entity_idx` ON `shift_close`(`billing_entity`);

ALTER TABLE `day_close`
  ADD COLUMN `billing_entity` ENUM('FACILITY', 'PHARMACY') NOT NULL DEFAULT 'FACILITY';

CREATE INDEX `day_close_billing_entity_idx` ON `day_close`(`billing_entity`);

CREATE INDEX `coverage_plan_provider_name_idx` ON `coverage_plan`(`provider_name`);

CREATE TABLE `price_book_entry` (
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

CREATE INDEX `price_book_entry_tenant_id_idx` ON `price_book_entry`(`tenant_id`);
CREATE INDEX `price_book_entry_facility_id_idx` ON `price_book_entry`(`facility_id`);
CREATE INDEX `price_book_entry_catalog_type_catalog_item_id_idx` ON `price_book_entry`(`catalog_type`, `catalog_item_id`);
CREATE INDEX `price_book_entry_payment_mode_idx` ON `price_book_entry`(`payment_mode`);
CREATE INDEX `price_book_entry_coverage_plan_id_idx` ON `price_book_entry`(`coverage_plan_id`);
CREATE INDEX `price_book_entry_insurer_key_idx` ON `price_book_entry`(`insurer_key`);
CREATE INDEX `price_book_entry_billing_entity_idx` ON `price_book_entry`(`billing_entity`);
CREATE INDEX `price_book_entry_effective_from_idx` ON `price_book_entry`(`effective_from`);
CREATE INDEX `price_book_entry_effective_to_idx` ON `price_book_entry`(`effective_to`);
CREATE INDEX `price_book_entry_is_active_idx` ON `price_book_entry`(`is_active`);
CREATE INDEX `price_book_entry_deleted_at_idx` ON `price_book_entry`(`deleted_at`);
CREATE INDEX `price_book_entry_human_friendly_id_idx` ON `price_book_entry`(`human_friendly_id`);
CREATE INDEX `price_book_entry_lookup_idx` ON `price_book_entry`(`tenant_id`, `facility_id`, `catalog_type`, `catalog_item_id`, `payment_mode`, `billing_entity`);

ALTER TABLE `price_book_entry` ADD CONSTRAINT `price_book_entry_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE `price_book_entry` ADD CONSTRAINT `price_book_entry_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE `price_book_entry` ADD CONSTRAINT `price_book_entry_coverage_plan_id_fkey` FOREIGN KEY (`coverage_plan_id`) REFERENCES `coverage_plan`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE `patient_insurance_enrollment` (
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

CREATE INDEX `patient_insurance_enrollment_tenant_id_idx` ON `patient_insurance_enrollment`(`tenant_id`);
CREATE INDEX `patient_insurance_enrollment_facility_id_idx` ON `patient_insurance_enrollment`(`facility_id`);
CREATE INDEX `patient_insurance_enrollment_patient_id_idx` ON `patient_insurance_enrollment`(`patient_id`);
CREATE INDEX `patient_insurance_enrollment_coverage_plan_id_idx` ON `patient_insurance_enrollment`(`coverage_plan_id`);
CREATE INDEX `patient_insurance_enrollment_member_id_idx` ON `patient_insurance_enrollment`(`member_id`);
CREATE INDEX `patient_insurance_enrollment_status_idx` ON `patient_insurance_enrollment`(`status`);
CREATE INDEX `patient_insurance_enrollment_valid_from_idx` ON `patient_insurance_enrollment`(`valid_from`);
CREATE INDEX `patient_insurance_enrollment_valid_to_idx` ON `patient_insurance_enrollment`(`valid_to`);
CREATE INDEX `patient_insurance_enrollment_deleted_at_idx` ON `patient_insurance_enrollment`(`deleted_at`);
CREATE INDEX `patient_insurance_enrollment_human_friendly_id_idx` ON `patient_insurance_enrollment`(`human_friendly_id`);
CREATE INDEX `patient_insurance_enrollment_tenant_id_patient_id_status_idx` ON `patient_insurance_enrollment`(`tenant_id`, `patient_id`, `status`);

ALTER TABLE `patient_insurance_enrollment` ADD CONSTRAINT `patient_insurance_enrollment_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE `patient_insurance_enrollment` ADD CONSTRAINT `patient_insurance_enrollment_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE `patient_insurance_enrollment` ADD CONSTRAINT `patient_insurance_enrollment_patient_id_fkey` FOREIGN KEY (`patient_id`) REFERENCES `patient`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE `patient_insurance_enrollment` ADD CONSTRAINT `patient_insurance_enrollment_coverage_plan_id_fkey` FOREIGN KEY (`coverage_plan_id`) REFERENCES `coverage_plan`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE `insurer_integration` (
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

CREATE INDEX `insurer_integration_tenant_id_idx` ON `insurer_integration`(`tenant_id`);
CREATE INDEX `insurer_integration_facility_id_idx` ON `insurer_integration`(`facility_id`);
CREATE INDEX `insurer_integration_coverage_plan_id_idx` ON `insurer_integration`(`coverage_plan_id`);
CREATE INDEX `insurer_integration_adapter_type_idx` ON `insurer_integration`(`adapter_type`);
CREATE INDEX `insurer_integration_is_enabled_idx` ON `insurer_integration`(`is_enabled`);
CREATE INDEX `insurer_integration_deleted_at_idx` ON `insurer_integration`(`deleted_at`);
CREATE INDEX `insurer_integration_human_friendly_id_idx` ON `insurer_integration`(`human_friendly_id`);

ALTER TABLE `insurer_integration` ADD CONSTRAINT `insurer_integration_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE `insurer_integration` ADD CONSTRAINT `insurer_integration_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE `insurer_integration` ADD CONSTRAINT `insurer_integration_coverage_plan_id_fkey` FOREIGN KEY (`coverage_plan_id`) REFERENCES `coverage_plan`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE `invoice_item` ADD CONSTRAINT `invoice_item_price_book_entry_id_fkey` FOREIGN KEY (`price_book_entry_id`) REFERENCES `price_book_entry`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE `invoice_item` ADD CONSTRAINT `invoice_item_coverage_plan_id_fkey` FOREIGN KEY (`coverage_plan_id`) REFERENCES `coverage_plan`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;
