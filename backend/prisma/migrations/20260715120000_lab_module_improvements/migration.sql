-- Laboratory module improvements:
-- sample rejection persistence, versioned/effective-dated reference ranges,
-- and exact applied-range snapshots on released results.

-- Sample rejection fields (mirror lab_order_item rejection shape)
ALTER TABLE `lab_sample`
  ADD COLUMN `rejection_reason` VARCHAR(255) NULL,
  ADD COLUMN `rejection_notes` TEXT NULL,
  ADD COLUMN `rejected_at` DATETIME(3) NULL;

CREATE INDEX `lab_sample_rejected_at_idx` ON `lab_sample`(`rejected_at`);

-- Versioned / effective-dated / method-aware reference ranges (master catalog)
ALTER TABLE `lab_test_reference_range`
  ADD COLUMN `method` VARCHAR(120) NULL AFTER `unit`,
  ADD COLUMN `effective_from` DATETIME(3) NULL AFTER `notes`,
  ADD COLUMN `effective_to` DATETIME(3) NULL AFTER `effective_from`,
  ADD COLUMN `version` INTEGER NOT NULL DEFAULT 1 AFTER `effective_to`;

CREATE INDEX `lab_test_ref_range_test_effective_idx`
  ON `lab_test_reference_range`(`lab_test_id`, `effective_from`);

-- Facility catalog twin
ALTER TABLE `facility_lab_test_reference_range`
  ADD COLUMN `method` VARCHAR(120) NULL AFTER `unit`,
  ADD COLUMN `effective_from` DATETIME(3) NULL AFTER `notes`,
  ADD COLUMN `effective_to` DATETIME(3) NULL AFTER `effective_from`,
  ADD COLUMN `version` INTEGER NOT NULL DEFAULT 1 AFTER `effective_to`;

CREATE INDEX `facility_lab_test_ref_range_offering_effective_idx`
  ON `facility_lab_test_reference_range`(`facility_lab_test_offering_id`, `effective_from`);

-- Exact applied range snapshot on released results (never overwritten by catalog edits)
ALTER TABLE `lab_result`
  ADD COLUMN `applied_reference_range_id` VARCHAR(36) NULL AFTER `reference_range_summary`,
  ADD COLUMN `applied_reference_range_json` JSON NULL AFTER `applied_reference_range_id`;

CREATE INDEX `lab_result_applied_reference_range_id_idx`
  ON `lab_result`(`applied_reference_range_id`);

-- Backfill structured snapshots from existing label/summary for released results.
-- Do not invent numeric bounds; preserve the historical text snapshot only.
UPDATE `lab_result`
SET `applied_reference_range_json` = JSON_OBJECT(
  'id', NULL,
  'label', `reference_range_label`,
  'summary', `reference_range_summary`,
  'source', 'BACKFILL_SUMMARY',
  'version', 1
)
WHERE `deleted_at` IS NULL
  AND `applied_reference_range_json` IS NULL
  AND (
    (`reference_range_label` IS NOT NULL AND TRIM(`reference_range_label`) <> '')
    OR (`reference_range_summary` IS NOT NULL AND TRIM(`reference_range_summary`) <> '')
  );
