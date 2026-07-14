-- Radiology module workflow improvements:
-- persist scheduling/assignment, study equipment/room linkage (read-only Biomedical refs),
-- and immutable report versioning / addenda lineage.

-- Order scheduling + assignment (Biomedical equipment is referenced only)
ALTER TABLE `radiology_order`
  ADD COLUMN `assigned_user_id` VARCHAR(36) NULL AFTER `request_details`,
  ADD COLUMN `scheduled_at` DATETIME(3) NULL AFTER `assigned_user_id`,
  ADD COLUMN `room` VARCHAR(120) NULL AFTER `scheduled_at`,
  ADD COLUMN `equipment_registry_id` VARCHAR(36) NULL AFTER `room`;

CREATE INDEX `radiology_order_assigned_user_id_idx` ON `radiology_order`(`assigned_user_id`);
CREATE INDEX `radiology_order_equipment_registry_id_idx` ON `radiology_order`(`equipment_registry_id`);
CREATE INDEX `radiology_order_scheduled_at_idx` ON `radiology_order`(`scheduled_at`);

ALTER TABLE `radiology_order`
  ADD CONSTRAINT `radiology_order_assigned_user_id_fkey`
    FOREIGN KEY (`assigned_user_id`) REFERENCES `user`(`id`)
    ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `radiology_order_equipment_registry_id_fkey`
    FOREIGN KEY (`equipment_registry_id`) REFERENCES `equipment_registry`(`id`)
    ON DELETE SET NULL ON UPDATE CASCADE;

-- Study room / equipment / execution timestamps
ALTER TABLE `imaging_study`
  ADD COLUMN `room` VARCHAR(120) NULL AFTER `modality`,
  ADD COLUMN `equipment_registry_id` VARCHAR(36) NULL AFTER `room`,
  ADD COLUMN `started_at` DATETIME(3) NULL AFTER `performed_at`,
  ADD COLUMN `completed_at` DATETIME(3) NULL AFTER `started_at`;

CREATE INDEX `imaging_study_equipment_registry_id_idx` ON `imaging_study`(`equipment_registry_id`);

ALTER TABLE `imaging_study`
  ADD CONSTRAINT `imaging_study_equipment_registry_id_fkey`
    FOREIGN KEY (`equipment_registry_id`) REFERENCES `equipment_registry`(`id`)
    ON DELETE SET NULL ON UPDATE CASCADE;

-- Report version lineage (FINAL rows must not be silently overwritten)
ALTER TABLE `radiology_result`
  ADD COLUMN `parent_result_id` VARCHAR(36) NULL AFTER `radiology_order_id`,
  ADD COLUMN `addendum_text` TEXT NULL AFTER `report_text`,
  ADD COLUMN `report_version` INTEGER NOT NULL DEFAULT 1 AFTER `addendum_text`;

CREATE INDEX `radiology_result_parent_result_id_idx` ON `radiology_result`(`parent_result_id`);
CREATE INDEX `radiology_result_report_version_idx` ON `radiology_result`(`report_version`);

ALTER TABLE `radiology_result`
  ADD CONSTRAINT `radiology_result_parent_result_id_fkey`
    FOREIGN KEY (`parent_result_id`) REFERENCES `radiology_result`(`id`)
    ON DELETE SET NULL ON UPDATE CASCADE;

-- Backfill report_version for historical rows (earliest per order = 1)
UPDATE `radiology_result` r
INNER JOIN (
  SELECT
    newer.id AS result_id,
    (
      SELECT COUNT(*)
      FROM `radiology_result` older
      WHERE older.`radiology_order_id` = newer.`radiology_order_id`
        AND older.`deleted_at` IS NULL
        AND (
          older.`created_at` < newer.`created_at`
          OR (older.`created_at` = newer.`created_at` AND older.`id` <= newer.`id`)
        )
    ) AS version_no
  FROM `radiology_result` newer
  WHERE newer.`deleted_at` IS NULL
) ranked ON ranked.result_id = r.id
SET r.`report_version` = ranked.version_no;

-- Link AMENDED rows to the latest FINAL sibling when parent is missing
UPDATE `radiology_result` amended
INNER JOIN (
  SELECT f1.id, f1.radiology_order_id
  FROM `radiology_result` f1
  INNER JOIN (
    SELECT radiology_order_id, MAX(created_at) AS max_created
    FROM `radiology_result`
    WHERE `deleted_at` IS NULL AND `status` = 'FINAL'
    GROUP BY radiology_order_id
  ) latest
    ON latest.radiology_order_id = f1.radiology_order_id
   AND latest.max_created = f1.created_at
  WHERE f1.`deleted_at` IS NULL AND f1.`status` = 'FINAL'
) final_base
  ON final_base.radiology_order_id = amended.radiology_order_id
SET amended.`parent_result_id` = final_base.id
WHERE amended.`deleted_at` IS NULL
  AND amended.`status` = 'AMENDED'
  AND amended.`parent_result_id` IS NULL
  AND amended.id <> final_base.id;
