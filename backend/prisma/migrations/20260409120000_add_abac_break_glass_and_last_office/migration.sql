-- CreateTable
CREATE TABLE `abac_policy` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `branch_id` VARCHAR(36) NULL,
    `department_id` VARCHAR(36) NULL,
    `name` VARCHAR(255) NOT NULL,
    `description` TEXT NULL,
    `resource_type` VARCHAR(120) NOT NULL,
    `action` VARCHAR(120) NOT NULL,
    `effect` ENUM('ALLOW', 'DENY') NOT NULL,
    `priority` INTEGER NOT NULL DEFAULT 100,
    `subject_conditions_json` JSON NULL,
    `object_conditions_json` JSON NULL,
    `environment_conditions_json` JSON NULL,
    `reason_template` VARCHAR(255) NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `created_by_user_id` VARCHAR(36) NULL,
    `updated_by_user_id` VARCHAR(36) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `abac_policy_tenant_id_idx`(`tenant_id`),
    INDEX `abac_policy_facility_id_idx`(`facility_id`),
    INDEX `abac_policy_branch_id_idx`(`branch_id`),
    INDEX `abac_policy_department_id_idx`(`department_id`),
    INDEX `abac_policy_resource_type_idx`(`resource_type`),
    INDEX `abac_policy_action_idx`(`action`),
    INDEX `abac_policy_effect_idx`(`effect`),
    INDEX `abac_policy_priority_idx`(`priority`),
    INDEX `abac_policy_is_active_idx`(`is_active`),
    INDEX `abac_policy_created_by_user_id_idx`(`created_by_user_id`),
    INDEX `abac_policy_updated_by_user_id_idx`(`updated_by_user_id`),
    INDEX `abac_policy_deleted_at_idx`(`deleted_at`),
    INDEX `abac_policy_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `break_glass_access` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `branch_id` VARCHAR(36) NULL,
    `patient_id` VARCHAR(36) NULL,
    `target_resource_type` VARCHAR(120) NOT NULL,
    `target_resource_id` VARCHAR(36) NULL,
    `requested_by_user_id` VARCHAR(36) NOT NULL,
    `approved_by_user_id` VARCHAR(36) NULL,
    `revoked_by_user_id` VARCHAR(36) NULL,
    `reason` VARCHAR(255) NOT NULL,
    `justification_json` JSON NULL,
    `requested_scope_json` JSON NULL,
    `status` ENUM('REQUESTED', 'ACTIVE', 'REJECTED', 'EXPIRED', 'REVOKED') NOT NULL DEFAULT 'REQUESTED',
    `review_status` ENUM('PENDING', 'APPROVED', 'REJECTED', 'ESCALATED') NOT NULL DEFAULT 'PENDING',
    `requested_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `approved_at` DATETIME(3) NULL,
    `starts_at` DATETIME(3) NULL,
    `expires_at` DATETIME(3) NULL,
    `revoked_at` DATETIME(3) NULL,
    `revoke_reason` TEXT NULL,
    `reviewed_at` DATETIME(3) NULL,
    `etag` VARCHAR(128) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `break_glass_access_tenant_id_idx`(`tenant_id`),
    INDEX `break_glass_access_facility_id_idx`(`facility_id`),
    INDEX `break_glass_access_branch_id_idx`(`branch_id`),
    INDEX `break_glass_access_patient_id_idx`(`patient_id`),
    INDEX `break_glass_access_target_resource_type_idx`(`target_resource_type`),
    INDEX `break_glass_access_target_resource_id_idx`(`target_resource_id`),
    INDEX `break_glass_access_requested_by_user_id_idx`(`requested_by_user_id`),
    INDEX `break_glass_access_approved_by_user_id_idx`(`approved_by_user_id`),
    INDEX `break_glass_access_revoked_by_user_id_idx`(`revoked_by_user_id`),
    INDEX `break_glass_access_status_idx`(`status`),
    INDEX `break_glass_access_review_status_idx`(`review_status`),
    INDEX `break_glass_access_requested_at_idx`(`requested_at`),
    INDEX `break_glass_access_expires_at_idx`(`expires_at`),
    INDEX `break_glass_access_deleted_at_idx`(`deleted_at`),
    INDEX `break_glass_access_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `break_glass_review` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `break_glass_access_id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `reviewer_user_id` VARCHAR(36) NOT NULL,
    `status` ENUM('PENDING', 'APPROVED', 'REJECTED', 'ESCALATED') NOT NULL,
    `notes` TEXT NULL,
    `decided_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `break_glass_review_break_glass_access_id_idx`(`break_glass_access_id`),
    INDEX `break_glass_review_tenant_id_idx`(`tenant_id`),
    INDEX `break_glass_review_reviewer_user_id_idx`(`reviewer_user_id`),
    INDEX `break_glass_review_status_idx`(`status`),
    INDEX `break_glass_review_decided_at_idx`(`decided_at`),
    INDEX `break_glass_review_deleted_at_idx`(`deleted_at`),
    INDEX `break_glass_review_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `office_context` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `branch_id` VARCHAR(36) NULL,
    `shift_id` VARCHAR(36) NOT NULL,
    `opened_by_user_id` VARCHAR(36) NOT NULL,
    `current_holder_user_id` VARCHAR(36) NULL,
    `office_date` DATETIME(3) NOT NULL,
    `status` ENUM('OPEN', 'HANDOVER_PENDING', 'CLOSED') NOT NULL DEFAULT 'OPEN',
    `opened_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `closed_at` DATETIME(3) NULL,
    `handover_due_at` DATETIME(3) NULL,
    `notes` TEXT NULL,
    `metadata_json` JSON NULL,
    `etag` VARCHAR(128) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `office_context_tenant_id_idx`(`tenant_id`),
    INDEX `office_context_facility_id_idx`(`facility_id`),
    INDEX `office_context_branch_id_idx`(`branch_id`),
    INDEX `office_context_shift_id_idx`(`shift_id`),
    INDEX `office_context_opened_by_user_id_idx`(`opened_by_user_id`),
    INDEX `office_context_current_holder_user_id_idx`(`current_holder_user_id`),
    INDEX `office_context_office_date_idx`(`office_date`),
    INDEX `office_context_status_idx`(`status`),
    INDEX `office_context_deleted_at_idx`(`deleted_at`),
    INDEX `office_context_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `shift_close` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `branch_id` VARCHAR(36) NULL,
    `office_context_id` VARCHAR(36) NOT NULL,
    `shift_id` VARCHAR(36) NOT NULL,
    `closed_by_user_id` VARCHAR(36) NOT NULL,
    `approved_by_user_id` VARCHAR(36) NULL,
    `status` ENUM('DRAFT', 'SUBMITTED', 'APPROVED', 'REJECTED') NOT NULL DEFAULT 'DRAFT',
    `totals_json` JSON NULL,
    `reconciliation_json` JSON NULL,
    `expected_amount` DECIMAL(12, 2) NULL,
    `actual_amount` DECIMAL(12, 2) NULL,
    `variance_amount` DECIMAL(12, 2) NULL,
    `submitted_at` DATETIME(3) NULL,
    `approved_at` DATETIME(3) NULL,
    `notes` TEXT NULL,
    `evidence_json` JSON NULL,
    `etag` VARCHAR(128) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `shift_close_tenant_id_idx`(`tenant_id`),
    INDEX `shift_close_facility_id_idx`(`facility_id`),
    INDEX `shift_close_branch_id_idx`(`branch_id`),
    INDEX `shift_close_office_context_id_idx`(`office_context_id`),
    INDEX `shift_close_shift_id_idx`(`shift_id`),
    INDEX `shift_close_closed_by_user_id_idx`(`closed_by_user_id`),
    INDEX `shift_close_approved_by_user_id_idx`(`approved_by_user_id`),
    INDEX `shift_close_status_idx`(`status`),
    INDEX `shift_close_submitted_at_idx`(`submitted_at`),
    INDEX `shift_close_approved_at_idx`(`approved_at`),
    INDEX `shift_close_deleted_at_idx`(`deleted_at`),
    INDEX `shift_close_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `day_close` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `branch_id` VARCHAR(36) NULL,
    `office_context_id` VARCHAR(36) NOT NULL,
    `submitted_by_user_id` VARCHAR(36) NOT NULL,
    `approved_by_user_id` VARCHAR(36) NULL,
    `status` ENUM('DRAFT', 'SUBMITTED', 'APPROVED', 'REJECTED') NOT NULL DEFAULT 'DRAFT',
    `checklist_json` JSON NULL,
    `blockers_json` JSON NULL,
    `unresolved_items_json` JSON NULL,
    `submitted_at` DATETIME(3) NULL,
    `approved_at` DATETIME(3) NULL,
    `notes` TEXT NULL,
    `evidence_json` JSON NULL,
    `etag` VARCHAR(128) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `day_close_tenant_id_idx`(`tenant_id`),
    INDEX `day_close_facility_id_idx`(`facility_id`),
    INDEX `day_close_branch_id_idx`(`branch_id`),
    INDEX `day_close_office_context_id_idx`(`office_context_id`),
    INDEX `day_close_submitted_by_user_id_idx`(`submitted_by_user_id`),
    INDEX `day_close_approved_by_user_id_idx`(`approved_by_user_id`),
    INDEX `day_close_status_idx`(`status`),
    INDEX `day_close_submitted_at_idx`(`submitted_at`),
    INDEX `day_close_approved_at_idx`(`approved_at`),
    INDEX `day_close_deleted_at_idx`(`deleted_at`),
    INDEX `day_close_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `handover` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `branch_id` VARCHAR(36) NULL,
    `office_context_id` VARCHAR(36) NOT NULL,
    `from_user_id` VARCHAR(36) NOT NULL,
    `to_user_id` VARCHAR(36) NOT NULL,
    `status` ENUM('PENDING', 'ACCEPTED', 'REJECTED', 'CANCELLED') NOT NULL DEFAULT 'PENDING',
    `items_json` JSON NULL,
    `signoff_notes` TEXT NULL,
    `accepted_notes` TEXT NULL,
    `submitted_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `accepted_at` DATETIME(3) NULL,
    `etag` VARCHAR(128) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `handover_tenant_id_idx`(`tenant_id`),
    INDEX `handover_facility_id_idx`(`facility_id`),
    INDEX `handover_branch_id_idx`(`branch_id`),
    INDEX `handover_office_context_id_idx`(`office_context_id`),
    INDEX `handover_from_user_id_idx`(`from_user_id`),
    INDEX `handover_to_user_id_idx`(`to_user_id`),
    INDEX `handover_status_idx`(`status`),
    INDEX `handover_submitted_at_idx`(`submitted_at`),
    INDEX `handover_accepted_at_idx`(`accepted_at`),
    INDEX `handover_deleted_at_idx`(`deleted_at`),
    INDEX `handover_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `custody_snapshot` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `branch_id` VARCHAR(36) NULL,
    `office_context_id` VARCHAR(36) NOT NULL,
    `captured_by_user_id` VARCHAR(36) NOT NULL,
    `status` ENUM('DRAFT', 'FINALIZED') NOT NULL DEFAULT 'DRAFT',
    `asset_snapshot_json` JSON NULL,
    `cash_drawer_snapshot_json` JSON NULL,
    `controlled_items_json` JSON NULL,
    `captured_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `finalized_at` DATETIME(3) NULL,
    `notes` TEXT NULL,
    `etag` VARCHAR(128) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `custody_snapshot_tenant_id_idx`(`tenant_id`),
    INDEX `custody_snapshot_facility_id_idx`(`facility_id`),
    INDEX `custody_snapshot_branch_id_idx`(`branch_id`),
    INDEX `custody_snapshot_office_context_id_idx`(`office_context_id`),
    INDEX `custody_snapshot_captured_by_user_id_idx`(`captured_by_user_id`),
    INDEX `custody_snapshot_status_idx`(`status`),
    INDEX `custody_snapshot_captured_at_idx`(`captured_at`),
    INDEX `custody_snapshot_finalized_at_idx`(`finalized_at`),
    INDEX `custody_snapshot_deleted_at_idx`(`deleted_at`),
    INDEX `custody_snapshot_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `closeout_pack` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `branch_id` VARCHAR(36) NULL,
    `office_context_id` VARCHAR(36) NOT NULL,
    `shift_close_id` VARCHAR(36) NULL,
    `day_close_id` VARCHAR(36) NULL,
    `handover_id` VARCHAR(36) NULL,
    `custody_snapshot_id` VARCHAR(36) NULL,
    `generated_by_user_id` VARCHAR(36) NULL,
    `status` ENUM('QUEUED', 'PROCESSING', 'READY', 'FAILED') NOT NULL DEFAULT 'QUEUED',
    `format` VARCHAR(20) NOT NULL,
    `output_storage_path` VARCHAR(512) NULL,
    `output_file_name` VARCHAR(255) NULL,
    `output_mime_type` VARCHAR(120) NULL,
    `output_size_bytes` INTEGER NULL,
    `checksum` VARCHAR(128) NULL,
    `generated_at` DATETIME(3) NULL,
    `error_message` TEXT NULL,
    `summary_json` JSON NULL,
    `parameter_overrides_json` JSON NULL,
    `etag` VARCHAR(128) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `closeout_pack_tenant_id_idx`(`tenant_id`),
    INDEX `closeout_pack_facility_id_idx`(`facility_id`),
    INDEX `closeout_pack_branch_id_idx`(`branch_id`),
    INDEX `closeout_pack_office_context_id_idx`(`office_context_id`),
    INDEX `closeout_pack_shift_close_id_idx`(`shift_close_id`),
    INDEX `closeout_pack_day_close_id_idx`(`day_close_id`),
    INDEX `closeout_pack_handover_id_idx`(`handover_id`),
    INDEX `closeout_pack_custody_snapshot_id_idx`(`custody_snapshot_id`),
    INDEX `closeout_pack_generated_by_user_id_idx`(`generated_by_user_id`),
    INDEX `closeout_pack_status_idx`(`status`),
    INDEX `closeout_pack_generated_at_idx`(`generated_at`),
    INDEX `closeout_pack_deleted_at_idx`(`deleted_at`),
    INDEX `closeout_pack_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `abac_policy` ADD CONSTRAINT `abac_policy_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `abac_policy` ADD CONSTRAINT `abac_policy_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `abac_policy` ADD CONSTRAINT `abac_policy_branch_id_fkey` FOREIGN KEY (`branch_id`) REFERENCES `branch`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `abac_policy` ADD CONSTRAINT `abac_policy_department_id_fkey` FOREIGN KEY (`department_id`) REFERENCES `department`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `abac_policy` ADD CONSTRAINT `abac_policy_created_by_user_id_fkey` FOREIGN KEY (`created_by_user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `abac_policy` ADD CONSTRAINT `abac_policy_updated_by_user_id_fkey` FOREIGN KEY (`updated_by_user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `break_glass_access` ADD CONSTRAINT `break_glass_access_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `break_glass_access` ADD CONSTRAINT `break_glass_access_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `break_glass_access` ADD CONSTRAINT `break_glass_access_branch_id_fkey` FOREIGN KEY (`branch_id`) REFERENCES `branch`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `break_glass_access` ADD CONSTRAINT `break_glass_access_patient_id_fkey` FOREIGN KEY (`patient_id`) REFERENCES `patient`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `break_glass_access` ADD CONSTRAINT `break_glass_access_requested_by_user_id_fkey` FOREIGN KEY (`requested_by_user_id`) REFERENCES `user`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `break_glass_access` ADD CONSTRAINT `break_glass_access_approved_by_user_id_fkey` FOREIGN KEY (`approved_by_user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `break_glass_access` ADD CONSTRAINT `break_glass_access_revoked_by_user_id_fkey` FOREIGN KEY (`revoked_by_user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `break_glass_review` ADD CONSTRAINT `break_glass_review_break_glass_access_id_fkey` FOREIGN KEY (`break_glass_access_id`) REFERENCES `break_glass_access`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `break_glass_review` ADD CONSTRAINT `break_glass_review_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `break_glass_review` ADD CONSTRAINT `break_glass_review_reviewer_user_id_fkey` FOREIGN KEY (`reviewer_user_id`) REFERENCES `user`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `office_context` ADD CONSTRAINT `office_context_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `office_context` ADD CONSTRAINT `office_context_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `office_context` ADD CONSTRAINT `office_context_branch_id_fkey` FOREIGN KEY (`branch_id`) REFERENCES `branch`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `office_context` ADD CONSTRAINT `office_context_shift_id_fkey` FOREIGN KEY (`shift_id`) REFERENCES `shift`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `office_context` ADD CONSTRAINT `office_context_opened_by_user_id_fkey` FOREIGN KEY (`opened_by_user_id`) REFERENCES `user`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `office_context` ADD CONSTRAINT `office_context_current_holder_user_id_fkey` FOREIGN KEY (`current_holder_user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `shift_close` ADD CONSTRAINT `shift_close_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `shift_close` ADD CONSTRAINT `shift_close_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `shift_close` ADD CONSTRAINT `shift_close_branch_id_fkey` FOREIGN KEY (`branch_id`) REFERENCES `branch`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `shift_close` ADD CONSTRAINT `shift_close_office_context_id_fkey` FOREIGN KEY (`office_context_id`) REFERENCES `office_context`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `shift_close` ADD CONSTRAINT `shift_close_shift_id_fkey` FOREIGN KEY (`shift_id`) REFERENCES `shift`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `shift_close` ADD CONSTRAINT `shift_close_closed_by_user_id_fkey` FOREIGN KEY (`closed_by_user_id`) REFERENCES `user`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `shift_close` ADD CONSTRAINT `shift_close_approved_by_user_id_fkey` FOREIGN KEY (`approved_by_user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `day_close` ADD CONSTRAINT `day_close_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `day_close` ADD CONSTRAINT `day_close_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `day_close` ADD CONSTRAINT `day_close_branch_id_fkey` FOREIGN KEY (`branch_id`) REFERENCES `branch`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `day_close` ADD CONSTRAINT `day_close_office_context_id_fkey` FOREIGN KEY (`office_context_id`) REFERENCES `office_context`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `day_close` ADD CONSTRAINT `day_close_submitted_by_user_id_fkey` FOREIGN KEY (`submitted_by_user_id`) REFERENCES `user`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `day_close` ADD CONSTRAINT `day_close_approved_by_user_id_fkey` FOREIGN KEY (`approved_by_user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `handover` ADD CONSTRAINT `handover_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `handover` ADD CONSTRAINT `handover_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `handover` ADD CONSTRAINT `handover_branch_id_fkey` FOREIGN KEY (`branch_id`) REFERENCES `branch`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `handover` ADD CONSTRAINT `handover_office_context_id_fkey` FOREIGN KEY (`office_context_id`) REFERENCES `office_context`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `handover` ADD CONSTRAINT `handover_from_user_id_fkey` FOREIGN KEY (`from_user_id`) REFERENCES `user`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `handover` ADD CONSTRAINT `handover_to_user_id_fkey` FOREIGN KEY (`to_user_id`) REFERENCES `user`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `custody_snapshot` ADD CONSTRAINT `custody_snapshot_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `custody_snapshot` ADD CONSTRAINT `custody_snapshot_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `custody_snapshot` ADD CONSTRAINT `custody_snapshot_branch_id_fkey` FOREIGN KEY (`branch_id`) REFERENCES `branch`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `custody_snapshot` ADD CONSTRAINT `custody_snapshot_office_context_id_fkey` FOREIGN KEY (`office_context_id`) REFERENCES `office_context`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `custody_snapshot` ADD CONSTRAINT `custody_snapshot_captured_by_user_id_fkey` FOREIGN KEY (`captured_by_user_id`) REFERENCES `user`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `closeout_pack` ADD CONSTRAINT `closeout_pack_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `closeout_pack` ADD CONSTRAINT `closeout_pack_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `closeout_pack` ADD CONSTRAINT `closeout_pack_branch_id_fkey` FOREIGN KEY (`branch_id`) REFERENCES `branch`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `closeout_pack` ADD CONSTRAINT `closeout_pack_office_context_id_fkey` FOREIGN KEY (`office_context_id`) REFERENCES `office_context`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `closeout_pack` ADD CONSTRAINT `closeout_pack_shift_close_id_fkey` FOREIGN KEY (`shift_close_id`) REFERENCES `shift_close`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `closeout_pack` ADD CONSTRAINT `closeout_pack_day_close_id_fkey` FOREIGN KEY (`day_close_id`) REFERENCES `day_close`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `closeout_pack` ADD CONSTRAINT `closeout_pack_handover_id_fkey` FOREIGN KEY (`handover_id`) REFERENCES `handover`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `closeout_pack` ADD CONSTRAINT `closeout_pack_custody_snapshot_id_fkey` FOREIGN KEY (`custody_snapshot_id`) REFERENCES `custody_snapshot`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `closeout_pack` ADD CONSTRAINT `closeout_pack_generated_by_user_id_fkey` FOREIGN KEY (`generated_by_user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;
