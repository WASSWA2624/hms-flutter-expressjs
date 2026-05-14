-- Refine clinician pharmacy-order prescription lines.
-- Adds structured dose, duration, instructions, and custom prescription fields.
-- Also supports subcutaneous (SC) medication routes.

ALTER TABLE `pharmacy_order_item`
  MODIFY COLUMN `route` ENUM('ORAL', 'IV', 'IM', 'SC', 'TOPICAL', 'INHALATION', 'OTHER') NULL,
  ADD COLUMN `dose_amount` DECIMAL(10, 2) NULL AFTER `dosage`,
  ADD COLUMN `dose_unit` VARCHAR(32) NULL AFTER `dose_amount`,
  ADD COLUMN `duration_value` INTEGER NULL AFTER `route`,
  ADD COLUMN `duration_unit` VARCHAR(32) NULL AFTER `duration_value`,
  ADD COLUMN `duration` VARCHAR(80) NULL AFTER `duration_unit`,
  ADD COLUMN `instructions` TEXT NULL AFTER `duration`,
  ADD COLUMN `custom_prescription` TEXT NULL AFTER `instructions`;
