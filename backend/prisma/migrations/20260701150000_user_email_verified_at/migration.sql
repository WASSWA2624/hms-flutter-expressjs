-- AlterTable
ALTER TABLE `user` ADD COLUMN `email_verified_at` DATETIME(3) NULL;

-- CreateIndex
CREATE INDEX `user_email_verified_at_idx` ON `user`(`email_verified_at`);
