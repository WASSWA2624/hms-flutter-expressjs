-- CreateTable
CREATE TABLE `human_id_counter` (
  `id` VARCHAR(36) NOT NULL,
  `human_friendly_id` VARCHAR(32) NULL,
  `model_name` VARCHAR(80) NOT NULL,
  `prefix` VARCHAR(16) NOT NULL,
  `scope_key` VARCHAR(160) NOT NULL,
  `last_value` INTEGER NOT NULL DEFAULT 0,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateIndex
CREATE UNIQUE INDEX `human_id_counter_model_name_prefix_scope_key_key` ON `human_id_counter`(`model_name`, `prefix`, `scope_key`);

-- CreateIndex
CREATE INDEX `human_id_counter_human_friendly_id_idx` ON `human_id_counter`(`human_friendly_id`);

-- AlterTable tenant
ALTER TABLE `tenant` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex tenant
CREATE INDEX `tenant_human_friendly_id_idx` ON `tenant`(`human_friendly_id`);

-- AlterTable facility
ALTER TABLE `facility` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex facility
CREATE INDEX `facility_human_friendly_id_idx` ON `facility`(`human_friendly_id`);

-- AlterTable branch
ALTER TABLE `branch` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex branch
CREATE INDEX `branch_human_friendly_id_idx` ON `branch`(`human_friendly_id`);

-- AlterTable department
ALTER TABLE `department` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex department
CREATE INDEX `department_human_friendly_id_idx` ON `department`(`human_friendly_id`);

-- AlterTable unit
ALTER TABLE `unit` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex unit
CREATE INDEX `unit_human_friendly_id_idx` ON `unit`(`human_friendly_id`);

-- AlterTable ward
ALTER TABLE `ward` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex ward
CREATE INDEX `ward_human_friendly_id_idx` ON `ward`(`human_friendly_id`);

-- AlterTable room
ALTER TABLE `room` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex room
CREATE INDEX `room_human_friendly_id_idx` ON `room`(`human_friendly_id`);

-- AlterTable bed
ALTER TABLE `bed` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex bed
CREATE INDEX `bed_human_friendly_id_idx` ON `bed`(`human_friendly_id`);

-- AlterTable address
ALTER TABLE `address` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex address
CREATE INDEX `address_human_friendly_id_idx` ON `address`(`human_friendly_id`);

-- AlterTable contact
ALTER TABLE `contact` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex contact
CREATE INDEX `contact_human_friendly_id_idx` ON `contact`(`human_friendly_id`);

-- AlterTable user
ALTER TABLE `user` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex user
CREATE INDEX `user_human_friendly_id_idx` ON `user`(`human_friendly_id`);

-- AlterTable user_profile
ALTER TABLE `user_profile` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex user_profile
CREATE INDEX `user_profile_human_friendly_id_idx` ON `user_profile`(`human_friendly_id`);

-- AlterTable user_session
ALTER TABLE `user_session` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex user_session
CREATE INDEX `user_session_human_friendly_id_idx` ON `user_session`(`human_friendly_id`);

-- AlterTable registration_follow_up
ALTER TABLE `registration_follow_up` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex registration_follow_up
CREATE INDEX `registration_follow_up_human_friendly_id_idx` ON `registration_follow_up`(`human_friendly_id`);

-- AlterTable verification_token
ALTER TABLE `verification_token` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex verification_token
CREATE INDEX `verification_token_human_friendly_id_idx` ON `verification_token`(`human_friendly_id`);

-- AlterTable role
ALTER TABLE `role` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex role
CREATE INDEX `role_human_friendly_id_idx` ON `role`(`human_friendly_id`);

-- AlterTable permission
ALTER TABLE `permission` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex permission
CREATE INDEX `permission_human_friendly_id_idx` ON `permission`(`human_friendly_id`);

-- AlterTable role_permission
ALTER TABLE `role_permission` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex role_permission
CREATE INDEX `role_permission_human_friendly_id_idx` ON `role_permission`(`human_friendly_id`);

-- AlterTable user_role
ALTER TABLE `user_role` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex user_role
CREATE INDEX `user_role_human_friendly_id_idx` ON `user_role`(`human_friendly_id`);

-- AlterTable api_key
ALTER TABLE `api_key` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex api_key
CREATE INDEX `api_key_human_friendly_id_idx` ON `api_key`(`human_friendly_id`);

-- AlterTable api_key_permission
ALTER TABLE `api_key_permission` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex api_key_permission
CREATE INDEX `api_key_permission_human_friendly_id_idx` ON `api_key_permission`(`human_friendly_id`);

-- AlterTable user_mfa
ALTER TABLE `user_mfa` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex user_mfa
CREATE INDEX `user_mfa_human_friendly_id_idx` ON `user_mfa`(`human_friendly_id`);

-- AlterTable oauth_account
ALTER TABLE `oauth_account` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex oauth_account
CREATE INDEX `oauth_account_human_friendly_id_idx` ON `oauth_account`(`human_friendly_id`);

-- AlterTable patient
ALTER TABLE `patient` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex patient
CREATE INDEX `patient_human_friendly_id_idx` ON `patient`(`human_friendly_id`);

-- AlterTable patient_identifier
ALTER TABLE `patient_identifier` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex patient_identifier
CREATE INDEX `patient_identifier_human_friendly_id_idx` ON `patient_identifier`(`human_friendly_id`);

-- AlterTable patient_contact
ALTER TABLE `patient_contact` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex patient_contact
CREATE INDEX `patient_contact_human_friendly_id_idx` ON `patient_contact`(`human_friendly_id`);

-- AlterTable patient_guardian
ALTER TABLE `patient_guardian` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex patient_guardian
CREATE INDEX `patient_guardian_human_friendly_id_idx` ON `patient_guardian`(`human_friendly_id`);

-- AlterTable patient_allergy
ALTER TABLE `patient_allergy` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex patient_allergy
CREATE INDEX `patient_allergy_human_friendly_id_idx` ON `patient_allergy`(`human_friendly_id`);

-- AlterTable patient_medical_history
ALTER TABLE `patient_medical_history` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex patient_medical_history
CREATE INDEX `patient_medical_history_human_friendly_id_idx` ON `patient_medical_history`(`human_friendly_id`);

-- AlterTable patient_document
ALTER TABLE `patient_document` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex patient_document
CREATE INDEX `patient_document_human_friendly_id_idx` ON `patient_document`(`human_friendly_id`);

-- AlterTable consent
ALTER TABLE `consent` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex consent
CREATE INDEX `consent_human_friendly_id_idx` ON `consent`(`human_friendly_id`);

-- AlterTable terms_acceptance
ALTER TABLE `terms_acceptance` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex terms_acceptance
CREATE INDEX `terms_acceptance_human_friendly_id_idx` ON `terms_acceptance`(`human_friendly_id`);

-- AlterTable appointment
ALTER TABLE `appointment` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex appointment
CREATE INDEX `appointment_human_friendly_id_idx` ON `appointment`(`human_friendly_id`);

-- AlterTable appointment_participant
ALTER TABLE `appointment_participant` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex appointment_participant
CREATE INDEX `appointment_participant_human_friendly_id_idx` ON `appointment_participant`(`human_friendly_id`);

-- AlterTable appointment_reminder
ALTER TABLE `appointment_reminder` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex appointment_reminder
CREATE INDEX `appointment_reminder_human_friendly_id_idx` ON `appointment_reminder`(`human_friendly_id`);

-- AlterTable provider_schedule
ALTER TABLE `provider_schedule` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex provider_schedule
CREATE INDEX `provider_schedule_human_friendly_id_idx` ON `provider_schedule`(`human_friendly_id`);

-- AlterTable availability_slot
ALTER TABLE `availability_slot` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex availability_slot
CREATE INDEX `availability_slot_human_friendly_id_idx` ON `availability_slot`(`human_friendly_id`);

-- AlterTable visit_queue
ALTER TABLE `visit_queue` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex visit_queue
CREATE INDEX `visit_queue_human_friendly_id_idx` ON `visit_queue`(`human_friendly_id`);

-- AlterTable encounter
ALTER TABLE `encounter` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex encounter
CREATE INDEX `encounter_human_friendly_id_idx` ON `encounter`(`human_friendly_id`);

-- AlterTable clinical_note
ALTER TABLE `clinical_note` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex clinical_note
CREATE INDEX `clinical_note_human_friendly_id_idx` ON `clinical_note`(`human_friendly_id`);

-- AlterTable diagnosis
ALTER TABLE `diagnosis` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex diagnosis
CREATE INDEX `diagnosis_human_friendly_id_idx` ON `diagnosis`(`human_friendly_id`);

-- AlterTable procedure
ALTER TABLE `procedure` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex procedure
CREATE INDEX `procedure_human_friendly_id_idx` ON `procedure`(`human_friendly_id`);

-- AlterTable vital_sign
ALTER TABLE `vital_sign` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex vital_sign
CREATE INDEX `vital_sign_human_friendly_id_idx` ON `vital_sign`(`human_friendly_id`);

-- AlterTable care_plan
ALTER TABLE `care_plan` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex care_plan
CREATE INDEX `care_plan_human_friendly_id_idx` ON `care_plan`(`human_friendly_id`);

-- AlterTable clinical_alert
ALTER TABLE `clinical_alert` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex clinical_alert
CREATE INDEX `clinical_alert_human_friendly_id_idx` ON `clinical_alert`(`human_friendly_id`);

-- AlterTable referral
ALTER TABLE `referral` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex referral
CREATE INDEX `referral_human_friendly_id_idx` ON `referral`(`human_friendly_id`);

-- AlterTable follow_up
ALTER TABLE `follow_up` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex follow_up
CREATE INDEX `follow_up_human_friendly_id_idx` ON `follow_up`(`human_friendly_id`);

-- AlterTable admission
ALTER TABLE `admission` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex admission
CREATE INDEX `admission_human_friendly_id_idx` ON `admission`(`human_friendly_id`);

-- AlterTable bed_assignment
ALTER TABLE `bed_assignment` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex bed_assignment
CREATE INDEX `bed_assignment_human_friendly_id_idx` ON `bed_assignment`(`human_friendly_id`);

-- AlterTable ward_round
ALTER TABLE `ward_round` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex ward_round
CREATE INDEX `ward_round_human_friendly_id_idx` ON `ward_round`(`human_friendly_id`);

-- AlterTable nursing_note
ALTER TABLE `nursing_note` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex nursing_note
CREATE INDEX `nursing_note_human_friendly_id_idx` ON `nursing_note`(`human_friendly_id`);

-- AlterTable medication_administration
ALTER TABLE `medication_administration` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex medication_administration
CREATE INDEX `medication_administration_human_friendly_id_idx` ON `medication_administration`(`human_friendly_id`);

-- AlterTable discharge_summary
ALTER TABLE `discharge_summary` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex discharge_summary
CREATE INDEX `discharge_summary_human_friendly_id_idx` ON `discharge_summary`(`human_friendly_id`);

-- AlterTable transfer_request
ALTER TABLE `transfer_request` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex transfer_request
CREATE INDEX `transfer_request_human_friendly_id_idx` ON `transfer_request`(`human_friendly_id`);

-- AlterTable icu_stay
ALTER TABLE `icu_stay` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex icu_stay
CREATE INDEX `icu_stay_human_friendly_id_idx` ON `icu_stay`(`human_friendly_id`);

-- AlterTable icu_observation
ALTER TABLE `icu_observation` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex icu_observation
CREATE INDEX `icu_observation_human_friendly_id_idx` ON `icu_observation`(`human_friendly_id`);

-- AlterTable critical_alert
ALTER TABLE `critical_alert` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex critical_alert
CREATE INDEX `critical_alert_human_friendly_id_idx` ON `critical_alert`(`human_friendly_id`);

-- AlterTable theatre_case
ALTER TABLE `theatre_case` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex theatre_case
CREATE INDEX `theatre_case_human_friendly_id_idx` ON `theatre_case`(`human_friendly_id`);

-- AlterTable anesthesia_record
ALTER TABLE `anesthesia_record` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex anesthesia_record
CREATE INDEX `anesthesia_record_human_friendly_id_idx` ON `anesthesia_record`(`human_friendly_id`);

-- AlterTable post_op_note
ALTER TABLE `post_op_note` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex post_op_note
CREATE INDEX `post_op_note_human_friendly_id_idx` ON `post_op_note`(`human_friendly_id`);

-- AlterTable lab_test
ALTER TABLE `lab_test` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex lab_test
CREATE INDEX `lab_test_human_friendly_id_idx` ON `lab_test`(`human_friendly_id`);

-- AlterTable lab_panel
ALTER TABLE `lab_panel` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex lab_panel
CREATE INDEX `lab_panel_human_friendly_id_idx` ON `lab_panel`(`human_friendly_id`);

-- AlterTable lab_order
ALTER TABLE `lab_order` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex lab_order
CREATE INDEX `lab_order_human_friendly_id_idx` ON `lab_order`(`human_friendly_id`);

-- AlterTable lab_order_item
ALTER TABLE `lab_order_item` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex lab_order_item
CREATE INDEX `lab_order_item_human_friendly_id_idx` ON `lab_order_item`(`human_friendly_id`);

-- AlterTable lab_sample
ALTER TABLE `lab_sample` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex lab_sample
CREATE INDEX `lab_sample_human_friendly_id_idx` ON `lab_sample`(`human_friendly_id`);

-- AlterTable lab_result
ALTER TABLE `lab_result` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex lab_result
CREATE INDEX `lab_result_human_friendly_id_idx` ON `lab_result`(`human_friendly_id`);

-- AlterTable lab_qc_log
ALTER TABLE `lab_qc_log` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex lab_qc_log
CREATE INDEX `lab_qc_log_human_friendly_id_idx` ON `lab_qc_log`(`human_friendly_id`);

-- AlterTable radiology_test
ALTER TABLE `radiology_test` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex radiology_test
CREATE INDEX `radiology_test_human_friendly_id_idx` ON `radiology_test`(`human_friendly_id`);

-- AlterTable radiology_order
ALTER TABLE `radiology_order` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex radiology_order
CREATE INDEX `radiology_order_human_friendly_id_idx` ON `radiology_order`(`human_friendly_id`);

-- AlterTable radiology_result
ALTER TABLE `radiology_result` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex radiology_result
CREATE INDEX `radiology_result_human_friendly_id_idx` ON `radiology_result`(`human_friendly_id`);

-- AlterTable imaging_study
ALTER TABLE `imaging_study` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex imaging_study
CREATE INDEX `imaging_study_human_friendly_id_idx` ON `imaging_study`(`human_friendly_id`);

-- AlterTable imaging_asset
ALTER TABLE `imaging_asset` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex imaging_asset
CREATE INDEX `imaging_asset_human_friendly_id_idx` ON `imaging_asset`(`human_friendly_id`);

-- AlterTable pacs_link
ALTER TABLE `pacs_link` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex pacs_link
CREATE INDEX `pacs_link_human_friendly_id_idx` ON `pacs_link`(`human_friendly_id`);

-- AlterTable drug
ALTER TABLE `drug` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex drug
CREATE INDEX `drug_human_friendly_id_idx` ON `drug`(`human_friendly_id`);

-- AlterTable drug_batch
ALTER TABLE `drug_batch` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex drug_batch
CREATE INDEX `drug_batch_human_friendly_id_idx` ON `drug_batch`(`human_friendly_id`);

-- AlterTable formulary_item
ALTER TABLE `formulary_item` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex formulary_item
CREATE INDEX `formulary_item_human_friendly_id_idx` ON `formulary_item`(`human_friendly_id`);

-- AlterTable pharmacy_order
ALTER TABLE `pharmacy_order` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex pharmacy_order
CREATE INDEX `pharmacy_order_human_friendly_id_idx` ON `pharmacy_order`(`human_friendly_id`);

-- AlterTable pharmacy_order_item
ALTER TABLE `pharmacy_order_item` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex pharmacy_order_item
CREATE INDEX `pharmacy_order_item_human_friendly_id_idx` ON `pharmacy_order_item`(`human_friendly_id`);

-- AlterTable dispense_log
ALTER TABLE `dispense_log` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex dispense_log
CREATE INDEX `dispense_log_human_friendly_id_idx` ON `dispense_log`(`human_friendly_id`);

-- AlterTable adverse_event
ALTER TABLE `adverse_event` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex adverse_event
CREATE INDEX `adverse_event_human_friendly_id_idx` ON `adverse_event`(`human_friendly_id`);

-- AlterTable inventory_item
ALTER TABLE `inventory_item` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex inventory_item
CREATE INDEX `inventory_item_human_friendly_id_idx` ON `inventory_item`(`human_friendly_id`);

-- AlterTable inventory_stock
ALTER TABLE `inventory_stock` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex inventory_stock
CREATE INDEX `inventory_stock_human_friendly_id_idx` ON `inventory_stock`(`human_friendly_id`);

-- AlterTable stock_movement
ALTER TABLE `stock_movement` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex stock_movement
CREATE INDEX `stock_movement_human_friendly_id_idx` ON `stock_movement`(`human_friendly_id`);

-- AlterTable supplier
ALTER TABLE `supplier` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex supplier
CREATE INDEX `supplier_human_friendly_id_idx` ON `supplier`(`human_friendly_id`);

-- AlterTable purchase_request
ALTER TABLE `purchase_request` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex purchase_request
CREATE INDEX `purchase_request_human_friendly_id_idx` ON `purchase_request`(`human_friendly_id`);

-- AlterTable purchase_order
ALTER TABLE `purchase_order` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex purchase_order
CREATE INDEX `purchase_order_human_friendly_id_idx` ON `purchase_order`(`human_friendly_id`);

-- AlterTable goods_receipt
ALTER TABLE `goods_receipt` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex goods_receipt
CREATE INDEX `goods_receipt_human_friendly_id_idx` ON `goods_receipt`(`human_friendly_id`);

-- AlterTable stock_adjustment
ALTER TABLE `stock_adjustment` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex stock_adjustment
CREATE INDEX `stock_adjustment_human_friendly_id_idx` ON `stock_adjustment`(`human_friendly_id`);

-- AlterTable emergency_case
ALTER TABLE `emergency_case` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex emergency_case
CREATE INDEX `emergency_case_human_friendly_id_idx` ON `emergency_case`(`human_friendly_id`);

-- AlterTable triage_assessment
ALTER TABLE `triage_assessment` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex triage_assessment
CREATE INDEX `triage_assessment_human_friendly_id_idx` ON `triage_assessment`(`human_friendly_id`);

-- AlterTable emergency_response
ALTER TABLE `emergency_response` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex emergency_response
CREATE INDEX `emergency_response_human_friendly_id_idx` ON `emergency_response`(`human_friendly_id`);

-- AlterTable ambulance
ALTER TABLE `ambulance` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex ambulance
CREATE INDEX `ambulance_human_friendly_id_idx` ON `ambulance`(`human_friendly_id`);

-- AlterTable ambulance_dispatch
ALTER TABLE `ambulance_dispatch` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex ambulance_dispatch
CREATE INDEX `ambulance_dispatch_human_friendly_id_idx` ON `ambulance_dispatch`(`human_friendly_id`);

-- AlterTable ambulance_trip
ALTER TABLE `ambulance_trip` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex ambulance_trip
CREATE INDEX `ambulance_trip_human_friendly_id_idx` ON `ambulance_trip`(`human_friendly_id`);

-- AlterTable invoice
ALTER TABLE `invoice` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex invoice
CREATE INDEX `invoice_human_friendly_id_idx` ON `invoice`(`human_friendly_id`);

-- AlterTable invoice_item
ALTER TABLE `invoice_item` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex invoice_item
CREATE INDEX `invoice_item_human_friendly_id_idx` ON `invoice_item`(`human_friendly_id`);

-- AlterTable payment
ALTER TABLE `payment` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex payment
CREATE INDEX `payment_human_friendly_id_idx` ON `payment`(`human_friendly_id`);

-- AlterTable refund
ALTER TABLE `refund` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex refund
CREATE INDEX `refund_human_friendly_id_idx` ON `refund`(`human_friendly_id`);

-- AlterTable pricing_rule
ALTER TABLE `pricing_rule` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex pricing_rule
CREATE INDEX `pricing_rule_human_friendly_id_idx` ON `pricing_rule`(`human_friendly_id`);

-- AlterTable coverage_plan
ALTER TABLE `coverage_plan` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex coverage_plan
CREATE INDEX `coverage_plan_human_friendly_id_idx` ON `coverage_plan`(`human_friendly_id`);

-- AlterTable insurance_claim
ALTER TABLE `insurance_claim` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex insurance_claim
CREATE INDEX `insurance_claim_human_friendly_id_idx` ON `insurance_claim`(`human_friendly_id`);

-- AlterTable pre_authorization
ALTER TABLE `pre_authorization` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex pre_authorization
CREATE INDEX `pre_authorization_human_friendly_id_idx` ON `pre_authorization`(`human_friendly_id`);

-- AlterTable billing_adjustment
ALTER TABLE `billing_adjustment` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex billing_adjustment
CREATE INDEX `billing_adjustment_human_friendly_id_idx` ON `billing_adjustment`(`human_friendly_id`);

-- AlterTable staff_profile
ALTER TABLE `staff_profile` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex staff_profile
CREATE INDEX `staff_profile_human_friendly_id_idx` ON `staff_profile`(`human_friendly_id`);

-- AlterTable staff_assignment
ALTER TABLE `staff_assignment` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex staff_assignment
CREATE INDEX `staff_assignment_human_friendly_id_idx` ON `staff_assignment`(`human_friendly_id`);

-- AlterTable staff_leave
ALTER TABLE `staff_leave` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex staff_leave
CREATE INDEX `staff_leave_human_friendly_id_idx` ON `staff_leave`(`human_friendly_id`);

-- AlterTable shift_template
ALTER TABLE `shift_template` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex shift_template
CREATE INDEX `shift_template_human_friendly_id_idx` ON `shift_template`(`human_friendly_id`);

-- AlterTable staff_availability
ALTER TABLE `staff_availability` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex staff_availability
CREATE INDEX `staff_availability_human_friendly_id_idx` ON `staff_availability`(`human_friendly_id`);

-- AlterTable shift
ALTER TABLE `shift` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex shift
CREATE INDEX `shift_human_friendly_id_idx` ON `shift`(`human_friendly_id`);

-- AlterTable shift_assignment
ALTER TABLE `shift_assignment` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex shift_assignment
CREATE INDEX `shift_assignment_human_friendly_id_idx` ON `shift_assignment`(`human_friendly_id`);

-- AlterTable shift_swap_request
ALTER TABLE `shift_swap_request` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex shift_swap_request
CREATE INDEX `shift_swap_request_human_friendly_id_idx` ON `shift_swap_request`(`human_friendly_id`);

-- AlterTable nurse_roster
ALTER TABLE `nurse_roster` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex nurse_roster
CREATE INDEX `nurse_roster_human_friendly_id_idx` ON `nurse_roster`(`human_friendly_id`);

-- AlterTable roster_day_off
ALTER TABLE `roster_day_off` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex roster_day_off
CREATE INDEX `roster_day_off_human_friendly_id_idx` ON `roster_day_off`(`human_friendly_id`);

-- AlterTable payroll_run
ALTER TABLE `payroll_run` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex payroll_run
CREATE INDEX `payroll_run_human_friendly_id_idx` ON `payroll_run`(`human_friendly_id`);

-- AlterTable payroll_item
ALTER TABLE `payroll_item` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex payroll_item
CREATE INDEX `payroll_item_human_friendly_id_idx` ON `payroll_item`(`human_friendly_id`);

-- AlterTable housekeeping_task
ALTER TABLE `housekeeping_task` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex housekeeping_task
CREATE INDEX `housekeeping_task_human_friendly_id_idx` ON `housekeeping_task`(`human_friendly_id`);

-- AlterTable housekeeping_schedule
ALTER TABLE `housekeeping_schedule` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex housekeeping_schedule
CREATE INDEX `housekeeping_schedule_human_friendly_id_idx` ON `housekeeping_schedule`(`human_friendly_id`);

-- AlterTable maintenance_request
ALTER TABLE `maintenance_request` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex maintenance_request
CREATE INDEX `maintenance_request_human_friendly_id_idx` ON `maintenance_request`(`human_friendly_id`);

-- AlterTable asset
ALTER TABLE `asset` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex asset
CREATE INDEX `asset_human_friendly_id_idx` ON `asset`(`human_friendly_id`);

-- AlterTable asset_service_log
ALTER TABLE `asset_service_log` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex asset_service_log
CREATE INDEX `asset_service_log_human_friendly_id_idx` ON `asset_service_log`(`human_friendly_id`);

-- AlterTable equipment_category
ALTER TABLE `equipment_category` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex equipment_category
CREATE INDEX `equipment_category_human_friendly_id_idx` ON `equipment_category`(`human_friendly_id`);

-- AlterTable equipment_registry
ALTER TABLE `equipment_registry` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex equipment_registry
CREATE INDEX `equipment_registry_human_friendly_id_idx` ON `equipment_registry`(`human_friendly_id`);

-- AlterTable equipment_location_history
ALTER TABLE `equipment_location_history` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex equipment_location_history
CREATE INDEX `equipment_location_history_human_friendly_id_idx` ON `equipment_location_history`(`human_friendly_id`);

-- AlterTable equipment_maintenance_plan
ALTER TABLE `equipment_maintenance_plan` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex equipment_maintenance_plan
CREATE INDEX `equipment_maintenance_plan_human_friendly_id_idx` ON `equipment_maintenance_plan`(`human_friendly_id`);

-- AlterTable equipment_work_order
ALTER TABLE `equipment_work_order` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex equipment_work_order
CREATE INDEX `equipment_work_order_human_friendly_id_idx` ON `equipment_work_order`(`human_friendly_id`);

-- AlterTable equipment_calibration_log
ALTER TABLE `equipment_calibration_log` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex equipment_calibration_log
CREATE INDEX `equipment_calibration_log_human_friendly_id_idx` ON `equipment_calibration_log`(`human_friendly_id`);

-- AlterTable equipment_safety_test_log
ALTER TABLE `equipment_safety_test_log` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex equipment_safety_test_log
CREATE INDEX `equipment_safety_test_log_human_friendly_id_idx` ON `equipment_safety_test_log`(`human_friendly_id`);

-- AlterTable equipment_downtime_log
ALTER TABLE `equipment_downtime_log` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex equipment_downtime_log
CREATE INDEX `equipment_downtime_log_human_friendly_id_idx` ON `equipment_downtime_log`(`human_friendly_id`);

-- AlterTable equipment_spare_part
ALTER TABLE `equipment_spare_part` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex equipment_spare_part
CREATE INDEX `equipment_spare_part_human_friendly_id_idx` ON `equipment_spare_part`(`human_friendly_id`);

-- AlterTable equipment_warranty_contract
ALTER TABLE `equipment_warranty_contract` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex equipment_warranty_contract
CREATE INDEX `equipment_warranty_contract_human_friendly_id_idx` ON `equipment_warranty_contract`(`human_friendly_id`);

-- AlterTable equipment_service_provider
ALTER TABLE `equipment_service_provider` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex equipment_service_provider
CREATE INDEX `equipment_service_provider_human_friendly_id_idx` ON `equipment_service_provider`(`human_friendly_id`);

-- AlterTable equipment_incident_report
ALTER TABLE `equipment_incident_report` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex equipment_incident_report
CREATE INDEX `equipment_incident_report_human_friendly_id_idx` ON `equipment_incident_report`(`human_friendly_id`);

-- AlterTable equipment_recall_notice
ALTER TABLE `equipment_recall_notice` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex equipment_recall_notice
CREATE INDEX `equipment_recall_notice_human_friendly_id_idx` ON `equipment_recall_notice`(`human_friendly_id`);

-- AlterTable equipment_utilization_snapshot
ALTER TABLE `equipment_utilization_snapshot` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex equipment_utilization_snapshot
CREATE INDEX `equipment_utilization_snapshot_human_friendly_id_idx` ON `equipment_utilization_snapshot`(`human_friendly_id`);

-- AlterTable equipment_disposal_transfer
ALTER TABLE `equipment_disposal_transfer` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex equipment_disposal_transfer
CREATE INDEX `equipment_disposal_transfer_human_friendly_id_idx` ON `equipment_disposal_transfer`(`human_friendly_id`);

-- AlterTable notification
ALTER TABLE `notification` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex notification
CREATE INDEX `notification_human_friendly_id_idx` ON `notification`(`human_friendly_id`);

-- AlterTable notification_delivery
ALTER TABLE `notification_delivery` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex notification_delivery
CREATE INDEX `notification_delivery_human_friendly_id_idx` ON `notification_delivery`(`human_friendly_id`);

-- AlterTable conversation
ALTER TABLE `conversation` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex conversation
CREATE INDEX `conversation_human_friendly_id_idx` ON `conversation`(`human_friendly_id`);

-- AlterTable message
ALTER TABLE `message` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex message
CREATE INDEX `message_human_friendly_id_idx` ON `message`(`human_friendly_id`);

-- AlterTable template
ALTER TABLE `template` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex template
CREATE INDEX `template_human_friendly_id_idx` ON `template`(`human_friendly_id`);

-- AlterTable template_variable
ALTER TABLE `template_variable` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex template_variable
CREATE INDEX `template_variable_human_friendly_id_idx` ON `template_variable`(`human_friendly_id`);

-- AlterTable report_definition
ALTER TABLE `report_definition` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex report_definition
CREATE INDEX `report_definition_human_friendly_id_idx` ON `report_definition`(`human_friendly_id`);

-- AlterTable report_run
ALTER TABLE `report_run` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex report_run
CREATE INDEX `report_run_human_friendly_id_idx` ON `report_run`(`human_friendly_id`);

-- AlterTable dashboard_widget
ALTER TABLE `dashboard_widget` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex dashboard_widget
CREATE INDEX `dashboard_widget_human_friendly_id_idx` ON `dashboard_widget`(`human_friendly_id`);

-- AlterTable kpi_snapshot
ALTER TABLE `kpi_snapshot` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex kpi_snapshot
CREATE INDEX `kpi_snapshot_human_friendly_id_idx` ON `kpi_snapshot`(`human_friendly_id`);

-- AlterTable analytics_event
ALTER TABLE `analytics_event` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex analytics_event
CREATE INDEX `analytics_event_human_friendly_id_idx` ON `analytics_event`(`human_friendly_id`);

-- AlterTable subscription_plan
ALTER TABLE `subscription_plan` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex subscription_plan
CREATE INDEX `subscription_plan_human_friendly_id_idx` ON `subscription_plan`(`human_friendly_id`);

-- AlterTable subscription
ALTER TABLE `subscription` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex subscription
CREATE INDEX `subscription_human_friendly_id_idx` ON `subscription`(`human_friendly_id`);

-- AlterTable subscription_invoice
ALTER TABLE `subscription_invoice` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex subscription_invoice
CREATE INDEX `subscription_invoice_human_friendly_id_idx` ON `subscription_invoice`(`human_friendly_id`);

-- AlterTable module
ALTER TABLE `module` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex module
CREATE INDEX `module_human_friendly_id_idx` ON `module`(`human_friendly_id`);

-- AlterTable module_subscription
ALTER TABLE `module_subscription` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex module_subscription
CREATE INDEX `module_subscription_human_friendly_id_idx` ON `module_subscription`(`human_friendly_id`);

-- AlterTable license
ALTER TABLE `license` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex license
CREATE INDEX `license_human_friendly_id_idx` ON `license`(`human_friendly_id`);

-- AlterTable audit_log
ALTER TABLE `audit_log` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex audit_log
CREATE INDEX `audit_log_human_friendly_id_idx` ON `audit_log`(`human_friendly_id`);

-- AlterTable phi_access_log
ALTER TABLE `phi_access_log` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex phi_access_log
CREATE INDEX `phi_access_log_human_friendly_id_idx` ON `phi_access_log`(`human_friendly_id`);

-- AlterTable data_processing_log
ALTER TABLE `data_processing_log` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex data_processing_log
CREATE INDEX `data_processing_log_human_friendly_id_idx` ON `data_processing_log`(`human_friendly_id`);

-- AlterTable breach_notification
ALTER TABLE `breach_notification` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex breach_notification
CREATE INDEX `breach_notification_human_friendly_id_idx` ON `breach_notification`(`human_friendly_id`);

-- AlterTable system_change_log
ALTER TABLE `system_change_log` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex system_change_log
CREATE INDEX `system_change_log_human_friendly_id_idx` ON `system_change_log`(`human_friendly_id`);

-- AlterTable integration
ALTER TABLE `integration` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex integration
CREATE INDEX `integration_human_friendly_id_idx` ON `integration`(`human_friendly_id`);

-- AlterTable integration_log
ALTER TABLE `integration_log` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex integration_log
CREATE INDEX `integration_log_human_friendly_id_idx` ON `integration_log`(`human_friendly_id`);

-- AlterTable webhook_subscription
ALTER TABLE `webhook_subscription` ADD COLUMN `human_friendly_id` VARCHAR(32) NULL;

-- CreateIndex webhook_subscription
CREATE INDEX `webhook_subscription_human_friendly_id_idx` ON `webhook_subscription`(`human_friendly_id`);

