-- Structured lab test reference ranges and ordered lab panel items

ALTER TABLE `lab_test`
  MODIFY `reference_range` VARCHAR(255) NULL;

CREATE TABLE `lab_test_reference_range` (
  `id` VARCHAR(36) NOT NULL,
  `lab_test_id` VARCHAR(36) NOT NULL,
  `label` VARCHAR(120) NULL,
  `gender` ENUM('MALE', 'FEMALE', 'OTHER', 'UNKNOWN') NULL,
  `age_min_value` INTEGER NULL,
  `age_min_unit` ENUM('DAY', 'WEEK', 'MONTH', 'YEAR') NULL,
  `age_max_value` INTEGER NULL,
  `age_max_unit` ENUM('DAY', 'WEEK', 'MONTH', 'YEAR') NULL,
  `normal_min_value` DECIMAL(12, 4) NULL,
  `normal_max_value` DECIMAL(12, 4) NULL,
  `critical_min_value` DECIMAL(12, 4) NULL,
  `critical_max_value` DECIMAL(12, 4) NULL,
  `reference_text` VARCHAR(255) NULL,
  `notes` VARCHAR(255) NULL,
  `sort_order` INTEGER NOT NULL DEFAULT 0,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,

  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `lab_panel_item` (
  `id` VARCHAR(36) NOT NULL,
  `lab_panel_id` VARCHAR(36) NOT NULL,
  `lab_test_id` VARCHAR(36) NOT NULL,
  `is_required` BOOLEAN NOT NULL DEFAULT true,
  `instructions` VARCHAR(255) NULL,
  `sort_order` INTEGER NOT NULL DEFAULT 0,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,

  PRIMARY KEY (`id`),
  UNIQUE INDEX `lab_panel_item_lab_panel_id_lab_test_id_key`(`lab_panel_id`, `lab_test_id`),
  INDEX `lab_panel_item_lab_panel_id_sort_order_idx`(`lab_panel_id`, `sort_order`),
  INDEX `lab_panel_item_lab_test_id_idx`(`lab_test_id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE INDEX `lab_test_reference_range_lab_test_id_sort_order_idx`
  ON `lab_test_reference_range`(`lab_test_id`, `sort_order`);

ALTER TABLE `lab_test_reference_range`
  ADD CONSTRAINT `lab_test_reference_range_lab_test_id_fkey`
  FOREIGN KEY (`lab_test_id`) REFERENCES `lab_test`(`id`)
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `lab_panel_item`
  ADD CONSTRAINT `lab_panel_item_lab_panel_id_fkey`
  FOREIGN KEY (`lab_panel_id`) REFERENCES `lab_panel`(`id`)
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `lab_panel_item`
  ADD CONSTRAINT `lab_panel_item_lab_test_id_fkey`
  FOREIGN KEY (`lab_test_id`) REFERENCES `lab_test`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;
