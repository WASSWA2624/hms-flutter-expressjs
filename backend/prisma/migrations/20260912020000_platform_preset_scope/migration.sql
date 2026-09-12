-- Platform presets: let a catalog definition be owned centrally.
--
-- Master data splits into a platform-owned definition and a per-facility
-- adoption. The adoption half already exists (`facility_lab_test_offering`,
-- `facility_lab_panel_offering`, `facility_radiology_procedure_offering`,
-- `facility_pharmacy_offering`), but every definition table required a
-- `tenant_id`, so a definition could only ever belong to one tenant and each
-- tenant carried its own duplicate of the same clinical catalog.
--
-- Making `tenant_id` nullable is what creates the platform tier:
--
--   tenant_id IS NULL      a platform preset, owned centrally, readable by
--                          every tenant and writable only by a platform actor
--   tenant_id = '<id>'     that tenant's own entry, exactly as before
--
-- This is the same convention `role` and `permission` already use, so there is
-- one notion of platform scope in the schema rather than two.
--
-- Nothing is rewritten here. Every existing row keeps its `tenant_id`, so this
-- migration is behaviour-preserving on its own; the deduplication onto shared
-- platform definitions is a separate, reviewable backfill script.
--
-- Guarded with information_schema + PREPARE because the fleet spans MariaDB
-- builds without `ALTER ... MODIFY IF`, and Prisma cannot run DELIMITER.

-- `lab_test`
SET @nullable := (
  SELECT IS_NULLABLE FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'lab_test'
    AND COLUMN_NAME = 'tenant_id'
);
SET @sql := IF(@nullable = 'NO',
  'ALTER TABLE `lab_test` MODIFY COLUMN `tenant_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- `lab_panel`
SET @nullable := (
  SELECT IS_NULLABLE FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'lab_panel'
    AND COLUMN_NAME = 'tenant_id'
);
SET @sql := IF(@nullable = 'NO',
  'ALTER TABLE `lab_panel` MODIFY COLUMN `tenant_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- `radiology_procedure`
SET @nullable := (
  SELECT IS_NULLABLE FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'radiology_procedure'
    AND COLUMN_NAME = 'tenant_id'
);
SET @sql := IF(@nullable = 'NO',
  'ALTER TABLE `radiology_procedure` MODIFY COLUMN `tenant_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- `drug`
SET @nullable := (
  SELECT IS_NULLABLE FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'drug'
    AND COLUMN_NAME = 'tenant_id'
);
SET @sql := IF(@nullable = 'NO',
  'ALTER TABLE `drug` MODIFY COLUMN `tenant_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- `clinical_term_catalog` - diagnoses and theatre procedures
SET @nullable := (
  SELECT IS_NULLABLE FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'clinical_term_catalog'
    AND COLUMN_NAME = 'tenant_id'
);
SET @sql := IF(@nullable = 'NO',
  'ALTER TABLE `clinical_term_catalog` MODIFY COLUMN `tenant_id` VARCHAR(36) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
