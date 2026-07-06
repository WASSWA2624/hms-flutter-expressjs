-- CreateTable
CREATE TABLE `facility_pharmacy_offering` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NOT NULL,
    `drug_id` VARCHAR(36) NOT NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `sort_order` INTEGER NOT NULL DEFAULT 0,
    `unit_price` DECIMAL(12, 2) NOT NULL,
    `currency` VARCHAR(10) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    UNIQUE INDEX `fpo_facility_drug_key`(`facility_id`, `drug_id`),
    INDEX `fpo_tenant_id_idx`(`tenant_id`),
    INDEX `fpo_facility_id_idx`(`facility_id`),
    INDEX `fpo_drug_id_idx`(`drug_id`),
    INDEX `fpo_is_active_idx`(`is_active`),
    INDEX `fpo_sort_order_idx`(`sort_order`),
    INDEX `fpo_deleted_at_idx`(`deleted_at`),
    INDEX `fpo_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `facility_pharmacy_offering` ADD CONSTRAINT `fpo_tenant_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `facility_pharmacy_offering` ADD CONSTRAINT `fpo_facility_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `facility_pharmacy_offering` ADD CONSTRAINT `fpo_drug_fkey` FOREIGN KEY (`drug_id`) REFERENCES `drug`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
