-- Rename nurse_roster → roster (table, FKs, indexes).
-- Prisma enum NurseRosterStatus → RosterStatus is schema-only (MySQL/MariaDB uses inline ENUM).
-- Drop FKs before indexes (MariaDB requires this). Uses DROP/ADD INDEX (portable).

-- Dependents: drop FKs and indexes on nurse_roster_id
ALTER TABLE `shift`
  DROP FOREIGN KEY `shift_nurse_roster_id_fkey`;

ALTER TABLE `shift`
  DROP INDEX `shift_nurse_roster_id_idx`;

ALTER TABLE `roster_day_off`
  DROP FOREIGN KEY `roster_day_off_nurse_roster_id_fkey`;

ALTER TABLE `roster_day_off`
  DROP INDEX `roster_day_off_nurse_roster_id_staff_profile_id_off_date_key`;

ALTER TABLE `roster_day_off`
  DROP INDEX `roster_day_off_nurse_roster_id_idx`;

-- Rename FK columns
ALTER TABLE `shift`
  CHANGE COLUMN `nurse_roster_id` `roster_id` VARCHAR(36) NULL;

ALTER TABLE `roster_day_off`
  CHANGE COLUMN `nurse_roster_id` `roster_id` VARCHAR(36) NOT NULL;

-- Rename primary table
RENAME TABLE `nurse_roster` TO `roster`;

-- Drop old FKs before renaming indexes they depend on
ALTER TABLE `roster` DROP FOREIGN KEY `nurse_roster_tenant_id_fkey`;
ALTER TABLE `roster` DROP FOREIGN KEY `nurse_roster_facility_id_fkey`;
ALTER TABLE `roster` DROP FOREIGN KEY `nurse_roster_department_id_fkey`;

-- Recreate roster table indexes with roster_* names
ALTER TABLE `roster` DROP INDEX `nurse_roster_tenant_id_idx`;
ALTER TABLE `roster` ADD INDEX `roster_tenant_id_idx` (`tenant_id`);
ALTER TABLE `roster` DROP INDEX `nurse_roster_facility_id_idx`;
ALTER TABLE `roster` ADD INDEX `roster_facility_id_idx` (`facility_id`);
ALTER TABLE `roster` DROP INDEX `nurse_roster_department_id_idx`;
ALTER TABLE `roster` ADD INDEX `roster_department_id_idx` (`department_id`);
ALTER TABLE `roster` DROP INDEX `nurse_roster_period_start_idx`;
ALTER TABLE `roster` ADD INDEX `roster_period_start_idx` (`period_start`);
ALTER TABLE `roster` DROP INDEX `nurse_roster_period_end_idx`;
ALTER TABLE `roster` ADD INDEX `roster_period_end_idx` (`period_end`);
ALTER TABLE `roster` DROP INDEX `nurse_roster_status_idx`;
ALTER TABLE `roster` ADD INDEX `roster_status_idx` (`status`);
ALTER TABLE `roster` DROP INDEX `nurse_roster_deleted_at_idx`;
ALTER TABLE `roster` ADD INDEX `roster_deleted_at_idx` (`deleted_at`);
ALTER TABLE `roster` DROP INDEX `nurse_roster_human_friendly_id_idx`;
ALTER TABLE `roster` ADD INDEX `roster_human_friendly_id_idx` (`human_friendly_id`);

-- Recreate roster table foreign keys with roster_* names
ALTER TABLE `roster`
  ADD CONSTRAINT `roster_tenant_id_fkey`
  FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `roster`
  ADD CONSTRAINT `roster_facility_id_fkey`
  FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`)
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE `roster`
  ADD CONSTRAINT `roster_department_id_fkey`
  FOREIGN KEY (`department_id`) REFERENCES `department`(`id`)
  ON DELETE SET NULL ON UPDATE CASCADE;

-- Dependent indexes + FKs
ALTER TABLE `shift`
  ADD INDEX `shift_roster_id_idx` (`roster_id`);

ALTER TABLE `shift`
  ADD CONSTRAINT `shift_roster_id_fkey`
  FOREIGN KEY (`roster_id`) REFERENCES `roster`(`id`)
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE `roster_day_off`
  ADD UNIQUE INDEX `roster_day_off_roster_id_staff_profile_id_off_date_key`
  (`roster_id`, `staff_profile_id`, `off_date`);

ALTER TABLE `roster_day_off`
  ADD INDEX `roster_day_off_roster_id_idx` (`roster_id`);

ALTER TABLE `roster_day_off`
  ADD CONSTRAINT `roster_day_off_roster_id_fkey`
  FOREIGN KEY (`roster_id`) REFERENCES `roster`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;
