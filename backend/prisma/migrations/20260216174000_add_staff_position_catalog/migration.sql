-- CreateTable
CREATE TABLE `staff_position` (
  `id` VARCHAR(36) NOT NULL,
  `human_friendly_id` VARCHAR(32) NULL,
  `tenant_id` VARCHAR(36) NOT NULL,
  `facility_id` VARCHAR(36) NULL,
  `department_id` VARCHAR(36) NULL,
  `name` VARCHAR(120) NOT NULL,
  `description` VARCHAR(255) NULL,
  `is_active` BOOLEAN NOT NULL DEFAULT true,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  `deleted_at` DATETIME(3) NULL,
  `version` INTEGER NOT NULL DEFAULT 1,

  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateIndex
CREATE INDEX `staff_position_tenant_id_idx` ON `staff_position`(`tenant_id`);

-- CreateIndex
CREATE INDEX `staff_position_facility_id_idx` ON `staff_position`(`facility_id`);

-- CreateIndex
CREATE INDEX `staff_position_department_id_idx` ON `staff_position`(`department_id`);

-- CreateIndex
CREATE INDEX `staff_position_name_idx` ON `staff_position`(`name`);

-- CreateIndex
CREATE INDEX `staff_position_is_active_idx` ON `staff_position`(`is_active`);

-- CreateIndex
CREATE INDEX `staff_position_deleted_at_idx` ON `staff_position`(`deleted_at`);

-- CreateIndex
CREATE INDEX `staff_position_human_friendly_id_idx` ON `staff_position`(`human_friendly_id`);

-- AddForeignKey
ALTER TABLE `staff_position` ADD CONSTRAINT `staff_position_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `staff_position` ADD CONSTRAINT `staff_position_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `staff_position` ADD CONSTRAINT `staff_position_department_id_fkey` FOREIGN KEY (`department_id`) REFERENCES `department`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;
