-- Persistent authentication: session lifetime anchors.
--
-- `user_session` gains the two timestamps the idle and absolute timeouts are
-- measured from. Refreshing rotates the token by writing a new row and revoking
-- the old one, so without these a chain had no memory:
--
--   * `chain_started_at` is inherited by every rotation, so the absolute
--     ceiling is anchored to the original sign-in. Before this column, each
--     refresh reset `expires_at` to now + AUTH_SESSION_TTL_DAYS and a session
--     could be kept alive indefinitely by refreshing.
--   * `last_used_at` is reset on every rotation and is what the idle timeout
--     reads. An expired ACCESS token is not idleness -- only the gap between
--     successful refreshes counts.
--
-- Both are nullable on purpose. Existing rows are backfilled from `created_at`
-- below, and the application treats a NULL anchor as "unknown" rather than
-- "epoch", so a row this migration cannot date is never revoked for being old.
--
-- Guarded with information_schema + PREPARE because the fleet spans MariaDB
-- builds without `ADD COLUMN IF NOT EXISTS`, and Prisma cannot run DELIMITER.

SET @exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'user_session'
    AND COLUMN_NAME = 'chain_started_at'
);
SET @sql := IF(@exists = 0,
  'ALTER TABLE `user_session` ADD COLUMN `chain_started_at` DATETIME(3) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'user_session'
    AND COLUMN_NAME = 'last_used_at'
);
SET @sql := IF(@exists = 0,
  'ALTER TABLE `user_session` ADD COLUMN `last_used_at` DATETIME(3) NULL',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Backfill. Idempotent: only rows still missing an anchor are touched, so this
-- is safe to re-run and safe to run while the application is serving traffic.
-- `created_at` is the honest origin for a session that predates the policy --
-- the rotation history is not recorded, so each surviving row is treated as
-- its own chain.
UPDATE `user_session`
   SET `chain_started_at` = `created_at`
 WHERE `chain_started_at` IS NULL;

UPDATE `user_session`
   SET `last_used_at` = `created_at`
 WHERE `last_used_at` IS NULL;

SET @exists := (
  SELECT COUNT(1) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'user_session'
    AND INDEX_NAME = 'user_session_last_used_at_idx'
);
SET @sql := IF(@exists = 0,
  'CREATE INDEX `user_session_last_used_at_idx` ON `user_session`(`last_used_at`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
