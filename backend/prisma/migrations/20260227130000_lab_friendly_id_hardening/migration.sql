-- Lab human-friendly-id uniqueness hardening
-- NOTE:
-- If this migration fails due to existing duplicates/missing values, run:
--   node prisma/scripts/check-friendly-id-collisions.js
--   node prisma/scripts/resolve-friendly-id-collisions.js
-- then re-apply migration.

CREATE UNIQUE INDEX `lab_test_tenant_id_human_friendly_id_key` ON `lab_test`(`tenant_id`, `human_friendly_id`);
CREATE UNIQUE INDEX `lab_panel_tenant_id_human_friendly_id_key` ON `lab_panel`(`tenant_id`, `human_friendly_id`);
CREATE UNIQUE INDEX `lab_order_human_friendly_id_key` ON `lab_order`(`human_friendly_id`);
CREATE UNIQUE INDEX `lab_order_item_human_friendly_id_key` ON `lab_order_item`(`human_friendly_id`);
CREATE UNIQUE INDEX `lab_sample_human_friendly_id_key` ON `lab_sample`(`human_friendly_id`);
CREATE UNIQUE INDEX `lab_result_human_friendly_id_key` ON `lab_result`(`human_friendly_id`);
CREATE UNIQUE INDEX `lab_qc_log_human_friendly_id_key` ON `lab_qc_log`(`human_friendly_id`);
