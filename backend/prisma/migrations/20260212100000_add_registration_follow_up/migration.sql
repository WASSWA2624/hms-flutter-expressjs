-- CreateTable
CREATE TABLE `registration_follow_up` (
    `id` VARCHAR(36) NOT NULL,
    `user_id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NULL,
    `facility_id` VARCHAR(36) NULL,
    `email` VARCHAR(255) NOT NULL,
    `phone` VARCHAR(40) NULL,
    `admin_name` VARCHAR(255) NULL,
    `facility_name` VARCHAR(255) NULL,
    `facility_type` ENUM('HOSPITAL', 'CLINIC', 'LAB', 'PHARMACY', 'OTHER') NULL,
    `location` VARCHAR(255) NULL,
    `interests` TEXT NULL,
    `account_status` ENUM('ACTIVE', 'INACTIVE', 'SUSPENDED', 'PENDING') NOT NULL,
    `locale` VARCHAR(32) NULL,
    `timezone` VARCHAR(64) NULL,
    `ip_address` VARCHAR(45) NULL,
    `user_agent` VARCHAR(255) NULL,
    `device_platform` VARCHAR(64) NULL,
    `referral_source` VARCHAR(255) NULL,
    `campaign` VARCHAR(255) NULL,
    `follow_up_metadata` JSON NULL,
    `registration_attempts` INTEGER NOT NULL DEFAULT 1,
    `first_registered_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `last_registration_attempt_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `registration_follow_up_tenant_id_idx`(`tenant_id`),
    INDEX `registration_follow_up_facility_id_idx`(`facility_id`),
    INDEX `registration_follow_up_email_idx`(`email`),
    INDEX `registration_follow_up_account_status_idx`(`account_status`),
    INDEX `registration_follow_up_last_registration_attempt_at_idx`(`last_registration_attempt_at`),
    INDEX `registration_follow_up_deleted_at_idx`(`deleted_at`),
    UNIQUE INDEX `registration_follow_up_user_id_key`(`user_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `registration_follow_up` ADD CONSTRAINT `registration_follow_up_user_id_fkey` FOREIGN KEY (`user_id`) REFERENCES `user`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `registration_follow_up` ADD CONSTRAINT `registration_follow_up_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `registration_follow_up` ADD CONSTRAINT `registration_follow_up_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;
