/*
  Warnings:

  - The values [CARD] on the enum `payment_method` will be removed. If these variants are still used in the database, this will fail.

*/
-- AlterTable
ALTER TABLE `appointment_reminder` MODIFY `channel` ENUM('EMAIL', 'SMS', 'PUSH', 'WHATSAPP', 'IN_APP', 'TELEGRAM', 'TIKTOK', 'INSTAGRAM', 'FACEBOOK', 'LINKEDIN', 'X', 'YOUTUBE', 'PINTEREST', 'REDDIT', 'DISCORD', 'CALL', 'OTHER') NOT NULL;

-- AlterTable
ALTER TABLE `contact` MODIFY `contact_type` ENUM('PHONE', 'EMAIL', 'WHATSAPP', 'TELEGRAM', 'TIKTOK', 'INSTAGRAM', 'FACEBOOK', 'LINKEDIN', 'X', 'YOUTUBE', 'PINTEREST', 'REDDIT', 'DISCORD', 'FAX', 'OTHER') NOT NULL;

-- AlterTable
ALTER TABLE `imaging_study` MODIFY `modality` ENUM('XRAY', 'CT', 'MRI', 'ULTRASOUND', 'PET', 'ECG', 'ECHO', 'ENDO', 'GASTRO', 'OTHER') NOT NULL;

-- AlterTable
ALTER TABLE `notification_delivery` MODIFY `channel` ENUM('EMAIL', 'SMS', 'PUSH', 'WHATSAPP', 'IN_APP', 'TELEGRAM', 'TIKTOK', 'INSTAGRAM', 'FACEBOOK', 'LINKEDIN', 'X', 'YOUTUBE', 'PINTEREST', 'REDDIT', 'DISCORD', 'CALL', 'OTHER') NOT NULL;

-- AlterTable
ALTER TABLE `patient_contact` MODIFY `contact_type` ENUM('PHONE', 'EMAIL', 'WHATSAPP', 'TELEGRAM', 'TIKTOK', 'INSTAGRAM', 'FACEBOOK', 'LINKEDIN', 'X', 'YOUTUBE', 'PINTEREST', 'REDDIT', 'DISCORD', 'FAX', 'OTHER') NOT NULL;

-- AlterTable
ALTER TABLE `payment` MODIFY `method` ENUM('CASH', 'CREDIT_CARD', 'DEBIT_CARD', 'PREPAID_CARD', 'GIFT_CARD', 'VOUCHER', 'BANK_CHECK', 'MOBILE_MONEY', 'BANK_TRANSFER', 'INSURANCE', 'OTHER') NOT NULL;

-- AlterTable
ALTER TABLE `radiology_test` MODIFY `modality` ENUM('XRAY', 'CT', 'MRI', 'ULTRASOUND', 'PET', 'ECG', 'ECHO', 'ENDO', 'GASTRO', 'OTHER') NOT NULL;

-- AlterTable
ALTER TABLE `template` MODIFY `channel` ENUM('EMAIL', 'SMS', 'PUSH', 'WHATSAPP', 'IN_APP', 'TELEGRAM', 'TIKTOK', 'INSTAGRAM', 'FACEBOOK', 'LINKEDIN', 'X', 'YOUTUBE', 'PINTEREST', 'REDDIT', 'DISCORD', 'CALL', 'OTHER') NOT NULL;

-- AlterTable
ALTER TABLE `user_mfa` MODIFY `channel` ENUM('EMAIL', 'SMS', 'PUSH', 'WHATSAPP', 'IN_APP', 'TELEGRAM', 'TIKTOK', 'INSTAGRAM', 'FACEBOOK', 'LINKEDIN', 'X', 'YOUTUBE', 'PINTEREST', 'REDDIT', 'DISCORD', 'CALL', 'OTHER') NOT NULL;

-- AlterTable
ALTER TABLE `ward` MODIFY `ward_type` ENUM('GENERAL', 'ICU', 'MATERNITY', 'PEDIATRIC', 'SURGICAL', 'DIALYSIS', 'ONCOLOGY', 'RADIATION', 'REHABILITATION', 'NURSING', 'PSYCHIATRY', 'PSYCHOLOGY', 'SOCIAL_WORK', 'NUTRITION', 'PHARMACY', 'LABORATORY', 'RADIOLOGY', 'IMAGING', 'ECHOCARDIOGRAPHY', 'ENDOSCOPY', 'ENDOCRINOLOGY', 'GASTROENTEROLOGY', 'NEUROLOGY', 'ORTHOPEDICS', 'PLASTIC_SURGERY', 'PODIATRY', 'RADIATION_ONCOLOGY', 'RHEUMATOLOGY', 'SURGERY', 'UROLOGY', 'VASCULAR_SURGERY', 'VENEREOLOGY', 'PEDIATRICS', 'CARDIOLOGY', 'OTHER') NOT NULL;

-- CreateTable
CREATE TABLE `equipment_category` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `code` VARCHAR(80) NULL,
    `risk_class` VARCHAR(80) NULL,
    `description` TEXT NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `equipment_category_tenant_id_idx`(`tenant_id`),
    INDEX `equipment_category_code_idx`(`code`),
    INDEX `equipment_category_deleted_at_idx`(`deleted_at`),
    UNIQUE INDEX `equipment_category_tenant_id_name_key`(`tenant_id`, `name`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `equipment_registry` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `equipment_category_id` VARCHAR(36) NULL,
    `facility_id` VARCHAR(36) NULL,
    `asset_id` VARCHAR(36) NULL,
    `name` VARCHAR(255) NULL,
    `description` TEXT NULL,
    `equipment_name` VARCHAR(255) NOT NULL,
    `equipment_code` VARCHAR(120) NULL,
    `serial_number` VARCHAR(120) NULL,
    `manufacturer` VARCHAR(255) NULL,
    `model_number` VARCHAR(120) NULL,
    `qr_code` VARCHAR(255) NULL,
    `barcode` VARCHAR(255) NULL,
    `status` VARCHAR(60) NOT NULL,
    `criticality_level` VARCHAR(60) NULL,
    `commissioning_date` DATETIME(3) NULL,
    `purchase_date` DATETIME(3) NULL,
    `usage_hours` INTEGER NOT NULL DEFAULT 0,
    `last_service_at` DATETIME(3) NULL,
    `next_service_due_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `equipment_registry_tenant_id_idx`(`tenant_id`),
    INDEX `equipment_registry_equipment_category_id_idx`(`equipment_category_id`),
    INDEX `equipment_registry_equipment_code_idx`(`equipment_code`),
    INDEX `equipment_registry_serial_number_idx`(`serial_number`),
    INDEX `equipment_registry_status_idx`(`status`),
    INDEX `equipment_registry_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `equipment_location_history` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `equipment_registry_id` VARCHAR(36) NOT NULL,
    `name` VARCHAR(255) NULL,
    `description` TEXT NULL,
    `from_location` VARCHAR(255) NULL,
    `to_location` VARCHAR(255) NOT NULL,
    `moved_by_user_id` VARCHAR(36) NULL,
    `moved_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `reason` VARCHAR(255) NULL,
    `notes` TEXT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `equipment_location_history_tenant_id_idx`(`tenant_id`),
    INDEX `equipment_location_history_equipment_registry_id_idx`(`equipment_registry_id`),
    INDEX `equipment_location_history_moved_by_user_id_idx`(`moved_by_user_id`),
    INDEX `equipment_location_history_moved_at_idx`(`moved_at`),
    INDEX `equipment_location_history_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `equipment_maintenance_plan` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `equipment_registry_id` VARCHAR(36) NOT NULL,
    `name` VARCHAR(255) NULL,
    `description` TEXT NULL,
    `plan_name` VARCHAR(255) NOT NULL,
    `maintenance_type` VARCHAR(60) NOT NULL,
    `status` VARCHAR(60) NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `interval_days` INTEGER NULL,
    `interval_usage_hours` INTEGER NULL,
    `sla_hours` INTEGER NULL,
    `checklist_json` JSON NULL,
    `last_run_at` DATETIME(3) NULL,
    `next_due_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `equipment_maintenance_plan_tenant_id_idx`(`tenant_id`),
    INDEX `equipment_maintenance_plan_equipment_registry_id_idx`(`equipment_registry_id`),
    INDEX `equipment_maintenance_plan_maintenance_type_idx`(`maintenance_type`),
    INDEX `equipment_maintenance_plan_status_idx`(`status`),
    INDEX `equipment_maintenance_plan_is_active_idx`(`is_active`),
    INDEX `equipment_maintenance_plan_next_due_at_idx`(`next_due_at`),
    INDEX `equipment_maintenance_plan_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `equipment_work_order` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `equipment_registry_id` VARCHAR(36) NOT NULL,
    `maintenance_plan_id` VARCHAR(36) NULL,
    `maintenance_request_id` VARCHAR(36) NULL,
    `name` VARCHAR(255) NULL,
    `description` TEXT NULL,
    `title` VARCHAR(255) NOT NULL,
    `priority` VARCHAR(40) NOT NULL,
    `status` VARCHAR(60) NOT NULL,
    `issue_source` VARCHAR(60) NULL,
    `reported_by_user_id` VARCHAR(36) NULL,
    `assigned_engineer_user_id` VARCHAR(36) NULL,
    `opened_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `acknowledged_at` DATETIME(3) NULL,
    `started_at` DATETIME(3) NULL,
    `completed_at` DATETIME(3) NULL,
    `closed_at` DATETIME(3) NULL,
    `resolution_notes` TEXT NULL,
    `downtime_started_at` DATETIME(3) NULL,
    `downtime_ended_at` DATETIME(3) NULL,
    `estimated_cost` DECIMAL(12, 2) NULL,
    `actual_cost` DECIMAL(12, 2) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `equipment_work_order_tenant_id_idx`(`tenant_id`),
    INDEX `equipment_work_order_equipment_registry_id_idx`(`equipment_registry_id`),
    INDEX `equipment_work_order_maintenance_plan_id_idx`(`maintenance_plan_id`),
    INDEX `equipment_work_order_status_idx`(`status`),
    INDEX `equipment_work_order_priority_idx`(`priority`),
    INDEX `equipment_work_order_assigned_engineer_user_id_idx`(`assigned_engineer_user_id`),
    INDEX `equipment_work_order_opened_at_idx`(`opened_at`),
    INDEX `equipment_work_order_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `equipment_calibration_log` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `equipment_registry_id` VARCHAR(36) NOT NULL,
    `equipment_work_order_id` VARCHAR(36) NULL,
    `name` VARCHAR(255) NULL,
    `description` TEXT NULL,
    `calibrated_by_user_id` VARCHAR(36) NULL,
    `calibrated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `result` VARCHAR(40) NOT NULL,
    `certificate_number` VARCHAR(120) NULL,
    `certificate_url` VARCHAR(255) NULL,
    `expires_at` DATETIME(3) NULL,
    `notes` TEXT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `equipment_calibration_log_tenant_id_idx`(`tenant_id`),
    INDEX `equipment_calibration_log_equipment_registry_id_idx`(`equipment_registry_id`),
    INDEX `equipment_calibration_log_equipment_work_order_id_idx`(`equipment_work_order_id`),
    INDEX `equipment_calibration_log_calibrated_by_user_id_idx`(`calibrated_by_user_id`),
    INDEX `equipment_calibration_log_result_idx`(`result`),
    INDEX `equipment_calibration_log_calibrated_at_idx`(`calibrated_at`),
    INDEX `equipment_calibration_log_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `equipment_safety_test_log` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `equipment_registry_id` VARCHAR(36) NOT NULL,
    `equipment_work_order_id` VARCHAR(36) NULL,
    `name` VARCHAR(255) NULL,
    `description` TEXT NULL,
    `tested_by_user_id` VARCHAR(36) NULL,
    `tested_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `test_type` VARCHAR(120) NULL,
    `result` VARCHAR(40) NOT NULL,
    `certificate_url` VARCHAR(255) NULL,
    `expires_at` DATETIME(3) NULL,
    `notes` TEXT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `equipment_safety_test_log_tenant_id_idx`(`tenant_id`),
    INDEX `equipment_safety_test_log_equipment_registry_id_idx`(`equipment_registry_id`),
    INDEX `equipment_safety_test_log_equipment_work_order_id_idx`(`equipment_work_order_id`),
    INDEX `equipment_safety_test_log_tested_by_user_id_idx`(`tested_by_user_id`),
    INDEX `equipment_safety_test_log_result_idx`(`result`),
    INDEX `equipment_safety_test_log_tested_at_idx`(`tested_at`),
    INDEX `equipment_safety_test_log_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `equipment_downtime_log` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `equipment_registry_id` VARCHAR(36) NOT NULL,
    `equipment_work_order_id` VARCHAR(36) NULL,
    `name` VARCHAR(255) NULL,
    `description` TEXT NULL,
    `started_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `ended_at` DATETIME(3) NULL,
    `reason` VARCHAR(255) NULL,
    `impact_level` VARCHAR(60) NULL,
    `is_clinically_critical` BOOLEAN NOT NULL DEFAULT false,
    `notes` TEXT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `equipment_downtime_log_tenant_id_idx`(`tenant_id`),
    INDEX `equipment_downtime_log_equipment_registry_id_idx`(`equipment_registry_id`),
    INDEX `equipment_downtime_log_equipment_work_order_id_idx`(`equipment_work_order_id`),
    INDEX `equipment_downtime_log_started_at_idx`(`started_at`),
    INDEX `equipment_downtime_log_is_clinically_critical_idx`(`is_clinically_critical`),
    INDEX `equipment_downtime_log_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `equipment_spare_part` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `equipment_registry_id` VARCHAR(36) NULL,
    `inventory_item_id` VARCHAR(36) NULL,
    `supplier_id` VARCHAR(36) NULL,
    `name` VARCHAR(255) NULL,
    `description` TEXT NULL,
    `part_name` VARCHAR(255) NOT NULL,
    `part_number` VARCHAR(120) NULL,
    `manufacturer` VARCHAR(255) NULL,
    `quantity_on_hand` INTEGER NOT NULL DEFAULT 0,
    `min_stock_level` INTEGER NOT NULL DEFAULT 0,
    `unit_cost` DECIMAL(12, 2) NULL,
    `expiry_date` DATETIME(3) NULL,
    `notes` TEXT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `equipment_spare_part_tenant_id_idx`(`tenant_id`),
    INDEX `equipment_spare_part_equipment_registry_id_idx`(`equipment_registry_id`),
    INDEX `equipment_spare_part_inventory_item_id_idx`(`inventory_item_id`),
    INDEX `equipment_spare_part_supplier_id_idx`(`supplier_id`),
    INDEX `equipment_spare_part_part_name_idx`(`part_name`),
    INDEX `equipment_spare_part_part_number_idx`(`part_number`),
    INDEX `equipment_spare_part_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `equipment_warranty_contract` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `equipment_registry_id` VARCHAR(36) NOT NULL,
    `supplier_id` VARCHAR(36) NULL,
    `name` VARCHAR(255) NULL,
    `description` TEXT NULL,
    `provider_name` VARCHAR(255) NULL,
    `contract_number` VARCHAR(120) NULL,
    `coverage_details` TEXT NULL,
    `starts_at` DATETIME(3) NOT NULL,
    `expires_at` DATETIME(3) NULL,
    `reminder_days_before` INTEGER NULL,
    `status` VARCHAR(60) NOT NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `notes` TEXT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `equipment_warranty_contract_tenant_id_idx`(`tenant_id`),
    INDEX `equipment_warranty_contract_equipment_registry_id_idx`(`equipment_registry_id`),
    INDEX `equipment_warranty_contract_supplier_id_idx`(`supplier_id`),
    INDEX `equipment_warranty_contract_status_idx`(`status`),
    INDEX `equipment_warranty_contract_is_active_idx`(`is_active`),
    INDEX `equipment_warranty_contract_expires_at_idx`(`expires_at`),
    INDEX `equipment_warranty_contract_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `equipment_service_provider` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `description` TEXT NULL,
    `service_scope` TEXT NULL,
    `contact_name` VARCHAR(255) NULL,
    `contact_email` VARCHAR(255) NULL,
    `contact_phone` VARCHAR(40) NULL,
    `sla_hours` INTEGER NULL,
    `contract_start_date` DATETIME(3) NULL,
    `contract_end_date` DATETIME(3) NULL,
    `status` VARCHAR(60) NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `equipment_service_provider_tenant_id_idx`(`tenant_id`),
    INDEX `equipment_service_provider_status_idx`(`status`),
    INDEX `equipment_service_provider_is_active_idx`(`is_active`),
    INDEX `equipment_service_provider_deleted_at_idx`(`deleted_at`),
    UNIQUE INDEX `equipment_service_provider_tenant_id_name_key`(`tenant_id`, `name`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `equipment_incident_report` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `equipment_registry_id` VARCHAR(36) NULL,
    `equipment_work_order_id` VARCHAR(36) NULL,
    `reported_by_user_id` VARCHAR(36) NULL,
    `name` VARCHAR(255) NULL,
    `title` VARCHAR(255) NOT NULL,
    `description` TEXT NULL,
    `severity` VARCHAR(60) NOT NULL,
    `status` VARCHAR(60) NOT NULL,
    `occurred_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `patient_impact` BOOLEAN NOT NULL DEFAULT false,
    `hazard_level` VARCHAR(60) NULL,
    `resolved_at` DATETIME(3) NULL,
    `root_cause` TEXT NULL,
    `immediate_action` TEXT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `equipment_incident_report_tenant_id_idx`(`tenant_id`),
    INDEX `equipment_incident_report_equipment_registry_id_idx`(`equipment_registry_id`),
    INDEX `equipment_incident_report_equipment_work_order_id_idx`(`equipment_work_order_id`),
    INDEX `equipment_incident_report_reported_by_user_id_idx`(`reported_by_user_id`),
    INDEX `equipment_incident_report_severity_idx`(`severity`),
    INDEX `equipment_incident_report_status_idx`(`status`),
    INDEX `equipment_incident_report_patient_impact_idx`(`patient_impact`),
    INDEX `equipment_incident_report_occurred_at_idx`(`occurred_at`),
    INDEX `equipment_incident_report_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `equipment_recall_notice` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `equipment_registry_id` VARCHAR(36) NULL,
    `equipment_service_provider_id` VARCHAR(36) NULL,
    `name` VARCHAR(255) NULL,
    `title` VARCHAR(255) NOT NULL,
    `description` TEXT NULL,
    `recall_reference` VARCHAR(120) NOT NULL,
    `severity` VARCHAR(60) NOT NULL,
    `status` VARCHAR(60) NOT NULL,
    `issued_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `due_by` DATETIME(3) NULL,
    `resolved_at` DATETIME(3) NULL,
    `action_taken` TEXT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `equipment_recall_notice_tenant_id_idx`(`tenant_id`),
    INDEX `equipment_recall_notice_equipment_registry_id_idx`(`equipment_registry_id`),
    INDEX `equipment_recall_notice_equipment_service_provider_id_idx`(`equipment_service_provider_id`),
    INDEX `equipment_recall_notice_severity_idx`(`severity`),
    INDEX `equipment_recall_notice_status_idx`(`status`),
    INDEX `equipment_recall_notice_issued_at_idx`(`issued_at`),
    INDEX `equipment_recall_notice_deleted_at_idx`(`deleted_at`),
    UNIQUE INDEX `equipment_recall_notice_tenant_id_recall_reference_key`(`tenant_id`, `recall_reference`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `equipment_utilization_snapshot` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `equipment_registry_id` VARCHAR(36) NOT NULL,
    `name` VARCHAR(255) NULL,
    `description` TEXT NULL,
    `captured_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `usage_hours` DECIMAL(10, 2) NULL,
    `procedure_count` INTEGER NOT NULL DEFAULT 0,
    `uptime_minutes` INTEGER NOT NULL DEFAULT 0,
    `downtime_minutes` INTEGER NOT NULL DEFAULT 0,
    `mttr_minutes` INTEGER NULL,
    `mtbf_minutes` INTEGER NULL,
    `availability_percentage` DECIMAL(5, 2) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `equipment_utilization_snapshot_tenant_id_idx`(`tenant_id`),
    INDEX `equipment_utilization_snapshot_equipment_registry_id_idx`(`equipment_registry_id`),
    INDEX `equipment_utilization_snapshot_captured_at_idx`(`captured_at`),
    INDEX `equipment_utilization_snapshot_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `equipment_disposal_transfer` (
    `id` VARCHAR(36) NOT NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `equipment_registry_id` VARCHAR(36) NOT NULL,
    `name` VARCHAR(255) NULL,
    `description` TEXT NULL,
    `action_type` VARCHAR(60) NOT NULL,
    `status` VARCHAR(60) NOT NULL,
    `to_facility_id` VARCHAR(36) NULL,
    `to_organization` VARCHAR(255) NULL,
    `reason` TEXT NULL,
    `approved_by_user_id` VARCHAR(36) NULL,
    `approved_at` DATETIME(3) NULL,
    `disposed_or_transferred_at` DATETIME(3) NULL,
    `certificate_url` VARCHAR(255) NULL,
    `notes` TEXT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `equipment_disposal_transfer_tenant_id_idx`(`tenant_id`),
    INDEX `equipment_disposal_transfer_equipment_registry_id_idx`(`equipment_registry_id`),
    INDEX `equipment_disposal_transfer_action_type_idx`(`action_type`),
    INDEX `equipment_disposal_transfer_status_idx`(`status`),
    INDEX `equipment_disposal_transfer_to_facility_id_idx`(`to_facility_id`),
    INDEX `equipment_disposal_transfer_approved_by_user_id_idx`(`approved_by_user_id`),
    INDEX `equipment_disposal_transfer_deleted_at_idx`(`deleted_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `equipment_category` ADD CONSTRAINT `equipment_category_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_registry` ADD CONSTRAINT `equipment_registry_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_registry` ADD CONSTRAINT `equipment_registry_equipment_category_id_fkey` FOREIGN KEY (`equipment_category_id`) REFERENCES `equipment_category`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_location_history` ADD CONSTRAINT `equipment_location_history_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_location_history` ADD CONSTRAINT `equipment_location_history_equipment_registry_id_fkey` FOREIGN KEY (`equipment_registry_id`) REFERENCES `equipment_registry`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_maintenance_plan` ADD CONSTRAINT `equipment_maintenance_plan_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_maintenance_plan` ADD CONSTRAINT `equipment_maintenance_plan_equipment_registry_id_fkey` FOREIGN KEY (`equipment_registry_id`) REFERENCES `equipment_registry`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_work_order` ADD CONSTRAINT `equipment_work_order_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_work_order` ADD CONSTRAINT `equipment_work_order_equipment_registry_id_fkey` FOREIGN KEY (`equipment_registry_id`) REFERENCES `equipment_registry`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_work_order` ADD CONSTRAINT `equipment_work_order_maintenance_plan_id_fkey` FOREIGN KEY (`maintenance_plan_id`) REFERENCES `equipment_maintenance_plan`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_calibration_log` ADD CONSTRAINT `equipment_calibration_log_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_calibration_log` ADD CONSTRAINT `equipment_calibration_log_equipment_registry_id_fkey` FOREIGN KEY (`equipment_registry_id`) REFERENCES `equipment_registry`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_calibration_log` ADD CONSTRAINT `equipment_calibration_log_equipment_work_order_id_fkey` FOREIGN KEY (`equipment_work_order_id`) REFERENCES `equipment_work_order`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_safety_test_log` ADD CONSTRAINT `equipment_safety_test_log_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_safety_test_log` ADD CONSTRAINT `equipment_safety_test_log_equipment_registry_id_fkey` FOREIGN KEY (`equipment_registry_id`) REFERENCES `equipment_registry`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_safety_test_log` ADD CONSTRAINT `equipment_safety_test_log_equipment_work_order_id_fkey` FOREIGN KEY (`equipment_work_order_id`) REFERENCES `equipment_work_order`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_downtime_log` ADD CONSTRAINT `equipment_downtime_log_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_downtime_log` ADD CONSTRAINT `equipment_downtime_log_equipment_registry_id_fkey` FOREIGN KEY (`equipment_registry_id`) REFERENCES `equipment_registry`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_downtime_log` ADD CONSTRAINT `equipment_downtime_log_equipment_work_order_id_fkey` FOREIGN KEY (`equipment_work_order_id`) REFERENCES `equipment_work_order`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_spare_part` ADD CONSTRAINT `equipment_spare_part_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_spare_part` ADD CONSTRAINT `equipment_spare_part_equipment_registry_id_fkey` FOREIGN KEY (`equipment_registry_id`) REFERENCES `equipment_registry`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_warranty_contract` ADD CONSTRAINT `equipment_warranty_contract_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_warranty_contract` ADD CONSTRAINT `equipment_warranty_contract_equipment_registry_id_fkey` FOREIGN KEY (`equipment_registry_id`) REFERENCES `equipment_registry`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_service_provider` ADD CONSTRAINT `equipment_service_provider_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_incident_report` ADD CONSTRAINT `equipment_incident_report_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_incident_report` ADD CONSTRAINT `equipment_incident_report_equipment_registry_id_fkey` FOREIGN KEY (`equipment_registry_id`) REFERENCES `equipment_registry`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_incident_report` ADD CONSTRAINT `equipment_incident_report_equipment_work_order_id_fkey` FOREIGN KEY (`equipment_work_order_id`) REFERENCES `equipment_work_order`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_recall_notice` ADD CONSTRAINT `equipment_recall_notice_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_recall_notice` ADD CONSTRAINT `equipment_recall_notice_equipment_registry_id_fkey` FOREIGN KEY (`equipment_registry_id`) REFERENCES `equipment_registry`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_recall_notice` ADD CONSTRAINT `equipment_recall_notice_equipment_service_provider_id_fkey` FOREIGN KEY (`equipment_service_provider_id`) REFERENCES `equipment_service_provider`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_utilization_snapshot` ADD CONSTRAINT `equipment_utilization_snapshot_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_utilization_snapshot` ADD CONSTRAINT `equipment_utilization_snapshot_equipment_registry_id_fkey` FOREIGN KEY (`equipment_registry_id`) REFERENCES `equipment_registry`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_disposal_transfer` ADD CONSTRAINT `equipment_disposal_transfer_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `equipment_disposal_transfer` ADD CONSTRAINT `equipment_disposal_transfer_equipment_registry_id_fkey` FOREIGN KEY (`equipment_registry_id`) REFERENCES `equipment_registry`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
