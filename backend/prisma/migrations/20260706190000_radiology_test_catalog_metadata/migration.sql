-- Structured radiology catalog metadata for facility imaging offerings.
ALTER TABLE `radiology_test`
  ADD COLUMN `body_region` VARCHAR(120) NULL AFTER `modality`,
  ADD COLUMN `laterality` VARCHAR(40) NULL AFTER `body_region`,
  ADD COLUMN `equipment` VARCHAR(120) NULL AFTER `laterality`,
  ADD COLUMN `procedure_type` VARCHAR(120) NULL AFTER `equipment`;

CREATE INDEX `radiology_test_body_region_idx` ON `radiology_test`(`body_region`);
