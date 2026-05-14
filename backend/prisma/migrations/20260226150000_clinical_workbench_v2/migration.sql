-- AlterTable
ALTER TABLE `clinical_alert`
  ADD COLUMN `status` ENUM('NEW','ACKNOWLEDGED','RESOLVED') NOT NULL DEFAULT 'NEW',
  ADD COLUMN `source` ENUM('MANUAL','AUTO_VITAL') NOT NULL DEFAULT 'MANUAL',
  ADD COLUMN `vital_sign_id` VARCHAR(36) NULL,
  ADD COLUMN `acknowledged_at` DATETIME(3) NULL,
  ADD COLUMN `acknowledged_by_user_id` VARCHAR(36) NULL,
  ADD COLUMN `resolved_at` DATETIME(3) NULL,
  ADD COLUMN `resolved_by_user_id` VARCHAR(36) NULL;

-- AlterTable
ALTER TABLE `follow_up`
  ADD COLUMN `status` ENUM('SCHEDULED','COMPLETED','CANCELLED') NOT NULL DEFAULT 'SCHEDULED',
  ADD COLUMN `completed_at` DATETIME(3) NULL,
  ADD COLUMN `completed_by_user_id` VARCHAR(36) NULL,
  ADD COLUMN `reminder_24h_sent_at` DATETIME(3) NULL,
  ADD COLUMN `reminder_due_sent_at` DATETIME(3) NULL;

-- CreateTable
CREATE TABLE `clinical_vital_alert_threshold` (
  `id` VARCHAR(36) NOT NULL,
  `human_friendly_id` VARCHAR(32) NULL,
  `tenant_id` VARCHAR(36) NOT NULL,
  `facility_id` VARCHAR(36) NULL,
  `vital_type` ENUM('TEMPERATURE','BLOOD_PRESSURE','HEART_RATE','RESPIRATORY_RATE','OXYGEN_SATURATION','WEIGHT','HEIGHT','BMI') NOT NULL,
  `component` VARCHAR(32) NOT NULL,
  `age_band` VARCHAR(32) NOT NULL,
  `normal_min` DECIMAL(8, 2) NULL,
  `normal_max` DECIMAL(8, 2) NULL,
  `critical_low` DECIMAL(8, 2) NULL,
  `critical_high` DECIMAL(8, 2) NULL,
  `is_active` BOOLEAN NOT NULL DEFAULT true,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  `deleted_at` DATETIME(3) NULL,
  `version` INTEGER NOT NULL DEFAULT 1,

  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `clinical_term_favorite` (
  `id` VARCHAR(36) NOT NULL,
  `human_friendly_id` VARCHAR(32) NULL,
  `tenant_id` VARCHAR(36) NOT NULL,
  `facility_id` VARCHAR(36) NULL,
  `owner_user_id` VARCHAR(36) NULL,
  `term_type` ENUM('DIAGNOSIS','PROCEDURE') NOT NULL,
  `scope` ENUM('PERSONAL','SHARED') NOT NULL,
  `code` VARCHAR(80) NULL,
  `description` TEXT NOT NULL,
  `usage_count` INTEGER NOT NULL DEFAULT 0,
  `last_used_at` DATETIME(3) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  `deleted_at` DATETIME(3) NULL,
  `version` INTEGER NOT NULL DEFAULT 1,

  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateIndex
CREATE INDEX `clinical_alert_status_idx` ON `clinical_alert`(`status`);
CREATE INDEX `clinical_alert_source_idx` ON `clinical_alert`(`source`);
CREATE INDEX `clinical_alert_vital_sign_id_idx` ON `clinical_alert`(`vital_sign_id`);
CREATE INDEX `clinical_alert_acknowledged_by_user_id_idx` ON `clinical_alert`(`acknowledged_by_user_id`);
CREATE INDEX `clinical_alert_resolved_by_user_id_idx` ON `clinical_alert`(`resolved_by_user_id`);

-- CreateIndex
CREATE INDEX `follow_up_status_idx` ON `follow_up`(`status`);
CREATE INDEX `follow_up_completed_by_user_id_idx` ON `follow_up`(`completed_by_user_id`);

-- CreateIndex
CREATE INDEX `clinical_vital_alert_threshold_tenant_id_idx` ON `clinical_vital_alert_threshold`(`tenant_id`);
CREATE INDEX `clinical_vital_alert_threshold_facility_id_idx` ON `clinical_vital_alert_threshold`(`facility_id`);
CREATE INDEX `clinical_vital_alert_threshold_vital_type_idx` ON `clinical_vital_alert_threshold`(`vital_type`);
CREATE INDEX `clinical_vital_alert_threshold_component_idx` ON `clinical_vital_alert_threshold`(`component`);
CREATE INDEX `clinical_vital_alert_threshold_age_band_idx` ON `clinical_vital_alert_threshold`(`age_band`);
CREATE INDEX `clinical_vital_alert_threshold_is_active_idx` ON `clinical_vital_alert_threshold`(`is_active`);
CREATE INDEX `clinical_vital_alert_threshold_deleted_at_idx` ON `clinical_vital_alert_threshold`(`deleted_at`);
CREATE INDEX `clinical_vital_alert_threshold_human_friendly_id_idx` ON `clinical_vital_alert_threshold`(`human_friendly_id`);

-- CreateIndex
CREATE INDEX `clinical_term_favorite_tenant_id_idx` ON `clinical_term_favorite`(`tenant_id`);
CREATE INDEX `clinical_term_favorite_facility_id_idx` ON `clinical_term_favorite`(`facility_id`);
CREATE INDEX `clinical_term_favorite_owner_user_id_idx` ON `clinical_term_favorite`(`owner_user_id`);
CREATE INDEX `clinical_term_favorite_term_type_idx` ON `clinical_term_favorite`(`term_type`);
CREATE INDEX `clinical_term_favorite_scope_idx` ON `clinical_term_favorite`(`scope`);
CREATE INDEX `clinical_term_favorite_code_idx` ON `clinical_term_favorite`(`code`);
CREATE INDEX `clinical_term_favorite_usage_count_idx` ON `clinical_term_favorite`(`usage_count`);
CREATE INDEX `clinical_term_favorite_deleted_at_idx` ON `clinical_term_favorite`(`deleted_at`);
CREATE INDEX `clinical_term_favorite_human_friendly_id_idx` ON `clinical_term_favorite`(`human_friendly_id`);

-- AddForeignKey
ALTER TABLE `clinical_alert`
  ADD CONSTRAINT `clinical_alert_vital_sign_id_fkey` FOREIGN KEY (`vital_sign_id`) REFERENCES `vital_sign`(`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `clinical_alert_acknowledged_by_user_id_fkey` FOREIGN KEY (`acknowledged_by_user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `clinical_alert_resolved_by_user_id_fkey` FOREIGN KEY (`resolved_by_user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `follow_up`
  ADD CONSTRAINT `follow_up_completed_by_user_id_fkey` FOREIGN KEY (`completed_by_user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `clinical_vital_alert_threshold`
  ADD CONSTRAINT `clinical_vital_alert_threshold_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT `clinical_vital_alert_threshold_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `clinical_term_favorite`
  ADD CONSTRAINT `clinical_term_favorite_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT `clinical_term_favorite_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `clinical_term_favorite_owner_user_id_fkey` FOREIGN KEY (`owner_user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;
