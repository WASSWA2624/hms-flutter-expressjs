-- Clinical request-time billing snapshots and catalog unit prices
ALTER TABLE `lab_order`
  ADD COLUMN `billing_snapshot` JSON NULL AFTER `ordered_by_user_id`;

ALTER TABLE `pharmacy_order`
  ADD COLUMN `billing_snapshot` JSON NULL AFTER `status`;

ALTER TABLE `lab_test`
  ADD COLUMN `unit_price` DECIMAL(12, 2) NULL AFTER `reference_range`,
  ADD COLUMN `currency` VARCHAR(10) NULL AFTER `unit_price`;

ALTER TABLE `lab_panel`
  ADD COLUMN `unit_price` DECIMAL(12, 2) NULL AFTER `description`,
  ADD COLUMN `currency` VARCHAR(10) NULL AFTER `unit_price`;

ALTER TABLE `radiology_test`
  ADD COLUMN `unit_price` DECIMAL(12, 2) NULL AFTER `modality`,
  ADD COLUMN `currency` VARCHAR(10) NULL AFTER `unit_price`;

ALTER TABLE `drug`
  ADD COLUMN `unit_price` DECIMAL(12, 2) NULL AFTER `strength`,
  ADD COLUMN `currency` VARCHAR(10) NULL AFTER `unit_price`;
