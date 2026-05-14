-- AlterTable
ALTER TABLE `human_id_counter` ADD COLUMN `deleted_at` DATETIME(3) NULL,
    ADD COLUMN `version` INTEGER NOT NULL DEFAULT 1;

-- CreateIndex
CREATE INDEX `human_id_counter_deleted_at_idx` ON `human_id_counter`(`deleted_at`);
