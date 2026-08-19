-- Communications workspace tables and conversation/message fields required before participant flags.

-- AlterTable
ALTER TABLE `conversation`
    ADD COLUMN `conversation_type` ENUM('DIRECT', 'GROUP') NOT NULL DEFAULT 'DIRECT',
    ADD COLUMN `status` ENUM('OPEN', 'ARCHIVED', 'CLOSED') NOT NULL DEFAULT 'OPEN',
    ADD COLUMN `is_sensitive` BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN `last_message_at` DATETIME(3) NULL,
    ADD COLUMN `archived_at` DATETIME(3) NULL;

-- CreateIndex
CREATE UNIQUE INDEX `conversation_tenant_id_human_friendly_id_key` ON `conversation`(`tenant_id`, `human_friendly_id`);
CREATE INDEX `conversation_status_idx` ON `conversation`(`status`);
CREATE INDEX `conversation_last_message_at_idx` ON `conversation`(`last_message_at`);

-- AlterTable
ALTER TABLE `message`
    ADD COLUMN `reply_to_message_id` VARCHAR(36) NULL,
    ADD COLUMN `message_type` ENUM('TEXT', 'SYSTEM') NOT NULL DEFAULT 'TEXT',
    ADD COLUMN `edited_at` DATETIME(3) NULL;

-- CreateIndex
CREATE INDEX `message_reply_to_message_id_idx` ON `message`(`reply_to_message_id`);

-- CreateTable
CREATE TABLE `conversation_participant` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `conversation_id` VARCHAR(36) NOT NULL,
    `user_id` VARCHAR(36) NOT NULL,
    `role_snapshot` VARCHAR(80) NULL,
    `joined_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `last_read_message_id` VARCHAR(36) NULL,
    `last_read_at` DATETIME(3) NULL,
    `archived_at` DATETIME(3) NULL,
    `muted_at` DATETIME(3) NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    UNIQUE INDEX `conversation_participant_conversation_id_user_id_key`(`conversation_id`, `user_id`),
    INDEX `conversation_participant_conversation_id_idx`(`conversation_id`),
    INDEX `conversation_participant_user_id_idx`(`user_id`),
    INDEX `conversation_participant_last_read_message_id_idx`(`last_read_message_id`),
    INDEX `conversation_participant_deleted_at_idx`(`deleted_at`),
    INDEX `conversation_participant_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB;

-- CreateTable
CREATE TABLE `conversation_visibility_role` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `conversation_id` VARCHAR(36) NOT NULL,
    `role_code` VARCHAR(80) NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    UNIQUE INDEX `conversation_visibility_role_conversation_id_role_code_key`(`conversation_id`, `role_code`),
    INDEX `conversation_visibility_role_tenant_id_idx`(`tenant_id`),
    INDEX `conversation_visibility_role_conversation_id_idx`(`conversation_id`),
    INDEX `conversation_visibility_role_deleted_at_idx`(`deleted_at`),
    INDEX `conversation_visibility_role_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB;

-- CreateTable
CREATE TABLE `message_attachment` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `message_id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `uploaded_by_user_id` VARCHAR(36) NULL,
    `storage_key` VARCHAR(255) NOT NULL,
    `storage_provider` VARCHAR(80) NOT NULL,
    `file_name` VARCHAR(255) NOT NULL,
    `content_type` VARCHAR(120) NOT NULL,
    `size_bytes` INTEGER NOT NULL,
    `attachment_kind` ENUM('DOCUMENT', 'IMAGE') NOT NULL,
    `public_url` VARCHAR(255) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `message_attachment_message_id_idx`(`message_id`),
    INDEX `message_attachment_tenant_id_idx`(`tenant_id`),
    INDEX `message_attachment_uploaded_by_user_id_idx`(`uploaded_by_user_id`),
    INDEX `message_attachment_attachment_kind_idx`(`attachment_kind`),
    INDEX `message_attachment_deleted_at_idx`(`deleted_at`),
    INDEX `message_attachment_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB;

-- AddForeignKey
ALTER TABLE `message` ADD CONSTRAINT `message_reply_to_message_id_fkey` FOREIGN KEY (`reply_to_message_id`) REFERENCES `message`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `conversation_participant` ADD CONSTRAINT `conversation_participant_conversation_id_fkey` FOREIGN KEY (`conversation_id`) REFERENCES `conversation`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `conversation_participant` ADD CONSTRAINT `conversation_participant_user_id_fkey` FOREIGN KEY (`user_id`) REFERENCES `user`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `conversation_participant` ADD CONSTRAINT `conversation_participant_last_read_message_id_fkey` FOREIGN KEY (`last_read_message_id`) REFERENCES `message`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `conversation_visibility_role` ADD CONSTRAINT `conversation_visibility_role_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `conversation_visibility_role` ADD CONSTRAINT `conversation_visibility_role_conversation_id_fkey` FOREIGN KEY (`conversation_id`) REFERENCES `conversation`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `message_attachment` ADD CONSTRAINT `message_attachment_message_id_fkey` FOREIGN KEY (`message_id`) REFERENCES `message`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `message_attachment` ADD CONSTRAINT `message_attachment_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `message_attachment` ADD CONSTRAINT `message_attachment_uploaded_by_user_id_fkey` FOREIGN KEY (`uploaded_by_user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;
