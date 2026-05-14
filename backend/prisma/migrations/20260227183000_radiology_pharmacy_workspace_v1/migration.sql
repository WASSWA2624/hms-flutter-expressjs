-- Radiology + Pharmacy workspace v1 schema changes

ALTER TABLE `dispense_log`
  ADD COLUMN `dispense_batch_ref` VARCHAR(64) NULL;

CREATE INDEX `dispense_log_dispense_batch_ref_idx` ON `dispense_log`(`dispense_batch_ref`);

CREATE TABLE `radiology_result_attestation` (
  `id` VARCHAR(36) NOT NULL,
  `human_friendly_id` VARCHAR(32) NULL,
  `radiology_result_id` VARCHAR(36) NOT NULL,
  `phase` ENUM('REQUEST', 'ATTEST') NOT NULL,
  `attested_by_user_id` VARCHAR(36) NOT NULL,
  `attested_role` VARCHAR(80) NULL,
  `statement` TEXT NULL,
  `reason` VARCHAR(255) NULL,
  `ip_address` VARCHAR(64) NULL,
  `attested_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  `deleted_at` DATETIME(3) NULL,
  `version` INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `radiology_result_attestation_radiology_result_id_phase_key` (`radiology_result_id`, `phase`),
  INDEX `radiology_result_attestation_radiology_result_id_idx` (`radiology_result_id`),
  INDEX `radiology_result_attestation_phase_idx` (`phase`),
  INDEX `radiology_result_attestation_attested_by_user_id_idx` (`attested_by_user_id`),
  INDEX `radiology_result_attestation_deleted_at_idx` (`deleted_at`),
  INDEX `radiology_result_attestation_human_friendly_id_idx` (`human_friendly_id`),
  CONSTRAINT `radiology_result_attestation_radiology_result_id_fkey`
    FOREIGN KEY (`radiology_result_id`) REFERENCES `radiology_result`(`id`)
    ON DELETE RESTRICT ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `pharmacy_dispense_attestation` (
  `id` VARCHAR(36) NOT NULL,
  `human_friendly_id` VARCHAR(32) NULL,
  `pharmacy_order_id` VARCHAR(36) NOT NULL,
  `dispense_batch_ref` VARCHAR(64) NOT NULL,
  `phase` ENUM('PREPARE', 'ATTEST') NOT NULL,
  `attested_by_user_id` VARCHAR(36) NOT NULL,
  `attested_role` VARCHAR(80) NULL,
  `statement` TEXT NULL,
  `reason` VARCHAR(255) NULL,
  `ip_address` VARCHAR(64) NULL,
  `attested_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  `deleted_at` DATETIME(3) NULL,
  `version` INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `pharmacy_dispense_attestation_order_batch_phase_key` (`pharmacy_order_id`, `dispense_batch_ref`, `phase`),
  INDEX `pharmacy_dispense_attestation_pharmacy_order_id_idx` (`pharmacy_order_id`),
  INDEX `pharmacy_dispense_attestation_dispense_batch_ref_idx` (`dispense_batch_ref`),
  INDEX `pharmacy_dispense_attestation_phase_idx` (`phase`),
  INDEX `pharmacy_dispense_attestation_attested_by_user_id_idx` (`attested_by_user_id`),
  INDEX `pharmacy_dispense_attestation_deleted_at_idx` (`deleted_at`),
  INDEX `pharmacy_dispense_attestation_human_friendly_id_idx` (`human_friendly_id`),
  CONSTRAINT `pharmacy_dispense_attestation_pharmacy_order_id_fkey`
    FOREIGN KEY (`pharmacy_order_id`) REFERENCES `pharmacy_order`(`id`)
    ON DELETE RESTRICT ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `drug_inventory_map` (
  `id` VARCHAR(36) NOT NULL,
  `human_friendly_id` VARCHAR(32) NULL,
  `tenant_id` VARCHAR(36) NOT NULL,
  `drug_id` VARCHAR(36) NOT NULL,
  `inventory_item_id` VARCHAR(36) NOT NULL,
  `is_default` BOOLEAN NOT NULL DEFAULT false,
  `deduction_factor` DECIMAL(10, 4) NOT NULL DEFAULT 1.0000,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  `deleted_at` DATETIME(3) NULL,
  `version` INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `drug_inventory_map_drug_id_inventory_item_id_key` (`drug_id`, `inventory_item_id`),
  INDEX `drug_inventory_map_tenant_id_idx` (`tenant_id`),
  INDEX `drug_inventory_map_drug_id_idx` (`drug_id`),
  INDEX `drug_inventory_map_inventory_item_id_idx` (`inventory_item_id`),
  INDEX `drug_inventory_map_is_default_idx` (`is_default`),
  INDEX `drug_inventory_map_deleted_at_idx` (`deleted_at`),
  INDEX `drug_inventory_map_human_friendly_id_idx` (`human_friendly_id`),
  CONSTRAINT `drug_inventory_map_drug_id_fkey`
    FOREIGN KEY (`drug_id`) REFERENCES `drug`(`id`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `drug_inventory_map_inventory_item_id_fkey`
    FOREIGN KEY (`inventory_item_id`) REFERENCES `inventory_item`(`id`)
    ON DELETE RESTRICT ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
