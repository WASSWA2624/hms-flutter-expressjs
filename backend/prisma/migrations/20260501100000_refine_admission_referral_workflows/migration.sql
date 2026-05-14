-- Refine clinical Admit and external Referral workflows.
-- Admission status is now assigned by the backend service as ADMITTED.
-- External referrals store receiving facility, structured reason metadata,
-- custom reason text, and optional notes.

ALTER TABLE `referral`
  ADD COLUMN `external_facility_name` VARCHAR(255) NULL AFTER `encounter_id`,
  ADD COLUMN `referral_reason_code` VARCHAR(80) NULL AFTER `reason`,
  ADD COLUMN `custom_reason` VARCHAR(255) NULL AFTER `referral_reason_code`,
  ADD COLUMN `notes` TEXT NULL AFTER `custom_reason`;

CREATE INDEX `referral_external_facility_name_idx` ON `referral`(`external_facility_name`);
CREATE INDEX `referral_referral_reason_code_idx` ON `referral`(`referral_reason_code`);
