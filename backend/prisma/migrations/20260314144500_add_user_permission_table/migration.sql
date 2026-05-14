CREATE TABLE `user_permission` (
  `id` VARCHAR(36) NOT NULL,
  `human_friendly_id` VARCHAR(32) NULL,
  `user_id` VARCHAR(36) NOT NULL,
  `permission_id` VARCHAR(36) NOT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  `deleted_at` DATETIME(3) NULL,
  `version` INTEGER NOT NULL DEFAULT 1,

  UNIQUE INDEX `user_permission_user_id_permission_id_key`(`user_id`, `permission_id`),
  INDEX `user_permission_user_id_idx`(`user_id`),
  INDEX `user_permission_permission_id_idx`(`permission_id`),
  INDEX `user_permission_deleted_at_idx`(`deleted_at`),
  INDEX `user_permission_human_friendly_id_idx`(`human_friendly_id`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE InnoDB;

ALTER TABLE `user_permission`
  ADD CONSTRAINT `user_permission_user_id_fkey`
  FOREIGN KEY (`user_id`) REFERENCES `user`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `user_permission`
  ADD CONSTRAINT `user_permission_permission_id_fkey`
  FOREIGN KEY (`permission_id`) REFERENCES `permission`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;
