-- Extend clinical term types for catalog layers
ALTER TABLE `clinical_term_favorite`
  MODIFY `term_type` ENUM('DIAGNOSIS', 'PROCEDURE', 'LAB_TEST', 'RADIOLOGY_TEST', 'PRESCRIPTION') NOT NULL;

ALTER TABLE `clinical_term_catalog`
  MODIFY `term_type` ENUM('DIAGNOSIS', 'PROCEDURE', 'LAB_TEST', 'RADIOLOGY_TEST', 'PRESCRIPTION') NOT NULL;

ALTER TABLE `clinical_term_favorite`
  ADD COLUMN `item_id` VARCHAR(36) NULL AFTER `scope`;

CREATE INDEX `clinical_term_favorite_item_id_idx` ON `clinical_term_favorite`(`item_id`);

CREATE TABLE `facility_catalog_offering` (
  `id` VARCHAR(36) NOT NULL,
  `human_friendly_id` VARCHAR(32) NULL,
  `tenant_id` VARCHAR(36) NOT NULL,
  `facility_id` VARCHAR(36) NOT NULL,
  `term_type` ENUM('DIAGNOSIS', 'PROCEDURE', 'LAB_TEST', 'RADIOLOGY_TEST', 'PRESCRIPTION') NOT NULL,
  `item_id` VARCHAR(36) NOT NULL,
  `is_active` BOOLEAN NOT NULL DEFAULT true,
  `sort_order` INTEGER NOT NULL DEFAULT 0,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  `deleted_at` DATETIME(3) NULL,
  `version` INTEGER NOT NULL DEFAULT 1,

  PRIMARY KEY (`id`),
  UNIQUE INDEX `facility_catalog_offering_facility_id_term_type_item_id_key`(`facility_id`, `term_type`, `item_id`),
  INDEX `facility_catalog_offering_tenant_id_idx`(`tenant_id`),
  INDEX `facility_catalog_offering_facility_id_idx`(`facility_id`),
  INDEX `facility_catalog_offering_term_type_idx`(`term_type`),
  INDEX `facility_catalog_offering_item_id_idx`(`item_id`),
  INDEX `facility_catalog_offering_is_active_idx`(`is_active`),
  INDEX `facility_catalog_offering_sort_order_idx`(`sort_order`),
  INDEX `facility_catalog_offering_deleted_at_idx`(`deleted_at`),
  INDEX `facility_catalog_offering_human_friendly_id_idx`(`human_friendly_id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE `facility_catalog_offering`
  ADD CONSTRAINT `facility_catalog_offering_tenant_id_fkey`
    FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT `facility_catalog_offering_facility_id_fkey`
    FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
