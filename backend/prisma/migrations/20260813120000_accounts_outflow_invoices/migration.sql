-- Accounts facility outflow invoices (Accounts desk Invoices tab; not Billing patient invoices).

CREATE TABLE `accounts_invoice` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `payee` VARCHAR(255) NOT NULL,
    `invoice_date` DATETIME(3) NOT NULL,
    `reference` VARCHAR(120) NULL,
    `notes` VARCHAR(500) NULL,
    `currency` VARCHAR(10) NOT NULL,
    `status` ENUM('DRAFT', 'ISSUED', 'VOIDED') NOT NULL DEFAULT 'DRAFT',
    `total_amount` DECIMAL(12, 2) NOT NULL,
    `void_reason` VARCHAR(500) NULL,
    `voided_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `accounts_invoice_tenant_id_idx`(`tenant_id`),
    INDEX `accounts_invoice_facility_id_idx`(`facility_id`),
    INDEX `accounts_invoice_status_idx`(`status`),
    INDEX `accounts_invoice_invoice_date_idx`(`invoice_date`),
    INDEX `accounts_invoice_payee_idx`(`payee`),
    INDEX `accounts_invoice_deleted_at_idx`(`deleted_at`),
    INDEX `accounts_invoice_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `accounts_invoice_item` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `accounts_invoice_id` VARCHAR(36) NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `description` VARCHAR(500) NULL,
    `quantity` DECIMAL(12, 2) NOT NULL,
    `unit_price` DECIMAL(12, 2) NOT NULL,
    `line_total` DECIMAL(12, 2) NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `accounts_invoice_item_accounts_invoice_id_idx`(`accounts_invoice_id`),
    INDEX `accounts_invoice_item_deleted_at_idx`(`deleted_at`),
    INDEX `accounts_invoice_item_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE `accounts_invoice` ADD CONSTRAINT `accounts_invoice_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE `accounts_invoice` ADD CONSTRAINT `accounts_invoice_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE `accounts_invoice_item` ADD CONSTRAINT `accounts_invoice_item_accounts_invoice_id_fkey` FOREIGN KEY (`accounts_invoice_id`) REFERENCES `accounts_invoice`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
