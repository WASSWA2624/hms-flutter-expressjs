-- Canonical demo login emails:
--   platform.admin@hosspi.com  (PLATFORM_ADMIN; formerly super.admin@hosspi.com)
--   platform.owner@hosspi.com  (PLATFORM_OWNER; created/updated by seed)

-- Rename legacy platform-admin login when the new address is free.
UPDATE `user`
SET
  `email` = 'platform.admin@hosspi.com',
  `updated_at` = CURRENT_TIMESTAMP(3)
WHERE `email` = 'super.admin@hosspi.com'
  AND `deleted_at` IS NULL
  AND NOT EXISTS (
    SELECT 1
    FROM `user` existing
    WHERE existing.email = 'platform.admin@hosspi.com'
      AND existing.deleted_at IS NULL
  );

-- Soft-delete the legacy address if both already exist (prefer canonical).
UPDATE `user`
SET
  `deleted_at` = COALESCE(`deleted_at`, CURRENT_TIMESTAMP(3)),
  `updated_at` = CURRENT_TIMESTAMP(3)
WHERE `email` = 'super.admin@hosspi.com'
  AND `deleted_at` IS NULL
  AND EXISTS (
    SELECT 1
    FROM `user` existing
    WHERE existing.email = 'platform.admin@hosspi.com'
      AND existing.deleted_at IS NULL
  );
