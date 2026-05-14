-- AlterTable
ALTER TABLE `tenant` ADD COLUMN `configuration_version_id` VARCHAR(36) NULL,
    ADD COLUMN `extension_json` JSON NULL;

-- AlterTable
ALTER TABLE `facility` ADD COLUMN `configuration_version_id` VARCHAR(36) NULL,
    ADD COLUMN `extension_json` JSON NULL;

-- AlterTable
ALTER TABLE `patient` ADD COLUMN `configuration_version_id` VARCHAR(36) NULL,
    ADD COLUMN `extension_json` JSON NULL;

-- AlterTable
ALTER TABLE `encounter` ADD COLUMN `configuration_version_id` VARCHAR(36) NULL,
    ADD COLUMN `extension_json` JSON NULL;

-- AlterTable
ALTER TABLE `pricing_rule` ADD COLUMN `configuration_version_id` VARCHAR(36) NULL,
    ADD COLUMN `extension_json` JSON NULL;

-- AlterTable
ALTER TABLE `subscription_plan` ADD COLUMN `add_on_eligibility_json` JSON NULL,
    ADD COLUMN `code` VARCHAR(80) NULL,
    ADD COLUMN `configuration_version_id` VARCHAR(36) NULL,
    ADD COLUMN `extension_json` JSON NULL,
    ADD COLUMN `limit_policy_json` JSON NULL,
    ADD COLUMN `max_facilities` INTEGER NULL,
    ADD COLUMN `max_modules` INTEGER NULL,
    ADD COLUMN `max_storage_mb` INTEGER NULL,
    ADD COLUMN `max_users` INTEGER NULL,
    ADD COLUMN `plan_fit_warning_percent` INTEGER NOT NULL DEFAULT 80,
    ADD COLUMN `tier_code` ENUM('FREE', 'BASIC', 'PRO', 'ADVANCED', 'CUSTOM') NULL;

-- AlterTable
ALTER TABLE `subscription` ADD COLUMN `change_effective_at` DATETIME(3) NULL,
    ADD COLUMN `change_requested_at` DATETIME(3) NULL,
    ADD COLUMN `change_status` ENUM('NONE', 'PENDING_UPGRADE', 'PENDING_DOWNGRADE', 'PRORATION_PENDING', 'APPLIED', 'CANCELLED') NOT NULL DEFAULT 'NONE',
    ADD COLUMN `configuration_version_id` VARCHAR(36) NULL,
    ADD COLUMN `entitlement_snapshot_json` JSON NULL,
    ADD COLUMN `etag` VARCHAR(128) NULL,
    ADD COLUMN `extension_json` JSON NULL,
    ADD COLUMN `facilities_used` INTEGER NULL,
    ADD COLUMN `modules_used` INTEGER NULL,
    ADD COLUMN `pending_plan_id` VARCHAR(36) NULL,
    ADD COLUMN `plan_fit_evaluated_at` DATETIME(3) NULL,
    ADD COLUMN `plan_fit_status` ENUM('HEALTHY', 'APPROACHING_LIMIT', 'EXCEEDED') NOT NULL DEFAULT 'HEALTHY',
    ADD COLUMN `proration_amount` DECIMAL(12, 2) NULL,
    ADD COLUMN `proration_currency_code` VARCHAR(3) NULL,
    ADD COLUMN `storage_used_mb` INTEGER NULL,
    ADD COLUMN `users_used` INTEGER NULL;

-- AlterTable
ALTER TABLE `module` ADD COLUMN `add_on_billing_cycle` ENUM('MONTHLY', 'QUARTERLY', 'YEARLY') NULL,
    ADD COLUMN `add_on_price` DECIMAL(12, 2) NULL,
    ADD COLUMN `configuration_version_id` VARCHAR(36) NULL,
    ADD COLUMN `entitlement_policy_json` JSON NULL,
    ADD COLUMN `extension_json` JSON NULL,
    ADD COLUMN `is_add_on` BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN `minimum_plan_tier_code` ENUM('FREE', 'BASIC', 'PRO', 'ADVANCED', 'CUSTOM') NULL,
    ADD COLUMN `module_group` INTEGER NULL,
    ADD COLUMN `slug` VARCHAR(120) NULL;

-- AlterTable
ALTER TABLE `module_subscription` ADD COLUMN `activated_at` DATETIME(3) NULL,
    ADD COLUMN `activation_requested_at` DATETIME(3) NULL,
    ADD COLUMN `configuration_version_id` VARCHAR(36) NULL,
    ADD COLUMN `deactivated_at` DATETIME(3) NULL,
    ADD COLUMN `eligibility_checked_at` DATETIME(3) NULL,
    ADD COLUMN `entitlement_denial_reason` VARCHAR(120) NULL,
    ADD COLUMN `entitlement_denied` BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN `etag` VARCHAR(128) NULL,
    ADD COLUMN `evaluated_plan_fit_status` ENUM('HEALTHY', 'APPROACHING_LIMIT', 'EXCEEDED') NULL,
    ADD COLUMN `extension_json` JSON NULL;

-- AlterTable
ALTER TABLE `license` ADD COLUMN `configuration_version_id` VARCHAR(36) NULL,
    ADD COLUMN `entitlement_snapshot_json` JSON NULL,
    ADD COLUMN `extension_json` JSON NULL,
    ADD COLUMN `plan_tier_code` ENUM('FREE', 'BASIC', 'PRO', 'ADVANCED', 'CUSTOM') NULL;

-- CreateTable
CREATE TABLE `configuration_snapshot` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NULL,
    `resource_type` VARCHAR(120) NOT NULL,
    `resource_id` VARCHAR(36) NOT NULL,
    `configuration_version` INTEGER NOT NULL,
    `snapshot_json` JSON NOT NULL,
    `checksum` VARCHAR(128) NULL,
    `is_immutable` BOOLEAN NOT NULL DEFAULT true,
    `created_by_user_id` VARCHAR(36) NULL,
    `superseded_by_snapshot_id` VARCHAR(36) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `configuration_snapshot_tenant_id_idx`(`tenant_id`),
    INDEX `configuration_snapshot_resource_type_idx`(`resource_type`),
    INDEX `configuration_snapshot_resource_id_idx`(`resource_id`),
    INDEX `configuration_snapshot_created_by_user_id_idx`(`created_by_user_id`),
    INDEX `configuration_snapshot_superseded_by_snapshot_id_idx`(`superseded_by_snapshot_id`),
    INDEX `configuration_snapshot_deleted_at_idx`(`deleted_at`),
    INDEX `configuration_snapshot_human_friendly_id_idx`(`human_friendly_id`),
    UNIQUE INDEX `configuration_snapshot_resource_type_resource_id_configurati_key`(`resource_type`, `resource_id`, `configuration_version`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateIndex
CREATE INDEX `tenant_configuration_version_id_idx` ON `tenant`(`configuration_version_id`);

-- CreateIndex
CREATE INDEX `facility_configuration_version_id_idx` ON `facility`(`configuration_version_id`);

-- CreateIndex
CREATE INDEX `patient_configuration_version_id_idx` ON `patient`(`configuration_version_id`);

-- CreateIndex
CREATE INDEX `encounter_configuration_version_id_idx` ON `encounter`(`configuration_version_id`);

-- CreateIndex
CREATE INDEX `pricing_rule_configuration_version_id_idx` ON `pricing_rule`(`configuration_version_id`);

-- CreateIndex
CREATE INDEX `subscription_plan_code_idx` ON `subscription_plan`(`code`);

-- CreateIndex
CREATE INDEX `subscription_plan_tier_code_idx` ON `subscription_plan`(`tier_code`);

-- CreateIndex
CREATE INDEX `subscription_plan_configuration_version_id_idx` ON `subscription_plan`(`configuration_version_id`);

-- CreateIndex
CREATE UNIQUE INDEX `subscription_plan_tenant_id_code_key` ON `subscription_plan`(`tenant_id`, `code`);

-- CreateIndex
CREATE INDEX `subscription_pending_plan_id_idx` ON `subscription`(`pending_plan_id`);

-- CreateIndex
CREATE INDEX `subscription_change_status_idx` ON `subscription`(`change_status`);

-- CreateIndex
CREATE INDEX `subscription_plan_fit_status_idx` ON `subscription`(`plan_fit_status`);

-- CreateIndex
CREATE INDEX `subscription_change_requested_at_idx` ON `subscription`(`change_requested_at`);

-- CreateIndex
CREATE INDEX `subscription_plan_fit_evaluated_at_idx` ON `subscription`(`plan_fit_evaluated_at`);

-- CreateIndex
CREATE INDEX `subscription_configuration_version_id_idx` ON `subscription`(`configuration_version_id`);

-- CreateIndex
CREATE INDEX `module_slug_idx` ON `module`(`slug`);

-- CreateIndex
CREATE INDEX `module_module_group_idx` ON `module`(`module_group`);

-- CreateIndex
CREATE INDEX `module_minimum_plan_tier_code_idx` ON `module`(`minimum_plan_tier_code`);

-- CreateIndex
CREATE INDEX `module_is_add_on_idx` ON `module`(`is_add_on`);

-- CreateIndex
CREATE INDEX `module_configuration_version_id_idx` ON `module`(`configuration_version_id`);

-- CreateIndex
CREATE UNIQUE INDEX `module_slug_key` ON `module`(`slug`);

-- CreateIndex
CREATE INDEX `module_subscription_entitlement_denied_idx` ON `module_subscription`(`entitlement_denied`);

-- CreateIndex
CREATE INDEX `module_subscription_evaluated_plan_fit_status_idx` ON `module_subscription`(`evaluated_plan_fit_status`);

-- CreateIndex
CREATE INDEX `module_subscription_eligibility_checked_at_idx` ON `module_subscription`(`eligibility_checked_at`);

-- CreateIndex
CREATE INDEX `module_subscription_configuration_version_id_idx` ON `module_subscription`(`configuration_version_id`);

-- CreateIndex
CREATE INDEX `license_plan_tier_code_idx` ON `license`(`plan_tier_code`);

-- CreateIndex
CREATE INDEX `license_configuration_version_id_idx` ON `license`(`configuration_version_id`);

-- AddForeignKey
ALTER TABLE `subscription` ADD CONSTRAINT `subscription_pending_plan_id_fkey` FOREIGN KEY (`pending_plan_id`) REFERENCES `subscription_plan`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `configuration_snapshot` ADD CONSTRAINT `configuration_snapshot_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `configuration_snapshot` ADD CONSTRAINT `configuration_snapshot_created_by_user_id_fkey` FOREIGN KEY (`created_by_user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `configuration_snapshot` ADD CONSTRAINT `configuration_snapshot_superseded_by_snapshot_id_fkey` FOREIGN KEY (`superseded_by_snapshot_id`) REFERENCES `configuration_snapshot`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;


