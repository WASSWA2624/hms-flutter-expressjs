-- CreateTable
CREATE TABLE `facility_radiology_test_offering` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NOT NULL,
    `radiology_test_id` VARCHAR(36) NOT NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `sort_order` INTEGER NOT NULL DEFAULT 0,
    `unit_price` DECIMAL(12, 2) NOT NULL,
    `currency` VARCHAR(10) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    UNIQUE INDEX `frto_facility_test_key`(`facility_id`, `radiology_test_id`),
    INDEX `frto_tenant_id_idx`(`tenant_id`),
    INDEX `frto_facility_id_idx`(`facility_id`),
    INDEX `frto_radiology_test_id_idx`(`radiology_test_id`),
    INDEX `frto_is_active_idx`(`is_active`),
    INDEX `frto_sort_order_idx`(`sort_order`),
    INDEX `frto_deleted_at_idx`(`deleted_at`),
    INDEX `frto_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `facility_radiology_test_offering` ADD CONSTRAINT `frto_tenant_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `facility_radiology_test_offering` ADD CONSTRAINT `frto_facility_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `facility_radiology_test_offering` ADD CONSTRAINT `frto_radiology_test_fkey` FOREIGN KEY (`radiology_test_id`) REFERENCES `radiology_test`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
