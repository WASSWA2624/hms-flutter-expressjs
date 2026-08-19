-- HR access, assignment hierarchy, availability slots, and compensation.

ALTER TABLE `staff_assignment`
  ADD COLUMN `room_id` VARCHAR(36) NULL;

CREATE INDEX `staff_assignment_room_id_idx`
  ON `staff_assignment`(`room_id`);

ALTER TABLE `staff_assignment`
  ADD CONSTRAINT `staff_assignment_room_id_fkey`
  FOREIGN KEY (`room_id`) REFERENCES `room`(`id`)
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE `staff_availability`
  ADD COLUMN `time_slots_json` JSON NULL,
  ADD COLUMN `status` VARCHAR(32) NULL;

UPDATE `staff_availability`
SET `status` = COALESCE(`status`, CAST(`preference` AS CHAR)),
    `time_slots_json` = COALESCE(
      `time_slots_json`,
      JSON_ARRAY(JSON_OBJECT('start_time', `start_time`, 'end_time', `end_time`))
    )
WHERE `deleted_at` IS NULL;

CREATE TABLE `staff_compensation` (
  `id` VARCHAR(36) NOT NULL,
  `human_friendly_id` VARCHAR(32) NULL,
  `staff_profile_id` VARCHAR(36) NOT NULL,
  `pay_type` VARCHAR(32) NOT NULL,
  `rate` DECIMAL(12, 2) NOT NULL,
  `currency` VARCHAR(10) NOT NULL,
  `effective_from` DATETIME(3) NOT NULL,
  `effective_to` DATETIME(3) NULL,
  `metadata_json` JSON NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  `deleted_at` DATETIME(3) NULL,
  `version` INTEGER NOT NULL DEFAULT 1,

  INDEX `staff_compensation_staff_profile_id_idx`(`staff_profile_id`),
  INDEX `staff_compensation_pay_type_idx`(`pay_type`),
  INDEX `staff_compensation_effective_from_idx`(`effective_from`),
  INDEX `staff_compensation_deleted_at_idx`(`deleted_at`),
  INDEX `staff_compensation_human_friendly_id_idx`(`human_friendly_id`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB;

ALTER TABLE `staff_compensation`
  ADD CONSTRAINT `staff_compensation_staff_profile_id_fkey`
  FOREIGN KEY (`staff_profile_id`) REFERENCES `staff_profile`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

INSERT INTO `staff_compensation` (
  `id`,
  `staff_profile_id`,
  `pay_type`,
  `rate`,
  `currency`,
  `effective_from`,
  `metadata_json`,
  `updated_at`
)
SELECT
  REPLACE(UUID(), '-', ''),
  `id`,
  'PER_HOUR',
  `consultation_fee`,
  COALESCE(NULLIF(`consultation_currency`, ''), 'USD'),
  COALESCE(`hire_date`, `created_at`, CURRENT_TIMESTAMP(3)),
  JSON_OBJECT('source', 'legacy_consultation_fee'),
  CURRENT_TIMESTAMP(3)
FROM `staff_profile`
WHERE `deleted_at` IS NULL
  AND `consultation_fee` IS NOT NULL;

ALTER TABLE `payroll_run`
  ADD COLUMN `preview_json` JSON NULL,
  ADD COLUMN `audit_trail_json` JSON NULL;

ALTER TABLE `payroll_item`
  ADD COLUMN `calculation_json` JSON NULL;
