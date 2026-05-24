ALTER TABLE `lab_order_item`
  ADD COLUMN `panel_id` VARCHAR(80) NULL,
  ADD COLUMN `panel_display_name` VARCHAR(255) NULL,
  ADD COLUMN `panel_code` VARCHAR(80) NULL,
  ADD COLUMN `panel_sort_order` INTEGER NULL,
  ADD COLUMN `panel_item_sort_order` INTEGER NULL;

CREATE INDEX `lab_order_item_panel_id_idx` ON `lab_order_item`(`panel_id`);
