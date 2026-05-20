-- Allow patient registration without a surname.

ALTER TABLE `patient`
  MODIFY COLUMN `last_name` VARCHAR(120) NULL;
