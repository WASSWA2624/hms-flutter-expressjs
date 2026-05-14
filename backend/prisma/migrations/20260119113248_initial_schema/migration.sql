-- CreateTable
CREATE TABLE `tenant` (
    `id` VARCHAR(36) NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `slug` VARCHAR(191) NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `tenant_deleted_at_idx`(`deleted_at`),
    INDEX `tenant_is_active_idx`(`is_active`),
    UNIQUE INDEX `tenant_slug_key`(`slug`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `facility` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `facility_type` ENUM('HOSPITAL', 'CLINIC', 'LAB', 'PHARMACY', 'OTHER') NOT NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `facility_tenant_id_idx`(`tenant_id`),
    INDEX `facility_facility_type_idx`(`facility_type`),
    INDEX `facility_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `branch` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `name` VARCHAR(255) NOT NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `branch_tenant_id_idx`(`tenant_id`),
    INDEX `branch_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `department` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `branch_id` VARCHAR(36) NULL,
    `name` VARCHAR(255) NOT NULL,
    `department_type` ENUM('CLINICAL', 'ADMINISTRATIVE', 'SUPPORT', 'DIAGNOSTICS', 'OTHER') NOT NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `department_tenant_id_idx`(`tenant_id`),
    INDEX `department_branch_id_idx`(`branch_id`),
    INDEX `department_department_type_idx`(`department_type`),
    INDEX `department_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `unit` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `department_id` VARCHAR(36) NULL,
    `name` VARCHAR(255) NOT NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `unit_tenant_id_idx`(`tenant_id`),
    INDEX `unit_department_id_idx`(`department_id`),
    INDEX `unit_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `ward` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NOT NULL,
    `department_id` VARCHAR(36) NULL,
    `name` VARCHAR(255) NOT NULL,
    `ward_type` ENUM('GENERAL', 'ICU', 'MATERNITY', 'PEDIATRIC', 'SURGICAL', 'OTHER') NOT NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `ward_tenant_id_idx`(`tenant_id`),
    INDEX `ward_department_id_idx`(`department_id`),
    INDEX `ward_ward_type_idx`(`ward_type`),
    INDEX `ward_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `room` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NOT NULL,
    `ward_id` VARCHAR(36) NULL,
    `name` VARCHAR(255) NOT NULL,
    `floor` VARCHAR(50) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `room_tenant_id_idx`(`tenant_id`),
    INDEX `room_ward_id_idx`(`ward_id`),
    INDEX `room_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `bed` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NOT NULL,
    `ward_id` VARCHAR(36) NOT NULL,
    `room_id` VARCHAR(36) NULL,
    `label` VARCHAR(50) NOT NULL,
    `status` ENUM('AVAILABLE', 'OCCUPIED', 'RESERVED', 'OUT_OF_SERVICE') NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `bed_tenant_id_idx`(`tenant_id`),
    INDEX `bed_ward_id_idx`(`ward_id`),
    INDEX `bed_room_id_idx`(`room_id`),
    INDEX `bed_status_idx`(`status`),
    INDEX `bed_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `address` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `address_type` ENUM('HOME', 'WORK', 'BILLING', 'SHIPPING', 'OTHER') NOT NULL,
    `line1` VARCHAR(255) NOT NULL,
    `line2` VARCHAR(255) NULL,
    `city` VARCHAR(120) NULL,
    `state` VARCHAR(120) NULL,
    `postal_code` VARCHAR(40) NULL,
    `country` VARCHAR(120) NULL,
    `latitude` DECIMAL(10, 7) NULL,
    `longitude` DECIMAL(10, 7) NULL,
    `facility_id` VARCHAR(36) NULL,
    `branch_id` VARCHAR(36) NULL,
    `patient_id` VARCHAR(36) NULL,
    `user_profile_id` VARCHAR(36) NULL,
    `staff_profile_id` VARCHAR(36) NULL,
    `supplier_id` VARCHAR(36) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `address_tenant_id_idx`(`tenant_id`),
    INDEX `address_branch_id_idx`(`branch_id`),
    INDEX `address_patient_id_idx`(`patient_id`),
    INDEX `address_user_profile_id_idx`(`user_profile_id`),
    INDEX `address_staff_profile_id_idx`(`staff_profile_id`),
    INDEX `address_supplier_id_idx`(`supplier_id`),
    INDEX `address_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `contact` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `contact_type` ENUM('PHONE', 'EMAIL', 'FAX', 'OTHER') NOT NULL,
    `value` VARCHAR(255) NOT NULL,
    `is_primary` BOOLEAN NOT NULL DEFAULT false,
    `facility_id` VARCHAR(36) NULL,
    `branch_id` VARCHAR(36) NULL,
    `patient_id` VARCHAR(36) NULL,
    `user_profile_id` VARCHAR(36) NULL,
    `staff_profile_id` VARCHAR(36) NULL,
    `supplier_id` VARCHAR(36) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `contact_tenant_id_idx`(`tenant_id`),
    INDEX `contact_facility_id_idx`(`facility_id`),
    INDEX `contact_branch_id_idx`(`branch_id`),
    INDEX `contact_patient_id_idx`(`patient_id`),
    INDEX `contact_user_profile_id_idx`(`user_profile_id`),
    INDEX `contact_staff_profile_id_idx`(`staff_profile_id`),
    INDEX `contact_supplier_id_idx`(`supplier_id`),
    INDEX `contact_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `user` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `email` VARCHAR(255) NOT NULL,
    `phone` VARCHAR(40) NULL,
    `password_hash` VARCHAR(255) NOT NULL,
    `status` ENUM('ACTIVE', 'INACTIVE', 'SUSPENDED', 'PENDING') NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `user_tenant_id_idx`(`tenant_id`),
    INDEX `user_facility_id_idx`(`facility_id`),
    INDEX `user_email_idx`(`email`),
    INDEX `user_status_idx`(`status`),
    INDEX `user_deleted_at_idx`(`deleted_at`),
    UNIQUE INDEX `user_tenant_id_email_key`(`tenant_id`, `email`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `user_profile` (
    `id` VARCHAR(36) NOT NULL,
    `user_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `first_name` VARCHAR(120) NOT NULL,
    `last_name` VARCHAR(120) NOT NULL,
    `gender` ENUM('MALE', 'FEMALE', 'OTHER', 'UNKNOWN') NULL,
    `date_of_birth` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `user_profile_user_id_idx`(`user_id`),
    INDEX `user_profile_deleted_at_idx`(`deleted_at`),
    UNIQUE INDEX `user_profile_user_id_key`(`user_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `user_session` (
    `id` VARCHAR(36) NOT NULL,
    `user_id` VARCHAR(36) NOT NULL,
    `refresh_token_hash` VARCHAR(255) NOT NULL,
    `ip_address` VARCHAR(45) NULL,
    `user_agent` VARCHAR(255) NULL,
    `expires_at` DATETIME(3) NOT NULL,
    `revoked_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `user_session_user_id_idx`(`user_id`),
    INDEX `user_session_expires_at_idx`(`expires_at`),
    INDEX `user_session_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `role` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `name` VARCHAR(120) NOT NULL,
    `description` VARCHAR(255) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `role_tenant_id_idx`(`tenant_id`),
    INDEX `role_facility_id_idx`(`facility_id`),
    INDEX `role_name_idx`(`name`),
    INDEX `role_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `permission` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `name` VARCHAR(120) NOT NULL,
    `description` VARCHAR(255) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `permission_tenant_id_idx`(`tenant_id`),
    INDEX `permission_name_idx`(`name`),
    INDEX `permission_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `role_permission` (
    `id` VARCHAR(36) NOT NULL,
    `role_id` VARCHAR(36) NOT NULL,
    `permission_id` VARCHAR(36) NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `role_permission_role_id_idx`(`role_id`),
    INDEX `role_permission_permission_id_idx`(`permission_id`),
    INDEX `role_permission_deleted_at_idx`(`deleted_at`),
    UNIQUE INDEX `role_permission_role_id_permission_id_key`(`role_id`, `permission_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `user_role` (
    `id` VARCHAR(36) NOT NULL,
    `user_id` VARCHAR(36) NOT NULL,
    `role_id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `user_role_user_id_idx`(`user_id`),
    INDEX `user_role_role_id_idx`(`role_id`),
    INDEX `user_role_tenant_id_idx`(`tenant_id`),
    INDEX `user_role_facility_id_idx`(`facility_id`),
    INDEX `user_role_deleted_at_idx`(`deleted_at`),
    UNIQUE INDEX `user_role_user_id_role_id_tenant_id_facility_id_key`(`user_id`, `role_id`, `tenant_id`, `facility_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `api_key` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `user_id` VARCHAR(36) NOT NULL,
    `name` VARCHAR(120) NOT NULL,
    `key_hash` VARCHAR(255) NOT NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `last_used_at` DATETIME(3) NULL,
    `expires_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `api_key_tenant_id_idx`(`tenant_id`),
    INDEX `api_key_user_id_idx`(`user_id`),
    INDEX `api_key_is_active_idx`(`is_active`),
    INDEX `api_key_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `api_key_permission` (
    `id` VARCHAR(36) NOT NULL,
    `api_key_id` VARCHAR(36) NOT NULL,
    `permission_id` VARCHAR(36) NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `api_key_permission_api_key_id_idx`(`api_key_id`),
    INDEX `api_key_permission_permission_id_idx`(`permission_id`),
    INDEX `api_key_permission_deleted_at_idx`(`deleted_at`),
    UNIQUE INDEX `api_key_permission_api_key_id_permission_id_key`(`api_key_id`, `permission_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `user_mfa` (
    `id` VARCHAR(36) NOT NULL,
    `user_id` VARCHAR(36) NOT NULL,
    `channel` ENUM('EMAIL', 'SMS', 'PUSH', 'WHATSAPP', 'IN_APP') NOT NULL,
    `secret_encrypted` VARCHAR(255) NOT NULL,
    `is_enabled` BOOLEAN NOT NULL DEFAULT true,
    `last_used_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `user_mfa_user_id_idx`(`user_id`),
    INDEX `user_mfa_channel_idx`(`channel`),
    INDEX `user_mfa_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `oauth_account` (
    `id` VARCHAR(36) NOT NULL,
    `user_id` VARCHAR(36) NOT NULL,
    `provider` VARCHAR(80) NOT NULL,
    `provider_user_id` VARCHAR(191) NOT NULL,
    `access_token_encrypted` VARCHAR(255) NULL,
    `refresh_token_encrypted` VARCHAR(255) NULL,
    `expires_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `oauth_account_user_id_idx`(`user_id`),
    INDEX `oauth_account_provider_idx`(`provider`),
    INDEX `oauth_account_provider_user_id_idx`(`provider_user_id`),
    INDEX `oauth_account_deleted_at_idx`(`deleted_at`),
    UNIQUE INDEX `oauth_account_provider_provider_user_id_key`(`provider`, `provider_user_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `patient` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `first_name` VARCHAR(120) NOT NULL,
    `last_name` VARCHAR(120) NOT NULL,
    `date_of_birth` DATETIME(3) NULL,
    `gender` ENUM('MALE', 'FEMALE', 'OTHER', 'UNKNOWN') NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `patient_tenant_id_idx`(`tenant_id`),
    INDEX `patient_facility_id_idx`(`facility_id`),
    INDEX `patient_is_active_idx`(`is_active`),
    INDEX `patient_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `patient_identifier` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `patient_id` VARCHAR(36) NOT NULL,
    `identifier_type` VARCHAR(80) NOT NULL,
    `identifier_value` VARCHAR(120) NOT NULL,
    `is_primary` BOOLEAN NOT NULL DEFAULT false,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `patient_identifier_tenant_id_idx`(`tenant_id`),
    INDEX `patient_identifier_patient_id_idx`(`patient_id`),
    INDEX `patient_identifier_identifier_type_idx`(`identifier_type`),
    INDEX `patient_identifier_deleted_at_idx`(`deleted_at`),
    UNIQUE INDEX `patient_identifier_tenant_id_identifier_value_key`(`tenant_id`, `identifier_value`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `patient_contact` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `patient_id` VARCHAR(36) NOT NULL,
    `contact_type` ENUM('PHONE', 'EMAIL', 'FAX', 'OTHER') NOT NULL,
    `value` VARCHAR(255) NOT NULL,
    `is_primary` BOOLEAN NOT NULL DEFAULT false,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `patient_contact_tenant_id_idx`(`tenant_id`),
    INDEX `patient_contact_patient_id_idx`(`patient_id`),
    INDEX `patient_contact_contact_type_idx`(`contact_type`),
    INDEX `patient_contact_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `patient_guardian` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `patient_id` VARCHAR(36) NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `relationship` VARCHAR(120) NULL,
    `phone` VARCHAR(40) NULL,
    `email` VARCHAR(255) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `patient_guardian_tenant_id_idx`(`tenant_id`),
    INDEX `patient_guardian_patient_id_idx`(`patient_id`),
    INDEX `patient_guardian_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `patient_allergy` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `patient_id` VARCHAR(36) NOT NULL,
    `allergen` VARCHAR(255) NOT NULL,
    `severity` ENUM('MILD', 'MODERATE', 'SEVERE') NOT NULL,
    `reaction` VARCHAR(255) NULL,
    `notes` TEXT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `patient_allergy_tenant_id_idx`(`tenant_id`),
    INDEX `patient_allergy_patient_id_idx`(`patient_id`),
    INDEX `patient_allergy_severity_idx`(`severity`),
    INDEX `patient_allergy_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `patient_medical_history` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `patient_id` VARCHAR(36) NOT NULL,
    `condition` VARCHAR(255) NOT NULL,
    `diagnosis_date` DATETIME(3) NULL,
    `notes` TEXT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `patient_medical_history_tenant_id_idx`(`tenant_id`),
    INDEX `patient_medical_history_patient_id_idx`(`patient_id`),
    INDEX `patient_medical_history_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `patient_document` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `patient_id` VARCHAR(36) NOT NULL,
    `document_type` VARCHAR(120) NOT NULL,
    `storage_key` VARCHAR(255) NOT NULL,
    `file_name` VARCHAR(255) NULL,
    `content_type` VARCHAR(120) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `patient_document_tenant_id_idx`(`tenant_id`),
    INDEX `patient_document_patient_id_idx`(`patient_id`),
    INDEX `patient_document_document_type_idx`(`document_type`),
    INDEX `patient_document_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `consent` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `patient_id` VARCHAR(36) NOT NULL,
    `consent_type` ENUM('TREATMENT', 'DATA_SHARING', 'RESEARCH', 'BILLING', 'OTHER') NOT NULL,
    `status` ENUM('GRANTED', 'REVOKED', 'PENDING') NOT NULL,
    `granted_at` DATETIME(3) NULL,
    `revoked_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `consent_tenant_id_idx`(`tenant_id`),
    INDEX `consent_patient_id_idx`(`patient_id`),
    INDEX `consent_status_idx`(`status`),
    INDEX `consent_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `terms_acceptance` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `user_id` VARCHAR(36) NOT NULL,
    `version_label` VARCHAR(40) NOT NULL,
    `accepted_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `terms_acceptance_tenant_id_idx`(`tenant_id`),
    INDEX `terms_acceptance_user_id_idx`(`user_id`),
    INDEX `terms_acceptance_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `appointment` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `patient_id` VARCHAR(36) NOT NULL,
    `provider_user_id` VARCHAR(36) NULL,
    `status` ENUM('SCHEDULED', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'NO_SHOW') NOT NULL,
    `scheduled_start` DATETIME(3) NOT NULL,
    `scheduled_end` DATETIME(3) NOT NULL,
    `reason` TEXT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `appointment_tenant_id_idx`(`tenant_id`),
    INDEX `appointment_facility_id_idx`(`facility_id`),
    INDEX `appointment_patient_id_idx`(`patient_id`),
    INDEX `appointment_provider_user_id_idx`(`provider_user_id`),
    INDEX `appointment_status_idx`(`status`),
    INDEX `appointment_scheduled_start_idx`(`scheduled_start`),
    INDEX `appointment_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `appointment_participant` (
    `id` VARCHAR(36) NOT NULL,
    `appointment_id` VARCHAR(36) NOT NULL,
    `participant_user_id` VARCHAR(36) NULL,
    `participant_patient_id` VARCHAR(36) NULL,
    `role` VARCHAR(80) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `appointment_participant_appointment_id_idx`(`appointment_id`),
    INDEX `appointment_participant_participant_user_id_idx`(`participant_user_id`),
    INDEX `appointment_participant_participant_patient_id_idx`(`participant_patient_id`),
    INDEX `appointment_participant_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `appointment_reminder` (
    `id` VARCHAR(36) NOT NULL,
    `appointment_id` VARCHAR(36) NOT NULL,
    `channel` ENUM('EMAIL', 'SMS', 'PUSH', 'WHATSAPP', 'IN_APP') NOT NULL,
    `scheduled_at` DATETIME(3) NOT NULL,
    `sent_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `appointment_reminder_appointment_id_idx`(`appointment_id`),
    INDEX `appointment_reminder_channel_idx`(`channel`),
    INDEX `appointment_reminder_scheduled_at_idx`(`scheduled_at`),
    INDEX `appointment_reminder_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `provider_schedule` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `provider_user_id` VARCHAR(36) NOT NULL,
    `day_of_week` INTEGER NOT NULL,
    `start_time` DATETIME(3) NOT NULL,
    `end_time` DATETIME(3) NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `provider_schedule_tenant_id_idx`(`tenant_id`),
    INDEX `provider_schedule_facility_id_idx`(`facility_id`),
    INDEX `provider_schedule_provider_user_id_idx`(`provider_user_id`),
    INDEX `provider_schedule_day_of_week_idx`(`day_of_week`),
    INDEX `provider_schedule_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `availability_slot` (
    `id` VARCHAR(36) NOT NULL,
    `schedule_id` VARCHAR(36) NOT NULL,
    `start_time` DATETIME(3) NOT NULL,
    `end_time` DATETIME(3) NOT NULL,
    `is_available` BOOLEAN NOT NULL DEFAULT true,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `availability_slot_schedule_id_idx`(`schedule_id`),
    INDEX `availability_slot_is_available_idx`(`is_available`),
    INDEX `availability_slot_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `visit_queue` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `patient_id` VARCHAR(36) NOT NULL,
    `appointment_id` VARCHAR(36) NULL,
    `provider_user_id` VARCHAR(36) NULL,
    `status` ENUM('SCHEDULED', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'NO_SHOW') NOT NULL,
    `queued_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `visit_queue_tenant_id_idx`(`tenant_id`),
    INDEX `visit_queue_facility_id_idx`(`facility_id`),
    INDEX `visit_queue_patient_id_idx`(`patient_id`),
    INDEX `visit_queue_appointment_id_idx`(`appointment_id`),
    INDEX `visit_queue_provider_user_id_idx`(`provider_user_id`),
    INDEX `visit_queue_status_idx`(`status`),
    INDEX `visit_queue_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `encounter` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `patient_id` VARCHAR(36) NOT NULL,
    `provider_user_id` VARCHAR(36) NULL,
    `encounter_type` ENUM('OPD', 'IPD', 'ICU', 'THEATRE', 'EMERGENCY', 'TELEMEDICINE') NOT NULL,
    `status` ENUM('OPEN', 'CLOSED', 'CANCELLED') NOT NULL,
    `started_at` DATETIME(3) NOT NULL,
    `ended_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `encounter_tenant_id_idx`(`tenant_id`),
    INDEX `encounter_facility_id_idx`(`facility_id`),
    INDEX `encounter_patient_id_idx`(`patient_id`),
    INDEX `encounter_provider_user_id_idx`(`provider_user_id`),
    INDEX `encounter_encounter_type_idx`(`encounter_type`),
    INDEX `encounter_status_idx`(`status`),
    INDEX `encounter_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `clinical_note` (
    `id` VARCHAR(36) NOT NULL,
    `encounter_id` VARCHAR(36) NOT NULL,
    `author_user_id` VARCHAR(36) NOT NULL,
    `note` TEXT NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `clinical_note_encounter_id_idx`(`encounter_id`),
    INDEX `clinical_note_author_user_id_idx`(`author_user_id`),
    INDEX `clinical_note_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `diagnosis` (
    `id` VARCHAR(36) NOT NULL,
    `encounter_id` VARCHAR(36) NOT NULL,
    `diagnosis_type` ENUM('PRIMARY', 'SECONDARY', 'DIFFERENTIAL') NOT NULL,
    `code` VARCHAR(80) NULL,
    `description` TEXT NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `diagnosis_encounter_id_idx`(`encounter_id`),
    INDEX `diagnosis_diagnosis_type_idx`(`diagnosis_type`),
    INDEX `diagnosis_code_idx`(`code`),
    INDEX `diagnosis_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `procedure` (
    `id` VARCHAR(36) NOT NULL,
    `encounter_id` VARCHAR(36) NOT NULL,
    `code` VARCHAR(80) NULL,
    `description` TEXT NOT NULL,
    `performed_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `procedure_encounter_id_idx`(`encounter_id`),
    INDEX `procedure_code_idx`(`code`),
    INDEX `procedure_performed_at_idx`(`performed_at`),
    INDEX `procedure_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `vital_sign` (
    `id` VARCHAR(36) NOT NULL,
    `encounter_id` VARCHAR(36) NOT NULL,
    `vital_type` ENUM('TEMPERATURE', 'BLOOD_PRESSURE', 'HEART_RATE', 'RESPIRATORY_RATE', 'OXYGEN_SATURATION', 'WEIGHT', 'HEIGHT', 'BMI') NOT NULL,
    `value` VARCHAR(80) NOT NULL,
    `unit` VARCHAR(20) NULL,
    `recorded_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `vital_sign_encounter_id_idx`(`encounter_id`),
    INDEX `vital_sign_vital_type_idx`(`vital_type`),
    INDEX `vital_sign_recorded_at_idx`(`recorded_at`),
    INDEX `vital_sign_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `care_plan` (
    `id` VARCHAR(36) NOT NULL,
    `encounter_id` VARCHAR(36) NOT NULL,
    `plan` TEXT NOT NULL,
    `start_date` DATETIME(3) NULL,
    `end_date` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `care_plan_encounter_id_idx`(`encounter_id`),
    INDEX `care_plan_start_date_idx`(`start_date`),
    INDEX `care_plan_end_date_idx`(`end_date`),
    INDEX `care_plan_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `clinical_alert` (
    `id` VARCHAR(36) NOT NULL,
    `encounter_id` VARCHAR(36) NOT NULL,
    `severity` ENUM('LOW', 'MEDIUM', 'HIGH', 'CRITICAL') NOT NULL,
    `message` TEXT NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `clinical_alert_encounter_id_idx`(`encounter_id`),
    INDEX `clinical_alert_severity_idx`(`severity`),
    INDEX `clinical_alert_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `referral` (
    `id` VARCHAR(36) NOT NULL,
    `encounter_id` VARCHAR(36) NOT NULL,
    `from_department_id` VARCHAR(36) NULL,
    `to_department_id` VARCHAR(36) NULL,
    `reason` TEXT NULL,
    `status` ENUM('REQUESTED', 'APPROVED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED') NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `referral_encounter_id_idx`(`encounter_id`),
    INDEX `referral_from_department_id_idx`(`from_department_id`),
    INDEX `referral_to_department_id_idx`(`to_department_id`),
    INDEX `referral_status_idx`(`status`),
    INDEX `referral_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `follow_up` (
    `id` VARCHAR(36) NOT NULL,
    `encounter_id` VARCHAR(36) NOT NULL,
    `scheduled_at` DATETIME(3) NOT NULL,
    `notes` TEXT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `follow_up_encounter_id_idx`(`encounter_id`),
    INDEX `follow_up_scheduled_at_idx`(`scheduled_at`),
    INDEX `follow_up_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `admission` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `patient_id` VARCHAR(36) NOT NULL,
    `encounter_id` VARCHAR(36) NULL,
    `status` ENUM('ADMITTED', 'DISCHARGED', 'TRANSFERRED', 'CANCELLED') NOT NULL,
    `admitted_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `discharged_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `admission_tenant_id_idx`(`tenant_id`),
    INDEX `admission_facility_id_idx`(`facility_id`),
    INDEX `admission_patient_id_idx`(`patient_id`),
    INDEX `admission_encounter_id_idx`(`encounter_id`),
    INDEX `admission_status_idx`(`status`),
    INDEX `admission_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `bed_assignment` (
    `id` VARCHAR(36) NOT NULL,
    `admission_id` VARCHAR(36) NOT NULL,
    `bed_id` VARCHAR(36) NOT NULL,
    `assigned_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `released_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `bed_assignment_admission_id_idx`(`admission_id`),
    INDEX `bed_assignment_bed_id_idx`(`bed_id`),
    INDEX `bed_assignment_assigned_at_idx`(`assigned_at`),
    INDEX `bed_assignment_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `ward_round` (
    `id` VARCHAR(36) NOT NULL,
    `admission_id` VARCHAR(36) NOT NULL,
    `round_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `notes` TEXT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `ward_round_admission_id_idx`(`admission_id`),
    INDEX `ward_round_round_at_idx`(`round_at`),
    INDEX `ward_round_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `nursing_note` (
    `id` VARCHAR(36) NOT NULL,
    `admission_id` VARCHAR(36) NOT NULL,
    `nurse_user_id` VARCHAR(36) NOT NULL,
    `note` TEXT NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `nursing_note_admission_id_idx`(`admission_id`),
    INDEX `nursing_note_nurse_user_id_idx`(`nurse_user_id`),
    INDEX `nursing_note_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `medication_administration` (
    `id` VARCHAR(36) NOT NULL,
    `admission_id` VARCHAR(36) NOT NULL,
    `prescription_id` VARCHAR(36) NULL,
    `administered_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `dose` VARCHAR(80) NOT NULL,
    `unit` VARCHAR(40) NULL,
    `route` ENUM('ORAL', 'IV', 'IM', 'TOPICAL', 'INHALATION', 'OTHER') NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `medication_administration_admission_id_idx`(`admission_id`),
    INDEX `medication_administration_route_idx`(`route`),
    INDEX `medication_administration_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `discharge_summary` (
    `id` VARCHAR(36) NOT NULL,
    `admission_id` VARCHAR(36) NOT NULL,
    `summary` TEXT NOT NULL,
    `status` ENUM('PLANNED', 'COMPLETED', 'CANCELLED') NOT NULL,
    `discharged_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `discharge_summary_admission_id_idx`(`admission_id`),
    INDEX `discharge_summary_status_idx`(`status`),
    INDEX `discharge_summary_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `transfer_request` (
    `id` VARCHAR(36) NOT NULL,
    `admission_id` VARCHAR(36) NOT NULL,
    `from_ward_id` VARCHAR(36) NULL,
    `to_ward_id` VARCHAR(36) NULL,
    `status` ENUM('REQUESTED', 'APPROVED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED') NOT NULL,
    `requested_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `transfer_request_admission_id_idx`(`admission_id`),
    INDEX `transfer_request_from_ward_id_idx`(`from_ward_id`),
    INDEX `transfer_request_to_ward_id_idx`(`to_ward_id`),
    INDEX `transfer_request_status_idx`(`status`),
    INDEX `transfer_request_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `icu_stay` (
    `id` VARCHAR(36) NOT NULL,
    `admission_id` VARCHAR(36) NOT NULL,
    `started_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `ended_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `icu_stay_admission_id_idx`(`admission_id`),
    INDEX `icu_stay_started_at_idx`(`started_at`),
    INDEX `icu_stay_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `icu_observation` (
    `id` VARCHAR(36) NOT NULL,
    `icu_stay_id` VARCHAR(36) NOT NULL,
    `observed_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `observation` TEXT NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `icu_observation_icu_stay_id_idx`(`icu_stay_id`),
    INDEX `icu_observation_observed_at_idx`(`observed_at`),
    INDEX `icu_observation_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `critical_alert` (
    `id` VARCHAR(36) NOT NULL,
    `icu_stay_id` VARCHAR(36) NOT NULL,
    `severity` ENUM('LOW', 'MEDIUM', 'HIGH', 'CRITICAL') NOT NULL,
    `message` TEXT NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `critical_alert_icu_stay_id_idx`(`icu_stay_id`),
    INDEX `critical_alert_severity_idx`(`severity`),
    INDEX `critical_alert_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `theatre_case` (
    `id` VARCHAR(36) NOT NULL,
    `encounter_id` VARCHAR(36) NOT NULL,
    `scheduled_at` DATETIME(3) NOT NULL,
    `status` ENUM('OPEN', 'CLOSED', 'CANCELLED') NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `theatre_case_encounter_id_idx`(`encounter_id`),
    INDEX `theatre_case_scheduled_at_idx`(`scheduled_at`),
    INDEX `theatre_case_status_idx`(`status`),
    INDEX `theatre_case_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `anesthesia_record` (
    `id` VARCHAR(36) NOT NULL,
    `theatre_case_id` VARCHAR(36) NOT NULL,
    `anesthetist_user_id` VARCHAR(36) NULL,
    `notes` TEXT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `anesthesia_record_theatre_case_id_idx`(`theatre_case_id`),
    INDEX `anesthesia_record_anesthetist_user_id_idx`(`anesthetist_user_id`),
    INDEX `anesthesia_record_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `post_op_note` (
    `id` VARCHAR(36) NOT NULL,
    `theatre_case_id` VARCHAR(36) NOT NULL,
    `note` TEXT NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `post_op_note_theatre_case_id_idx`(`theatre_case_id`),
    INDEX `post_op_note_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `lab_test` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `code` VARCHAR(80) NULL,
    `unit` VARCHAR(40) NULL,
    `reference_range` VARCHAR(120) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `lab_test_tenant_id_idx`(`tenant_id`),
    INDEX `lab_test_code_idx`(`code`),
    INDEX `lab_test_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `lab_panel` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `code` VARCHAR(80) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `lab_panel_tenant_id_idx`(`tenant_id`),
    INDEX `lab_panel_code_idx`(`code`),
    INDEX `lab_panel_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `lab_order` (
    `id` VARCHAR(36) NOT NULL,
    `encounter_id` VARCHAR(36) NULL,
    `patient_id` VARCHAR(36) NOT NULL,
    `status` ENUM('ORDERED', 'COLLECTED', 'IN_PROCESS', 'COMPLETED', 'CANCELLED') NOT NULL,
    `ordered_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `lab_order_encounter_id_idx`(`encounter_id`),
    INDEX `lab_order_patient_id_idx`(`patient_id`),
    INDEX `lab_order_status_idx`(`status`),
    INDEX `lab_order_ordered_at_idx`(`ordered_at`),
    INDEX `lab_order_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `lab_order_item` (
    `id` VARCHAR(36) NOT NULL,
    `lab_order_id` VARCHAR(36) NOT NULL,
    `lab_test_id` VARCHAR(36) NOT NULL,
    `status` ENUM('ORDERED', 'COLLECTED', 'IN_PROCESS', 'COMPLETED', 'CANCELLED') NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `lab_order_item_lab_order_id_idx`(`lab_order_id`),
    INDEX `lab_order_item_lab_test_id_idx`(`lab_test_id`),
    INDEX `lab_order_item_status_idx`(`status`),
    INDEX `lab_order_item_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `lab_sample` (
    `id` VARCHAR(36) NOT NULL,
    `lab_order_id` VARCHAR(36) NOT NULL,
    `status` ENUM('PENDING', 'COLLECTED', 'REJECTED', 'RECEIVED') NOT NULL,
    `collected_at` DATETIME(3) NULL,
    `received_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `lab_sample_lab_order_id_idx`(`lab_order_id`),
    INDEX `lab_sample_status_idx`(`status`),
    INDEX `lab_sample_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `lab_result` (
    `id` VARCHAR(36) NOT NULL,
    `lab_order_item_id` VARCHAR(36) NOT NULL,
    `status` ENUM('NORMAL', 'ABNORMAL', 'CRITICAL', 'PENDING') NOT NULL,
    `result_value` VARCHAR(120) NULL,
    `result_unit` VARCHAR(40) NULL,
    `result_text` TEXT NULL,
    `reported_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `lab_result_lab_order_item_id_idx`(`lab_order_item_id`),
    INDEX `lab_result_status_idx`(`status`),
    INDEX `lab_result_reported_at_idx`(`reported_at`),
    INDEX `lab_result_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `lab_qc_log` (
    `id` VARCHAR(36) NOT NULL,
    `lab_test_id` VARCHAR(36) NOT NULL,
    `status` VARCHAR(80) NULL,
    `notes` TEXT NULL,
    `logged_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `lab_qc_log_lab_test_id_idx`(`lab_test_id`),
    INDEX `lab_qc_log_logged_at_idx`(`logged_at`),
    INDEX `lab_qc_log_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `radiology_test` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `code` VARCHAR(80) NULL,
    `modality` ENUM('XRAY', 'CT', 'MRI', 'ULTRASOUND', 'PET', 'OTHER') NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `radiology_test_tenant_id_idx`(`tenant_id`),
    INDEX `radiology_test_code_idx`(`code`),
    INDEX `radiology_test_modality_idx`(`modality`),
    INDEX `radiology_test_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `radiology_order` (
    `id` VARCHAR(36) NOT NULL,
    `encounter_id` VARCHAR(36) NULL,
    `patient_id` VARCHAR(36) NOT NULL,
    `radiology_test_id` VARCHAR(36) NULL,
    `status` ENUM('ORDERED', 'IN_PROCESS', 'COMPLETED', 'CANCELLED') NOT NULL,
    `ordered_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `radiology_order_encounter_id_idx`(`encounter_id`),
    INDEX `radiology_order_patient_id_idx`(`patient_id`),
    INDEX `radiology_order_radiology_test_id_idx`(`radiology_test_id`),
    INDEX `radiology_order_status_idx`(`status`),
    INDEX `radiology_order_ordered_at_idx`(`ordered_at`),
    INDEX `radiology_order_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `radiology_result` (
    `id` VARCHAR(36) NOT NULL,
    `radiology_order_id` VARCHAR(36) NOT NULL,
    `status` ENUM('DRAFT', 'FINAL', 'AMENDED') NOT NULL,
    `report_text` TEXT NULL,
    `reported_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `radiology_result_radiology_order_id_idx`(`radiology_order_id`),
    INDEX `radiology_result_status_idx`(`status`),
    INDEX `radiology_result_reported_at_idx`(`reported_at`),
    INDEX `radiology_result_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `imaging_study` (
    `id` VARCHAR(36) NOT NULL,
    `radiology_order_id` VARCHAR(36) NOT NULL,
    `modality` ENUM('XRAY', 'CT', 'MRI', 'ULTRASOUND', 'PET', 'OTHER') NOT NULL,
    `performed_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `imaging_study_radiology_order_id_idx`(`radiology_order_id`),
    INDEX `imaging_study_modality_idx`(`modality`),
    INDEX `imaging_study_performed_at_idx`(`performed_at`),
    INDEX `imaging_study_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `imaging_asset` (
    `id` VARCHAR(36) NOT NULL,
    `imaging_study_id` VARCHAR(36) NOT NULL,
    `storage_key` VARCHAR(255) NOT NULL,
    `file_name` VARCHAR(255) NULL,
    `content_type` VARCHAR(120) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `imaging_asset_imaging_study_id_idx`(`imaging_study_id`),
    INDEX `imaging_asset_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `pacs_link` (
    `id` VARCHAR(36) NOT NULL,
    `imaging_study_id` VARCHAR(36) NOT NULL,
    `url` VARCHAR(255) NOT NULL,
    `expires_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `pacs_link_imaging_study_id_idx`(`imaging_study_id`),
    INDEX `pacs_link_expires_at_idx`(`expires_at`),
    INDEX `pacs_link_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `drug` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `code` VARCHAR(80) NULL,
    `form` VARCHAR(80) NULL,
    `strength` VARCHAR(80) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `drug_tenant_id_idx`(`tenant_id`),
    INDEX `drug_code_idx`(`code`),
    INDEX `drug_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `drug_batch` (
    `id` VARCHAR(36) NOT NULL,
    `drug_id` VARCHAR(36) NOT NULL,
    `batch_number` VARCHAR(80) NOT NULL,
    `expiry_date` DATETIME(3) NULL,
    `quantity` INTEGER NOT NULL DEFAULT 0,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `drug_batch_drug_id_idx`(`drug_id`),
    INDEX `drug_batch_batch_number_idx`(`batch_number`),
    INDEX `drug_batch_expiry_date_idx`(`expiry_date`),
    INDEX `drug_batch_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `formulary_item` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `drug_id` VARCHAR(36) NOT NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `formulary_item_tenant_id_idx`(`tenant_id`),
    INDEX `formulary_item_drug_id_idx`(`drug_id`),
    INDEX `formulary_item_is_active_idx`(`is_active`),
    INDEX `formulary_item_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `pharmacy_order` (
    `id` VARCHAR(36) NOT NULL,
    `encounter_id` VARCHAR(36) NULL,
    `patient_id` VARCHAR(36) NOT NULL,
    `status` ENUM('ORDERED', 'DISPENSED', 'PARTIALLY_DISPENSED', 'CANCELLED') NOT NULL,
    `ordered_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `pharmacy_order_encounter_id_idx`(`encounter_id`),
    INDEX `pharmacy_order_patient_id_idx`(`patient_id`),
    INDEX `pharmacy_order_status_idx`(`status`),
    INDEX `pharmacy_order_ordered_at_idx`(`ordered_at`),
    INDEX `pharmacy_order_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `pharmacy_order_item` (
    `id` VARCHAR(36) NOT NULL,
    `pharmacy_order_id` VARCHAR(36) NOT NULL,
    `drug_id` VARCHAR(36) NOT NULL,
    `quantity` INTEGER NOT NULL,
    `dosage` VARCHAR(80) NULL,
    `frequency` ENUM('ONCE', 'BID', 'TID', 'QID', 'PRN', 'STAT', 'CUSTOM') NULL,
    `route` ENUM('ORAL', 'IV', 'IM', 'TOPICAL', 'INHALATION', 'OTHER') NULL,
    `status` ENUM('DRAFT', 'ACTIVE', 'COMPLETED', 'CANCELLED') NOT NULL DEFAULT 'ACTIVE',
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `pharmacy_order_item_pharmacy_order_id_idx`(`pharmacy_order_id`),
    INDEX `pharmacy_order_item_drug_id_idx`(`drug_id`),
    INDEX `pharmacy_order_item_status_idx`(`status`),
    INDEX `pharmacy_order_item_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `dispense_log` (
    `id` VARCHAR(36) NOT NULL,
    `pharmacy_order_item_id` VARCHAR(36) NOT NULL,
    `status` ENUM('PENDING', 'DISPENSED', 'RETURNED', 'CANCELLED') NOT NULL,
    `dispensed_at` DATETIME(3) NULL,
    `quantity_dispensed` INTEGER NOT NULL DEFAULT 0,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `dispense_log_pharmacy_order_item_id_idx`(`pharmacy_order_item_id`),
    INDEX `dispense_log_status_idx`(`status`),
    INDEX `dispense_log_dispensed_at_idx`(`dispensed_at`),
    INDEX `dispense_log_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `adverse_event` (
    `id` VARCHAR(36) NOT NULL,
    `patient_id` VARCHAR(36) NOT NULL,
    `drug_id` VARCHAR(36) NULL,
    `severity` ENUM('MILD', 'MODERATE', 'SEVERE') NOT NULL,
    `description` TEXT NULL,
    `reported_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `adverse_event_patient_id_idx`(`patient_id`),
    INDEX `adverse_event_drug_id_idx`(`drug_id`),
    INDEX `adverse_event_severity_idx`(`severity`),
    INDEX `adverse_event_reported_at_idx`(`reported_at`),
    INDEX `adverse_event_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `inventory_item` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `category` ENUM('MEDICATION', 'SUPPLY', 'EQUIPMENT', 'OTHER') NOT NULL,
    `sku` VARCHAR(80) NULL,
    `unit` VARCHAR(40) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `inventory_item_tenant_id_idx`(`tenant_id`),
    INDEX `inventory_item_category_idx`(`category`),
    INDEX `inventory_item_sku_idx`(`sku`),
    INDEX `inventory_item_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `inventory_stock` (
    `id` VARCHAR(36) NOT NULL,
    `inventory_item_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `quantity` INTEGER NOT NULL DEFAULT 0,
    `reorder_level` INTEGER NOT NULL DEFAULT 0,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `inventory_stock_inventory_item_id_idx`(`inventory_item_id`),
    INDEX `inventory_stock_facility_id_idx`(`facility_id`),
    INDEX `inventory_stock_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `stock_movement` (
    `id` VARCHAR(36) NOT NULL,
    `inventory_item_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `movement_type` ENUM('INBOUND', 'OUTBOUND', 'ADJUSTMENT', 'TRANSFER') NOT NULL,
    `reason` ENUM('PURCHASE', 'DISPENSE', 'RETURN', 'DAMAGE', 'EXPIRY', 'OTHER') NOT NULL,
    `quantity` INTEGER NOT NULL,
    `occurred_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `stock_movement_inventory_item_id_idx`(`inventory_item_id`),
    INDEX `stock_movement_facility_id_idx`(`facility_id`),
    INDEX `stock_movement_movement_type_idx`(`movement_type`),
    INDEX `stock_movement_reason_idx`(`reason`),
    INDEX `stock_movement_occurred_at_idx`(`occurred_at`),
    INDEX `stock_movement_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `supplier` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `contact_email` VARCHAR(255) NULL,
    `phone` VARCHAR(40) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `supplier_tenant_id_idx`(`tenant_id`),
    INDEX `supplier_name_idx`(`name`),
    INDEX `supplier_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `purchase_request` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `requested_by_user_id` VARCHAR(36) NULL,
    `status` VARCHAR(60) NOT NULL,
    `requested_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `purchase_request_tenant_id_idx`(`tenant_id`),
    INDEX `purchase_request_facility_id_idx`(`facility_id`),
    INDEX `purchase_request_requested_by_user_id_idx`(`requested_by_user_id`),
    INDEX `purchase_request_status_idx`(`status`),
    INDEX `purchase_request_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `purchase_order` (
    `id` VARCHAR(36) NOT NULL,
    `purchase_request_id` VARCHAR(36) NULL,
    `supplier_id` VARCHAR(36) NULL,
    `status` VARCHAR(60) NOT NULL,
    `ordered_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `purchase_order_purchase_request_id_idx`(`purchase_request_id`),
    INDEX `purchase_order_supplier_id_idx`(`supplier_id`),
    INDEX `purchase_order_status_idx`(`status`),
    INDEX `purchase_order_ordered_at_idx`(`ordered_at`),
    INDEX `purchase_order_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `goods_receipt` (
    `id` VARCHAR(36) NOT NULL,
    `purchase_order_id` VARCHAR(36) NOT NULL,
    `received_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `status` VARCHAR(60) NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `goods_receipt_purchase_order_id_idx`(`purchase_order_id`),
    INDEX `goods_receipt_status_idx`(`status`),
    INDEX `goods_receipt_received_at_idx`(`received_at`),
    INDEX `goods_receipt_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `stock_adjustment` (
    `id` VARCHAR(36) NOT NULL,
    `inventory_item_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `quantity` INTEGER NOT NULL,
    `reason` ENUM('PURCHASE', 'DISPENSE', 'RETURN', 'DAMAGE', 'EXPIRY', 'OTHER') NOT NULL,
    `adjusted_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `stock_adjustment_inventory_item_id_idx`(`inventory_item_id`),
    INDEX `stock_adjustment_facility_id_idx`(`facility_id`),
    INDEX `stock_adjustment_reason_idx`(`reason`),
    INDEX `stock_adjustment_adjusted_at_idx`(`adjusted_at`),
    INDEX `stock_adjustment_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `emergency_case` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `patient_id` VARCHAR(36) NOT NULL,
    `severity` ENUM('LOW', 'MEDIUM', 'HIGH', 'CRITICAL') NOT NULL,
    `status` ENUM('OPEN', 'CLOSED', 'CANCELLED') NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `emergency_case_tenant_id_idx`(`tenant_id`),
    INDEX `emergency_case_facility_id_idx`(`facility_id`),
    INDEX `emergency_case_patient_id_idx`(`patient_id`),
    INDEX `emergency_case_severity_idx`(`severity`),
    INDEX `emergency_case_status_idx`(`status`),
    INDEX `emergency_case_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `triage_assessment` (
    `id` VARCHAR(36) NOT NULL,
    `emergency_case_id` VARCHAR(36) NOT NULL,
    `triage_level` ENUM('LEVEL_1', 'LEVEL_2', 'LEVEL_3', 'LEVEL_4', 'LEVEL_5') NOT NULL,
    `notes` TEXT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `triage_assessment_emergency_case_id_idx`(`emergency_case_id`),
    INDEX `triage_assessment_triage_level_idx`(`triage_level`),
    INDEX `triage_assessment_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `emergency_response` (
    `id` VARCHAR(36) NOT NULL,
    `emergency_case_id` VARCHAR(36) NOT NULL,
    `response_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `notes` TEXT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `emergency_response_emergency_case_id_idx`(`emergency_case_id`),
    INDEX `emergency_response_response_at_idx`(`response_at`),
    INDEX `emergency_response_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `ambulance` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `identifier` VARCHAR(120) NOT NULL,
    `status` ENUM('AVAILABLE', 'DISPATCHED', 'EN_ROUTE', 'ON_SCENE', 'TRANSPORTING', 'OUT_OF_SERVICE') NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `ambulance_tenant_id_idx`(`tenant_id`),
    INDEX `ambulance_facility_id_idx`(`facility_id`),
    INDEX `ambulance_status_idx`(`status`),
    INDEX `ambulance_identifier_idx`(`identifier`),
    INDEX `ambulance_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `ambulance_dispatch` (
    `id` VARCHAR(36) NOT NULL,
    `ambulance_id` VARCHAR(36) NOT NULL,
    `emergency_case_id` VARCHAR(36) NOT NULL,
    `dispatched_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `status` ENUM('AVAILABLE', 'DISPATCHED', 'EN_ROUTE', 'ON_SCENE', 'TRANSPORTING', 'OUT_OF_SERVICE') NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `ambulance_dispatch_ambulance_id_idx`(`ambulance_id`),
    INDEX `ambulance_dispatch_emergency_case_id_idx`(`emergency_case_id`),
    INDEX `ambulance_dispatch_status_idx`(`status`),
    INDEX `ambulance_dispatch_dispatched_at_idx`(`dispatched_at`),
    INDEX `ambulance_dispatch_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `ambulance_trip` (
    `id` VARCHAR(36) NOT NULL,
    `ambulance_id` VARCHAR(36) NOT NULL,
    `emergency_case_id` VARCHAR(36) NOT NULL,
    `started_at` DATETIME(3) NULL,
    `ended_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `ambulance_trip_ambulance_id_idx`(`ambulance_id`),
    INDEX `ambulance_trip_emergency_case_id_idx`(`emergency_case_id`),
    INDEX `ambulance_trip_started_at_idx`(`started_at`),
    INDEX `ambulance_trip_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `invoice` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `patient_id` VARCHAR(36) NULL,
    `status` ENUM('DRAFT', 'SENT', 'PAID', 'OVERDUE', 'CANCELLED') NOT NULL,
    `billing_status` ENUM('DRAFT', 'ISSUED', 'PAID', 'PARTIAL', 'CANCELLED') NOT NULL DEFAULT 'DRAFT',
    `total_amount` DECIMAL(12, 2) NOT NULL,
    `currency` VARCHAR(10) NOT NULL,
    `issued_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `invoice_tenant_id_idx`(`tenant_id`),
    INDEX `invoice_facility_id_idx`(`facility_id`),
    INDEX `invoice_patient_id_idx`(`patient_id`),
    INDEX `invoice_status_idx`(`status`),
    INDEX `invoice_billing_status_idx`(`billing_status`),
    INDEX `invoice_issued_at_idx`(`issued_at`),
    INDEX `invoice_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `invoice_item` (
    `id` VARCHAR(36) NOT NULL,
    `invoice_id` VARCHAR(36) NOT NULL,
    `description` VARCHAR(255) NOT NULL,
    `quantity` INTEGER NOT NULL DEFAULT 1,
    `unit_price` DECIMAL(12, 2) NOT NULL,
    `total_price` DECIMAL(12, 2) NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `invoice_item_invoice_id_idx`(`invoice_id`),
    INDEX `invoice_item_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `payment` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `patient_id` VARCHAR(36) NULL,
    `invoice_id` VARCHAR(36) NOT NULL,
    `status` ENUM('PENDING', 'COMPLETED', 'FAILED', 'REFUNDED') NOT NULL,
    `method` ENUM('CASH', 'CARD', 'MOBILE_MONEY', 'BANK_TRANSFER', 'INSURANCE', 'OTHER') NOT NULL,
    `amount` DECIMAL(12, 2) NOT NULL,
    `paid_at` DATETIME(3) NULL,
    `transaction_ref` VARCHAR(120) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `payment_tenant_id_idx`(`tenant_id`),
    INDEX `payment_facility_id_idx`(`facility_id`),
    INDEX `payment_patient_id_idx`(`patient_id`),
    INDEX `payment_invoice_id_idx`(`invoice_id`),
    INDEX `payment_status_idx`(`status`),
    INDEX `payment_method_idx`(`method`),
    INDEX `payment_paid_at_idx`(`paid_at`),
    INDEX `payment_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `refund` (
    `id` VARCHAR(36) NOT NULL,
    `payment_id` VARCHAR(36) NOT NULL,
    `amount` DECIMAL(12, 2) NOT NULL,
    `refunded_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `reason` VARCHAR(255) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `refund_payment_id_idx`(`payment_id`),
    INDEX `refund_refunded_at_idx`(`refunded_at`),
    INDEX `refund_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `pricing_rule` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `description` TEXT NULL,
    `amount` DECIMAL(12, 2) NOT NULL,
    `currency` VARCHAR(10) NOT NULL,
    `effective_from` DATETIME(3) NULL,
    `effective_to` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `pricing_rule_tenant_id_idx`(`tenant_id`),
    INDEX `pricing_rule_effective_from_idx`(`effective_from`),
    INDEX `pricing_rule_effective_to_idx`(`effective_to`),
    INDEX `pricing_rule_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `coverage_plan` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `provider_name` VARCHAR(255) NULL,
    `coverage_percentage` INTEGER NULL DEFAULT 0,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `coverage_plan_tenant_id_idx`(`tenant_id`),
    INDEX `coverage_plan_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `insurance_claim` (
    `id` VARCHAR(36) NOT NULL,
    `coverage_plan_id` VARCHAR(36) NOT NULL,
    `invoice_id` VARCHAR(36) NOT NULL,
    `status` ENUM('SUBMITTED', 'APPROVED', 'REJECTED', 'PAID', 'CANCELLED') NOT NULL,
    `submitted_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `insurance_claim_coverage_plan_id_idx`(`coverage_plan_id`),
    INDEX `insurance_claim_invoice_id_idx`(`invoice_id`),
    INDEX `insurance_claim_status_idx`(`status`),
    INDEX `insurance_claim_submitted_at_idx`(`submitted_at`),
    INDEX `insurance_claim_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `pre_authorization` (
    `id` VARCHAR(36) NOT NULL,
    `coverage_plan_id` VARCHAR(36) NOT NULL,
    `status` ENUM('PENDING', 'APPROVED', 'DENIED', 'EXPIRED') NOT NULL,
    `requested_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `approved_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `pre_authorization_coverage_plan_id_idx`(`coverage_plan_id`),
    INDEX `pre_authorization_status_idx`(`status`),
    INDEX `pre_authorization_requested_at_idx`(`requested_at`),
    INDEX `pre_authorization_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `billing_adjustment` (
    `id` VARCHAR(36) NOT NULL,
    `invoice_id` VARCHAR(36) NOT NULL,
    `amount` DECIMAL(12, 2) NOT NULL,
    `status` ENUM('DRAFT', 'ISSUED', 'PAID', 'PARTIAL', 'CANCELLED') NOT NULL,
    `reason` VARCHAR(255) NULL,
    `adjusted_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `billing_adjustment_invoice_id_idx`(`invoice_id`),
    INDEX `billing_adjustment_status_idx`(`status`),
    INDEX `billing_adjustment_adjusted_at_idx`(`adjusted_at`),
    INDEX `billing_adjustment_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `staff_profile` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `user_id` VARCHAR(36) NOT NULL,
    `department_id` VARCHAR(36) NULL,
    `staff_number` VARCHAR(80) NULL,
    `position` VARCHAR(120) NULL,
    `hire_date` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    UNIQUE INDEX `staff_profile_user_id_key`(`user_id`),
    INDEX `staff_profile_tenant_id_idx`(`tenant_id`),
    INDEX `staff_profile_user_id_idx`(`user_id`),
    INDEX `staff_profile_department_id_idx`(`department_id`),
    INDEX `staff_profile_staff_number_idx`(`staff_number`),
    INDEX `staff_profile_deleted_at_idx`(`deleted_at`),
    UNIQUE INDEX `staff_profile_tenant_id_staff_number_key`(`tenant_id`, `staff_number`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `staff_assignment` (
    `id` VARCHAR(36) NOT NULL,
    `staff_profile_id` VARCHAR(36) NOT NULL,
    `department_id` VARCHAR(36) NULL,
    `unit_id` VARCHAR(36) NULL,
    `start_date` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `end_date` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `staff_assignment_staff_profile_id_idx`(`staff_profile_id`),
    INDEX `staff_assignment_department_id_idx`(`department_id`),
    INDEX `staff_assignment_unit_id_idx`(`unit_id`),
    INDEX `staff_assignment_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `staff_leave` (
    `id` VARCHAR(36) NOT NULL,
    `staff_profile_id` VARCHAR(36) NOT NULL,
    `status` ENUM('REQUESTED', 'APPROVED', 'REJECTED', 'CANCELLED') NOT NULL,
    `start_date` DATETIME(3) NOT NULL,
    `end_date` DATETIME(3) NOT NULL,
    `reason` TEXT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `staff_leave_staff_profile_id_idx`(`staff_profile_id`),
    INDEX `staff_leave_status_idx`(`status`),
    INDEX `staff_leave_start_date_idx`(`start_date`),
    INDEX `staff_leave_end_date_idx`(`end_date`),
    INDEX `staff_leave_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `shift` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `shift_type` ENUM('DAY', 'NIGHT', 'SWING', 'ON_CALL') NOT NULL,
    `status` ENUM('SCHEDULED', 'COMPLETED', 'CANCELLED') NOT NULL,
    `start_time` DATETIME(3) NOT NULL,
    `end_time` DATETIME(3) NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `shift_tenant_id_idx`(`tenant_id`),
    INDEX `shift_facility_id_idx`(`facility_id`),
    INDEX `shift_shift_type_idx`(`shift_type`),
    INDEX `shift_status_idx`(`status`),
    INDEX `shift_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `shift_assignment` (
    `id` VARCHAR(36) NOT NULL,
    `shift_id` VARCHAR(36) NOT NULL,
    `staff_profile_id` VARCHAR(36) NOT NULL,
    `assigned_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `shift_assignment_shift_id_idx`(`shift_id`),
    INDEX `shift_assignment_staff_profile_id_idx`(`staff_profile_id`),
    INDEX `shift_assignment_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `shift_swap_request` (
    `id` VARCHAR(36) NOT NULL,
    `shift_id` VARCHAR(36) NOT NULL,
    `requester_staff_id` VARCHAR(36) NOT NULL,
    `target_staff_id` VARCHAR(36) NULL,
    `status` ENUM('SCHEDULED', 'COMPLETED', 'CANCELLED') NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `shift_swap_request_shift_id_idx`(`shift_id`),
    INDEX `shift_swap_request_requester_staff_id_idx`(`requester_staff_id`),
    INDEX `shift_swap_request_target_staff_id_idx`(`target_staff_id`),
    INDEX `shift_swap_request_status_idx`(`status`),
    INDEX `shift_swap_request_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `payroll_run` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `period_start` DATETIME(3) NOT NULL,
    `period_end` DATETIME(3) NOT NULL,
    `status` ENUM('DRAFT', 'PROCESSED', 'PAID', 'CANCELLED') NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `payroll_run_tenant_id_idx`(`tenant_id`),
    INDEX `payroll_run_period_start_idx`(`period_start`),
    INDEX `payroll_run_period_end_idx`(`period_end`),
    INDEX `payroll_run_status_idx`(`status`),
    INDEX `payroll_run_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `payroll_item` (
    `id` VARCHAR(36) NOT NULL,
    `payroll_run_id` VARCHAR(36) NOT NULL,
    `staff_profile_id` VARCHAR(36) NOT NULL,
    `amount` DECIMAL(12, 2) NOT NULL,
    `currency` VARCHAR(10) NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `payroll_item_payroll_run_id_idx`(`payroll_run_id`),
    INDEX `payroll_item_staff_profile_id_idx`(`staff_profile_id`),
    INDEX `payroll_item_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `housekeeping_task` (
    `id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `room_id` VARCHAR(36) NULL,
    `assigned_to_staff_id` VARCHAR(36) NULL,
    `status` ENUM('PENDING', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED') NOT NULL,
    `scheduled_at` DATETIME(3) NULL,
    `completed_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `housekeeping_task_facility_id_idx`(`facility_id`),
    INDEX `housekeeping_task_room_id_idx`(`room_id`),
    INDEX `housekeeping_task_assigned_to_staff_id_idx`(`assigned_to_staff_id`),
    INDEX `housekeeping_task_status_idx`(`status`),
    INDEX `housekeeping_task_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `housekeeping_schedule` (
    `id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `room_id` VARCHAR(36) NULL,
    `frequency` VARCHAR(80) NULL,
    `start_date` DATETIME(3) NULL,
    `end_date` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `housekeeping_schedule_facility_id_idx`(`facility_id`),
    INDEX `housekeeping_schedule_room_id_idx`(`room_id`),
    INDEX `housekeeping_schedule_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `maintenance_request` (
    `id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `asset_id` VARCHAR(36) NULL,
    `status` ENUM('OPEN', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED') NOT NULL,
    `description` TEXT NULL,
    `reported_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `resolved_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `maintenance_request_facility_id_idx`(`facility_id`),
    INDEX `maintenance_request_asset_id_idx`(`asset_id`),
    INDEX `maintenance_request_status_idx`(`status`),
    INDEX `maintenance_request_reported_at_idx`(`reported_at`),
    INDEX `maintenance_request_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `asset` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `name` VARCHAR(255) NOT NULL,
    `asset_tag` VARCHAR(80) NULL,
    `status` ENUM('OPEN', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED') NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `asset_tenant_id_idx`(`tenant_id`),
    INDEX `asset_facility_id_idx`(`facility_id`),
    INDEX `asset_asset_tag_idx`(`asset_tag`),
    INDEX `asset_status_idx`(`status`),
    INDEX `asset_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `asset_service_log` (
    `id` VARCHAR(36) NOT NULL,
    `asset_id` VARCHAR(36) NOT NULL,
    `serviced_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `notes` TEXT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `asset_service_log_asset_id_idx`(`asset_id`),
    INDEX `asset_service_log_serviced_at_idx`(`serviced_at`),
    INDEX `asset_service_log_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `notification` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `user_id` VARCHAR(36) NULL,
    `notification_type` ENUM('SYSTEM', 'APPOINTMENT', 'BILLING', 'LAB', 'PHARMACY', 'EMERGENCY', 'OTHER') NOT NULL,
    `priority` ENUM('LOW', 'MEDIUM', 'HIGH', 'URGENT') NOT NULL,
    `title` VARCHAR(255) NOT NULL,
    `message` TEXT NOT NULL,
    `read_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `notification_tenant_id_idx`(`tenant_id`),
    INDEX `notification_user_id_idx`(`user_id`),
    INDEX `notification_notification_type_idx`(`notification_type`),
    INDEX `notification_priority_idx`(`priority`),
    INDEX `notification_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `notification_delivery` (
    `id` VARCHAR(36) NOT NULL,
    `notification_id` VARCHAR(36) NOT NULL,
    `channel` ENUM('EMAIL', 'SMS', 'PUSH', 'WHATSAPP', 'IN_APP') NOT NULL,
    `status` VARCHAR(60) NULL,
    `sent_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `notification_delivery_notification_id_idx`(`notification_id`),
    INDEX `notification_delivery_channel_idx`(`channel`),
    INDEX `notification_delivery_sent_at_idx`(`sent_at`),
    INDEX `notification_delivery_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `conversation` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `subject` VARCHAR(255) NULL,
    `created_by_user_id` VARCHAR(36) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `conversation_tenant_id_idx`(`tenant_id`),
    INDEX `conversation_created_by_user_id_idx`(`created_by_user_id`),
    INDEX `conversation_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `message` (
    `id` VARCHAR(36) NOT NULL,
    `conversation_id` VARCHAR(36) NOT NULL,
    `sender_user_id` VARCHAR(36) NULL,
    `sender_patient_id` VARCHAR(36) NULL,
    `content` TEXT NOT NULL,
    `sent_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `message_conversation_id_idx`(`conversation_id`),
    INDEX `message_sender_user_id_idx`(`sender_user_id`),
    INDEX `message_sender_patient_id_idx`(`sender_patient_id`),
    INDEX `message_sent_at_idx`(`sent_at`),
    INDEX `message_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `template` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `name` VARCHAR(120) NOT NULL,
    `channel` ENUM('EMAIL', 'SMS', 'PUSH', 'WHATSAPP', 'IN_APP') NOT NULL,
    `body` TEXT NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `template_tenant_id_idx`(`tenant_id`),
    INDEX `template_channel_idx`(`channel`),
    INDEX `template_name_idx`(`name`),
    INDEX `template_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `template_variable` (
    `id` VARCHAR(36) NOT NULL,
    `template_id` VARCHAR(36) NOT NULL,
    `key` VARCHAR(120) NOT NULL,
    `description` VARCHAR(255) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `template_variable_template_id_idx`(`template_id`),
    INDEX `template_variable_key_idx`(`key`),
    INDEX `template_variable_deleted_at_idx`(`deleted_at`),
    UNIQUE INDEX `template_variable_template_id_key_key`(`template_id`, `key`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `report_definition` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `query` TEXT NOT NULL,
    `description` TEXT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `report_definition_tenant_id_idx`(`tenant_id`),
    INDEX `report_definition_name_idx`(`name`),
    INDEX `report_definition_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `report_run` (
    `id` VARCHAR(36) NOT NULL,
    `report_definition_id` VARCHAR(36) NOT NULL,
    `run_by_user_id` VARCHAR(36) NULL,
    `status` VARCHAR(60) NOT NULL,
    `started_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `completed_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `report_run_report_definition_id_idx`(`report_definition_id`),
    INDEX `report_run_run_by_user_id_idx`(`run_by_user_id`),
    INDEX `report_run_status_idx`(`status`),
    INDEX `report_run_started_at_idx`(`started_at`),
    INDEX `report_run_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `dashboard_widget` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `config_json` JSON NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `dashboard_widget_tenant_id_idx`(`tenant_id`),
    INDEX `dashboard_widget_name_idx`(`name`),
    INDEX `dashboard_widget_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `kpi_snapshot` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `value` DECIMAL(14, 4) NOT NULL,
    `recorded_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `kpi_snapshot_tenant_id_idx`(`tenant_id`),
    INDEX `kpi_snapshot_recorded_at_idx`(`recorded_at`),
    INDEX `kpi_snapshot_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `analytics_event` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `user_id` VARCHAR(36) NULL,
    `event_name` VARCHAR(255) NOT NULL,
    `payload_json` JSON NULL,
    `occurred_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `analytics_event_tenant_id_idx`(`tenant_id`),
    INDEX `analytics_event_user_id_idx`(`user_id`),
    INDEX `analytics_event_event_name_idx`(`event_name`),
    INDEX `analytics_event_occurred_at_idx`(`occurred_at`),
    INDEX `analytics_event_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `subscription_plan` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NULL,
    `name` VARCHAR(255) NOT NULL,
    `price` DECIMAL(12, 2) NOT NULL,
    `billing_cycle` ENUM('MONTHLY', 'QUARTERLY', 'YEARLY') NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `subscription_plan_tenant_id_idx`(`tenant_id`),
    INDEX `subscription_plan_billing_cycle_idx`(`billing_cycle`),
    INDEX `subscription_plan_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `subscription` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `plan_id` VARCHAR(36) NOT NULL,
    `status` ENUM('ACTIVE', 'PAST_DUE', 'CANCELLED', 'TRIAL') NOT NULL,
    `start_date` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `end_date` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `subscription_tenant_id_idx`(`tenant_id`),
    INDEX `subscription_plan_id_idx`(`plan_id`),
    INDEX `subscription_status_idx`(`status`),
    INDEX `subscription_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `subscription_invoice` (
    `id` VARCHAR(36) NOT NULL,
    `subscription_id` VARCHAR(36) NOT NULL,
    `invoice_id` VARCHAR(36) NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `subscription_invoice_subscription_id_idx`(`subscription_id`),
    INDEX `subscription_invoice_invoice_id_idx`(`invoice_id`),
    INDEX `subscription_invoice_deleted_at_idx`(`deleted_at`),
    UNIQUE INDEX `subscription_invoice_subscription_id_invoice_id_key`(`subscription_id`, `invoice_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `module` (
    `id` VARCHAR(36) NOT NULL,
    `name` VARCHAR(120) NOT NULL,
    `description` TEXT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `module_name_idx`(`name`),
    INDEX `module_deleted_at_idx`(`deleted_at`),
    UNIQUE INDEX `module_name_key`(`name`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `module_subscription` (
    `id` VARCHAR(36) NOT NULL,
    `module_id` VARCHAR(36) NOT NULL,
    `subscription_id` VARCHAR(36) NOT NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `module_subscription_module_id_idx`(`module_id`),
    INDEX `module_subscription_subscription_id_idx`(`subscription_id`),
    INDEX `module_subscription_is_active_idx`(`is_active`),
    INDEX `module_subscription_deleted_at_idx`(`deleted_at`),
    UNIQUE INDEX `module_subscription_module_id_subscription_id_key`(`module_id`, `subscription_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `license` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `license_type` ENUM('PER_USER', 'PER_FACILITY', 'ENTERPRISE') NOT NULL,
    `status` ENUM('ACTIVE', 'PAST_DUE', 'CANCELLED', 'TRIAL') NOT NULL,
    `issued_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `expires_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `license_tenant_id_idx`(`tenant_id`),
    INDEX `license_license_type_idx`(`license_type`),
    INDEX `license_status_idx`(`status`),
    INDEX `license_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `audit_log` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `user_id` VARCHAR(36) NULL,
    `action` ENUM('CREATE', 'UPDATE', 'DELETE', 'ACCESS', 'EXPORT', 'LOGIN', 'LOGOUT') NOT NULL,
    `entity` VARCHAR(120) NOT NULL,
    `entity_id` VARCHAR(36) NOT NULL,
    `diff_json` JSON NULL,
    `ip_address` VARCHAR(45) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `audit_log_tenant_id_idx`(`tenant_id`),
    INDEX `audit_log_user_id_idx`(`user_id`),
    INDEX `audit_log_action_idx`(`action`),
    INDEX `audit_log_entity_idx`(`entity`),
    INDEX `audit_log_created_at_idx`(`created_at`),
    INDEX `audit_log_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `phi_access_log` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `user_id` VARCHAR(36) NOT NULL,
    `patient_id` VARCHAR(36) NOT NULL,
    `access_scope` ENUM('TENANT', 'FACILITY', 'DEPARTMENT', 'PATIENT') NOT NULL,
    `reason` VARCHAR(255) NULL,
    `accessed_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `phi_access_log_tenant_id_idx`(`tenant_id`),
    INDEX `phi_access_log_user_id_idx`(`user_id`),
    INDEX `phi_access_log_patient_id_idx`(`patient_id`),
    INDEX `phi_access_log_access_scope_idx`(`access_scope`),
    INDEX `phi_access_log_accessed_at_idx`(`accessed_at`),
    INDEX `phi_access_log_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `data_processing_log` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `user_id` VARCHAR(36) NULL,
    `purpose` ENUM('TREATMENT', 'BILLING', 'OPERATIONS', 'RESEARCH', 'MARKETING') NOT NULL,
    `legal_basis` ENUM('CONSENT', 'CONTRACT', 'LEGAL_OBLIGATION', 'VITAL_INTERESTS', 'PUBLIC_INTEREST', 'LEGITIMATE_INTERESTS') NOT NULL,
    `details` TEXT NULL,
    `processed_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `data_processing_log_tenant_id_idx`(`tenant_id`),
    INDEX `data_processing_log_user_id_idx`(`user_id`),
    INDEX `data_processing_log_purpose_idx`(`purpose`),
    INDEX `data_processing_log_legal_basis_idx`(`legal_basis`),
    INDEX `data_processing_log_processed_at_idx`(`processed_at`),
    INDEX `data_processing_log_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `breach_notification` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `severity` ENUM('LOW', 'MEDIUM', 'HIGH', 'CRITICAL') NOT NULL,
    `status` ENUM('OPEN', 'INVESTIGATING', 'RESOLVED', 'REPORTED') NOT NULL,
    `description` TEXT NULL,
    `reported_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `resolved_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `breach_notification_tenant_id_idx`(`tenant_id`),
    INDEX `breach_notification_severity_idx`(`severity`),
    INDEX `breach_notification_status_idx`(`status`),
    INDEX `breach_notification_reported_at_idx`(`reported_at`),
    INDEX `breach_notification_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `system_change_log` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `user_id` VARCHAR(36) NULL,
    `change_type` VARCHAR(120) NOT NULL,
    `details` TEXT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `system_change_log_tenant_id_idx`(`tenant_id`),
    INDEX `system_change_log_user_id_idx`(`user_id`),
    INDEX `system_change_log_change_type_idx`(`change_type`),
    INDEX `system_change_log_created_at_idx`(`created_at`),
    INDEX `system_change_log_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `integration` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `integration_type` ENUM('HL7', 'FHIR', 'LAB', 'RADIOLOGY', 'BILLING', 'OTHER') NOT NULL,
    `status` ENUM('ACTIVE', 'INACTIVE', 'ERROR') NOT NULL,
    `name` VARCHAR(120) NOT NULL,
    `config_json` JSON NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `integration_tenant_id_idx`(`tenant_id`),
    INDEX `integration_integration_type_idx`(`integration_type`),
    INDEX `integration_status_idx`(`status`),
    INDEX `integration_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `integration_log` (
    `id` VARCHAR(36) NOT NULL,
    `integration_id` VARCHAR(36) NOT NULL,
    `status` ENUM('ACTIVE', 'INACTIVE', 'ERROR') NOT NULL,
    `message` TEXT NULL,
    `logged_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `integration_log_integration_id_idx`(`integration_id`),
    INDEX `integration_log_status_idx`(`status`),
    INDEX `integration_log_logged_at_idx`(`logged_at`),
    INDEX `integration_log_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `webhook_subscription` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `integration_id` VARCHAR(36) NULL,
    `event` VARCHAR(120) NOT NULL,
    `target_url` VARCHAR(255) NOT NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `webhook_subscription_tenant_id_idx`(`tenant_id`),
    INDEX `webhook_subscription_integration_id_idx`(`integration_id`),
    INDEX `webhook_subscription_event_idx`(`event`),
    INDEX `webhook_subscription_is_active_idx`(`is_active`),
    INDEX `webhook_subscription_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `facility` ADD CONSTRAINT `facility_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `branch` ADD CONSTRAINT `branch_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `branch` ADD CONSTRAINT `branch_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `department` ADD CONSTRAINT `department_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `department` ADD CONSTRAINT `department_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `department` ADD CONSTRAINT `department_branch_id_fkey` FOREIGN KEY (`branch_id`) REFERENCES `branch`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `unit` ADD CONSTRAINT `unit_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `unit` ADD CONSTRAINT `unit_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `unit` ADD CONSTRAINT `unit_department_id_fkey` FOREIGN KEY (`department_id`) REFERENCES `department`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `ward` ADD CONSTRAINT `ward_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `ward` ADD CONSTRAINT `ward_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `ward` ADD CONSTRAINT `ward_department_id_fkey` FOREIGN KEY (`department_id`) REFERENCES `department`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `room` ADD CONSTRAINT `room_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `room` ADD CONSTRAINT `room_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `room` ADD CONSTRAINT `room_ward_id_fkey` FOREIGN KEY (`ward_id`) REFERENCES `ward`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `bed` ADD CONSTRAINT `bed_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `bed` ADD CONSTRAINT `bed_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `bed` ADD CONSTRAINT `bed_ward_id_fkey` FOREIGN KEY (`ward_id`) REFERENCES `ward`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `bed` ADD CONSTRAINT `bed_room_id_fkey` FOREIGN KEY (`room_id`) REFERENCES `room`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `address` ADD CONSTRAINT `address_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `address` ADD CONSTRAINT `address_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `address` ADD CONSTRAINT `address_branch_id_fkey` FOREIGN KEY (`branch_id`) REFERENCES `branch`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `address` ADD CONSTRAINT `address_patient_id_fkey` FOREIGN KEY (`patient_id`) REFERENCES `patient`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `address` ADD CONSTRAINT `address_user_profile_id_fkey` FOREIGN KEY (`user_profile_id`) REFERENCES `user_profile`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `address` ADD CONSTRAINT `address_staff_profile_id_fkey` FOREIGN KEY (`staff_profile_id`) REFERENCES `staff_profile`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `address` ADD CONSTRAINT `address_supplier_id_fkey` FOREIGN KEY (`supplier_id`) REFERENCES `supplier`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `contact` ADD CONSTRAINT `contact_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `contact` ADD CONSTRAINT `contact_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `contact` ADD CONSTRAINT `contact_branch_id_fkey` FOREIGN KEY (`branch_id`) REFERENCES `branch`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `contact` ADD CONSTRAINT `contact_patient_id_fkey` FOREIGN KEY (`patient_id`) REFERENCES `patient`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `contact` ADD CONSTRAINT `contact_user_profile_id_fkey` FOREIGN KEY (`user_profile_id`) REFERENCES `user_profile`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `contact` ADD CONSTRAINT `contact_staff_profile_id_fkey` FOREIGN KEY (`staff_profile_id`) REFERENCES `staff_profile`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `contact` ADD CONSTRAINT `contact_supplier_id_fkey` FOREIGN KEY (`supplier_id`) REFERENCES `supplier`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `user` ADD CONSTRAINT `user_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `user` ADD CONSTRAINT `user_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `user_profile` ADD CONSTRAINT `user_profile_user_id_fkey` FOREIGN KEY (`user_id`) REFERENCES `user`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `user_profile` ADD CONSTRAINT `user_profile_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `user_session` ADD CONSTRAINT `user_session_user_id_fkey` FOREIGN KEY (`user_id`) REFERENCES `user`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `role` ADD CONSTRAINT `role_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `permission` ADD CONSTRAINT `permission_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `role_permission` ADD CONSTRAINT `role_permission_role_id_fkey` FOREIGN KEY (`role_id`) REFERENCES `role`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `role_permission` ADD CONSTRAINT `role_permission_permission_id_fkey` FOREIGN KEY (`permission_id`) REFERENCES `permission`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `user_role` ADD CONSTRAINT `user_role_user_id_fkey` FOREIGN KEY (`user_id`) REFERENCES `user`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `user_role` ADD CONSTRAINT `user_role_role_id_fkey` FOREIGN KEY (`role_id`) REFERENCES `role`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `user_role` ADD CONSTRAINT `user_role_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `api_key` ADD CONSTRAINT `api_key_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `api_key` ADD CONSTRAINT `api_key_user_id_fkey` FOREIGN KEY (`user_id`) REFERENCES `user`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `api_key_permission` ADD CONSTRAINT `api_key_permission_api_key_id_fkey` FOREIGN KEY (`api_key_id`) REFERENCES `api_key`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `api_key_permission` ADD CONSTRAINT `api_key_permission_permission_id_fkey` FOREIGN KEY (`permission_id`) REFERENCES `permission`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `user_mfa` ADD CONSTRAINT `user_mfa_user_id_fkey` FOREIGN KEY (`user_id`) REFERENCES `user`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `oauth_account` ADD CONSTRAINT `oauth_account_user_id_fkey` FOREIGN KEY (`user_id`) REFERENCES `user`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `patient` ADD CONSTRAINT `patient_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `patient` ADD CONSTRAINT `patient_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `patient_identifier` ADD CONSTRAINT `patient_identifier_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `patient_identifier` ADD CONSTRAINT `patient_identifier_patient_id_fkey` FOREIGN KEY (`patient_id`) REFERENCES `patient`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `patient_contact` ADD CONSTRAINT `patient_contact_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `patient_contact` ADD CONSTRAINT `patient_contact_patient_id_fkey` FOREIGN KEY (`patient_id`) REFERENCES `patient`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `patient_guardian` ADD CONSTRAINT `patient_guardian_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `patient_guardian` ADD CONSTRAINT `patient_guardian_patient_id_fkey` FOREIGN KEY (`patient_id`) REFERENCES `patient`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `patient_allergy` ADD CONSTRAINT `patient_allergy_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `patient_allergy` ADD CONSTRAINT `patient_allergy_patient_id_fkey` FOREIGN KEY (`patient_id`) REFERENCES `patient`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `patient_medical_history` ADD CONSTRAINT `patient_medical_history_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `patient_medical_history` ADD CONSTRAINT `patient_medical_history_patient_id_fkey` FOREIGN KEY (`patient_id`) REFERENCES `patient`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `patient_document` ADD CONSTRAINT `patient_document_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `patient_document` ADD CONSTRAINT `patient_document_patient_id_fkey` FOREIGN KEY (`patient_id`) REFERENCES `patient`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `consent` ADD CONSTRAINT `consent_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `consent` ADD CONSTRAINT `consent_patient_id_fkey` FOREIGN KEY (`patient_id`) REFERENCES `patient`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `terms_acceptance` ADD CONSTRAINT `terms_acceptance_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `terms_acceptance` ADD CONSTRAINT `terms_acceptance_user_id_fkey` FOREIGN KEY (`user_id`) REFERENCES `user`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `appointment` ADD CONSTRAINT `appointment_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `appointment` ADD CONSTRAINT `appointment_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `appointment` ADD CONSTRAINT `appointment_patient_id_fkey` FOREIGN KEY (`patient_id`) REFERENCES `patient`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `appointment` ADD CONSTRAINT `appointment_provider_user_id_fkey` FOREIGN KEY (`provider_user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `appointment_participant` ADD CONSTRAINT `appointment_participant_appointment_id_fkey` FOREIGN KEY (`appointment_id`) REFERENCES `appointment`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `appointment_participant` ADD CONSTRAINT `appointment_participant_participant_user_id_fkey` FOREIGN KEY (`participant_user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `appointment_participant` ADD CONSTRAINT `appointment_participant_participant_patient_id_fkey` FOREIGN KEY (`participant_patient_id`) REFERENCES `patient`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `appointment_reminder` ADD CONSTRAINT `appointment_reminder_appointment_id_fkey` FOREIGN KEY (`appointment_id`) REFERENCES `appointment`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `provider_schedule` ADD CONSTRAINT `provider_schedule_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `provider_schedule` ADD CONSTRAINT `provider_schedule_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `provider_schedule` ADD CONSTRAINT `provider_schedule_provider_user_id_fkey` FOREIGN KEY (`provider_user_id`) REFERENCES `user`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `availability_slot` ADD CONSTRAINT `availability_slot_schedule_id_fkey` FOREIGN KEY (`schedule_id`) REFERENCES `provider_schedule`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `visit_queue` ADD CONSTRAINT `visit_queue_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `visit_queue` ADD CONSTRAINT `visit_queue_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `visit_queue` ADD CONSTRAINT `visit_queue_patient_id_fkey` FOREIGN KEY (`patient_id`) REFERENCES `patient`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `visit_queue` ADD CONSTRAINT `visit_queue_appointment_id_fkey` FOREIGN KEY (`appointment_id`) REFERENCES `appointment`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `visit_queue` ADD CONSTRAINT `visit_queue_provider_user_id_fkey` FOREIGN KEY (`provider_user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `encounter` ADD CONSTRAINT `encounter_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `encounter` ADD CONSTRAINT `encounter_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `encounter` ADD CONSTRAINT `encounter_patient_id_fkey` FOREIGN KEY (`patient_id`) REFERENCES `patient`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `encounter` ADD CONSTRAINT `encounter_provider_user_id_fkey` FOREIGN KEY (`provider_user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `clinical_note` ADD CONSTRAINT `clinical_note_encounter_id_fkey` FOREIGN KEY (`encounter_id`) REFERENCES `encounter`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `clinical_note` ADD CONSTRAINT `clinical_note_author_user_id_fkey` FOREIGN KEY (`author_user_id`) REFERENCES `user`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `diagnosis` ADD CONSTRAINT `diagnosis_encounter_id_fkey` FOREIGN KEY (`encounter_id`) REFERENCES `encounter`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `procedure` ADD CONSTRAINT `procedure_encounter_id_fkey` FOREIGN KEY (`encounter_id`) REFERENCES `encounter`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `vital_sign` ADD CONSTRAINT `vital_sign_encounter_id_fkey` FOREIGN KEY (`encounter_id`) REFERENCES `encounter`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `care_plan` ADD CONSTRAINT `care_plan_encounter_id_fkey` FOREIGN KEY (`encounter_id`) REFERENCES `encounter`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `clinical_alert` ADD CONSTRAINT `clinical_alert_encounter_id_fkey` FOREIGN KEY (`encounter_id`) REFERENCES `encounter`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `referral` ADD CONSTRAINT `referral_encounter_id_fkey` FOREIGN KEY (`encounter_id`) REFERENCES `encounter`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `referral` ADD CONSTRAINT `referral_from_department_id_fkey` FOREIGN KEY (`from_department_id`) REFERENCES `department`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `referral` ADD CONSTRAINT `referral_to_department_id_fkey` FOREIGN KEY (`to_department_id`) REFERENCES `department`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `follow_up` ADD CONSTRAINT `follow_up_encounter_id_fkey` FOREIGN KEY (`encounter_id`) REFERENCES `encounter`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `admission` ADD CONSTRAINT `admission_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `admission` ADD CONSTRAINT `admission_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `admission` ADD CONSTRAINT `admission_patient_id_fkey` FOREIGN KEY (`patient_id`) REFERENCES `patient`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `admission` ADD CONSTRAINT `admission_encounter_id_fkey` FOREIGN KEY (`encounter_id`) REFERENCES `encounter`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `bed_assignment` ADD CONSTRAINT `bed_assignment_admission_id_fkey` FOREIGN KEY (`admission_id`) REFERENCES `admission`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `bed_assignment` ADD CONSTRAINT `bed_assignment_bed_id_fkey` FOREIGN KEY (`bed_id`) REFERENCES `bed`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `ward_round` ADD CONSTRAINT `ward_round_admission_id_fkey` FOREIGN KEY (`admission_id`) REFERENCES `admission`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `nursing_note` ADD CONSTRAINT `nursing_note_admission_id_fkey` FOREIGN KEY (`admission_id`) REFERENCES `admission`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `nursing_note` ADD CONSTRAINT `nursing_note_nurse_user_id_fkey` FOREIGN KEY (`nurse_user_id`) REFERENCES `user`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `medication_administration` ADD CONSTRAINT `medication_administration_admission_id_fkey` FOREIGN KEY (`admission_id`) REFERENCES `admission`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `discharge_summary` ADD CONSTRAINT `discharge_summary_admission_id_fkey` FOREIGN KEY (`admission_id`) REFERENCES `admission`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `transfer_request` ADD CONSTRAINT `transfer_request_admission_id_fkey` FOREIGN KEY (`admission_id`) REFERENCES `admission`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `transfer_request` ADD CONSTRAINT `transfer_request_from_ward_id_fkey` FOREIGN KEY (`from_ward_id`) REFERENCES `ward`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `transfer_request` ADD CONSTRAINT `transfer_request_to_ward_id_fkey` FOREIGN KEY (`to_ward_id`) REFERENCES `ward`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `icu_stay` ADD CONSTRAINT `icu_stay_admission_id_fkey` FOREIGN KEY (`admission_id`) REFERENCES `admission`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `icu_observation` ADD CONSTRAINT `icu_observation_icu_stay_id_fkey` FOREIGN KEY (`icu_stay_id`) REFERENCES `icu_stay`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `critical_alert` ADD CONSTRAINT `critical_alert_icu_stay_id_fkey` FOREIGN KEY (`icu_stay_id`) REFERENCES `icu_stay`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `theatre_case` ADD CONSTRAINT `theatre_case_encounter_id_fkey` FOREIGN KEY (`encounter_id`) REFERENCES `encounter`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `anesthesia_record` ADD CONSTRAINT `anesthesia_record_theatre_case_id_fkey` FOREIGN KEY (`theatre_case_id`) REFERENCES `theatre_case`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `anesthesia_record` ADD CONSTRAINT `anesthesia_record_anesthetist_user_id_fkey` FOREIGN KEY (`anesthetist_user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `post_op_note` ADD CONSTRAINT `post_op_note_theatre_case_id_fkey` FOREIGN KEY (`theatre_case_id`) REFERENCES `theatre_case`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `lab_test` ADD CONSTRAINT `lab_test_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `lab_panel` ADD CONSTRAINT `lab_panel_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `lab_order` ADD CONSTRAINT `lab_order_encounter_id_fkey` FOREIGN KEY (`encounter_id`) REFERENCES `encounter`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `lab_order` ADD CONSTRAINT `lab_order_patient_id_fkey` FOREIGN KEY (`patient_id`) REFERENCES `patient`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `lab_order_item` ADD CONSTRAINT `lab_order_item_lab_order_id_fkey` FOREIGN KEY (`lab_order_id`) REFERENCES `lab_order`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `lab_order_item` ADD CONSTRAINT `lab_order_item_lab_test_id_fkey` FOREIGN KEY (`lab_test_id`) REFERENCES `lab_test`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `lab_sample` ADD CONSTRAINT `lab_sample_lab_order_id_fkey` FOREIGN KEY (`lab_order_id`) REFERENCES `lab_order`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `lab_result` ADD CONSTRAINT `lab_result_lab_order_item_id_fkey` FOREIGN KEY (`lab_order_item_id`) REFERENCES `lab_order_item`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `lab_qc_log` ADD CONSTRAINT `lab_qc_log_lab_test_id_fkey` FOREIGN KEY (`lab_test_id`) REFERENCES `lab_test`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `radiology_test` ADD CONSTRAINT `radiology_test_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `radiology_order` ADD CONSTRAINT `radiology_order_encounter_id_fkey` FOREIGN KEY (`encounter_id`) REFERENCES `encounter`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `radiology_order` ADD CONSTRAINT `radiology_order_patient_id_fkey` FOREIGN KEY (`patient_id`) REFERENCES `patient`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `radiology_order` ADD CONSTRAINT `radiology_order_radiology_test_id_fkey` FOREIGN KEY (`radiology_test_id`) REFERENCES `radiology_test`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `radiology_result` ADD CONSTRAINT `radiology_result_radiology_order_id_fkey` FOREIGN KEY (`radiology_order_id`) REFERENCES `radiology_order`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `imaging_study` ADD CONSTRAINT `imaging_study_radiology_order_id_fkey` FOREIGN KEY (`radiology_order_id`) REFERENCES `radiology_order`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `imaging_asset` ADD CONSTRAINT `imaging_asset_imaging_study_id_fkey` FOREIGN KEY (`imaging_study_id`) REFERENCES `imaging_study`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `pacs_link` ADD CONSTRAINT `pacs_link_imaging_study_id_fkey` FOREIGN KEY (`imaging_study_id`) REFERENCES `imaging_study`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `drug` ADD CONSTRAINT `drug_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `drug_batch` ADD CONSTRAINT `drug_batch_drug_id_fkey` FOREIGN KEY (`drug_id`) REFERENCES `drug`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `formulary_item` ADD CONSTRAINT `formulary_item_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `formulary_item` ADD CONSTRAINT `formulary_item_drug_id_fkey` FOREIGN KEY (`drug_id`) REFERENCES `drug`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `pharmacy_order` ADD CONSTRAINT `pharmacy_order_encounter_id_fkey` FOREIGN KEY (`encounter_id`) REFERENCES `encounter`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `pharmacy_order` ADD CONSTRAINT `pharmacy_order_patient_id_fkey` FOREIGN KEY (`patient_id`) REFERENCES `patient`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `pharmacy_order_item` ADD CONSTRAINT `pharmacy_order_item_pharmacy_order_id_fkey` FOREIGN KEY (`pharmacy_order_id`) REFERENCES `pharmacy_order`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `pharmacy_order_item` ADD CONSTRAINT `pharmacy_order_item_drug_id_fkey` FOREIGN KEY (`drug_id`) REFERENCES `drug`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `dispense_log` ADD CONSTRAINT `dispense_log_pharmacy_order_item_id_fkey` FOREIGN KEY (`pharmacy_order_item_id`) REFERENCES `pharmacy_order_item`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `adverse_event` ADD CONSTRAINT `adverse_event_patient_id_fkey` FOREIGN KEY (`patient_id`) REFERENCES `patient`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `adverse_event` ADD CONSTRAINT `adverse_event_drug_id_fkey` FOREIGN KEY (`drug_id`) REFERENCES `drug`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `inventory_item` ADD CONSTRAINT `inventory_item_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `inventory_stock` ADD CONSTRAINT `inventory_stock_inventory_item_id_fkey` FOREIGN KEY (`inventory_item_id`) REFERENCES `inventory_item`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `inventory_stock` ADD CONSTRAINT `inventory_stock_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `stock_movement` ADD CONSTRAINT `stock_movement_inventory_item_id_fkey` FOREIGN KEY (`inventory_item_id`) REFERENCES `inventory_item`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `stock_movement` ADD CONSTRAINT `stock_movement_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `supplier` ADD CONSTRAINT `supplier_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `purchase_request` ADD CONSTRAINT `purchase_request_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `purchase_request` ADD CONSTRAINT `purchase_request_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `purchase_request` ADD CONSTRAINT `purchase_request_requested_by_user_id_fkey` FOREIGN KEY (`requested_by_user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `purchase_order` ADD CONSTRAINT `purchase_order_purchase_request_id_fkey` FOREIGN KEY (`purchase_request_id`) REFERENCES `purchase_request`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `purchase_order` ADD CONSTRAINT `purchase_order_supplier_id_fkey` FOREIGN KEY (`supplier_id`) REFERENCES `supplier`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `goods_receipt` ADD CONSTRAINT `goods_receipt_purchase_order_id_fkey` FOREIGN KEY (`purchase_order_id`) REFERENCES `purchase_order`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `stock_adjustment` ADD CONSTRAINT `stock_adjustment_inventory_item_id_fkey` FOREIGN KEY (`inventory_item_id`) REFERENCES `inventory_item`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `stock_adjustment` ADD CONSTRAINT `stock_adjustment_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `emergency_case` ADD CONSTRAINT `emergency_case_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `emergency_case` ADD CONSTRAINT `emergency_case_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `emergency_case` ADD CONSTRAINT `emergency_case_patient_id_fkey` FOREIGN KEY (`patient_id`) REFERENCES `patient`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `triage_assessment` ADD CONSTRAINT `triage_assessment_emergency_case_id_fkey` FOREIGN KEY (`emergency_case_id`) REFERENCES `emergency_case`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `emergency_response` ADD CONSTRAINT `emergency_response_emergency_case_id_fkey` FOREIGN KEY (`emergency_case_id`) REFERENCES `emergency_case`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `ambulance` ADD CONSTRAINT `ambulance_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `ambulance` ADD CONSTRAINT `ambulance_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `ambulance_dispatch` ADD CONSTRAINT `ambulance_dispatch_ambulance_id_fkey` FOREIGN KEY (`ambulance_id`) REFERENCES `ambulance`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `ambulance_dispatch` ADD CONSTRAINT `ambulance_dispatch_emergency_case_id_fkey` FOREIGN KEY (`emergency_case_id`) REFERENCES `emergency_case`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `ambulance_trip` ADD CONSTRAINT `ambulance_trip_ambulance_id_fkey` FOREIGN KEY (`ambulance_id`) REFERENCES `ambulance`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `ambulance_trip` ADD CONSTRAINT `ambulance_trip_emergency_case_id_fkey` FOREIGN KEY (`emergency_case_id`) REFERENCES `emergency_case`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `invoice` ADD CONSTRAINT `invoice_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `invoice` ADD CONSTRAINT `invoice_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `invoice` ADD CONSTRAINT `invoice_patient_id_fkey` FOREIGN KEY (`patient_id`) REFERENCES `patient`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `invoice_item` ADD CONSTRAINT `invoice_item_invoice_id_fkey` FOREIGN KEY (`invoice_id`) REFERENCES `invoice`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `payment` ADD CONSTRAINT `payment_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `payment` ADD CONSTRAINT `payment_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `payment` ADD CONSTRAINT `payment_patient_id_fkey` FOREIGN KEY (`patient_id`) REFERENCES `patient`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `payment` ADD CONSTRAINT `payment_invoice_id_fkey` FOREIGN KEY (`invoice_id`) REFERENCES `invoice`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `refund` ADD CONSTRAINT `refund_payment_id_fkey` FOREIGN KEY (`payment_id`) REFERENCES `payment`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `pricing_rule` ADD CONSTRAINT `pricing_rule_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `coverage_plan` ADD CONSTRAINT `coverage_plan_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `insurance_claim` ADD CONSTRAINT `insurance_claim_coverage_plan_id_fkey` FOREIGN KEY (`coverage_plan_id`) REFERENCES `coverage_plan`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `insurance_claim` ADD CONSTRAINT `insurance_claim_invoice_id_fkey` FOREIGN KEY (`invoice_id`) REFERENCES `invoice`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `pre_authorization` ADD CONSTRAINT `pre_authorization_coverage_plan_id_fkey` FOREIGN KEY (`coverage_plan_id`) REFERENCES `coverage_plan`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `billing_adjustment` ADD CONSTRAINT `billing_adjustment_invoice_id_fkey` FOREIGN KEY (`invoice_id`) REFERENCES `invoice`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `staff_profile` ADD CONSTRAINT `staff_profile_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `staff_profile` ADD CONSTRAINT `staff_profile_user_id_fkey` FOREIGN KEY (`user_id`) REFERENCES `user`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `staff_profile` ADD CONSTRAINT `staff_profile_department_id_fkey` FOREIGN KEY (`department_id`) REFERENCES `department`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `staff_assignment` ADD CONSTRAINT `staff_assignment_staff_profile_id_fkey` FOREIGN KEY (`staff_profile_id`) REFERENCES `staff_profile`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `staff_assignment` ADD CONSTRAINT `staff_assignment_department_id_fkey` FOREIGN KEY (`department_id`) REFERENCES `department`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `staff_assignment` ADD CONSTRAINT `staff_assignment_unit_id_fkey` FOREIGN KEY (`unit_id`) REFERENCES `unit`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `staff_leave` ADD CONSTRAINT `staff_leave_staff_profile_id_fkey` FOREIGN KEY (`staff_profile_id`) REFERENCES `staff_profile`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `shift` ADD CONSTRAINT `shift_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `shift` ADD CONSTRAINT `shift_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `shift_assignment` ADD CONSTRAINT `shift_assignment_shift_id_fkey` FOREIGN KEY (`shift_id`) REFERENCES `shift`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `shift_assignment` ADD CONSTRAINT `shift_assignment_staff_profile_id_fkey` FOREIGN KEY (`staff_profile_id`) REFERENCES `staff_profile`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `shift_swap_request` ADD CONSTRAINT `shift_swap_request_shift_id_fkey` FOREIGN KEY (`shift_id`) REFERENCES `shift`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `shift_swap_request` ADD CONSTRAINT `shift_swap_request_requester_staff_id_fkey` FOREIGN KEY (`requester_staff_id`) REFERENCES `staff_profile`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `shift_swap_request` ADD CONSTRAINT `shift_swap_request_target_staff_id_fkey` FOREIGN KEY (`target_staff_id`) REFERENCES `staff_profile`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `payroll_run` ADD CONSTRAINT `payroll_run_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `payroll_item` ADD CONSTRAINT `payroll_item_payroll_run_id_fkey` FOREIGN KEY (`payroll_run_id`) REFERENCES `payroll_run`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `payroll_item` ADD CONSTRAINT `payroll_item_staff_profile_id_fkey` FOREIGN KEY (`staff_profile_id`) REFERENCES `staff_profile`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `housekeeping_task` ADD CONSTRAINT `housekeeping_task_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `housekeeping_task` ADD CONSTRAINT `housekeeping_task_room_id_fkey` FOREIGN KEY (`room_id`) REFERENCES `room`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `housekeeping_task` ADD CONSTRAINT `housekeeping_task_assigned_to_staff_id_fkey` FOREIGN KEY (`assigned_to_staff_id`) REFERENCES `staff_profile`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `housekeeping_schedule` ADD CONSTRAINT `housekeeping_schedule_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `housekeeping_schedule` ADD CONSTRAINT `housekeeping_schedule_room_id_fkey` FOREIGN KEY (`room_id`) REFERENCES `room`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `maintenance_request` ADD CONSTRAINT `maintenance_request_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `maintenance_request` ADD CONSTRAINT `maintenance_request_asset_id_fkey` FOREIGN KEY (`asset_id`) REFERENCES `asset`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `asset` ADD CONSTRAINT `asset_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `asset` ADD CONSTRAINT `asset_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `asset_service_log` ADD CONSTRAINT `asset_service_log_asset_id_fkey` FOREIGN KEY (`asset_id`) REFERENCES `asset`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `notification` ADD CONSTRAINT `notification_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `notification` ADD CONSTRAINT `notification_user_id_fkey` FOREIGN KEY (`user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `notification_delivery` ADD CONSTRAINT `notification_delivery_notification_id_fkey` FOREIGN KEY (`notification_id`) REFERENCES `notification`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `conversation` ADD CONSTRAINT `conversation_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `conversation` ADD CONSTRAINT `conversation_created_by_user_id_fkey` FOREIGN KEY (`created_by_user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `message` ADD CONSTRAINT `message_conversation_id_fkey` FOREIGN KEY (`conversation_id`) REFERENCES `conversation`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `message` ADD CONSTRAINT `message_sender_user_id_fkey` FOREIGN KEY (`sender_user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `message` ADD CONSTRAINT `message_sender_patient_id_fkey` FOREIGN KEY (`sender_patient_id`) REFERENCES `patient`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `template` ADD CONSTRAINT `template_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `template_variable` ADD CONSTRAINT `template_variable_template_id_fkey` FOREIGN KEY (`template_id`) REFERENCES `template`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `report_definition` ADD CONSTRAINT `report_definition_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `report_run` ADD CONSTRAINT `report_run_report_definition_id_fkey` FOREIGN KEY (`report_definition_id`) REFERENCES `report_definition`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `report_run` ADD CONSTRAINT `report_run_run_by_user_id_fkey` FOREIGN KEY (`run_by_user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `dashboard_widget` ADD CONSTRAINT `dashboard_widget_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `kpi_snapshot` ADD CONSTRAINT `kpi_snapshot_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `analytics_event` ADD CONSTRAINT `analytics_event_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `analytics_event` ADD CONSTRAINT `analytics_event_user_id_fkey` FOREIGN KEY (`user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `subscription_plan` ADD CONSTRAINT `subscription_plan_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `subscription` ADD CONSTRAINT `subscription_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `subscription` ADD CONSTRAINT `subscription_plan_id_fkey` FOREIGN KEY (`plan_id`) REFERENCES `subscription_plan`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `subscription_invoice` ADD CONSTRAINT `subscription_invoice_subscription_id_fkey` FOREIGN KEY (`subscription_id`) REFERENCES `subscription`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `subscription_invoice` ADD CONSTRAINT `subscription_invoice_invoice_id_fkey` FOREIGN KEY (`invoice_id`) REFERENCES `invoice`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `module_subscription` ADD CONSTRAINT `module_subscription_module_id_fkey` FOREIGN KEY (`module_id`) REFERENCES `module`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `module_subscription` ADD CONSTRAINT `module_subscription_subscription_id_fkey` FOREIGN KEY (`subscription_id`) REFERENCES `subscription`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `license` ADD CONSTRAINT `license_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `audit_log` ADD CONSTRAINT `audit_log_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `audit_log` ADD CONSTRAINT `audit_log_user_id_fkey` FOREIGN KEY (`user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `phi_access_log` ADD CONSTRAINT `phi_access_log_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `phi_access_log` ADD CONSTRAINT `phi_access_log_user_id_fkey` FOREIGN KEY (`user_id`) REFERENCES `user`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `phi_access_log` ADD CONSTRAINT `phi_access_log_patient_id_fkey` FOREIGN KEY (`patient_id`) REFERENCES `patient`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `data_processing_log` ADD CONSTRAINT `data_processing_log_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `data_processing_log` ADD CONSTRAINT `data_processing_log_user_id_fkey` FOREIGN KEY (`user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `breach_notification` ADD CONSTRAINT `breach_notification_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `system_change_log` ADD CONSTRAINT `system_change_log_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `system_change_log` ADD CONSTRAINT `system_change_log_user_id_fkey` FOREIGN KEY (`user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `integration` ADD CONSTRAINT `integration_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `integration_log` ADD CONSTRAINT `integration_log_integration_id_fkey` FOREIGN KEY (`integration_id`) REFERENCES `integration`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `webhook_subscription` ADD CONSTRAINT `webhook_subscription_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `webhook_subscription` ADD CONSTRAINT `webhook_subscription_integration_id_fkey` FOREIGN KEY (`integration_id`) REFERENCES `integration`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;
