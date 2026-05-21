-- Enforce one active OPD/emergency encounter per patient in a tenant/facility.
-- Existing duplicate open encounters are closed except for the earliest started row
-- so the unique lock can be backfilled safely.

ALTER TABLE `encounter`
  ADD COLUMN `active_opd_lock_key` VARCHAR(160) NULL AFTER `status`;

UPDATE `encounter` AS `enc`
JOIN (
  SELECT
    `ranked`.`id`,
    `ranked`.`row_number`
  FROM (
    SELECT
      `id`,
      ROW_NUMBER() OVER (
        PARTITION BY `tenant_id`, COALESCE(`facility_id`, 'GLOBAL'), `patient_id`
        ORDER BY `started_at` ASC, `created_at` ASC, `id` ASC
      ) AS `row_number`
    FROM `encounter`
    WHERE
      `deleted_at` IS NULL
      AND `status` = 'OPEN'
      AND `encounter_type` IN ('OPD', 'EMERGENCY')
  ) AS `ranked`
) AS `active_rank`
  ON `enc`.`id` = `active_rank`.`id`
SET
  `enc`.`status` = CASE
    WHEN `active_rank`.`row_number` = 1 THEN `enc`.`status`
    ELSE 'CLOSED'
  END,
  `enc`.`ended_at` = CASE
    WHEN `active_rank`.`row_number` = 1 THEN `enc`.`ended_at`
    ELSE COALESCE(`enc`.`ended_at`, NOW())
  END,
  `enc`.`active_opd_lock_key` = CASE
    WHEN `active_rank`.`row_number` = 1 THEN CONCAT(
      'opd:',
      `enc`.`tenant_id`,
      ':',
      COALESCE(`enc`.`facility_id`, 'GLOBAL'),
      ':',
      `enc`.`patient_id`
    )
    ELSE NULL
  END;

CREATE UNIQUE INDEX `encounter_active_opd_lock_key_key`
  ON `encounter`(`active_opd_lock_key`);
