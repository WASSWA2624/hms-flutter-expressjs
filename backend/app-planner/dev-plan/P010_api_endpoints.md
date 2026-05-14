# P010 API Endpoints

Goal: define the route-family contract before module implementation.

Path rules:
- business endpoints live under `/api/v1`
- resources use plural kebab-case paths
- standard CRUD is list, create, get, update, archive or soft-delete
- workflow transitions use `POST /resource/:id/<action>`

Route families:
- access and org: `/auth`, `/user-sessions`, `/tenants`, `/facilities`, `/branches`, `/departments`, `/units`, `/wards`, `/rooms`, `/beds`, `/users`, `/user-profiles`, `/roles`, `/permissions`, `/role-permissions`, `/user-roles`, `/abac-policies`, `/break-glass-accesses`, `/break-glass-reviews`, `/api-keys`, `/api-key-permissions`, `/oauth-accounts`
- patient and scheduling: `/patients`, `/patient-identifiers`, `/patient-contacts`, `/patient-guardians`, `/patient-allergies`, `/patient-medical-histories`, `/patient-documents`, `/consents`, `/terms-acceptances`, `/appointments`, `/appointment-participants`, `/appointment-reminders`, `/provider-schedules`, `/availability-slots`, `/visit-queues`
- clinical and acute care: `/encounters`, `/clinical-notes`, `/diagnoses`, `/procedures`, `/vital-signs`, `/care-plans`, `/referrals`, `/follow-ups`, `/admissions`, `/bed-assignments`, `/ward-rounds`, `/nursing-notes`, `/medication-administrations`, `/discharge-summaries`, `/transfer-requests`, `/icu-stays`, `/icu-observations`, `/critical-alerts`, `/theatre-cases`, `/anesthesia-records`, `/post-op-notes`, `/emergency-cases`, `/triage-assessments`, `/emergency-responses`
- diagnostics and pharmacy: `/lab-tests`, `/lab-panels`, `/lab-orders`, `/lab-order-items`, `/lab-samples`, `/lab-results`, `/lab-qc-logs`, `/radiology-tests`, `/radiology-orders`, `/radiology-results`, `/imaging-studies`, `/imaging-assets`, `/pacs-links`, `/drugs`, `/drug-batches`, `/formulary-items`, `/pharmacy-orders`, `/pharmacy-order-items`, `/dispense-logs`, `/adverse-events`
- billing and workforce: `/invoices`, `/invoice-items`, `/payments`, `/refunds`, `/pricing-rules`, `/coverage-plans`, `/insurance-claims`, `/pre-authorizations`, `/billing-adjustments`, `/staff-positions`, `/staff-profiles`, `/staff-assignments`, `/staff-leaves`, `/shifts`, `/shift-assignments`, `/shift-swap-requests`, `/nurse-rosters`, `/shift-templates`, `/roster-day-offs`, `/staff-availabilities`, `/payroll-runs`, `/payroll-items`
- operations and biomedical: `/inventory-items`, `/inventory-stocks`, `/stock-movements`, `/suppliers`, `/purchase-requests`, `/purchase-orders`, `/goods-receipts`, `/stock-adjustments`, `/housekeeping-tasks`, `/housekeeping-schedules`, `/maintenance-requests`, `/assets`, `/asset-service-logs`, `/equipment-categories`, `/equipment-registries`, `/equipment-location-histories`, `/equipment-disposal-transfers`, `/equipment-maintenance-plans`, `/equipment-work-orders`, `/equipment-calibration-logs`, `/equipment-safety-test-logs`, `/equipment-downtime-logs`, `/equipment-incident-reports`, `/equipment-recall-notices`, `/equipment-spare-parts`, `/equipment-warranty-contracts`, `/equipment-service-providers`, `/equipment-utilization-snapshots`
- mortuary and closeout: `/mortuary-cases`, `/mortuary-deceased-profiles`, `/mortuary-storage-units`, `/mortuary-storage-slots`, `/mortuary-storage-assignments`, `/mortuary-custody-events`, `/mortuary-viewings`, `/mortuary-post-mortem-requests`, `/mortuary-release-authorisations`, `/mortuary-billable-events`, `/notifications`, `/notification-deliveries`, `/conversations`, `/messages`, `/templates`, `/template-variables`, `/report-definitions`, `/report-runs`, `/dashboard-widgets`, `/kpi-snapshots`, `/analytics-events`, `/integrations`, `/integration-logs`, `/webhook-subscriptions`, `/office-contexts`, `/shift-closes`, `/day-closes`, `/handovers`, `/custody-snapshots`, `/closeout-packs`

Required action endpoints:
- roster publish and rebalance
- claim submission and approval
- maintenance plan scheduling and work-order completion
- mortuary storage assignment, release approval, and final release
- shift close submit and approve, day close finalize, closeout pack generate
