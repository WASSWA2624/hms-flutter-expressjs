# P011 Modules

Goal: implement backend modules in the only approved order.

Execution groups:
1. Identity, access, and subscriptions
   - `auth`, `user-session`, `tenant`, `facility`, `branch`, `department`, `unit`, `ward`, `room`, `bed`, `address`, `contact`, `user`, `user-profile`, `user-mfa`, `role`, `permission`, `role-permission`, `user-role`, `abac-policy`, `break-glass-access`, `break-glass-review`, `api-key`, `api-key-permission`, `oauth-account`, `module`, `module-subscription`, `subscription-plan`, `subscription`, `license`
2. Patient registry and scheduling
   - `patient`, `patient-identifier`, `patient-contact`, `patient-guardian`, `patient-allergy`, `patient-medical-history`, `patient-document`, `consent`, `terms-acceptance`, `appointment`, `appointment-participant`, `appointment-reminder`, `provider-schedule`, `availability-slot`, `visit-queue`
3. Clinical and inpatient care
   - `encounter`, `clinical-note`, `diagnosis`, `procedure`, `vital-sign`, `care-plan`, `referral`, `follow-up`, `admission`, `bed-assignment`, `ward-round`, `nursing-note`, `medication-administration`, `discharge-summary`, `transfer-request`, `icu-stay`, `icu-observation`, `critical-alert`, `theatre-case`, `anesthesia-record`, `post-op-note`, `emergency-case`, `triage-assessment`, `emergency-response`
4. Diagnostics and pharmacy
   - `lab-test`, `lab-panel`, `lab-order`, `lab-order-item`, `lab-sample`, `lab-result`, `lab-qc-log`, `radiology-test`, `radiology-order`, `radiology-result`, `imaging-study`, `imaging-asset`, `pacs-link`, `drug`, `drug-batch`, `formulary-item`, `pharmacy-order`, `pharmacy-order-item`, `dispense-log`, `adverse-event`
5. Billing and workforce
   - `invoice`, `invoice-item`, `payment`, `refund`, `pricing-rule`, `coverage-plan`, `insurance-claim`, `pre-authorization`, `billing-adjustment`, `staff-position`, `staff-profile`, `staff-assignment`, `staff-leave`, `shift`, `shift-assignment`, `shift-swap-request`, `nurse-roster`, `shift-template`, `roster-day-off`, `staff-availability`, `payroll-run`, `payroll-item`
6. Operations and biomedical
   - `inventory-item`, `inventory-stock`, `stock-movement`, `supplier`, `purchase-request`, `purchase-order`, `goods-receipt`, `stock-adjustment`, `housekeeping-task`, `housekeeping-schedule`, `maintenance-request`, `asset`, `asset-service-log`, `equipment-category`, `equipment-registry`, `equipment-location-history`, `equipment-disposal-transfer`, `equipment-maintenance-plan`, `equipment-work-order`, `equipment-calibration-log`, `equipment-safety-test-log`, `equipment-downtime-log`, `equipment-incident-report`, `equipment-recall-notice`, `equipment-spare-part`, `equipment-warranty-contract`, `equipment-service-provider`, `equipment-utilization-snapshot`
7. Mortuary and closeout
   - `mortuary-case`, `mortuary-deceased-profile`, `mortuary-storage-unit`, `mortuary-storage-slot`, `mortuary-storage-assignment`, `mortuary-custody-event`, `mortuary-viewing`, `mortuary-post-mortem-request`, `mortuary-release-authorisation`, `mortuary-billable-event`, `office-context`, `shift-close`, `day-close`, `handover`, `custody-snapshot`, `closeout-pack`
8. Communications, reporting, integrations, and orchestration
   - `notification`, `notification-delivery`, `conversation`, `message`, `template`, `template-variable`, `report-definition`, `report-run`, `dashboard-widget`, `kpi-snapshot`, `analytics-event`, `integration`, `integration-log`, `webhook-subscription`, `public`, `campaign`, `feedback`, `billing`, `doctor`, `clinical-term`, `clinical-alert-threshold`, `opd-flow`, `ipd-flow`, `theatre-flow`, `report-schedule`, `interop`, `scheduling-workspace`, `lab-workspace`, `radiology-workspace`, `pharmacy-workspace`, `hr-workspace`, `housekeeping-workspace`, `biomedical-workspace`, `mortuary-workspace`, `reports-workspace`, `subscriptions-workspace`, `dashboard-workspace`, `communications-workspace`, `settings-workspace`

Done gate for every module:
- follow `module-creation.md` in order
- keep workflow standalone inside its paid module boundary
- keep permission keys, route families, and entitlements aligned with docs
- complete tests, docs, and seed updates together
