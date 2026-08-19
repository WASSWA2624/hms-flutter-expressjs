-- CreateTable
CREATE TABLE `facility_lab_test_offering` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NOT NULL,
    `lab_test_id` VARCHAR(36) NOT NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `sort_order` INTEGER NOT NULL DEFAULT 0,
    `unit_price` DECIMAL(12, 2) NOT NULL,
    `currency` VARCHAR(10) NULL,
    `specimen_type` VARCHAR(80) NULL,
    `result_kind` ENUM('NUMERIC', 'QUALITATIVE', 'TEXT') NULL,
    `unit` VARCHAR(40) NULL,
    `description` VARCHAR(255) NULL,
    `reference_range` VARCHAR(255) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    UNIQUE INDEX `facility_lab_test_offering_facility_id_lab_test_id_key`(`facility_id`, `lab_test_id`),
    INDEX `facility_lab_test_offering_tenant_id_idx`(`tenant_id`),
    INDEX `facility_lab_test_offering_facility_id_idx`(`facility_id`),
    INDEX `facility_lab_test_offering_lab_test_id_idx`(`lab_test_id`),
    INDEX `facility_lab_test_offering_is_active_idx`(`is_active`),
    INDEX `facility_lab_test_offering_sort_order_idx`(`sort_order`),
    INDEX `facility_lab_test_offering_deleted_at_idx`(`deleted_at`),
    INDEX `facility_lab_test_offering_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB;

-- CreateTable
CREATE TABLE `facility_lab_test_reference_range` (
    `id` VARCHAR(36) NOT NULL,
    `facility_lab_test_offering_id` VARCHAR(36) NOT NULL,
    `label` VARCHAR(120) NULL,
    `unit` VARCHAR(40) NULL,
    `gender` ENUM('MALE', 'FEMALE', 'OTHER', 'UNKNOWN') NULL,
    `age_min_value` INTEGER NULL,
    `age_min_unit` ENUM('DAY', 'WEEK', 'MONTH', 'YEAR') NULL,
    `age_max_value` INTEGER NULL,
    `age_max_unit` ENUM('DAY', 'WEEK', 'MONTH', 'YEAR') NULL,
    `normal_min_value` DECIMAL(12, 4) NULL,
    `normal_max_value` DECIMAL(12, 4) NULL,
    `critical_min_value` DECIMAL(12, 4) NULL,
    `critical_max_value` DECIMAL(12, 4) NULL,
    `reference_text` VARCHAR(255) NULL,
    `notes` VARCHAR(255) NULL,
    `sort_order` INTEGER NOT NULL DEFAULT 0,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,

    INDEX `fltr_offering_sort_idx`(`facility_lab_test_offering_id`, `sort_order`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB;

-- CreateTable
CREATE TABLE `facility_lab_test_unit_option` (
    `id` VARCHAR(36) NOT NULL,
    `facility_lab_test_offering_id` VARCHAR(36) NOT NULL,
    `label` VARCHAR(80) NULL,
    `unit` VARCHAR(40) NOT NULL,
    `ucum_code` VARCHAR(40) NULL,
    `is_default` BOOLEAN NOT NULL DEFAULT false,
    `sort_order` INTEGER NOT NULL DEFAULT 0,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,

    UNIQUE INDEX `fltu_offering_unit_key`(`facility_lab_test_offering_id`, `unit`),
    INDEX `fltu_offering_sort_idx`(`facility_lab_test_offering_id`, `sort_order`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB;

-- CreateTable
CREATE TABLE `facility_lab_test_result_option` (
    `id` VARCHAR(36) NOT NULL,
    `facility_lab_test_offering_id` VARCHAR(36) NOT NULL,
    `value` VARCHAR(80) NOT NULL,
    `label` VARCHAR(120) NULL,
    `aliases_json` JSON NULL,
    `status` ENUM('NORMAL', 'ABNORMAL', 'CRITICAL', 'PENDING', 'VERIFIED', 'REJECTED') NOT NULL DEFAULT 'ABNORMAL',
    `result_flag` VARCHAR(40) NULL,
    `is_positive` BOOLEAN NOT NULL DEFAULT false,
    `sort_order` INTEGER NOT NULL DEFAULT 0,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,

    UNIQUE INDEX `fltro_offering_value_key`(`facility_lab_test_offering_id`, `value`),
    INDEX `fltro_offering_sort_idx`(`facility_lab_test_offering_id`, `sort_order`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB;

-- CreateTable
CREATE TABLE `facility_lab_panel_offering` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NOT NULL,
    `lab_panel_id` VARCHAR(36) NOT NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `sort_order` INTEGER NOT NULL DEFAULT 0,
    `unit_price` DECIMAL(12, 2) NOT NULL,
    `currency` VARCHAR(10) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    UNIQUE INDEX `facility_lab_panel_offering_facility_id_lab_panel_id_key`(`facility_id`, `lab_panel_id`),
    INDEX `facility_lab_panel_offering_tenant_id_idx`(`tenant_id`),
    INDEX `facility_lab_panel_offering_facility_id_idx`(`facility_id`),
    INDEX `facility_lab_panel_offering_lab_panel_id_idx`(`lab_panel_id`),
    INDEX `facility_lab_panel_offering_is_active_idx`(`is_active`),
    INDEX `facility_lab_panel_offering_sort_order_idx`(`sort_order`),
    INDEX `facility_lab_panel_offering_deleted_at_idx`(`deleted_at`),
    INDEX `facility_lab_panel_offering_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB;

-- AddForeignKey
ALTER TABLE `facility_lab_test_offering` ADD CONSTRAINT `flto_tenant_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `facility_lab_test_offering` ADD CONSTRAINT `flto_facility_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `facility_lab_test_offering` ADD CONSTRAINT `flto_lab_test_fkey` FOREIGN KEY (`lab_test_id`) REFERENCES `lab_test`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `facility_lab_test_reference_range` ADD CONSTRAINT `fltr_offering_fkey` FOREIGN KEY (`facility_lab_test_offering_id`) REFERENCES `facility_lab_test_offering`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `facility_lab_test_unit_option` ADD CONSTRAINT `fltu_offering_fkey` FOREIGN KEY (`facility_lab_test_offering_id`) REFERENCES `facility_lab_test_offering`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `facility_lab_test_result_option` ADD CONSTRAINT `fltro_offering_fkey` FOREIGN KEY (`facility_lab_test_offering_id`) REFERENCES `facility_lab_test_offering`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `facility_lab_panel_offering` ADD CONSTRAINT `flpo_tenant_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `facility_lab_panel_offering` ADD CONSTRAINT `flpo_facility_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `facility_lab_panel_offering` ADD CONSTRAINT `flpo_lab_panel_fkey` FOREIGN KEY (`lab_panel_id`) REFERENCES `lab_panel`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
