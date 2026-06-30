-- Staff leave type, half-day, handover, and covering staff fields.

ALTER TABLE `staff_leave`
  ADD COLUMN `leave_type` ENUM(
    'ANNUAL',
    'SICK',
    'MATERNITY',
    'PATERNITY',
    'COMPASSIONATE',
    'UNPAID',
    'STUDY',
    'EMERGENCY',
    'OTHER'
  ) NOT NULL DEFAULT 'ANNUAL',
  ADD COLUMN `is_half_day` BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN `half_day_period` ENUM('MORNING', 'AFTERNOON') NULL,
  ADD COLUMN `handover_notes` TEXT NULL,
  ADD COLUMN `covering_staff_profile_id` VARCHAR(36) NULL;

CREATE INDEX `staff_leave_leave_type_idx` ON `staff_leave`(`leave_type`);
CREATE INDEX `staff_leave_covering_staff_profile_id_idx` ON `staff_leave`(`covering_staff_profile_id`);

ALTER TABLE `staff_leave`
  ADD CONSTRAINT `staff_leave_covering_staff_profile_id_fkey`
  FOREIGN KEY (`covering_staff_profile_id`) REFERENCES `staff_profile`(`id`)
  ON DELETE SET NULL ON UPDATE CASCADE;
