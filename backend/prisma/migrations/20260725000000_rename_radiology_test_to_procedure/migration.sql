-- Rename radiology_test table to radiology_procedure
-- This migration renames the core catalog table and related FK columns
-- to align with the new "procedure" terminology throughout the system.
--
-- Steps:
--   1. Rename facility_radiology_test_offering → facility_radiology_procedure_offering
--   2. Rename the FK column radiology_test_id → radiology_procedure_id in that table
--   3. Rename radiology_test → radiology_procedure
--   4. Rename FK column radiology_test_id → radiology_procedure_id in radiology_order
--
-- Backward compatibility: the old route /api/v1/radiology-tests remains as an alias.
-- Existing STD_RAD_TEST_ prefixed IDs remain valid (new records may use STD_RAD_PROCEDURE_).

-- Step 1: Drop FK constraints referencing radiology_test from facility table
ALTER TABLE `facility_radiology_test_offering`
  DROP FOREIGN KEY IF EXISTS `facility_radiology_test_offering_radiology_test_id_fkey`;

ALTER TABLE `facility_radiology_test_offering`
  DROP FOREIGN KEY IF EXISTS `frto_radiology_test_fk`;

-- Step 2: Rename the column in facility offering table
ALTER TABLE `facility_radiology_test_offering`
  CHANGE COLUMN `radiology_test_id` `radiology_procedure_id` VARCHAR(36) NOT NULL;

-- Step 3: Drop unique key on old column name and recreate
ALTER TABLE `facility_radiology_test_offering`
  DROP INDEX IF EXISTS `frto_facility_test_key`;

ALTER TABLE `facility_radiology_test_offering`
  ADD UNIQUE INDEX `frpo_facility_procedure_key` (`facility_id`, `radiology_procedure_id`);

-- Step 4: Rename the index on old column
ALTER TABLE `facility_radiology_test_offering`
  DROP INDEX IF EXISTS `facility_radiology_test_offering_radiology_test_id_idx`;

ALTER TABLE `facility_radiology_test_offering`
  ADD INDEX `facility_radiology_procedure_offering_radiology_procedure_id_idx` (`radiology_procedure_id`);

-- Step 5: Rename the facility_radiology_test_offering table
RENAME TABLE `facility_radiology_test_offering` TO `facility_radiology_procedure_offering`;

-- Step 6: Drop FK on radiology_order referencing radiology_test
ALTER TABLE `radiology_order`
  DROP FOREIGN KEY IF EXISTS `radiology_order_radiology_test_id_fkey`;

ALTER TABLE `radiology_order`
  DROP FOREIGN KEY IF EXISTS `ro_radiology_test_fk`;

-- Step 7: Rename the FK column in radiology_order
ALTER TABLE `radiology_order`
  CHANGE COLUMN `radiology_test_id` `radiology_procedure_id` VARCHAR(36) NULL;

-- Step 8: Rename index on radiology_order
ALTER TABLE `radiology_order`
  DROP INDEX IF EXISTS `radiology_order_radiology_test_id_idx`;

ALTER TABLE `radiology_order`
  ADD INDEX `radiology_order_radiology_procedure_id_idx` (`radiology_procedure_id`);

-- Step 9: Rename radiology_test table to radiology_procedure
RENAME TABLE `radiology_test` TO `radiology_procedure`;

-- Step 10: Re-add FK from facility_radiology_procedure_offering to radiology_procedure
ALTER TABLE `facility_radiology_procedure_offering`
  ADD CONSTRAINT `frpo_radiology_procedure_fk`
  FOREIGN KEY (`radiology_procedure_id`) REFERENCES `radiology_procedure` (`id`);

-- Step 11: Re-add FK from radiology_order to radiology_procedure
ALTER TABLE `radiology_order`
  ADD CONSTRAINT `radiology_order_radiology_procedure_id_fkey`
  FOREIGN KEY (`radiology_procedure_id`) REFERENCES `radiology_procedure` (`id`);
