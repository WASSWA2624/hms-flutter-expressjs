-- Sync the migration history with prisma/schema.prisma.
--
-- The datamodel had drifted: several tables, columns, indexes and foreign keys
-- existed only in schema.prisma. Generated with:
--   prisma migrate diff --from-migrations prisma/migrations --to-schema prisma/schema.prisma --script
-- ENGINE=InnoDB is pinned explicitly because the production host defaults to
-- MyISAM, which silently ignores foreign key definitions.

-- DropForeignKey
ALTER TABLE `appointment` DROP FOREIGN KEY `appointment_patient_id_fkey`;

-- DropForeignKey
ALTER TABLE `coverage_plan` DROP FOREIGN KEY `coverage_plan_insurance_company_id_fkey`;

-- DropForeignKey
ALTER TABLE `facility_lab_panel_offering` DROP FOREIGN KEY `flpo_facility_fkey`;

-- DropForeignKey
ALTER TABLE `facility_lab_panel_offering` DROP FOREIGN KEY `flpo_lab_panel_fkey`;

-- DropForeignKey
ALTER TABLE `facility_lab_panel_offering` DROP FOREIGN KEY `flpo_tenant_fkey`;

-- DropForeignKey
ALTER TABLE `facility_lab_test_offering` DROP FOREIGN KEY `flto_facility_fkey`;

-- DropForeignKey
ALTER TABLE `facility_lab_test_offering` DROP FOREIGN KEY `flto_lab_test_fkey`;

-- DropForeignKey
ALTER TABLE `facility_lab_test_offering` DROP FOREIGN KEY `flto_tenant_fkey`;

-- DropForeignKey
ALTER TABLE `facility_lab_test_reference_range` DROP FOREIGN KEY `fltr_offering_fkey`;

-- DropForeignKey
ALTER TABLE `facility_lab_test_result_option` DROP FOREIGN KEY `fltro_offering_fkey`;

-- DropForeignKey
ALTER TABLE `facility_lab_test_unit_option` DROP FOREIGN KEY `fltu_offering_fkey`;

-- DropForeignKey
ALTER TABLE `facility_pharmacy_offering` DROP FOREIGN KEY `fpo_drug_fkey`;

-- DropForeignKey
ALTER TABLE `facility_pharmacy_offering` DROP FOREIGN KEY `fpo_facility_fkey`;

-- DropForeignKey
ALTER TABLE `facility_pharmacy_offering` DROP FOREIGN KEY `fpo_tenant_fkey`;

-- DropForeignKey
ALTER TABLE `facility_radiology_procedure_offering` DROP FOREIGN KEY `frpo_radiology_procedure_fkey`;

-- DropForeignKey
ALTER TABLE `facility_radiology_procedure_offering` DROP FOREIGN KEY `frto_facility_fkey`;

-- DropForeignKey
ALTER TABLE `facility_radiology_procedure_offering` DROP FOREIGN KEY `frto_tenant_fkey`;

-- DropForeignKey
ALTER TABLE `pharmacy_order` DROP FOREIGN KEY `pharmacy_order_patient_id_fkey`;

-- DropForeignKey
ALTER TABLE `radiology_procedure` DROP FOREIGN KEY `radiology_test_tenant_id_fkey`;

-- DropForeignKey
ALTER TABLE `report_run` DROP FOREIGN KEY `report_run_run_by_user_id_fkey`;

-- DropForeignKey
ALTER TABLE `role` DROP FOREIGN KEY `role_tenant_id_fkey`;

-- DropIndex
DROP INDEX `conversation_participant_is_favorite_idx` ON `conversation_participant`;

-- DropIndex
DROP INDEX `conversation_participant_is_flagged_idx` ON `conversation_participant`;

-- DropIndex
DROP INDEX `radiology_order_priority_idx` ON `radiology_order`;

-- DropIndex
DROP INDEX `report_run_run_by_user_id_idx` ON `report_run`;

-- AlterTable
ALTER TABLE `abac_policy` MODIFY `subject_conditions_json` JSON NULL,
    MODIFY `object_conditions_json` JSON NULL,
    MODIFY `environment_conditions_json` JSON NULL;

-- AlterTable
ALTER TABLE `admission` MODIFY `billing_snapshot` JSON NULL;

-- AlterTable
ALTER TABLE `analytics_event` ADD COLUMN `entity_public_id` VARCHAR(64) NULL,
    ADD COLUMN `entity_type` VARCHAR(80) NULL,
    ADD COLUMN `event_category` VARCHAR(80) NOT NULL,
    ADD COLUMN `facility_id` VARCHAR(36) NULL,
    ADD COLUMN `severity` VARCHAR(40) NOT NULL,
    MODIFY `payload_json` JSON NULL;

-- AlterTable
ALTER TABLE `anesthesia_record` ADD COLUMN `finalized_at` DATETIME(3) NULL,
    ADD COLUMN `finalized_by_user_id` VARCHAR(36) NULL,
    ADD COLUMN `record_status` ENUM('DRAFT', 'FINAL') NOT NULL DEFAULT 'DRAFT',
    ADD COLUMN `reopen_reason` TEXT NULL,
    ADD COLUMN `reopened_at` DATETIME(3) NULL,
    ADD COLUMN `reopened_by_user_id` VARCHAR(36) NULL;

-- AlterTable
ALTER TABLE `audit_log` MODIFY `diff_json` JSON NULL;

-- AlterTable
ALTER TABLE `break_glass_access` MODIFY `justification_json` JSON NULL,
    MODIFY `requested_scope_json` JSON NULL;

-- AlterTable
ALTER TABLE `closeout_pack` MODIFY `summary_json` JSON NULL,
    MODIFY `parameter_overrides_json` JSON NULL;

-- AlterTable
ALTER TABLE `configuration_snapshot` MODIFY `snapshot_json` JSON NOT NULL;

-- AlterTable
ALTER TABLE `custody_snapshot` MODIFY `asset_snapshot_json` JSON NULL,
    MODIFY `cash_drawer_snapshot_json` JSON NULL,
    MODIFY `controlled_items_json` JSON NULL;

-- AlterTable
ALTER TABLE `dashboard_widget` ADD COLUMN `is_pinned` BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN `placement` VARCHAR(120) NULL,
    ADD COLUMN `report_definition_id` VARCHAR(36) NULL,
    ADD COLUMN `role_scope_json` JSON NULL,
    ADD COLUMN `sort_order` INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN `widget_type` VARCHAR(40) NOT NULL,
    MODIFY `config_json` JSON NOT NULL;

-- AlterTable
ALTER TABLE `day_close` MODIFY `checklist_json` JSON NULL,
    MODIFY `blockers_json` JSON NULL,
    MODIFY `unresolved_items_json` JSON NULL,
    MODIFY `evidence_json` JSON NULL;

-- AlterTable
ALTER TABLE `discharge_summary` MODIFY `clearance_snapshot` JSON NULL;

-- AlterTable
ALTER TABLE `emergency_case` MODIFY `extension_json` JSON NULL;

-- AlterTable
ALTER TABLE `encounter` MODIFY `extension_json` JSON NULL;

-- AlterTable
ALTER TABLE `equipment_maintenance_plan` MODIFY `checklist_json` JSON NULL;

-- AlterTable
ALTER TABLE `facility` MODIFY `extension_json` JSON NULL;

-- AlterTable
ALTER TABLE `facility_lab_test_result_option` MODIFY `aliases_json` JSON NULL,
    MODIFY `status` ENUM('NORMAL', 'ABNORMAL', 'CRITICAL', 'PENDING') NOT NULL DEFAULT 'ABNORMAL';

-- AlterTable
ALTER TABLE `handover` MODIFY `items_json` JSON NULL;

-- AlterTable
ALTER TABLE `insurance_company` MODIFY `contact_json` JSON NULL;

-- AlterTable
ALTER TABLE `insurer_integration` MODIFY `config_json` JSON NULL;

-- AlterTable
ALTER TABLE `integration` MODIFY `config_json` JSON NULL;

-- AlterTable
ALTER TABLE `invoice_item` MODIFY `price_source` VARCHAR(20) NULL;

-- AlterTable
ALTER TABLE `kpi_snapshot` ADD COLUMN `facility_id` VARCHAR(36) NULL,
    ADD COLUMN `metric_group` VARCHAR(80) NOT NULL,
    ADD COLUMN `metric_key` VARCHAR(80) NOT NULL,
    ADD COLUMN `threshold_state` VARCHAR(40) NOT NULL;

-- AlterTable
ALTER TABLE `lab_order` MODIFY `billing_snapshot` JSON NULL;

-- AlterTable
ALTER TABLE `lab_result` MODIFY `applied_reference_range_json` JSON NULL;

-- AlterTable
ALTER TABLE `lab_test_result_option` MODIFY `aliases_json` JSON NULL;

-- AlterTable
ALTER TABLE `lab_test_unit_option` MODIFY `is_default` BOOLEAN NOT NULL DEFAULT false;

-- AlterTable
ALTER TABLE `license` MODIFY `entitlement_snapshot_json` JSON NULL,
    MODIFY `extension_json` JSON NULL;

-- AlterTable
ALTER TABLE `medication_administration` MODIFY `route` ENUM('ORAL', 'IV', 'IM', 'SC', 'SUBLINGUAL', 'RECTAL', 'VAGINAL', 'TOPICAL', 'INHALATION', 'OPHTHALMIC', 'OTIC', 'NASAL', 'INTRADERMAL', 'OTHER') NOT NULL;

-- AlterTable
ALTER TABLE `module` MODIFY `entitlement_policy_json` JSON NULL,
    MODIFY `extension_json` JSON NULL;

-- AlterTable
ALTER TABLE `module_subscription` MODIFY `extension_json` JSON NULL;

-- AlterTable
ALTER TABLE `mortuary_case` MODIFY `extension_json` JSON NULL;

-- AlterTable
ALTER TABLE `mortuary_custody_event` MODIFY `evidence_json` JSON NULL;

-- AlterTable
ALTER TABLE `mortuary_deceased_profile` MODIFY `extension_json` JSON NULL;

-- AlterTable
ALTER TABLE `notification` ADD COLUMN `context_public_id` VARCHAR(64) NULL,
    ADD COLUMN `context_type` VARCHAR(80) NULL,
    ADD COLUMN `target_path` VARCHAR(255) NULL,
    ADD COLUMN `template_id` VARCHAR(36) NULL;

-- AlterTable
ALTER TABLE `notification_delivery` ADD COLUMN `attempt_count` INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN `delivered_at` DATETIME(3) NULL,
    ADD COLUMN `error_message` TEXT NULL,
    ADD COLUMN `failed_at` DATETIME(3) NULL,
    ADD COLUMN `last_attempt_at` DATETIME(3) NULL,
    ADD COLUMN `provider_name` VARCHAR(120) NULL,
    ADD COLUMN `recipient_target` VARCHAR(255) NULL,
    ADD COLUMN `retryable` BOOLEAN NOT NULL DEFAULT false,
    MODIFY `status` ENUM('QUEUED', 'SENDING', 'SENT', 'DELIVERED', 'FAILED', 'READ') NOT NULL DEFAULT 'QUEUED';

-- AlterTable
ALTER TABLE `nursing_note` MODIFY `billing_snapshot` JSON NULL;

-- AlterTable
ALTER TABLE `office_context` MODIFY `metadata_json` JSON NULL;

-- AlterTable
ALTER TABLE `patient` MODIFY `extension_json` JSON NULL;

-- AlterTable
ALTER TABLE `patient_insurance_enrollment` MODIFY `extension_json` JSON NULL;

-- AlterTable
ALTER TABLE `patient_report_job` MODIFY `sections_json` JSON NOT NULL,
    MODIFY `period_json` JSON NULL;

-- AlterTable
ALTER TABLE `payroll_item` MODIFY `calculation_json` JSON NULL;

-- AlterTable
ALTER TABLE `payroll_run` MODIFY `preview_json` JSON NULL,
    MODIFY `audit_trail_json` JSON NULL;

-- AlterTable
ALTER TABLE `pharmacy_order` MODIFY `billing_snapshot` JSON NULL;

-- AlterTable
ALTER TABLE `pharmacy_order_item` DROP COLUMN `duration`;

-- AlterTable
ALTER TABLE `post_op_note` ADD COLUMN `finalized_at` DATETIME(3) NULL,
    ADD COLUMN `finalized_by_user_id` VARCHAR(36) NULL,
    ADD COLUMN `record_status` ENUM('DRAFT', 'FINAL') NOT NULL DEFAULT 'DRAFT',
    ADD COLUMN `reopen_reason` TEXT NULL,
    ADD COLUMN `reopened_at` DATETIME(3) NULL,
    ADD COLUMN `reopened_by_user_id` VARCHAR(36) NULL;

-- AlterTable
ALTER TABLE `pricing_rule` MODIFY `extension_json` JSON NULL;

-- AlterTable
ALTER TABLE `procedure` MODIFY `billing_snapshot` JSON NULL;

-- AlterTable
ALTER TABLE `radiology_order` DROP COLUMN `body_region`,
    DROP COLUMN `clinical_indication`,
    DROP COLUMN `contrast_preference`,
    DROP COLUMN `custom_request_details`,
    DROP COLUMN `laterality`,
    DROP COLUMN `priority`,
    DROP COLUMN `request_kind`,
    DROP COLUMN `request_notes`,
    MODIFY `request_details` JSON NULL;

-- AlterTable
ALTER TABLE `registration_follow_up` MODIFY `follow_up_metadata` JSON NULL;

-- AlterTable
ALTER TABLE `report_definition` DROP COLUMN `query`,
    ADD COLUMN `category` VARCHAR(80) NOT NULL,
    ADD COLUMN `dataset_key` VARCHAR(80) NOT NULL,
    ADD COLUMN `default_format` VARCHAR(20) NOT NULL,
    ADD COLUMN `definition_json` JSON NOT NULL,
    ADD COLUMN `facility_id` VARCHAR(36) NULL,
    ADD COLUMN `parameter_schema_json` JSON NULL,
    ADD COLUMN `status` VARCHAR(40) NOT NULL;

-- AlterTable
ALTER TABLE `report_run` DROP COLUMN `run_by_user_id`,
    ADD COLUMN `error_message` TEXT NULL,
    ADD COLUMN `expires_at` DATETIME(3) NULL,
    ADD COLUMN `facility_id` VARCHAR(36) NULL,
    ADD COLUMN `format` VARCHAR(20) NOT NULL,
    ADD COLUMN `output_file_name` VARCHAR(255) NULL,
    ADD COLUMN `output_mime_type` VARCHAR(120) NULL,
    ADD COLUMN `output_size_bytes` INTEGER NULL,
    ADD COLUMN `output_storage_path` VARCHAR(512) NULL,
    ADD COLUMN `parameters_json` JSON NULL,
    ADD COLUMN `queued_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    ADD COLUMN `requested_by_user_id` VARCHAR(36) NULL,
    ADD COLUMN `schedule_id` VARCHAR(36) NULL,
    ADD COLUMN `trigger_type` VARCHAR(40) NOT NULL,
    MODIFY `started_at` DATETIME(3) NULL;

-- AlterTable
ALTER TABLE `roster` MODIFY `constraints` JSON NULL;

-- AlterTable
ALTER TABLE `shift_close` MODIFY `totals_json` JSON NULL,
    MODIFY `reconciliation_json` JSON NULL,
    MODIFY `evidence_json` JSON NULL;

-- AlterTable
ALTER TABLE `shift_template` MODIFY `weekly_schedule_json` JSON NULL;

-- AlterTable
ALTER TABLE `staff_availability` MODIFY `time_slots_json` JSON NULL;

-- AlterTable
ALTER TABLE `staff_compensation` MODIFY `metadata_json` JSON NULL;

-- AlterTable
ALTER TABLE `subscription` MODIFY `entitlement_snapshot_json` JSON NULL,
    MODIFY `extension_json` JSON NULL;

-- AlterTable
ALTER TABLE `subscription_plan` MODIFY `add_on_eligibility_json` JSON NULL,
    MODIFY `extension_json` JSON NULL,
    MODIFY `limit_policy_json` JSON NULL;

-- AlterTable
ALTER TABLE `tenant` MODIFY `extension_json` JSON NULL;

-- AlterTable
ALTER TABLE `theatre_case` ADD COLUMN `anesthetist_user_id` VARCHAR(36) NULL,
    ADD COLUMN `cancelled_at` DATETIME(3) NULL,
    ADD COLUMN `completed_at` DATETIME(3) NULL,
    ADD COLUMN `room_id` VARCHAR(36) NULL,
    ADD COLUMN `stage_notes` TEXT NULL,
    ADD COLUMN `started_at` DATETIME(3) NULL,
    ADD COLUMN `surgeon_user_id` VARCHAR(36) NULL,
    ADD COLUMN `workflow_stage` VARCHAR(80) NULL,
    MODIFY `status` ENUM('SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED') NOT NULL,
    MODIFY `billing_snapshot` JSON NULL;

-- AlterTable
ALTER TABLE `therapy_episode` MODIFY `billing_snapshot` JSON NULL,
    MODIFY `extension_json` JSON NULL;

-- AlterTable
ALTER TABLE `therapy_session` MODIFY `billing_snapshot` JSON NULL;

-- AlterTable
ALTER TABLE `ward_round` MODIFY `billing_snapshot` JSON NULL;

-- CreateTable
CREATE TABLE `theatre_case_resource_allocation` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `theatre_case_id` VARCHAR(36) NOT NULL,
    `resource_type` ENUM('ROOM', 'STAFF', 'EQUIPMENT') NOT NULL,
    `resource_id` VARCHAR(36) NOT NULL,
    `assigned_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `released_at` DATETIME(3) NULL,
    `assigned_by_user_id` VARCHAR(36) NULL,
    `released_by_user_id` VARCHAR(36) NULL,
    `notes` TEXT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `theatre_case_resource_allocation_theatre_case_id_idx`(`theatre_case_id`),
    INDEX `theatre_case_resource_allocation_resource_type_idx`(`resource_type`),
    INDEX `theatre_case_resource_allocation_resource_id_idx`(`resource_id`),
    INDEX `theatre_case_resource_allocation_assigned_at_idx`(`assigned_at`),
    INDEX `theatre_case_resource_allocation_released_at_idx`(`released_at`),
    INDEX `theatre_case_resource_allocation_deleted_at_idx`(`deleted_at`),
    INDEX `theatre_case_resource_allocation_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB;

-- CreateTable
CREATE TABLE `theatre_case_checklist_item` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `theatre_case_id` VARCHAR(36) NOT NULL,
    `phase` ENUM('PRE_OP', 'SIGN_IN', 'TIME_OUT', 'SIGN_OUT', 'PACU_HANDOFF') NOT NULL,
    `item_code` VARCHAR(120) NOT NULL,
    `item_label` VARCHAR(255) NOT NULL,
    `is_checked` BOOLEAN NOT NULL DEFAULT false,
    `checked_at` DATETIME(3) NULL,
    `checked_by_user_id` VARCHAR(36) NULL,
    `notes` TEXT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `theatre_case_checklist_item_theatre_case_id_idx`(`theatre_case_id`),
    INDEX `theatre_case_checklist_item_phase_idx`(`phase`),
    INDEX `theatre_case_checklist_item_is_checked_idx`(`is_checked`),
    INDEX `theatre_case_checklist_item_checked_at_idx`(`checked_at`),
    INDEX `theatre_case_checklist_item_deleted_at_idx`(`deleted_at`),
    INDEX `theatre_case_checklist_item_human_friendly_id_idx`(`human_friendly_id`),
    UNIQUE INDEX `theatre_case_checklist_item_theatre_case_id_phase_item_code_key`(`theatre_case_id`, `phase`, `item_code`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB;

-- CreateTable
CREATE TABLE `anesthesia_observation` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `theatre_case_id` VARCHAR(36) NOT NULL,
    `observed_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `observation_type` VARCHAR(80) NULL,
    `metric_key` VARCHAR(80) NULL,
    `metric_value` VARCHAR(120) NULL,
    `unit` VARCHAR(40) NULL,
    `notes` TEXT NULL,
    `observed_by_user_id` VARCHAR(36) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `anesthesia_observation_theatre_case_id_idx`(`theatre_case_id`),
    INDEX `anesthesia_observation_observed_at_idx`(`observed_at`),
    INDEX `anesthesia_observation_observation_type_idx`(`observation_type`),
    INDEX `anesthesia_observation_metric_key_idx`(`metric_key`),
    INDEX `anesthesia_observation_deleted_at_idx`(`deleted_at`),
    INDEX `anesthesia_observation_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB;

-- CreateTable
CREATE TABLE `billing_approval` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `approval_type` ENUM('REFUND', 'VOID', 'ADJUSTMENT') NOT NULL,
    `target_entity` VARCHAR(80) NOT NULL,
    `target_entity_id` VARCHAR(36) NOT NULL,
    `requested_by_user_id` VARCHAR(36) NOT NULL,
    `approved_by_user_id` VARCHAR(36) NULL,
    `status` ENUM('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED') NOT NULL DEFAULT 'PENDING',
    `reason` VARCHAR(255) NULL,
    `payload_json` JSON NULL,
    `decision_notes` TEXT NULL,
    `requested_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `decided_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `billing_approval_tenant_id_idx`(`tenant_id`),
    INDEX `billing_approval_facility_id_idx`(`facility_id`),
    INDEX `billing_approval_approval_type_idx`(`approval_type`),
    INDEX `billing_approval_target_entity_target_entity_id_idx`(`target_entity`, `target_entity_id`),
    INDEX `billing_approval_requested_by_user_id_idx`(`requested_by_user_id`),
    INDEX `billing_approval_approved_by_user_id_idx`(`approved_by_user_id`),
    INDEX `billing_approval_status_idx`(`status`),
    INDEX `billing_approval_requested_at_idx`(`requested_at`),
    INDEX `billing_approval_decided_at_idx`(`decided_at`),
    INDEX `billing_approval_deleted_at_idx`(`deleted_at`),
    INDEX `billing_approval_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB;

-- CreateTable
CREATE TABLE `report_schedule` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `report_definition_id` VARCHAR(36) NOT NULL,
    `created_by` VARCHAR(36) NULL,
    `name` VARCHAR(255) NOT NULL,
    `status` VARCHAR(40) NOT NULL,
    `frequency` VARCHAR(40) NOT NULL,
    `time_of_day` VARCHAR(5) NULL,
    `day_of_week` INTEGER NULL,
    `day_of_month` INTEGER NULL,
    `timezone` VARCHAR(80) NOT NULL,
    `format` VARCHAR(20) NOT NULL,
    `parameter_overrides_json` JSON NULL,
    `next_run_at` DATETIME(3) NULL,
    `last_run_at` DATETIME(3) NULL,
    `retention_days` INTEGER NOT NULL DEFAULT 30,
    `locked_at` DATETIME(3) NULL,
    `locked_by` VARCHAR(120) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `report_schedule_tenant_id_idx`(`tenant_id`),
    INDEX `report_schedule_facility_id_idx`(`facility_id`),
    INDEX `report_schedule_report_definition_id_idx`(`report_definition_id`),
    INDEX `report_schedule_created_by_idx`(`created_by`),
    INDEX `report_schedule_status_idx`(`status`),
    INDEX `report_schedule_frequency_idx`(`frequency`),
    INDEX `report_schedule_next_run_at_idx`(`next_run_at`),
    INDEX `report_schedule_locked_at_idx`(`locked_at`),
    INDEX `report_schedule_deleted_at_idx`(`deleted_at`),
    INDEX `report_schedule_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB;

-- CreateTable
CREATE TABLE `unit_management_assignment` (
    `id` VARCHAR(36) NOT NULL,
    `human_friendly_id` VARCHAR(32) NULL,
    `tenant_id` VARCHAR(36) NOT NULL,
    `facility_id` VARCHAR(36) NULL,
    `department_id` VARCHAR(36) NULL,
    `unit_id` VARCHAR(36) NULL,
    `ward_id` VARCHAR(36) NULL,
    `user_id` VARCHAR(36) NOT NULL,
    `staff_profile_id` VARCHAR(36) NULL,
    `role_name` VARCHAR(80) NOT NULL,
    `start_date` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `end_date` DATETIME(3) NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,
    `deleted_at` DATETIME(3) NULL,
    `version` INTEGER NOT NULL DEFAULT 1,

    INDEX `unit_management_assignment_tenant_id_idx`(`tenant_id`),
    INDEX `unit_management_assignment_facility_id_idx`(`facility_id`),
    INDEX `unit_management_assignment_department_id_idx`(`department_id`),
    INDEX `unit_management_assignment_unit_id_idx`(`unit_id`),
    INDEX `unit_management_assignment_ward_id_idx`(`ward_id`),
    INDEX `unit_management_assignment_user_id_idx`(`user_id`),
    INDEX `unit_management_assignment_staff_profile_id_idx`(`staff_profile_id`),
    INDEX `unit_management_assignment_role_name_idx`(`role_name`),
    INDEX `unit_management_assignment_is_active_idx`(`is_active`),
    INDEX `unit_management_assignment_start_date_idx`(`start_date`),
    INDEX `unit_management_assignment_deleted_at_idx`(`deleted_at`),
    INDEX `unit_management_assignment_human_friendly_id_idx`(`human_friendly_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE=InnoDB;

-- CreateIndex
CREATE INDEX `analytics_event_facility_id_idx` ON `analytics_event`(`facility_id`);

-- CreateIndex
CREATE INDEX `analytics_event_event_category_idx` ON `analytics_event`(`event_category`);

-- CreateIndex
CREATE INDEX `analytics_event_entity_type_idx` ON `analytics_event`(`entity_type`);

-- CreateIndex
CREATE INDEX `analytics_event_entity_public_id_idx` ON `analytics_event`(`entity_public_id`);

-- CreateIndex
CREATE INDEX `analytics_event_severity_idx` ON `analytics_event`(`severity`);

-- CreateIndex
CREATE INDEX `anesthesia_record_record_status_idx` ON `anesthesia_record`(`record_status`);

-- CreateIndex
CREATE INDEX `anesthesia_record_finalized_at_idx` ON `anesthesia_record`(`finalized_at`);

-- CreateIndex
CREATE INDEX `dashboard_widget_report_definition_id_idx` ON `dashboard_widget`(`report_definition_id`);

-- CreateIndex
CREATE INDEX `dashboard_widget_widget_type_idx` ON `dashboard_widget`(`widget_type`);

-- CreateIndex
CREATE INDEX `dashboard_widget_placement_idx` ON `dashboard_widget`(`placement`);

-- CreateIndex
CREATE INDEX `dashboard_widget_sort_order_idx` ON `dashboard_widget`(`sort_order`);

-- CreateIndex
CREATE INDEX `dashboard_widget_is_pinned_idx` ON `dashboard_widget`(`is_pinned`);

-- CreateIndex
CREATE INDEX `day_close_billing_entity_idx` ON `day_close`(`billing_entity`);

-- CreateIndex
CREATE INDEX `invoice_billing_entity_idx` ON `invoice`(`billing_entity`);

-- CreateIndex
CREATE INDEX `invoice_item_catalog_type_catalog_item_id_idx` ON `invoice_item`(`catalog_type`, `catalog_item_id`);

-- CreateIndex
CREATE INDEX `kpi_snapshot_facility_id_idx` ON `kpi_snapshot`(`facility_id`);

-- CreateIndex
CREATE INDEX `kpi_snapshot_metric_key_idx` ON `kpi_snapshot`(`metric_key`);

-- CreateIndex
CREATE INDEX `kpi_snapshot_metric_group_idx` ON `kpi_snapshot`(`metric_group`);

-- CreateIndex
CREATE INDEX `kpi_snapshot_threshold_state_idx` ON `kpi_snapshot`(`threshold_state`);

-- CreateIndex
CREATE INDEX `notification_template_id_idx` ON `notification`(`template_id`);

-- CreateIndex
CREATE INDEX `notification_delivery_status_idx` ON `notification_delivery`(`status`);

-- CreateIndex
CREATE INDEX `payment_billing_entity_idx` ON `payment`(`billing_entity`);

-- CreateIndex
CREATE INDEX `post_op_note_record_status_idx` ON `post_op_note`(`record_status`);

-- CreateIndex
CREATE INDEX `post_op_note_finalized_at_idx` ON `post_op_note`(`finalized_at`);

-- CreateIndex
CREATE INDEX `price_book_entry_tenant_id_idx` ON `price_book_entry`(`tenant_id`);

-- CreateIndex
CREATE INDEX `price_book_entry_catalog_type_catalog_item_id_idx` ON `price_book_entry`(`catalog_type`, `catalog_item_id`);

-- CreateIndex
CREATE INDEX `price_book_entry_payment_mode_idx` ON `price_book_entry`(`payment_mode`);

-- CreateIndex
CREATE INDEX `price_book_entry_insurer_key_idx` ON `price_book_entry`(`insurer_key`);

-- CreateIndex
CREATE INDEX `price_book_entry_billing_entity_idx` ON `price_book_entry`(`billing_entity`);

-- CreateIndex
CREATE INDEX `price_book_entry_effective_from_idx` ON `price_book_entry`(`effective_from`);

-- CreateIndex
CREATE INDEX `price_book_entry_effective_to_idx` ON `price_book_entry`(`effective_to`);

-- CreateIndex
CREATE INDEX `price_book_entry_is_active_idx` ON `price_book_entry`(`is_active`);

-- CreateIndex
CREATE INDEX `price_book_entry_deleted_at_idx` ON `price_book_entry`(`deleted_at`);

-- CreateIndex
CREATE INDEX `price_book_entry_human_friendly_id_idx` ON `price_book_entry`(`human_friendly_id`);

-- CreateIndex
CREATE INDEX `report_definition_facility_id_idx` ON `report_definition`(`facility_id`);

-- CreateIndex
CREATE INDEX `report_definition_dataset_key_idx` ON `report_definition`(`dataset_key`);

-- CreateIndex
CREATE INDEX `report_definition_status_idx` ON `report_definition`(`status`);

-- CreateIndex
CREATE INDEX `report_run_facility_id_idx` ON `report_run`(`facility_id`);

-- CreateIndex
CREATE INDEX `report_run_schedule_id_idx` ON `report_run`(`schedule_id`);

-- CreateIndex
CREATE INDEX `report_run_requested_by_user_id_idx` ON `report_run`(`requested_by_user_id`);

-- CreateIndex
CREATE INDEX `report_run_trigger_type_idx` ON `report_run`(`trigger_type`);

-- CreateIndex
CREATE INDEX `report_run_format_idx` ON `report_run`(`format`);

-- CreateIndex
CREATE INDEX `report_run_queued_at_idx` ON `report_run`(`queued_at`);

-- CreateIndex
CREATE INDEX `report_run_expires_at_idx` ON `report_run`(`expires_at`);

-- CreateIndex
CREATE INDEX `shift_close_billing_entity_idx` ON `shift_close`(`billing_entity`);

-- CreateIndex
CREATE INDEX `theatre_case_room_id_idx` ON `theatre_case`(`room_id`);

-- CreateIndex
CREATE INDEX `theatre_case_surgeon_user_id_idx` ON `theatre_case`(`surgeon_user_id`);

-- CreateIndex
CREATE INDEX `theatre_case_anesthetist_user_id_idx` ON `theatre_case`(`anesthetist_user_id`);

-- CreateIndex
CREATE INDEX `theatre_case_started_at_idx` ON `theatre_case`(`started_at`);

-- CreateIndex
CREATE INDEX `theatre_case_completed_at_idx` ON `theatre_case`(`completed_at`);

-- AddForeignKey
ALTER TABLE `role` ADD CONSTRAINT `role_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `appointment` ADD CONSTRAINT `appointment_patient_id_fkey` FOREIGN KEY (`patient_id`) REFERENCES `patient`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `facility_lab_test_offering` ADD CONSTRAINT `facility_lab_test_offering_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `facility_lab_test_offering` ADD CONSTRAINT `facility_lab_test_offering_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `facility_lab_test_offering` ADD CONSTRAINT `facility_lab_test_offering_lab_test_id_fkey` FOREIGN KEY (`lab_test_id`) REFERENCES `lab_test`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `facility_lab_test_reference_range` ADD CONSTRAINT `facility_lab_test_reference_range_facility_lab_test_offerin_fkey` FOREIGN KEY (`facility_lab_test_offering_id`) REFERENCES `facility_lab_test_offering`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `facility_lab_test_unit_option` ADD CONSTRAINT `facility_lab_test_unit_option_facility_lab_test_offering_id_fkey` FOREIGN KEY (`facility_lab_test_offering_id`) REFERENCES `facility_lab_test_offering`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `facility_lab_test_result_option` ADD CONSTRAINT `facility_lab_test_result_option_facility_lab_test_offering__fkey` FOREIGN KEY (`facility_lab_test_offering_id`) REFERENCES `facility_lab_test_offering`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `facility_lab_panel_offering` ADD CONSTRAINT `facility_lab_panel_offering_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `facility_lab_panel_offering` ADD CONSTRAINT `facility_lab_panel_offering_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `facility_lab_panel_offering` ADD CONSTRAINT `facility_lab_panel_offering_lab_panel_id_fkey` FOREIGN KEY (`lab_panel_id`) REFERENCES `lab_panel`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `facility_radiology_procedure_offering` ADD CONSTRAINT `facility_radiology_procedure_offering_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `facility_radiology_procedure_offering` ADD CONSTRAINT `facility_radiology_procedure_offering_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `facility_radiology_procedure_offering` ADD CONSTRAINT `facility_radiology_procedure_offering_radiology_procedure_i_fkey` FOREIGN KEY (`radiology_procedure_id`) REFERENCES `radiology_procedure`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `theatre_case_resource_allocation` ADD CONSTRAINT `theatre_case_resource_allocation_theatre_case_id_fkey` FOREIGN KEY (`theatre_case_id`) REFERENCES `theatre_case`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `theatre_case_checklist_item` ADD CONSTRAINT `theatre_case_checklist_item_theatre_case_id_fkey` FOREIGN KEY (`theatre_case_id`) REFERENCES `theatre_case`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `anesthesia_observation` ADD CONSTRAINT `anesthesia_observation_theatre_case_id_fkey` FOREIGN KEY (`theatre_case_id`) REFERENCES `theatre_case`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `radiology_procedure` ADD CONSTRAINT `radiology_procedure_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `facility_pharmacy_offering` ADD CONSTRAINT `facility_pharmacy_offering_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `facility_pharmacy_offering` ADD CONSTRAINT `facility_pharmacy_offering_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `facility_pharmacy_offering` ADD CONSTRAINT `facility_pharmacy_offering_drug_id_fkey` FOREIGN KEY (`drug_id`) REFERENCES `drug`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `pharmacy_order` ADD CONSTRAINT `pharmacy_order_patient_id_fkey` FOREIGN KEY (`patient_id`) REFERENCES `patient`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `coverage_plan` ADD CONSTRAINT `coverage_plan_insurance_company_id_fkey` FOREIGN KEY (`insurance_company_id`) REFERENCES `insurance_company`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `opening_balance_entry` ADD CONSTRAINT `opening_balance_entry_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `opening_balance_entry` ADD CONSTRAINT `opening_balance_entry_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `opening_balance_entry` ADD CONSTRAINT `opening_balance_entry_account_id_fkey` FOREIGN KEY (`account_id`) REFERENCES `chart_account`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `opening_balance_entry` ADD CONSTRAINT `opening_balance_entry_department_id_fkey` FOREIGN KEY (`department_id`) REFERENCES `department`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `opening_balance_entry` ADD CONSTRAINT `opening_balance_entry_approved_by_fkey` FOREIGN KEY (`approved_by`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `billing_approval` ADD CONSTRAINT `billing_approval_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `billing_approval` ADD CONSTRAINT `billing_approval_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `billing_approval` ADD CONSTRAINT `billing_approval_requested_by_user_id_fkey` FOREIGN KEY (`requested_by_user_id`) REFERENCES `user`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `billing_approval` ADD CONSTRAINT `billing_approval_approved_by_user_id_fkey` FOREIGN KEY (`approved_by_user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `notification` ADD CONSTRAINT `notification_template_id_fkey` FOREIGN KEY (`template_id`) REFERENCES `template`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `report_definition` ADD CONSTRAINT `report_definition_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `report_run` ADD CONSTRAINT `report_run_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `report_run` ADD CONSTRAINT `report_run_schedule_id_fkey` FOREIGN KEY (`schedule_id`) REFERENCES `report_schedule`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `report_run` ADD CONSTRAINT `report_run_requested_by_user_id_fkey` FOREIGN KEY (`requested_by_user_id`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `dashboard_widget` ADD CONSTRAINT `dashboard_widget_report_definition_id_fkey` FOREIGN KEY (`report_definition_id`) REFERENCES `report_definition`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `kpi_snapshot` ADD CONSTRAINT `kpi_snapshot_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `analytics_event` ADD CONSTRAINT `analytics_event_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `report_schedule` ADD CONSTRAINT `report_schedule_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `report_schedule` ADD CONSTRAINT `report_schedule_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `report_schedule` ADD CONSTRAINT `report_schedule_report_definition_id_fkey` FOREIGN KEY (`report_definition_id`) REFERENCES `report_definition`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `report_schedule` ADD CONSTRAINT `report_schedule_created_by_fkey` FOREIGN KEY (`created_by`) REFERENCES `user`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `unit_management_assignment` ADD CONSTRAINT `unit_management_assignment_tenant_id_fkey` FOREIGN KEY (`tenant_id`) REFERENCES `tenant`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `unit_management_assignment` ADD CONSTRAINT `unit_management_assignment_facility_id_fkey` FOREIGN KEY (`facility_id`) REFERENCES `facility`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `unit_management_assignment` ADD CONSTRAINT `unit_management_assignment_department_id_fkey` FOREIGN KEY (`department_id`) REFERENCES `department`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `unit_management_assignment` ADD CONSTRAINT `unit_management_assignment_unit_id_fkey` FOREIGN KEY (`unit_id`) REFERENCES `unit`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `unit_management_assignment` ADD CONSTRAINT `unit_management_assignment_ward_id_fkey` FOREIGN KEY (`ward_id`) REFERENCES `ward`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `unit_management_assignment` ADD CONSTRAINT `unit_management_assignment_user_id_fkey` FOREIGN KEY (`user_id`) REFERENCES `user`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `unit_management_assignment` ADD CONSTRAINT `unit_management_assignment_staff_profile_id_fkey` FOREIGN KEY (`staff_profile_id`) REFERENCES `staff_profile`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- RenameIndex
ALTER TABLE `billable_charge_event` RENAME INDEX `billable_charge_event_source_idx` TO `billable_charge_event_source_module_source_id_idx`;

-- RenameIndex
ALTER TABLE `facility_lab_test_reference_range` RENAME INDEX `fltr_offering_sort_idx` TO `facility_lab_test_reference_range_facility_lab_test_offering_idx`;

-- RenameIndex
ALTER TABLE `facility_lab_test_result_option` RENAME INDEX `fltro_offering_sort_idx` TO `facility_lab_test_result_option_facility_lab_test_offering_i_idx`;

-- RenameIndex
ALTER TABLE `facility_lab_test_result_option` RENAME INDEX `fltro_offering_value_key` TO `facility_lab_test_result_option_facility_lab_test_offering_i_key`;

-- RenameIndex
ALTER TABLE `facility_lab_test_unit_option` RENAME INDEX `fltu_offering_sort_idx` TO `facility_lab_test_unit_option_facility_lab_test_offering_id__idx`;

-- RenameIndex
ALTER TABLE `facility_lab_test_unit_option` RENAME INDEX `fltu_offering_unit_key` TO `facility_lab_test_unit_option_facility_lab_test_offering_id__key`;

-- RenameIndex
ALTER TABLE `facility_pharmacy_offering` RENAME INDEX `fpo_deleted_at_idx` TO `facility_pharmacy_offering_deleted_at_idx`;

-- RenameIndex
ALTER TABLE `facility_pharmacy_offering` RENAME INDEX `fpo_drug_id_idx` TO `facility_pharmacy_offering_drug_id_idx`;

-- RenameIndex
ALTER TABLE `facility_pharmacy_offering` RENAME INDEX `fpo_facility_id_idx` TO `facility_pharmacy_offering_facility_id_idx`;

-- RenameIndex
ALTER TABLE `facility_pharmacy_offering` RENAME INDEX `fpo_human_friendly_id_idx` TO `facility_pharmacy_offering_human_friendly_id_idx`;

-- RenameIndex
ALTER TABLE `facility_pharmacy_offering` RENAME INDEX `fpo_is_active_idx` TO `facility_pharmacy_offering_is_active_idx`;

-- RenameIndex
ALTER TABLE `facility_pharmacy_offering` RENAME INDEX `fpo_sort_order_idx` TO `facility_pharmacy_offering_sort_order_idx`;

-- RenameIndex
ALTER TABLE `facility_pharmacy_offering` RENAME INDEX `fpo_tenant_id_idx` TO `facility_pharmacy_offering_tenant_id_idx`;

-- RenameIndex
ALTER TABLE `facility_radiology_procedure_offering` RENAME INDEX `frpo_radiology_procedure_id_idx` TO `facility_radiology_procedure_offering_radiology_procedure_id_idx`;

-- RenameIndex
ALTER TABLE `facility_radiology_procedure_offering` RENAME INDEX `frto_deleted_at_idx` TO `facility_radiology_procedure_offering_deleted_at_idx`;

-- RenameIndex
ALTER TABLE `facility_radiology_procedure_offering` RENAME INDEX `frto_facility_id_idx` TO `facility_radiology_procedure_offering_facility_id_idx`;

-- RenameIndex
ALTER TABLE `facility_radiology_procedure_offering` RENAME INDEX `frto_human_friendly_id_idx` TO `facility_radiology_procedure_offering_human_friendly_id_idx`;

-- RenameIndex
ALTER TABLE `facility_radiology_procedure_offering` RENAME INDEX `frto_is_active_idx` TO `facility_radiology_procedure_offering_is_active_idx`;

-- RenameIndex
ALTER TABLE `facility_radiology_procedure_offering` RENAME INDEX `frto_sort_order_idx` TO `facility_radiology_procedure_offering_sort_order_idx`;

-- RenameIndex
ALTER TABLE `facility_radiology_procedure_offering` RENAME INDEX `frto_tenant_id_idx` TO `facility_radiology_procedure_offering_tenant_id_idx`;

-- RenameIndex
ALTER TABLE `invoice_item` RENAME INDEX `invoice_item_coverage_plan_id_fkey` TO `invoice_item_coverage_plan_id_idx`;

-- RenameIndex
ALTER TABLE `invoice_item` RENAME INDEX `invoice_item_price_book_entry_id_fkey` TO `invoice_item_price_book_entry_id_idx`;

-- RenameIndex
ALTER TABLE `pharmacy_dispense_attestation` RENAME INDEX `pharmacy_dispense_attestation_order_batch_phase_key` TO `pharmacy_dispense_attestation_pharmacy_order_id_dispense_bat_key`;

-- RenameIndex
ALTER TABLE `price_book_entry` RENAME INDEX `price_book_entry_coverage_plan_id_fkey` TO `price_book_entry_coverage_plan_id_idx`;

-- RenameIndex
ALTER TABLE `price_book_entry` RENAME INDEX `price_book_entry_facility_id_fkey` TO `price_book_entry_facility_id_idx`;

-- RenameIndex
ALTER TABLE `radiology_procedure` RENAME INDEX `radiology_test_body_region_idx` TO `radiology_procedure_body_region_idx`;

-- RenameIndex
ALTER TABLE `radiology_procedure` RENAME INDEX `radiology_test_code_idx` TO `radiology_procedure_code_idx`;

-- RenameIndex
ALTER TABLE `radiology_procedure` RENAME INDEX `radiology_test_deleted_at_idx` TO `radiology_procedure_deleted_at_idx`;

-- RenameIndex
ALTER TABLE `radiology_procedure` RENAME INDEX `radiology_test_human_friendly_id_idx` TO `radiology_procedure_human_friendly_id_idx`;

-- RenameIndex
ALTER TABLE `radiology_procedure` RENAME INDEX `radiology_test_modality_idx` TO `radiology_procedure_modality_idx`;

-- RenameIndex
ALTER TABLE `radiology_procedure` RENAME INDEX `radiology_test_tenant_id_idx` TO `radiology_procedure_tenant_id_idx`;

