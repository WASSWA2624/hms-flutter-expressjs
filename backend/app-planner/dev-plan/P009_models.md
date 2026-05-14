# P009 Models

Goal: define the target database model inventory before route and module implementation.

Model groups:
1. Access and governance
   - `tenant`, `facility`, `branch`, `department`, `unit`, `ward`, `room`, `bed`, `address`, `contact`, `user`, `user_profile`, `user_session`, `verification_token`, `role`, `permission`, `role_permission`, `user_role`, `api_key`, `api_key_permission`, `oauth_account`, `abac_policy`, `break_glass_access`, `break_glass_review`, `module`, `module_subscription`, `subscription_plan`, `subscription`, `license`, `audit_log`, `phi_access_log`, `data_processing_log`
2. Patient, scheduling, and care
   - `patient`, `patient_identifier`, `patient_contact`, `patient_guardian`, `patient_allergy`, `patient_medical_history`, `patient_document`, `consent`, `terms_acceptance`, `appointment`, `appointment_participant`, `appointment_reminder`, `provider_schedule`, `availability_slot`, `visit_queue`, `encounter`, `clinical_note`, `diagnosis`, `procedure`, `vital_sign`, `care_plan`, `referral`, `follow_up`, `admission`, `bed_assignment`, `ward_round`, `nursing_note`, `medication_administration`, `discharge_summary`, `transfer_request`, `icu_stay`, `icu_observation`, `critical_alert`, `theatre_case`, `anesthesia_record`, `post_op_note`, `emergency_case`, `triage_assessment`, `emergency_response`
3. Diagnostics and pharmacy
   - `lab_test`, `lab_panel`, `lab_order`, `lab_order_item`, `lab_sample`, `lab_result`, `lab_qc_log`, `radiology_test`, `radiology_order`, `radiology_result`, `imaging_study`, `imaging_asset`, `pacs_link`, `drug`, `drug_batch`, `formulary_item`, `pharmacy_order`, `pharmacy_order_item`, `dispense_log`, `adverse_event`
4. Billing and workforce
   - `invoice`, `invoice_item`, `payment`, `refund`, `pricing_rule`, `coverage_plan`, `insurance_claim`, `pre_authorization`, `billing_adjustment`, `staff_position`, `staff_profile`, `staff_assignment`, `staff_leave`, `shift`, `shift_assignment`, `shift_swap_request`, `nurse_roster`, `shift_template`, `roster_day_off`, `staff_availability`, `payroll_run`, `payroll_item`
5. Operations and biomedical
   - `inventory_item`, `inventory_stock`, `stock_movement`, `supplier`, `purchase_request`, `purchase_order`, `goods_receipt`, `stock_adjustment`, `housekeeping_task`, `housekeeping_schedule`, `maintenance_request`, `asset`, `asset_service_log`, `equipment_category`, `equipment_registry`, `equipment_location_history`, `equipment_disposal_transfer`, `equipment_maintenance_plan`, `equipment_work_order`, `equipment_calibration_log`, `equipment_safety_test_log`, `equipment_downtime_log`, `equipment_incident_report`, `equipment_recall_notice`, `equipment_spare_part`, `equipment_warranty_contract`, `equipment_service_provider`, `equipment_utilization_snapshot`
6. Mortuary, communications, reporting, and closeout
   - `mortuary_case`, `mortuary_deceased_profile`, `mortuary_storage_unit`, `mortuary_storage_slot`, `mortuary_storage_assignment`, `mortuary_custody_event`, `mortuary_viewing`, `mortuary_post_mortem_request`, `mortuary_release_authorisation`, `mortuary_billable_event`, `notification`, `notification_delivery`, `conversation`, `message`, `template`, `template_variable`, `report_definition`, `report_run`, `dashboard_widget`, `kpi_snapshot`, `analytics_event`, `integration`, `integration_log`, `webhook_subscription`, `office_context`, `shift_close`, `day_close`, `handover`, `custody_snapshot`, `closeout_pack`

Acceptance:
- all names are lowercase `snake_case`
- `tenant_id`, `facility_id`, audit fields, and soft-delete strategy are applied consistently
- biomedical and mortuary domains have first-class tables, not borrowed generic placeholders
