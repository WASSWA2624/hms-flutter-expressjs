-- Allow platform-scoped roles (tenant_id NULL).
ALTER TABLE `role` DROP FOREIGN KEY `role_tenant_id_fkey`;
ALTER TABLE `role` MODIFY `tenant_id` VARCHAR(36) NULL;
ALTER TABLE `role` ADD CONSTRAINT `role_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
