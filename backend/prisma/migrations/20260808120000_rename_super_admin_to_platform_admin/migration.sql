-- Rename Super Admin → Platform Admin in live RBAC catalog rows.
-- Role/permission names are string keys (not Prisma UserRole enum columns).

-- When PLATFORM_ADMIN already exists in the same tenant scope, re-point
-- assignments and soft-delete SUPER_ADMIN.
UPDATE `user_role` ur
INNER JOIN `role` old_role
  ON old_role.id = ur.role_id
 AND old_role.name = 'SUPER_ADMIN'
INNER JOIN `role` new_role
  ON new_role.name = 'PLATFORM_ADMIN'
 AND new_role.deleted_at IS NULL
 AND (
   (old_role.tenant_id IS NULL AND new_role.tenant_id IS NULL)
   OR old_role.tenant_id = new_role.tenant_id
 )
SET ur.role_id = new_role.id
WHERE NOT EXISTS (
  SELECT 1
  FROM `user_role` existing
  WHERE existing.user_id = ur.user_id
    AND existing.role_id = new_role.id
    AND existing.deleted_at IS NULL
);

UPDATE `role`
SET
  `deleted_at` = COALESCE(`deleted_at`, CURRENT_TIMESTAMP(3)),
  `updated_at` = CURRENT_TIMESTAMP(3)
WHERE `name` = 'SUPER_ADMIN'
  AND EXISTS (
    SELECT 1
    FROM `role` existing
    WHERE existing.name = 'PLATFORM_ADMIN'
      AND existing.deleted_at IS NULL
      AND (
        (`role`.tenant_id IS NULL AND existing.tenant_id IS NULL)
        OR `role`.tenant_id = existing.tenant_id
      )
  );

UPDATE `role`
SET
  `name` = 'PLATFORM_ADMIN',
  `display_name` = CASE
    WHEN `display_name` IS NULL
      OR TRIM(`display_name`) = ''
      OR `display_name` IN ('Super Admin', 'SUPER_ADMIN')
    THEN 'Platform Admin'
    ELSE `display_name`
  END,
  `updated_at` = CURRENT_TIMESTAMP(3)
WHERE `name` = 'SUPER_ADMIN'
  AND `deleted_at` IS NULL;

-- Permissions are tenant-scoped; rematch within the same tenant_id.
UPDATE `role_permission` rp
INNER JOIN `permission` old_perm
  ON old_perm.id = rp.permission_id
 AND old_perm.name = 'system:admin'
INNER JOIN `permission` new_perm
  ON new_perm.name = 'platform:admin'
 AND new_perm.deleted_at IS NULL
 AND new_perm.tenant_id = old_perm.tenant_id
SET rp.permission_id = new_perm.id
WHERE NOT EXISTS (
  SELECT 1
  FROM `role_permission` existing
  WHERE existing.role_id = rp.role_id
    AND existing.permission_id = new_perm.id
    AND existing.deleted_at IS NULL
);

UPDATE `user_permission` up
INNER JOIN `permission` old_perm
  ON old_perm.id = up.permission_id
 AND old_perm.name = 'system:admin'
INNER JOIN `permission` new_perm
  ON new_perm.name = 'platform:admin'
 AND new_perm.deleted_at IS NULL
 AND new_perm.tenant_id = old_perm.tenant_id
SET up.permission_id = new_perm.id
WHERE NOT EXISTS (
  SELECT 1
  FROM `user_permission` existing
  WHERE existing.user_id = up.user_id
    AND existing.permission_id = new_perm.id
    AND existing.deleted_at IS NULL
);

UPDATE `permission`
SET
  `deleted_at` = COALESCE(`deleted_at`, CURRENT_TIMESTAMP(3)),
  `updated_at` = CURRENT_TIMESTAMP(3)
WHERE `name` = 'system:admin'
  AND EXISTS (
    SELECT 1
    FROM `permission` existing
    WHERE existing.name = 'platform:admin'
      AND existing.deleted_at IS NULL
      AND existing.tenant_id = `permission`.tenant_id
  );

UPDATE `permission`
SET
  `name` = 'platform:admin',
  `display_name` = CASE
    WHEN `display_name` IS NULL
      OR TRIM(`display_name`) = ''
      OR `display_name` IN ('System — Admin', 'System - Admin', 'system:admin')
    THEN 'Platform — Admin'
    ELSE `display_name`
  END,
  `updated_at` = CURRENT_TIMESTAMP(3)
WHERE `name` = 'system:admin'
  AND `deleted_at` IS NULL;
