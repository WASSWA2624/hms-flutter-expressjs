-- Configurable lab unit catalogs, qualitative result options, and persisted result interpretation

ALTER TABLE `lab_test`
  ADD COLUMN `category` VARCHAR(80) NULL AFTER `code`,
  ADD COLUMN `specimen_type` VARCHAR(80) NULL AFTER `category`,
  ADD COLUMN `result_kind` ENUM('NUMERIC', 'QUALITATIVE', 'TEXT') NOT NULL DEFAULT 'NUMERIC' AFTER `specimen_type`,
  ADD COLUMN `description` VARCHAR(255) NULL AFTER `unit`;

ALTER TABLE `lab_panel`
  ADD COLUMN `category` VARCHAR(80) NULL AFTER `code`,
  ADD COLUMN `description` VARCHAR(255) NULL AFTER `category`;

ALTER TABLE `lab_test_reference_range`
  ADD COLUMN `unit` VARCHAR(40) NULL AFTER `label`;

CREATE TABLE `lab_test_unit_option` (
  `id` VARCHAR(36) NOT NULL,
  `lab_test_id` VARCHAR(36) NOT NULL,
  `label` VARCHAR(80) NULL,
  `unit` VARCHAR(40) NOT NULL,
  `ucum_code` VARCHAR(40) NULL,
  `is_default` BOOLEAN NOT NULL DEFAULT true,
  `sort_order` INTEGER NOT NULL DEFAULT 0,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,

  PRIMARY KEY (`id`),
  UNIQUE INDEX `lab_test_unit_option_lab_test_id_unit_key`(`lab_test_id`, `unit`),
  INDEX `lab_test_unit_option_lab_test_id_sort_order_idx`(`lab_test_id`, `sort_order`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `lab_test_result_option` (
  `id` VARCHAR(36) NOT NULL,
  `lab_test_id` VARCHAR(36) NOT NULL,
  `value` VARCHAR(80) NOT NULL,
  `label` VARCHAR(120) NULL,
  `aliases_json` JSON NULL,
  `status` ENUM('NORMAL', 'ABNORMAL', 'CRITICAL', 'PENDING') NOT NULL DEFAULT 'ABNORMAL',
  `result_flag` VARCHAR(40) NULL,
  `is_positive` BOOLEAN NOT NULL DEFAULT false,
  `sort_order` INTEGER NOT NULL DEFAULT 0,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,

  PRIMARY KEY (`id`),
  UNIQUE INDEX `lab_test_result_option_lab_test_id_value_key`(`lab_test_id`, `value`),
  INDEX `lab_test_result_option_lab_test_id_sort_order_idx`(`lab_test_id`, `sort_order`),
  INDEX `lab_test_result_option_status_idx`(`status`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE `lab_result`
  ADD COLUMN `result_flag` VARCHAR(40) NULL AFTER `result_unit`,
  ADD COLUMN `is_positive` BOOLEAN NOT NULL DEFAULT false AFTER `result_flag`,
  ADD COLUMN `reference_range_label` VARCHAR(120) NULL AFTER `is_positive`,
  ADD COLUMN `reference_range_summary` VARCHAR(255) NULL AFTER `reference_range_label`;

CREATE INDEX `lab_test_category_idx` ON `lab_test`(`category`);
CREATE INDEX `lab_test_specimen_type_idx` ON `lab_test`(`specimen_type`);
CREATE INDEX `lab_test_result_kind_idx` ON `lab_test`(`result_kind`);

ALTER TABLE `lab_test_unit_option`
  ADD CONSTRAINT `lab_test_unit_option_lab_test_id_fkey`
  FOREIGN KEY (`lab_test_id`) REFERENCES `lab_test`(`id`)
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `lab_test_result_option`
  ADD CONSTRAINT `lab_test_result_option_lab_test_id_fkey`
  FOREIGN KEY (`lab_test_id`) REFERENCES `lab_test`(`id`)
  ON DELETE CASCADE ON UPDATE CASCADE;

INSERT INTO `lab_test_unit_option` (
  `id`,
  `lab_test_id`,
  `label`,
  `unit`,
  `ucum_code`,
  `is_default`,
  `sort_order`,
  `created_at`,
  `updated_at`
)
SELECT
  UUID(),
  `id`,
  NULL,
  `unit`,
  NULL,
  true,
  0,
  CURRENT_TIMESTAMP(3),
  CURRENT_TIMESTAMP(3)
FROM `lab_test`
WHERE `unit` IS NOT NULL
  AND TRIM(`unit`) <> '';

UPDATE `lab_test_reference_range` `rr`
JOIN `lab_test` `lt`
  ON `lt`.`id` = `rr`.`lab_test_id`
SET `rr`.`unit` = `lt`.`unit`
WHERE (`rr`.`unit` IS NULL OR TRIM(`rr`.`unit`) = '')
  AND `lt`.`unit` IS NOT NULL
  AND TRIM(`lt`.`unit`) <> '';
