-- Release 1 + Release 2 core schema changes:
-- - Doctor onboarding foundations
-- - OPD/provider scheduling enhancements
-- - Core friendly-id uniqueness hardening

-- ========================
-- User title/position base
-- ========================
ALTER TABLE `user`
  ADD COLUMN `position_title` VARCHAR(120) NOT NULL DEFAULT 'UNSPECIFIED' AFTER `facility_id`;

UPDATE `user`
SET `position_title` = 'UNSPECIFIED'
WHERE `position_title` IS NULL OR TRIM(`position_title`) = '';

CREATE INDEX `user_position_title_idx` ON `user`(`position_title`);

-- =====================================
-- Provider schedule hybrid model support
-- =====================================
ALTER TABLE `provider_schedule`
  ADD COLUMN `schedule_type` ENUM('RECURRING', 'OVERRIDE') NOT NULL DEFAULT 'RECURRING' AFTER `provider_user_id`,
  ADD COLUMN `timezone` VARCHAR(64) NOT NULL DEFAULT 'UTC' AFTER `schedule_type`,
  ADD COLUMN `effective_from` DATETIME(3) NULL AFTER `timezone`,
  ADD COLUMN `effective_to` DATETIME(3) NULL AFTER `effective_from`;

ALTER TABLE `availability_slot`
  ADD COLUMN `override_date` DATETIME(3) NULL AFTER `schedule_id`;

CREATE INDEX `provider_schedule_schedule_type_idx` ON `provider_schedule`(`schedule_type`);
CREATE INDEX `provider_schedule_timezone_idx` ON `provider_schedule`(`timezone`);
CREATE INDEX `provider_schedule_effective_from_idx` ON `provider_schedule`(`effective_from`);
CREATE INDEX `provider_schedule_effective_to_idx` ON `provider_schedule`(`effective_to`);
CREATE INDEX `availability_slot_override_date_idx` ON `availability_slot`(`override_date`);

-- =====================================
-- Core human-friendly-id unique hardening
-- =====================================
-- NOTE:
-- If this migration fails due to existing duplicates, run:
--   node prisma/scripts/check-friendly-id-collisions.js
--   node prisma/scripts/resolve-friendly-id-collisions.js
-- then re-apply migration.

CREATE UNIQUE INDEX `user_tenant_id_human_friendly_id_key` ON `user`(`tenant_id`, `human_friendly_id`);
CREATE UNIQUE INDEX `staff_profile_tenant_id_human_friendly_id_key` ON `staff_profile`(`tenant_id`, `human_friendly_id`);
CREATE UNIQUE INDEX `staff_position_tenant_id_human_friendly_id_key` ON `staff_position`(`tenant_id`, `human_friendly_id`);
CREATE UNIQUE INDEX `patient_tenant_id_human_friendly_id_key` ON `patient`(`tenant_id`, `human_friendly_id`);
CREATE UNIQUE INDEX `appointment_tenant_id_human_friendly_id_key` ON `appointment`(`tenant_id`, `human_friendly_id`);
CREATE UNIQUE INDEX `visit_queue_tenant_id_human_friendly_id_key` ON `visit_queue`(`tenant_id`, `human_friendly_id`);
CREATE UNIQUE INDEX `encounter_tenant_id_human_friendly_id_key` ON `encounter`(`tenant_id`, `human_friendly_id`);
CREATE UNIQUE INDEX `provider_schedule_tenant_id_human_friendly_id_key` ON `provider_schedule`(`tenant_id`, `human_friendly_id`);
CREATE UNIQUE INDEX `availability_slot_schedule_id_human_friendly_id_key` ON `availability_slot`(`schedule_id`, `human_friendly_id`);
