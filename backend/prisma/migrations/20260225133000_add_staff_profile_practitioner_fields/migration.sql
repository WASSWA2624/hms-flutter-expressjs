-- AlterTable
ALTER TABLE `staff_profile`
  ADD COLUMN `practitioner_type` VARCHAR(32) NULL,
  ADD COLUMN `consultation_fee` DECIMAL(12, 2) NULL,
  ADD COLUMN `consultation_currency` VARCHAR(10) NULL,
  ADD COLUMN `is_fee_overridden` BOOLEAN NOT NULL DEFAULT false;

-- CreateIndex
CREATE INDEX `staff_profile_practitioner_type_idx` ON `staff_profile`(`practitioner_type`);
