-- Lab workflow enhancements: ordering physician tracking and manual interpretation overrides

ALTER TABLE `lab_order`
  ADD COLUMN `ordered_by_user_id` VARCHAR(36) NULL AFTER `ordered_at`;

CREATE INDEX `lab_order_ordered_by_user_id_idx` ON `lab_order`(`ordered_by_user_id`);

ALTER TABLE `lab_order`
  ADD CONSTRAINT `lab_order_ordered_by_user_id_fkey`
    FOREIGN KEY (`ordered_by_user_id`) REFERENCES `user`(`id`)
    ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE `lab_result`
  ADD COLUMN `interpretation_override` BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN `reference_range_override` VARCHAR(255) NULL,
  ADD COLUMN `result_flag_override` VARCHAR(40) NULL;
