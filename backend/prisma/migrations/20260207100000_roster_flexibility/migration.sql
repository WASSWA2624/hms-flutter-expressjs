-- CreateTable shift_template
CREATE TABLE `shift_template` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `name` VARCHAR(120) NOT NULL,
    `shift_type` ENUM('DAY', 'NIGHT', 'SWING', 'ON_CALL') NOT NULL,
    `default_start_time` VARCHAR(10) NOT NULL,
    `default_end_time` VARCHAR(10) NOT NULL,
    `duration_minutes` INTEGER NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `shift_template_tenant_id_idx`(`tenant_id`),
    INDEX `shift_template_facility_id_idx`(`facility_id`),
    INDEX `shift_template_shift_type_idx`(`shift_type`),
    INDEX `shift_template_is_active_idx`(`is_active`),
    INDEX `shift_template_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable staff_availability
CREATE TABLE `staff_availability` (
    `id` VARCHAR(36) NOT NULL,
    `staff_profile_id` VARCHAR(36) NOT NULL,
    `day_of_week` INTEGER NOT NULL,
    `start_time` VARCHAR(10) NOT NULL,
    `end_time` VARCHAR(10) NOT NULL,
    `preference` ENUM('PREFERRED', 'AVAILABLE', 'UNAVAILABLE') NOT NULL DEFAULT 'AVAILABLE',
    `effective_from` DATETIME(3) NOT NULL,
    `effective_to` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `staff_availability_staff_profile_id_idx`(`staff_profile_id`),
    INDEX `staff_availability_day_of_week_idx`(`day_of_week`),
    INDEX `staff_availability_effective_from_idx`(`effective_from`),
    INDEX `staff_availability_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AlterTable shift - add nurse_roster_id, shift_template_id
ALTER TABLE `shift` ADD COLUMN `nurse_roster_id` VARCHAR(36) NULL,
    ADD COLUMN `shift_template_id` VARCHAR(36) NULL;

-- CreateTable roster_day_off
CREATE TABLE `roster_day_off` (
    `id` VARCHAR(36) NOT NULL,
    `nurse_roster_id` VARCHAR(36) NOT NULL,
    `staff_profile_id` VARCHAR(36) NOT NULL,
    `off_date` DATE NOT NULL,
    `reason` VARCHAR(255) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    UNIQUE INDEX `roster_day_off_nurse_roster_id_staff_profile_id_off_date_key`(`nurse_roster_id`, `staff_profile_id`, `off_date`),
    INDEX `roster_day_off_nurse_roster_id_idx`(`nurse_roster_id`),
    INDEX `roster_day_off_staff_profile_id_idx`(`staff_profile_id`),
    INDEX `roster_day_off_off_date_idx`(`off_date`),
    INDEX `roster_day_off_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey shift_template
ALTER TABLE `shift_template` ADD CONSTRAINT `shift_template_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE `shift_template` ADD CONSTRAINT `shift_template_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey staff_availability
ALTER TABLE `staff_availability` ADD CONSTRAINT `staff_availability_staff_profile_id_fkey` FOREIGN KEY (`staff_profile_id`) REFERENCES `staff_profile`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey shift
ALTER TABLE `shift` ADD CONSTRAINT `shift_nurse_roster_id_fkey` FOREIGN KEY (`nurse_roster_id`) REFERENCES `nurse_roster`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE `shift` ADD CONSTRAINT `shift_shift_template_id_fkey` FOREIGN KEY (`shift_template_id`) REFERENCES `shift_template`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey roster_day_off
ALTER TABLE `roster_day_off` ADD CONSTRAINT `roster_day_off_nurse_roster_id_fkey` FOREIGN KEY (`nurse_roster_id`) REFERENCES `nurse_roster`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE `roster_day_off` ADD CONSTRAINT `roster_day_off_staff_profile_id_fkey` FOREIGN KEY (`staff_profile_id`) REFERENCES `staff_profile`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- CreateIndex shift
CREATE INDEX `shift_nurse_roster_id_idx` ON `shift`(`nurse_roster_id`);
CREATE INDEX `shift_shift_template_id_idx` ON `shift`(`shift_template_id`);
