-- Stock transfer endpoints: sending/receiving facilities + paired ship/receive group.
ALTER TABLE `stock_movement`
  ADD COLUMN `from_facility_id` VARCHAR(36) NULL AFTER `facility_id`,
  ADD COLUMN `to_facility_id` VARCHAR(36) NULL AFTER `from_facility_id`,
  ADD COLUMN `transfer_group_id` VARCHAR(36) NULL AFTER `to_facility_id`;

CREATE INDEX `stock_movement_from_facility_id_idx` ON `stock_movement`(`from_facility_id`);
CREATE INDEX `stock_movement_to_facility_id_idx` ON `stock_movement`(`to_facility_id`);
CREATE INDEX `stock_movement_transfer_group_id_idx` ON `stock_movement`(`transfer_group_id`);

ALTER TABLE `stock_movement`
  ADD CONSTRAINT `stock_movement_from_facility_id_fkey`
    FOREIGN KEY (`from_facility_id`) REFERENCES `facility`(`id`)
    ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `stock_movement_to_facility_id_fkey`
    FOREIGN KEY (`to_facility_id`) REFERENCES `facility`(`id`)
    ON DELETE SET NULL ON UPDATE CASCADE;
