-- Allow platform-scoped permissions (tenant_id NULL), matching platform roles.
ALTER TABLE `permission`
  DROP FOREIGN KEY `permission_tenant_id_fkey`;

ALTER TABLE `permission`
  MODIFY `tenant_id` VARCHAR(36) NULL;

ALTER TABLE `permission`
  ADD CONSTRAINT `permission_tenant_id_fkey`
  FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`)
  ON DELETE SET NULL
  ON UPDATE CASCADE;
