-- Add extension_json to emergency_case to persist handoff receiving-work snapshots
-- (downstream OPD/IPD/ICU/Theater references, stage, billing-deferred flag) and
-- other case-level metadata without duplicating downstream workflow records.
ALTER TABLE `emergency_case`
  ADD COLUMN `extension_json` JSON NULL;
