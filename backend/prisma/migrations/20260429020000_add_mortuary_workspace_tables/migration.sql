-- CreateTable
CREATE TABLE `mortuary_deceased_profile` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NOT NULL,
    `first_name` VARCHAR(120) NULL,
    `last_name` VARCHAR(120) NULL,
    `display_name` VARCHAR(255) NOT NULL,
    `gender` ENUM('MALE', 'FEMALE', 'OTHER', 'UNKNOWN') NULL,
    `date_of_birth` DATETIME(3) NULL,
    `date_of_death` DATETIME(3) NULL,
    `next_of_kin_name` VARCHAR(255) NULL,
    `next_of_kin_phone` VARCHAR(40) NULL,
    `next_of_kin_email` VARCHAR(255) NULL,
    `external_reference` VARCHAR(120) NULL,
    `identification_notes` TEXT NULL,
    `extension_json` JSON NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `mortuary_deceased_profile_tenant_id_idx`(`tenant_id`),
    INDEX `mortuary_deceased_profile_facility_id_idx`(`facility_id`),
    INDEX `mortuary_deceased_profile_display_name_idx`(`display_name`),
    INDEX `mortuary_deceased_profile_date_of_death_idx`(`date_of_death`),
    INDEX `mortuary_deceased_profile_deleted_at_idx`(`deleted_at`),
    INDEX `mortuary_deceased_profile_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `mortuary_storage_unit` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `unit_type` VARCHAR(60) NOT NULL,
    `status` VARCHAR(40) NOT NULL DEFAULT 'ACTIVE',
    `location_label` VARCHAR(255) NULL,
    `capacity` INTEGER NOT NULL DEFAULT 0,
    `notes` TEXT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `mortuary_storage_unit_tenant_id_idx`(`tenant_id`),
    INDEX `mortuary_storage_unit_facility_id_idx`(`facility_id`),
    INDEX `mortuary_storage_unit_status_idx`(`status`),
    INDEX `mortuary_storage_unit_unit_type_idx`(`unit_type`),
    INDEX `mortuary_storage_unit_deleted_at_idx`(`deleted_at`),
    INDEX `mortuary_storage_unit_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `mortuary_storage_slot` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NOT NULL,
    `storage_unit_id` VARCHAR(36) NOT NULL,
    `slot_code` VARCHAR(60) NOT NULL,
    `label` VARCHAR(120) NULL,
    `status` ENUM('AVAILABLE', 'OCCUPIED', 'HELD', 'OUT_OF_SERVICE', 'CLEANING') NOT NULL DEFAULT 'AVAILABLE',
    `temperature_zone` VARCHAR(60) NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `notes` TEXT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `mortuary_storage_slot_tenant_id_idx`(`tenant_id`),
    INDEX `mortuary_storage_slot_facility_id_idx`(`facility_id`),
    INDEX `mortuary_storage_slot_storage_unit_id_idx`(`storage_unit_id`),
    INDEX `mortuary_storage_slot_status_idx`(`status`),
    INDEX `mortuary_storage_slot_is_active_idx`(`is_active`),
    INDEX `mortuary_storage_slot_deleted_at_idx`(`deleted_at`),
    INDEX `mortuary_storage_slot_human_friendly_id_idx`(`human_friendly_id`),
    UNIQUE INDEX `mortuary_storage_slot_storage_unit_id_slot_code_key`(`storage_unit_id`, `slot_code`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `mortuary_case` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NOT NULL,
    `patient_id` VARCHAR(36) NULL,
    `deceased_profile_id` VARCHAR(36) NULL,
    `status` ENUM('RECEIVED', 'IDENTIFICATION_PENDING', 'IN_STORAGE', 'POST_MORTEM_PENDING', 'READY_FOR_RELEASE', 'RELEASED', 'CLOSED', 'CANCELLED') NOT NULL DEFAULT 'RECEIVED',
    `identification_status` ENUM('UNVERIFIED', 'PARTIAL', 'VERIFIED') NOT NULL DEFAULT 'UNVERIFIED',
    `source_workflow` VARCHAR(80) NULL,
    `source_department` VARCHAR(120) NULL,
    `source_reference_id` VARCHAR(120) NULL,
    `received_from` VARCHAR(120) NULL,
    `received_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `release_ready_at` DATETIME(3) NULL,
    `released_at` DATETIME(3) NULL,
    `closed_at` DATETIME(3) NULL,
    `next_of_kin_name` VARCHAR(255) NULL,
    `authorised_contact_name` VARCHAR(255) NULL,
    `authorised_contact_phone` VARCHAR(40) NULL,
    `billing_status` VARCHAR(40) NOT NULL DEFAULT 'PENDING',
    `notes` TEXT NULL,
    `extension_json` JSON NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `mortuary_case_tenant_id_idx`(`tenant_id`),
    INDEX `mortuary_case_facility_id_idx`(`facility_id`),
    INDEX `mortuary_case_patient_id_idx`(`patient_id`),
    INDEX `mortuary_case_deceased_profile_id_idx`(`deceased_profile_id`),
    INDEX `mortuary_case_status_idx`(`status`),
    INDEX `mortuary_case_identification_status_idx`(`identification_status`),
    INDEX `mortuary_case_billing_status_idx`(`billing_status`),
    INDEX `mortuary_case_received_at_idx`(`received_at`),
    INDEX `mortuary_case_deleted_at_idx`(`deleted_at`),
    INDEX `mortuary_case_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `mortuary_storage_assignment` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NOT NULL,
    `mortuary_case_id` VARCHAR(36) NOT NULL,
    `storage_unit_id` VARCHAR(36) NOT NULL,
    `storage_slot_id` VARCHAR(36) NOT NULL,
    `assignment_status` VARCHAR(40) NOT NULL DEFAULT 'ACTIVE',
    `assigned_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `ended_at` DATETIME(3) NULL,
    `reason` VARCHAR(255) NULL,
    `notes` TEXT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `mortuary_storage_assignment_tenant_id_idx`(`tenant_id`),
    INDEX `mortuary_storage_assignment_facility_id_idx`(`facility_id`),
    INDEX `mortuary_storage_assignment_mortuary_case_id_idx`(`mortuary_case_id`),
    INDEX `mortuary_storage_assignment_storage_unit_id_idx`(`storage_unit_id`),
    INDEX `mortuary_storage_assignment_storage_slot_id_idx`(`storage_slot_id`),
    INDEX `mortuary_storage_assignment_assignment_status_idx`(`assignment_status`),
    INDEX `mortuary_storage_assignment_assigned_at_idx`(`assigned_at`),
    INDEX `mortuary_storage_assignment_ended_at_idx`(`ended_at`),
    INDEX `mortuary_storage_assignment_deleted_at_idx`(`deleted_at`),
    INDEX `mortuary_storage_assignment_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `mortuary_custody_event` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NOT NULL,
    `mortuary_case_id` VARCHAR(36) NOT NULL,
    `event_type` ENUM('RECEIVED', 'STORAGE_ASSIGNED', 'TRANSFERRED', 'VIEWING', 'POST_MORTEM_TRANSFER', 'DOCUMENT_UPDATED', 'RELEASED', 'CORRECTION') NOT NULL,
    `event_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `actor_name` VARCHAR(255) NULL,
    `actor_role` VARCHAR(120) NULL,
    `location_label` VARCHAR(255) NULL,
    `reason` VARCHAR(255) NULL,
    `notes` TEXT NULL,
    `evidence_json` JSON NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `mortuary_custody_event_tenant_id_idx`(`tenant_id`),
    INDEX `mortuary_custody_event_facility_id_idx`(`facility_id`),
    INDEX `mortuary_custody_event_mortuary_case_id_idx`(`mortuary_case_id`),
    INDEX `mortuary_custody_event_event_type_idx`(`event_type`),
    INDEX `mortuary_custody_event_event_at_idx`(`event_at`),
    INDEX `mortuary_custody_event_deleted_at_idx`(`deleted_at`),
    INDEX `mortuary_custody_event_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `mortuary_viewing` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NOT NULL,
    `mortuary_case_id` VARCHAR(36) NOT NULL,
    `scheduled_at` DATETIME(3) NOT NULL,
    `status` VARCHAR(40) NOT NULL DEFAULT 'SCHEDULED',
    `authorised_by_name` VARCHAR(255) NULL,
    `attendee_summary` TEXT NULL,
    `completed_at` DATETIME(3) NULL,
    `notes` TEXT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `mortuary_viewing_tenant_id_idx`(`tenant_id`),
    INDEX `mortuary_viewing_facility_id_idx`(`facility_id`),
    INDEX `mortuary_viewing_mortuary_case_id_idx`(`mortuary_case_id`),
    INDEX `mortuary_viewing_scheduled_at_idx`(`scheduled_at`),
    INDEX `mortuary_viewing_status_idx`(`status`),
    INDEX `mortuary_viewing_deleted_at_idx`(`deleted_at`),
    INDEX `mortuary_viewing_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `mortuary_post_mortem_request` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NOT NULL,
    `mortuary_case_id` VARCHAR(36) NOT NULL,
    `requested_by_name` VARCHAR(255) NULL,
    `request_reason` TEXT NULL,
    `status` ENUM('REQUESTED', 'APPROVED', 'SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED') NOT NULL DEFAULT 'REQUESTED',
    `diagnostics_reference_id` VARCHAR(120) NULL,
    `scheduled_at` DATETIME(3) NULL,
    `completed_at` DATETIME(3) NULL,
    `report_received_at` DATETIME(3) NULL,
    `notes` TEXT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `mortuary_post_mortem_request_tenant_id_idx`(`tenant_id`),
    INDEX `mortuary_post_mortem_request_facility_id_idx`(`facility_id`),
    INDEX `mortuary_post_mortem_request_mortuary_case_id_idx`(`mortuary_case_id`),
    INDEX `mortuary_post_mortem_request_status_idx`(`status`),
    INDEX `mortuary_post_mortem_request_scheduled_at_idx`(`scheduled_at`),
    INDEX `mortuary_post_mortem_request_deleted_at_idx`(`deleted_at`),
    INDEX `mortuary_post_mortem_request_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `mortuary_release_authorisation` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NOT NULL,
    `mortuary_case_id` VARCHAR(36) NOT NULL,
    `recipient_name` VARCHAR(255) NOT NULL,
    `recipient_relationship` VARCHAR(120) NULL,
    `verification_reference` VARCHAR(120) NULL,
    `funeral_service_name` VARCHAR(255) NULL,
    `release_method` VARCHAR(80) NULL,
    `status` ENUM('DRAFT', 'APPROVED', 'RELEASED', 'CANCELLED') NOT NULL DEFAULT 'DRAFT',
    `approved_by_name` VARCHAR(255) NULL,
    `approved_at` DATETIME(3) NULL,
    `released_at` DATETIME(3) NULL,
    `notes` TEXT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `mortuary_release_authorisation_tenant_id_idx`(`tenant_id`),
    INDEX `mortuary_release_authorisation_facility_id_idx`(`facility_id`),
    INDEX `mortuary_release_authorisation_mortuary_case_id_idx`(`mortuary_case_id`),
    INDEX `mortuary_release_authorisation_status_idx`(`status`),
    INDEX `mortuary_release_authorisation_approved_at_idx`(`approved_at`),
    INDEX `mortuary_release_authorisation_released_at_idx`(`released_at`),
    INDEX `mortuary_release_authorisation_deleted_at_idx`(`deleted_at`),
    INDEX `mortuary_release_authorisation_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `mortuary_billable_event` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NOT NULL,
    `mortuary_case_id` VARCHAR(36) NOT NULL,
    `event_type` VARCHAR(80) NOT NULL,
    `description` TEXT NULL,
    `amount` DECIMAL(12, 2) NULL,
    `currency` VARCHAR(10) NULL,
    `status` VARCHAR(40) NOT NULL DEFAULT 'PENDING',
    `billing_reference_id` VARCHAR(120) NULL,
    `charged_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `settled_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `mortuary_billable_event_tenant_id_idx`(`tenant_id`),
    INDEX `mortuary_billable_event_facility_id_idx`(`facility_id`),
    INDEX `mortuary_billable_event_mortuary_case_id_idx`(`mortuary_case_id`),
    INDEX `mortuary_billable_event_event_type_idx`(`event_type`),
    INDEX `mortuary_billable_event_status_idx`(`status`),
    INDEX `mortuary_billable_event_charged_at_idx`(`charged_at`),
    INDEX `mortuary_billable_event_settled_at_idx`(`settled_at`),
    INDEX `mortuary_billable_event_deleted_at_idx`(`deleted_at`),
    INDEX `mortuary_billable_event_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `mortuary_deceased_profile` ADD CONSTRAINT `mortuary_deceased_profile_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `mortuary_deceased_profile` ADD CONSTRAINT `mortuary_deceased_profile_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `mortuary_storage_unit` ADD CONSTRAINT `mortuary_storage_unit_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `mortuary_storage_unit` ADD CONSTRAINT `mortuary_storage_unit_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `mortuary_storage_slot` ADD CONSTRAINT `mortuary_storage_slot_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `mortuary_storage_slot` ADD CONSTRAINT `mortuary_storage_slot_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `mortuary_storage_slot` ADD CONSTRAINT `mortuary_storage_slot_storage_unit_id_fkey` FOREIGN KEY (`storage_unit_id`) REFERENCES `mortuary_storage_unit`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `mortuary_case` ADD CONSTRAINT `mortuary_case_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `mortuary_case` ADD CONSTRAINT `mortuary_case_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `mortuary_case` ADD CONSTRAINT `mortuary_case_patient_id_fkey` FOREIGN KEY (`patient_id`) REFERENCES `patient`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `mortuary_case` ADD CONSTRAINT `mortuary_case_deceased_profile_id_fkey` FOREIGN KEY (`deceased_profile_id`) REFERENCES `mortuary_deceased_profile`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `mortuary_storage_assignment` ADD CONSTRAINT `mortuary_storage_assignment_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `mortuary_storage_assignment` ADD CONSTRAINT `mortuary_storage_assignment_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `mortuary_storage_assignment` ADD CONSTRAINT `mortuary_storage_assignment_mortuary_case_id_fkey` FOREIGN KEY (`mortuary_case_id`) REFERENCES `mortuary_case`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `mortuary_storage_assignment` ADD CONSTRAINT `mortuary_storage_assignment_storage_unit_id_fkey` FOREIGN KEY (`storage_unit_id`) REFERENCES `mortuary_storage_unit`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `mortuary_storage_assignment` ADD CONSTRAINT `mortuary_storage_assignment_storage_slot_id_fkey` FOREIGN KEY (`storage_slot_id`) REFERENCES `mortuary_storage_slot`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `mortuary_custody_event` ADD CONSTRAINT `mortuary_custody_event_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `mortuary_custody_event` ADD CONSTRAINT `mortuary_custody_event_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `mortuary_custody_event` ADD CONSTRAINT `mortuary_custody_event_mortuary_case_id_fkey` FOREIGN KEY (`mortuary_case_id`) REFERENCES `mortuary_case`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `mortuary_viewing` ADD CONSTRAINT `mortuary_viewing_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `mortuary_viewing` ADD CONSTRAINT `mortuary_viewing_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `mortuary_viewing` ADD CONSTRAINT `mortuary_viewing_mortuary_case_id_fkey` FOREIGN KEY (`mortuary_case_id`) REFERENCES `mortuary_case`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `mortuary_post_mortem_request` ADD CONSTRAINT `mortuary_post_mortem_request_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `mortuary_post_mortem_request` ADD CONSTRAINT `mortuary_post_mortem_request_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `mortuary_post_mortem_request` ADD CONSTRAINT `mortuary_post_mortem_request_mortuary_case_id_fkey` FOREIGN KEY (`mortuary_case_id`) REFERENCES `mortuary_case`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `mortuary_release_authorisation` ADD CONSTRAINT `mortuary_release_authorisation_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `mortuary_release_authorisation` ADD CONSTRAINT `mortuary_release_authorisation_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `mortuary_release_authorisation` ADD CONSTRAINT `mortuary_release_authorisation_mortuary_case_id_fkey` FOREIGN KEY (`mortuary_case_id`) REFERENCES `mortuary_case`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `mortuary_billable_event` ADD CONSTRAINT `mortuary_billable_event_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `mortuary_billable_event` ADD CONSTRAINT `mortuary_billable_event_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `mortuary_billable_event` ADD CONSTRAINT `mortuary_billable_event_mortuary_case_id_fkey` FOREIGN KEY (`mortuary_case_id`) REFERENCES `mortuary_case`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
