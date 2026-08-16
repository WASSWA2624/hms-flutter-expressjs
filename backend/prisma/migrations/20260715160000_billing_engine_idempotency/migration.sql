-- Centralized billing engine: idempotent billable charge events +
-- billing snapshots on admission / nursing note for catalogue-driven charges.

-- Admission request-time billing snapshot
SET @col_exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'admission'
    AND COLUMN_NAME = 'billing_snapshot'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE `admission` ADD COLUMN `billing_snapshot` JSON NULL AFTER `discharged_at`',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Nursing note request-time billing snapshot
SET @col_exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'nursing_note'
    AND COLUMN_NAME = 'billing_snapshot'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE `nursing_note` ADD COLUMN `billing_snapshot` JSON NULL AFTER `note`',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS `billable_charge_event` (
  `id` VARCHAR(36) NOT NULL,
  `human_friendly_id` VARCHAR(32) NULL,
  `tenant_id` VARCHAR(36) NOT NULL,
  `facility_id` VARCHAR(36) NULL,
  `patient_id` VARCHAR(36) NULL,
  `encounter_id` VARCHAR(36) NULL,
  `source_module` VARCHAR(40) NOT NULL,
  `source_id` VARCHAR(36) NOT NULL,
  `charge_key` VARCHAR(120) NOT NULL DEFAULT 'PRIMARY',
  `invoice_id` VARCHAR(36) NULL,
  `catalog_type` ENUM('DRUG', 'LAB_TEST', 'LAB_PANEL', 'RADIOLOGY_TEST', 'CONSULTATION', 'SERVICE') NULL,
  `catalog_item_id` VARCHAR(36) NULL,
  `actor_user_id` VARCHAR(36) NULL,
  `unit_price_snapshot` DECIMAL(12, 2) NULL,
  `total_amount_snapshot` DECIMAL(12, 2) NULL,
  `currency` VARCHAR(10) NULL,
  `status` VARCHAR(20) NOT NULL DEFAULT 'POSTED',
  `posted_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `reversed_at` DATETIME(3) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  `deleted_at` DATETIME(3) NULL,
  `version` INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `billable_charge_event_idempotency_uidx`(`tenant_id`, `source_module`, `source_id`, `charge_key`),
  INDEX `billable_charge_event_tenant_id_idx`(`tenant_id`),
  INDEX `billable_charge_event_facility_id_idx`(`facility_id`),
  INDEX `billable_charge_event_patient_id_idx`(`patient_id`),
  INDEX `billable_charge_event_encounter_id_idx`(`encounter_id`),
  INDEX `billable_charge_event_invoice_id_idx`(`invoice_id`),
  INDEX `billable_charge_event_source_idx`(`source_module`, `source_id`),
  INDEX `billable_charge_event_status_idx`(`status`),
  INDEX `billable_charge_event_deleted_at_idx`(`deleted_at`),
  INDEX `billable_charge_event_human_friendly_id_idx`(`human_friendly_id`),
  CONSTRAINT `billable_charge_event_tenant_id_fkey`
    FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `billable_charge_event_facility_id_fkey`
    FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `billable_charge_event_patient_id_fkey`
    FOREIGN KEY (`patient_id`) REFERENCES `patient`(`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `billable_charge_event_encounter_id_fkey`
    FOREIGN KEY (`encounter_id`) REFERENCES `encounter`(`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `billable_charge_event_invoice_id_fkey`
    FOREIGN KEY (`invoice_id`) REFERENCES `invoice`(`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `billable_charge_event_actor_user_id_fkey`
    FOREIGN KEY (`actor_user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB;
