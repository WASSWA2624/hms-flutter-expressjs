-- CreateTable
CREATE TABLE `nurse_roster` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `department_id` VARCHAR(36) NULL,
    `period_start` DATETIME(3) NOT NULL,
    `period_end` DATETIME(3) NOT NULL,
    `status` ENUM('DRAFT', 'PUBLISHED') NOT NULL DEFAULT 'DRAFT',
    `constraints` JSON NULL,
    `published_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `nurse_roster_tenant_id_idx`(`tenant_id`),
    INDEX `nurse_roster_facility_id_idx`(`facility_id`),
    INDEX `nurse_roster_department_id_idx`(`department_id`),
    INDEX `nurse_roster_period_start_idx`(`period_start`),
    INDEX `nurse_roster_period_end_idx`(`period_end`),
    INDEX `nurse_roster_status_idx`(`status`),
    INDEX `nurse_roster_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `nurse_roster` ADD CONSTRAINT `nurse_roster_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `nurse_roster` ADD CONSTRAINT `nurse_roster_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `nurse_roster` ADD CONSTRAINT `nurse_roster_department_id_fkey` FOREIGN KEY (`department_id`) REFERENCES `department`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;
