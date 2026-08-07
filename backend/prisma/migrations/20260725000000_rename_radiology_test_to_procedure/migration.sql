-- Rename radiology_test → radiology_procedure and related offering/order FKs.
-- Uses short constraint names (MySQL identifier limit is 64 chars).

ALTER TABLE `facility_radiology_test_offering`
  DROP FOREIGN KEY `frto_radiology_test_fkey`;

ALTER TABLE `facility_radiology_test_offering`
  DROP INDEX `frto_radiology_test_id_idx`;

ALTER TABLE `facility_radiology_test_offering`
  DROP INDEX `frto_facility_test_key`;

ALTER TABLE `facility_radiology_test_offering`
  CHANGE COLUMN `radiology_test_id` `radiology_procedure_id` VARCHAR(36) NOT NULL;

ALTER TABLE `facility_radiology_test_offering`
  ADD UNIQUE INDEX `frpo_facility_procedure_key` (`facility_id`, `radiology_procedure_id`);

ALTER TABLE `facility_radiology_test_offering`
  ADD INDEX `frpo_radiology_procedure_id_idx` (`radiology_procedure_id`);

RENAME TABLE `facility_radiology_test_offering` TO `facility_radiology_procedure_offering`;

ALTER TABLE `radiology_order`
  DROP FOREIGN KEY `radiology_order_radiology_test_id_fkey`;

ALTER TABLE `radiology_order`
  DROP INDEX `radiology_order_radiology_test_id_idx`;

ALTER TABLE `radiology_order`
  CHANGE COLUMN `radiology_test_id` `radiology_procedure_id` VARCHAR(36) NULL;

ALTER TABLE `radiology_order`
  ADD INDEX `radiology_order_radiology_procedure_id_idx` (`radiology_procedure_id`);

RENAME TABLE `radiology_test` TO `radiology_procedure`;

ALTER TABLE `facility_radiology_procedure_offering`
  ADD CONSTRAINT `frpo_radiology_procedure_fkey`
  FOREIGN KEY (`radiology_procedure_id`) REFERENCES `radiology_procedure` (`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `radiology_order`
  ADD CONSTRAINT `radiology_order_radiology_procedure_id_fkey`
  FOREIGN KEY (`radiology_procedure_id`) REFERENCES `radiology_procedure` (`id`)
  ON DELETE SET NULL ON UPDATE CASCADE;
