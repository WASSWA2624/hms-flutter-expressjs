ALTER TABLE `lab_order_item`
  ADD COLUMN `rejection_reason` VARCHAR(255) NULL,
  ADD COLUMN `rejection_notes` TEXT NULL,
  ADD COLUMN `rejected_at` DATETIME(3) NULL;

CREATE INDEX `lab_order_item_rejected_at_idx` ON `lab_order_item`(`rejected_at`);
