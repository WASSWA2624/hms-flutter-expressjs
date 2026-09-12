-- Currency and consultation presets.
--
-- Completes the preset model for the two domains that had no table at all:
-- currency was a bare VarChar column plus a DEFAULT_TENANT_CURRENCY constant,
-- and the consultation fee lived in `tenant.extension_json.billing`.
--
--   currency_preset / tenant_currency_adoption
--       Currencies are always platform-owned - a currency is not a tenant's to
--       invent - so there is no tenant tier here, only adoption. A tenant
--       chooses which currencies it offers and which is its default.
--
--   consultation_type / facility_consultation_type_offering
--       Follows the clinical catalogs exactly: a null tenant_id is a platform
--       preset, a tenant id is that tenant's own entry, and the facility
--       offering carries the local fee.
--
-- Additive only. Four new tables, no existing table altered and no data moved.
-- The tenant foreign keys are RESTRICT on purpose: a nullable tenant_id would
-- otherwise default to SET NULL, which on the definition tables would turn a
-- deleted tenant's private catalog into shared platform presets.

-- CreateTable
CREATE TABLE `currency_preset` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `code` VARCHAR(3) NOT NULL,
    `name` VARCHAR(120) NOT NULL,
    `symbol` VARCHAR(8) NULL,
    `decimal_places` INTEGER NOT NULL DEFAULT 2,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `sort_order` INTEGER NOT NULL DEFAULT 0,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `currency_preset_is_active_idx`(`is_active`),
    INDEX `currency_preset_sort_order_idx`(`sort_order`),
    INDEX `currency_preset_deleted_at_idx`(`deleted_at`),
    INDEX `currency_preset_human_friendly_id_idx`(`human_friendly_id`),
    UNIQUE INDEX `currency_preset_code_key`(`code`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `tenant_currency_adoption` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `currency_preset_id` VARCHAR(36) NOT NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `is_default` BOOLEAN NOT NULL DEFAULT false,
    `sort_order` INTEGER NOT NULL DEFAULT 0,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `tenant_currency_adoption_tenant_id_idx`(`tenant_id`),
    INDEX `tenant_currency_adoption_currency_preset_id_idx`(`currency_preset_id`),
    INDEX `tenant_currency_adoption_is_active_idx`(`is_active`),
    INDEX `tenant_currency_adoption_is_default_idx`(`is_default`),
    INDEX `tenant_currency_adoption_deleted_at_idx`(`deleted_at`),
    INDEX `tenant_currency_adoption_human_friendly_id_idx`(`human_friendly_id`),
    UNIQUE INDEX `tenant_currency_adoption_tenant_id_currency_preset_id_key`(`tenant_id`, `currency_preset_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `consultation_type` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NULL,
    `name` VARCHAR(160) NOT NULL,
    `code` VARCHAR(80) NULL,
    `category` VARCHAR(80) NULL,
    `description` VARCHAR(255) NULL,
    `default_duration_minutes` INTEGER NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `consultation_type_tenant_id_idx`(`tenant_id`),
    INDEX `consultation_type_code_idx`(`code`),
    INDEX `consultation_type_category_idx`(`category`),
    INDEX `consultation_type_deleted_at_idx`(`deleted_at`),
    INDEX `consultation_type_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `facility_consultation_type_offering` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NOT NULL,
    `consultation_type_id` VARCHAR(36) NOT NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `sort_order` INTEGER NOT NULL DEFAULT 0,
    `unit_price` DECIMAL(12, 2) NOT NULL,
    `currency` VARCHAR(10) NULL,
    `default_duration_minutes` INTEGER NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `facility_consultation_type_offering_tenant_id_idx`(`tenant_id`),
    INDEX `facility_consultation_type_offering_facility_id_idx`(`facility_id`),
    INDEX `facility_consultation_type_offering_consultation_type_id_idx`(`consultation_type_id`),
    INDEX `facility_consultation_type_offering_is_active_idx`(`is_active`),
    INDEX `facility_consultation_type_offering_sort_order_idx`(`sort_order`),
    INDEX `facility_consultation_type_offering_deleted_at_idx`(`deleted_at`),
    INDEX `facility_consultation_type_offering_human_friendly_id_idx`(`human_friendly_id`),
    UNIQUE INDEX `fcto_facility_type_key`(`facility_id`, `consultation_type_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `tenant_currency_adoption` ADD CONSTRAINT `tenant_currency_adoption_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `tenant_currency_adoption` ADD CONSTRAINT `tenant_currency_adoption_currency_preset_id_fkey` FOREIGN KEY (`currency_preset_id`) REFERENCES `currency_preset`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `consultation_type` ADD CONSTRAINT `consultation_type_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `facility_consultation_type_offering` ADD CONSTRAINT `facility_consultation_type_offering_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `facility_consultation_type_offering` ADD CONSTRAINT `facility_consultation_type_offering_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `facility_consultation_type_offering` ADD CONSTRAINT `facility_consultation_type_offering_consultation_type_id_fkey` FOREIGN KEY (`consultation_type_id`) REFERENCES `consultation_type`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

