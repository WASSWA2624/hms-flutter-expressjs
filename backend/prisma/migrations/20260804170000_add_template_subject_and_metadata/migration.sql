-- AlterTable
ALTER TABLE `template`
  ADD COLUMN `subject` VARCHAR(255) NULL AFTER `channel`,
  ADD COLUMN `description` VARCHAR(255) NULL AFTER `subject`,
  ADD COLUMN `is_active` BOOLEAN NOT NULL DEFAULT true AFTER `body`;

-- AlterTable
ALTER TABLE `template_variable`
  ADD COLUMN `sample_value` VARCHAR(255) NULL AFTER `description`;
