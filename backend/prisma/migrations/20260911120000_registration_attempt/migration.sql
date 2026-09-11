-- Registration truthfulness: durable registration attempts.
--
-- One row per self-serve registration submission, keyed by the client's
-- `Idempotency-Key`. The row gives the backend three things it did not have
-- before:
--
--   1. Idempotent replay -- a repeated key returns the original outcome instead
--      of bootstrapping a second user, tenant, and facility.
--   2. A status lookup -- a client whose request timed out can ask what actually
--      happened rather than guessing from the transport error.
--   3. Database-level duplicate protection -- `claimed_email` is written inside
--      the same transaction that creates the tenant, facility, and user, so the
--      unique index below rejects a concurrent second bootstrap for the same
--      email. The column is NULL for attempts that did not create an account
--      (rejections, verification resends), and MySQL allows many NULLs in a
--      unique index, so only real claims compete.
--
-- `result_json` stores the replay payload only. It never holds credentials,
-- verification codes, or verification links.
--
-- Guarded with information_schema + PREPARE because the fleet spans MariaDB
-- builds without `CREATE INDEX IF NOT EXISTS`, and Prisma cannot run DELIMITER.

CREATE TABLE IF NOT EXISTS `registration_attempt` (
  `id` VARCHAR(36) NOT NULL,
  `human_friendly_id` VARCHAR(32) NULL,
  `idempotency_key` VARCHAR(191) NOT NULL,
  `request_hash` VARCHAR(64) NULL,
  `email` VARCHAR(255) NOT NULL,
  `claimed_email` VARCHAR(255) NULL,
  `status` ENUM('IN_PROGRESS', 'SUCCEEDED', 'REJECTED') NOT NULL DEFAULT 'IN_PROGRESS',
  `outcome_code` VARCHAR(64) NULL,
  `email_status` ENUM('PENDING', 'SENT', 'FAILED') NOT NULL DEFAULT 'PENDING',
  `error_status_code` INTEGER NULL,
  `error_code` VARCHAR(191) NULL,
  `user_id` VARCHAR(36) NULL,
  `tenant_id` VARCHAR(36) NULL,
  `facility_id` VARCHAR(36) NULL,
  `result_json` JSON NULL,
  `started_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `completed_at` DATETIME(3) NULL,
  `expires_at` DATETIME(3) NOT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  `deleted_at` DATETIME(3) NULL,
  `version` INTEGER NOT NULL DEFAULT 1,

  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'registration_attempt'
    AND INDEX_NAME = 'registration_attempt_idempotency_key_key'
);
SET @sql := IF(@exists = 0,
  'CREATE UNIQUE INDEX `registration_attempt_idempotency_key_key` ON `registration_attempt`(`idempotency_key`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'registration_attempt'
    AND INDEX_NAME = 'registration_attempt_claimed_email_key'
);
SET @sql := IF(@exists = 0,
  'CREATE UNIQUE INDEX `registration_attempt_claimed_email_key` ON `registration_attempt`(`claimed_email`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'registration_attempt'
    AND INDEX_NAME = 'registration_attempt_email_idx'
);
SET @sql := IF(@exists = 0,
  'CREATE INDEX `registration_attempt_email_idx` ON `registration_attempt`(`email`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'registration_attempt'
    AND INDEX_NAME = 'registration_attempt_status_idx'
);
SET @sql := IF(@exists = 0,
  'CREATE INDEX `registration_attempt_status_idx` ON `registration_attempt`(`status`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'registration_attempt'
    AND INDEX_NAME = 'registration_attempt_expires_at_idx'
);
SET @sql := IF(@exists = 0,
  'CREATE INDEX `registration_attempt_expires_at_idx` ON `registration_attempt`(`expires_at`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'registration_attempt'
    AND INDEX_NAME = 'registration_attempt_tenant_id_idx'
);
SET @sql := IF(@exists = 0,
  'CREATE INDEX `registration_attempt_tenant_id_idx` ON `registration_attempt`(`tenant_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'registration_attempt'
    AND INDEX_NAME = 'registration_attempt_facility_id_idx'
);
SET @sql := IF(@exists = 0,
  'CREATE INDEX `registration_attempt_facility_id_idx` ON `registration_attempt`(`facility_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'registration_attempt'
    AND INDEX_NAME = 'registration_attempt_deleted_at_idx'
);
SET @sql := IF(@exists = 0,
  'CREATE INDEX `registration_attempt_deleted_at_idx` ON `registration_attempt`(`deleted_at`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'registration_attempt'
    AND INDEX_NAME = 'registration_attempt_human_friendly_id_idx'
);
SET @sql := IF(@exists = 0,
  'CREATE INDEX `registration_attempt_human_friendly_id_idx` ON `registration_attempt`(`human_friendly_id`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'registration_attempt'
    AND CONSTRAINT_NAME = 'registration_attempt_user_id_fkey'
);
SET @sql := IF(@exists = 0,
  'ALTER TABLE `registration_attempt` ADD CONSTRAINT `registration_attempt_user_id_fkey` FOREIGN KEY (`user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'registration_attempt'
    AND CONSTRAINT_NAME = 'registration_attempt_tenant_id_fkey'
);
SET @sql := IF(@exists = 0,
  'ALTER TABLE `registration_attempt` ADD CONSTRAINT `registration_attempt_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'registration_attempt'
    AND CONSTRAINT_NAME = 'registration_attempt_facility_id_fkey'
);
SET @sql := IF(@exists = 0,
  'ALTER TABLE `registration_attempt` ADD CONSTRAINT `registration_attempt_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
