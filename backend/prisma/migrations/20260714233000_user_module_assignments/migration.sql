CREATE TABLE `user_module_assignment` (
  `id` VARCHAR(36) NOT NULL,
  `human_friendly_id` VARCHAR(32) NULL,
  `user_id` VARCHAR(36) NOT NULL,
  `module_id` VARCHAR(36) NOT NULL,
  `tenant_id` VARCHAR(36) NOT NULL,
  `facility_id` VARCHAR(36) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  `deleted_at` DATETIME(3) NULL,
  `version` INTEGER NOT NULL DEFAULT 1,

  UNIQUE INDEX `uma_user_mod_tenant_fac_key`
    (`user_id`, `module_id`, `tenant_id`, `facility_id`),
  INDEX `user_module_assignment_user_id_idx` (`user_id`),
  INDEX `user_module_assignment_module_id_idx` (`module_id`),
  INDEX `user_module_assignment_tenant_id_idx` (`tenant_id`),
  INDEX `user_module_assignment_facility_id_idx` (`facility_id`),
  INDEX `user_module_assignment_deleted_at_idx` (`deleted_at`),
  INDEX `user_module_assignment_human_friendly_id_idx` (`human_friendly_id`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE `user_module_assignment`
  ADD CONSTRAINT `user_module_assignment_user_id_fkey`
    FOREIGN KEY (`user_id`) REFERENCES `user`(`id`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT `user_module_assignment_module_id_fkey`
    FOREIGN KEY (`module_id`) REFERENCES `module`(`id`)
    ON DELETE RESTRICT ON UPDATE CASCADE;

-- Rollback:
-- DROP TABLE `user_module_assignment`;
