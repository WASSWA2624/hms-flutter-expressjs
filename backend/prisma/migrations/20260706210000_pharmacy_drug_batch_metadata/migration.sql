-- AlterTable
ALTER TABLE `drug_batch` ADD COLUMN `manufactured_at` DATETIME(3) NULL,
    ADD COLUMN `expiry_alert_lead_days` INTEGER NULL;
