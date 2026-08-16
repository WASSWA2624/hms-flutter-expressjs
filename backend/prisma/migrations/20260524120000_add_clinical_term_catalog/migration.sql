-- CreateTable
CREATE TABLE `clinical_term_catalog` (
  `id` VARCHAR(36) NOT NULL,
  `human_friendly_id` VARCHAR(32) NULL,
  `tenant_id` VARCHAR(36) NOT NULL,
  `facility_id` VARCHAR(36) NULL,
  `catalog_key` VARCHAR(120) NOT NULL,
  `term_type` ENUM('DIAGNOSIS','PROCEDURE') NOT NULL,
  `code` VARCHAR(80) NULL,
  `description` TEXT NOT NULL,
  `category` VARCHAR(120) NULL,
  `source` VARCHAR(80) NULL,
  `sort_order` INTEGER NOT NULL DEFAULT 0,
  `usage_rank` INTEGER NOT NULL DEFAULT 0,
  `is_active` BOOLEAN NOT NULL DEFAULT true,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  `deleted_at` DATETIME(3) NULL,
  `version` INTEGER NOT NULL DEFAULT 1,

  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB;

-- CreateIndex
CREATE UNIQUE INDEX `clinical_term_catalog_tenant_id_term_type_catalog_key_key` ON `clinical_term_catalog`(`tenant_id`, `term_type`, `catalog_key`);
CREATE INDEX `clinical_term_catalog_tenant_id_idx` ON `clinical_term_catalog`(`tenant_id`);
CREATE INDEX `clinical_term_catalog_facility_id_idx` ON `clinical_term_catalog`(`facility_id`);
CREATE INDEX `clinical_term_catalog_term_type_idx` ON `clinical_term_catalog`(`term_type`);
CREATE INDEX `clinical_term_catalog_code_idx` ON `clinical_term_catalog`(`code`);
CREATE INDEX `clinical_term_catalog_category_idx` ON `clinical_term_catalog`(`category`);
CREATE INDEX `clinical_term_catalog_sort_order_idx` ON `clinical_term_catalog`(`sort_order`);
CREATE INDEX `clinical_term_catalog_usage_rank_idx` ON `clinical_term_catalog`(`usage_rank`);
CREATE INDEX `clinical_term_catalog_is_active_idx` ON `clinical_term_catalog`(`is_active`);
CREATE INDEX `clinical_term_catalog_deleted_at_idx` ON `clinical_term_catalog`(`deleted_at`);
CREATE INDEX `clinical_term_catalog_human_friendly_id_idx` ON `clinical_term_catalog`(`human_friendly_id`);

-- AddForeignKey
ALTER TABLE `clinical_term_catalog`
  ADD CONSTRAINT `clinical_term_catalog_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT `clinical_term_catalog_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;
