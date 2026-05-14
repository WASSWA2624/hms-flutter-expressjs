/*
  Warnings:

  - Added the required column `tenant_id` to the `report_run` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE `report_definition` ADD COLUMN `created_by` VARCHAR(36) NULL;

-- AlterTable
ALTER TABLE `report_run` ADD COLUMN `tenant_id` VARCHAR(36) NOT NULL;

-- CreateIndex
CREATE INDEX `report_definition_created_by_idx` ON `report_definition`(`created_by`);

-- CreateIndex
CREATE INDEX `report_run_tenant_id_idx` ON `report_run`(`tenant_id`);

-- AddForeignKey
ALTER TABLE `report_definition` ADD CONSTRAINT `report_definition_created_by_fkey` FOREIGN KEY (`created_by`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `report_run` ADD CONSTRAINT `report_run_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
