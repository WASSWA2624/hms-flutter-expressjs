-- CreateTable
CREATE TABLE `pharmacy_storage_room` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `code` VARCHAR(80) NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `pharmacy_storage_room_tenant_id_idx`(`tenant_id`),
    INDEX `pharmacy_storage_room_facility_id_idx`(`facility_id`),
    INDEX `pharmacy_storage_room_is_active_idx`(`is_active`),
    INDEX `pharmacy_storage_room_deleted_at_idx`(`deleted_at`),
    INDEX `pharmacy_storage_room_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `pharmacy_storage_shelf` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NOT NULL,
    `storage_room_id` VARCHAR(36) NOT NULL,
    `shelf_code` VARCHAR(80) NOT NULL,
    `label` VARCHAR(120) NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `pharmacy_storage_shelf_tenant_id_idx`(`tenant_id`),
    INDEX `pharmacy_storage_shelf_facility_id_idx`(`facility_id`),
    INDEX `pharmacy_storage_shelf_storage_room_id_idx`(`storage_room_id`),
    INDEX `pharmacy_storage_shelf_is_active_idx`(`is_active`),
    INDEX `pharmacy_storage_shelf_deleted_at_idx`(`deleted_at`),
    INDEX `pharmacy_storage_shelf_human_friendly_id_idx`(`human_friendly_id`),
    UNIQUE INDEX `pharmacy_storage_shelf_storage_room_id_shelf_code_key`(`storage_room_id`, `shelf_code`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AlterTable
ALTER TABLE `drug_batch`
    ADD COLUMN `storage_room_id` VARCHAR(36) NULL,
    ADD COLUMN `storage_shelf_id` VARCHAR(36) NULL;

-- AlterTable
ALTER TABLE `facility_pharmacy_offering`
    ADD COLUMN `default_storage_shelf_id` VARCHAR(36) NULL;

-- CreateIndex
CREATE INDEX `drug_batch_storage_room_id_idx` ON `drug_batch`(`storage_room_id`);
CREATE INDEX `drug_batch_storage_shelf_id_idx` ON `drug_batch`(`storage_shelf_id`);

-- AddForeignKey
ALTER TABLE `pharmacy_storage_room` ADD CONSTRAINT `pharmacy_storage_room_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE `pharmacy_storage_room` ADD CONSTRAINT `pharmacy_storage_room_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `pharmacy_storage_shelf` ADD CONSTRAINT `pharmacy_storage_shelf_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE `pharmacy_storage_shelf` ADD CONSTRAINT `pharmacy_storage_shelf_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE `pharmacy_storage_shelf` ADD CONSTRAINT `pharmacy_storage_shelf_storage_room_id_fkey` FOREIGN KEY (`storage_room_id`) REFERENCES `pharmacy_storage_room`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `drug_batch` ADD CONSTRAINT `drug_batch_storage_room_id_fkey` FOREIGN KEY (`storage_room_id`) REFERENCES `pharmacy_storage_room`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE `drug_batch` ADD CONSTRAINT `drug_batch_storage_shelf_id_fkey` FOREIGN KEY (`storage_shelf_id`) REFERENCES `pharmacy_storage_shelf`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE `facility_pharmacy_offering` ADD CONSTRAINT `facility_pharmacy_offering_default_storage_shelf_id_fkey` FOREIGN KEY (`default_storage_shelf_id`) REFERENCES `pharmacy_storage_shelf`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;
