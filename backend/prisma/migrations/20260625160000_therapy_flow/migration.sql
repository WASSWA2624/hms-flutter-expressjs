-- Therapy flow orchestration tables

CREATE TABLE `therapy_episode` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `encounter_id` VARCHAR(36) NOT NULL,
    `admission_id` VARCHAR(36) NULL,
    `referral_id` VARCHAR(36) NULL,
    `source_kind` VARCHAR(40) NULL,
    `source_id` VARCHAR(36) NULL,
    `source_title` VARCHAR(255) NULL,
    `referral_reason` TEXT NULL,
    `therapist_user_id` VARCHAR(36) NULL,
    `therapy_status` ENUM('REFERRAL', 'ACCEPTED', 'ASSESSMENT', 'ACTIVE_PLAN', 'SESSION_SCHEDULED', 'FOLLOW_UP_DUE', 'MISSED', 'COMPLETED', 'CLOSED') NOT NULL DEFAULT 'REFERRAL',
    `next_step` VARCHAR(255) NULL,
    `plan_summary` TEXT NULL,
    `goals` TEXT NULL,
    `instructions` TEXT NULL,
    `contraindications` TEXT NULL,
    `session_frequency` VARCHAR(120) NULL,
    `plan_started_at` DATETIME(3) NULL,
    `plan_ends_at` DATETIME(3) NULL,
    `outcome_summary` TEXT NULL,
    `billing_status` VARCHAR(40) NULL,
    `billing_snapshot` JSON NULL,
    `accepted_at` DATETIME(3) NULL,
    `assessed_at` DATETIME(3) NULL,
    `closed_at` DATETIME(3) NULL,
    `extension_json` JSON NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `therapy_episode_encounter_id_idx`(`encounter_id`),
    INDEX `therapy_episode_admission_id_idx`(`admission_id`),
    INDEX `therapy_episode_referral_id_idx`(`referral_id`),
    INDEX `therapy_episode_therapist_user_id_idx`(`therapist_user_id`),
    INDEX `therapy_episode_therapy_status_idx`(`therapy_status`),
    INDEX `therapy_episode_source_kind_idx`(`source_kind`),
    INDEX `therapy_episode_closed_at_idx`(`closed_at`),
    INDEX `therapy_episode_deleted_at_idx`(`deleted_at`),
    INDEX `therapy_episode_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `therapy_session` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `therapy_episode_id` VARCHAR(36) NOT NULL,
    `therapist_user_id` VARCHAR(36) NULL,
    `scheduled_start_at` DATETIME(3) NOT NULL,
    `scheduled_end_at` DATETIME(3) NULL,
    `location` VARCHAR(255) NULL,
    `attendance_status` ENUM('SCHEDULED', 'ATTENDED', 'NO_SHOW', 'CANCELLED', 'RESCHEDULED') NOT NULL DEFAULT 'SCHEDULED',
    `session_note` TEXT NULL,
    `billing_snapshot` JSON NULL,
    `attended_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `therapy_session_therapy_episode_id_idx`(`therapy_episode_id`),
    INDEX `therapy_session_therapist_user_id_idx`(`therapist_user_id`),
    INDEX `therapy_session_scheduled_start_at_idx`(`scheduled_start_at`),
    INDEX `therapy_session_attendance_status_idx`(`attendance_status`),
    INDEX `therapy_session_deleted_at_idx`(`deleted_at`),
    INDEX `therapy_session_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE `therapy_episode` ADD CONSTRAINT `therapy_episode_encounter_id_fkey` FOREIGN KEY (`encounter_id`) REFERENCES `encounter`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE `therapy_episode` ADD CONSTRAINT `therapy_episode_admission_id_fkey` FOREIGN KEY (`admission_id`) REFERENCES `admission`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE `therapy_episode` ADD CONSTRAINT `therapy_episode_referral_id_fkey` FOREIGN KEY (`referral_id`) REFERENCES `referral`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE `therapy_episode` ADD CONSTRAINT `therapy_episode_therapist_user_id_fkey` FOREIGN KEY (`therapist_user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE `therapy_session` ADD CONSTRAINT `therapy_session_therapy_episode_id_fkey` FOREIGN KEY (`therapy_episode_id`) REFERENCES `therapy_episode`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE `therapy_session` ADD CONSTRAINT `therapy_session_therapist_user_id_fkey` FOREIGN KEY (`therapist_user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;
