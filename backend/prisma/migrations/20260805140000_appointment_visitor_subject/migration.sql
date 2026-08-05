-- AlterEnum
ALTER TABLE `appointment` MODIFY COLUMN `patient_id` VARCHAR(36) NULL;

-- CreateEnum
-- MySQL: add AppointmentSubjectType via column with default
ALTER TABLE `appointment`
  ADD COLUMN `subject_type` ENUM('PATIENT', 'VISITOR') NOT NULL DEFAULT 'PATIENT',
  ADD COLUMN `visitor_name` VARCHAR(160) NULL,
  ADD COLUMN `visitor_phone` VARCHAR(40) NULL,
  ADD COLUMN `visitor_email` VARCHAR(160) NULL,
  ADD COLUMN `visitor_organization` VARCHAR(160) NULL;

CREATE INDEX `appointment_subject_type_idx` ON `appointment`(`subject_type`);
