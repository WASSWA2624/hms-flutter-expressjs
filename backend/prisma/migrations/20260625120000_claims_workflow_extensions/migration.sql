-- Extend pre-authorization and insurance claim records for encounter linkage and settlement tracking.

ALTER TABLE `pre_authorization`
  ADD COLUMN `patient_id` VARCHAR(36) NULL,
  ADD COLUMN `encounter_id` VARCHAR(36) NULL,
  ADD COLUMN `admission_id` VARCHAR(36) NULL,
  ADD COLUMN `reason` VARCHAR(120) NULL,
  ADD COLUMN `approved_amount` DECIMAL(12, 2) NULL,
  ADD COLUMN `consumed_amount` DECIMAL(12, 2) NULL,
  ADD COLUMN `notes` TEXT NULL;

ALTER TABLE `pre_authorization`
  ADD INDEX `pre_authorization_patient_id_idx` (`patient_id`),
  ADD INDEX `pre_authorization_encounter_id_idx` (`encounter_id`),
  ADD INDEX `pre_authorization_admission_id_idx` (`admission_id`);

ALTER TABLE `pre_authorization`
  ADD CONSTRAINT `pre_authorization_patient_id_fkey`
    FOREIGN KEY (`patient_id`) REFERENCES `patient`(`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `pre_authorization_encounter_id_fkey`
    FOREIGN KEY (`encounter_id`) REFERENCES `encounter`(`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `pre_authorization_admission_id_fkey`
    FOREIGN KEY (`admission_id`) REFERENCES `admission`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE `insurance_claim`
  ADD COLUMN `settlement_amount` DECIMAL(12, 2) NULL,
  ADD COLUMN `payer_reference` VARCHAR(120) NULL,
  ADD COLUMN `notes` TEXT NULL,
  ADD COLUMN `resubmitted_at` DATETIME(3) NULL;
