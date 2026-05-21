# HMS Patients, OPD, OPD Patients, and Triage — Comprehensive QA + Fix Pass

You are working inside the HOSSPI HMS codebase.

Repository structure:

```txt
app-planner/
backend/
frontend/
```

The backend is an Express.js + Prisma + MySQL API.
The frontend is a Flutter app using Riverpod, GoRouter, Dio, and shared HMS UI components.

No useful screenshots were included in the archive. Preserve and refine the existing UI/UX based on the current Flutter implementation and app-planner notes.

## Demo accounts to test

Use this password for every account:

```txt
Hosspi@2624.
```

Test with all supplied users:

| Email                       | Expected role/context |
| --------------------------- | --------------------- |
| `super.admin@hosspi.com`    | Super admin           |
| `tenant.admin@hosspi.com`   | Tenant admin          |
| `facility.admin@hosspi.com` | Facility admin        |
| `doctor@hosspi.com`         | Doctor                |
| `nurse@hosspi.com`          | Nurse                 |
| `lab@hosspi.com`            | Lab                   |
| `pharmacy@hosspi.com`       | Pharmacy              |
| `reception@hosspi.com`      | Reception             |
| `billing@hosspi.com`        | Billing               |
| `operations@hosspi.com`     | Operations            |
| `hr@hosspi.com`             | HR                    |
| `biomed@hosspi.com`         | Biomedical            |
| `housekeeping@hosspi.com`   | Housekeeping          |
| `ambulance@hosspi.com`      | Ambulance             |
| `patient.portal@hosspi.com` | Patient portal        |

If a role should not access a module, the denial must be intentional, clean, and user-friendly. Do not leave broken pages, hidden failures, infinite loaders, disabled buttons without explanation, or unauthorized API crashes.

---

## Main objective

Perform a full QA-and-fix pass across:

1. Patients module
2. OPD workspace
3. OPD patients / active OPD encounter flows
4. Triage and vitals workflows
5. Role-based access across all supplied accounts
6. Duplicate prevention and flow simplification

Test every visible button, menu item, table action, modal action, form field, filter, search box, pagination control, summary card, and workflow action.

When something fails, fix it immediately in the correct backend/frontend layer and add or update tests. Do not leave TODOs, skipped tests, unfinished stubs, duplicate actions, or partially working flows.

---

## Important architecture rules

### Frontend

Use the existing frontend architecture:

```txt
frontend/lib/features/patients/
frontend/lib/features/opd/
frontend/lib/shared/
frontend/lib/core/
```

Do not create duplicate patient, OPD, or triage modules.

Reuse existing shared components:

```txt
AppWorkspace
AppListTable
AppDialog
AppSearchBar
AppPermissionActionList
OpdEncounterDialog
FlowActionsDialog
AppVitalsForm
AppRecordVitalsDialog
AppTriage components
```

Frontend rules:

* UI must go through controllers/providers and repositories.
* Widgets must not call APIs directly.
* Use localized labels.
* Keep actions permission-aware.
* Keep modal-first workflows.
* Use targeted refresh after mutations instead of reloading the whole app.
* Preserve responsive behavior on desktop, tablet, and small screens.
* Use accessible labels/tooltips for icon-only buttons.
* Do not duplicate buttons that perform the same action in the same context.

### Backend

Use the existing backend layering:

```txt
route -> controller -> service -> repository -> Prisma
```

Do not bypass services or repositories.

Important backend modules:

```txt
backend/src/modules/patient
backend/src/modules/patient-identifier
backend/src/modules/patient-contact
backend/src/modules/patient-guardian
backend/src/modules/patient-allergy
backend/src/modules/patient-medical-history
backend/src/modules/patient-document
backend/src/modules/opd-flow
backend/src/modules/triage
backend/src/modules/triage-assessment
backend/src/modules/visit-queue
backend/src/modules/vital-sign
backend/src/modules/encounter
```

Backend rules:

* Validate all request payloads with existing validation patterns.
* Enforce tenant/facility scoping.
* Enforce RBAC consistently.
* Prevent duplicate active OPD encounters.
* Preserve auditability.
* Return consistent API responses and useful errors.
* Do not expose passwords, tokens, or sensitive data in logs.

---

## Backend API areas to verify

### Patients

Verify and fix these routes and related workflows:

```txt
GET    /api/v1/patients
GET    /api/v1/patients/workspace/overview
GET    /api/v1/patients/workspace/reference-data
GET    /api/v1/patients/duplicates
POST   /api/v1/patients/merge/preview
POST   /api/v1/patients/merge
POST   /api/v1/patients/duplicates/:reviewId/dismiss
GET    /api/v1/patients/:patientId/workspace
GET    /api/v1/patients/:patientId/timeline
GET    /api/v1/patients/:patientId/consents
GET    /api/v1/patients/:patientId/appointments
GET    /api/v1/patients/:patientId/visit-queue
GET    /api/v1/patients/:patientId/encounters
GET    /api/v1/patients/:patientId/admissions
GET    /api/v1/patients/:patientId/follow-ups
GET    /api/v1/patients/:patientId/referrals
GET    /api/v1/patients/:patientId/invoices
GET    /api/v1/patients/:patientId/payments
GET    /api/v1/patients/:patientId/phi-access-logs
POST   /api/v1/patients/:patientId/documents/upload
GET    /api/v1/patients/:patientId/documents/:documentId/preview
GET    /api/v1/patients/:patientId/documents/:documentId/download
GET    /api/v1/patients/:id
POST   /api/v1/patients
PUT    /api/v1/patients/:id
DELETE /api/v1/patients/:id
```

Also verify patient submodules:

```txt
/patient-identifiers
/patient-contacts
/patient-guardians
/patient-allergies
/patient-medical-histories
/patient-documents
```

### OPD

Verify and fix these OPD flow routes:

```txt
GET  /api/v1/opd-flows
GET  /api/v1/opd-flows/:id
GET  /api/v1/opd-flows/resolve-legacy/:resource/:id
POST /api/v1/opd-flows/start
POST /api/v1/opd-flows/bootstrap
POST /api/v1/opd-flows/:id/pay-consultation
POST /api/v1/opd-flows/:id/record-vitals
POST /api/v1/opd-flows/:id/assign-doctor
POST /api/v1/opd-flows/:id/doctor-review
POST /api/v1/opd-flows/:id/disposition
POST /api/v1/opd-flows/:id/correct-stage
```

Verify OPD stages:

```txt
WAITING_CONSULTATION_PAYMENT
WAITING_VITALS
WAITING_DOCTOR_ASSIGNMENT
WAITING_DOCTOR_REVIEW
LAB_REQUESTED
RADIOLOGY_REQUESTED
LAB_AND_RADIOLOGY_REQUESTED
PHARMACY_REQUESTED
WAITING_DISPOSITION
ADMITTED
DISCHARGED
```

Expected OPD progression:

```txt
Start encounter
-> Consultation payment if required
-> Record vitals
-> Assign doctor
-> Doctor review
-> Lab/radiology/pharmacy/procedure/referral/follow-up if needed
-> Disposition
-> Discharged/admitted/terminal state
```

### Visit queue

Verify and fix:

```txt
/api/v1/visit-queues
POST /api/v1/visit-queues/:id/prioritize
```

Queue actions must work from OPD and patient contexts.

### Triage

Verify and fix:

```txt
GET  /api/v1/triage
GET  /api/v1/triage/:id
POST /api/v1/triage/:id/record-vitals
POST /api/v1/triage/:id/assign-provider
POST /api/v1/triage/:id/route
POST /api/v1/triage/:id/correct-stage
```

Also verify:

```txt
/api/v1/triage-assessments
/api/v1/vital-signs
```

Triage route destinations must work correctly:

```txt
CONSULTATION
LAB
RADIOLOGY
LAB_AND_RADIOLOGY
PHYSIOTHERAPY
OTHER_SERVICE
ADMIT
EMERGENCY
THEATRE
MINOR_PROCEDURE
DISCHARGE
```

---

## Frontend areas to test and fix

### Patients page

Primary route:

```txt
/patients
```

Test and fix:

* Patient list loading
* Search by name, patient number, phone, and identifier
* Filters
* Advanced filters
* Column visibility
* Pagination
* Refresh
* Summary cards
* Add patient
* Emergency registration
* Edit patient
* Delete patient
* Duplicate warning
* Save anyway flow
* Duplicate review
* Merge preview
* Merge patients
* Dismiss duplicate
* Patient detail drawer/dialog/page
* Identifiers
* Contacts
* Guardians
* Allergies
* Medical history
* Documents
* Consents
* Appointments
* Visit queue
* Encounters
* Admissions
* Follow-ups
* Referrals
* Invoices
* Payments
* PHI access logs
* Copy patient ID
* Copy encounter ID where available
* Patient report action
* Appointment quick action
* OPD check-in quick action
* Active OPD action when an active encounter exists

Emergency registration must create an incomplete emergency patient safely and clearly mark that completion is required.

### OPD workspace

Primary route:

```txt
/opd
```

Test and fix:

* Workspace load
* Summary cards
* Table search
* Date filters
* Advanced filters
* Filter groups
* Column visibility
* Pagination
* Refresh
* Start walk-in
* Start emergency arrival
* Start from existing patient
* Start from appointment
* Start with new patient registration
* Consultation fee flow
* Pay-now flow
* Unpaid consultation flow
* Provider selection
* Notes
* Appointment check-in
* Appointment queue
* Appointment reschedule
* Appointment cancel
* Queue prioritize
* Queue move
* Start consultation from queue
* Open OPD flow action dialog
* Payment action
* Record/edit vitals
* Assign/change doctor
* Doctor review
* Diagnosis
* Lab request
* Radiology request
* Pharmacy request/prescription
* Procedure request
* Referral
* Follow-up
* Disposition
* Correct stage
* Print summary

OPD summary cards should filter the current table, not open unrelated screens. Keep them compact and clickable. Hide zero-value cards where the current design expects that behavior.

### OPD patients

Treat “OPD patients” as the intersection of:

* Patient registry records with active OPD encounters
* OPD workspace rows linked to patients
* Patient quick actions that start or continue OPD flows

Test and fix:

* Starting OPD from patient detail
* Reusing existing active OPD encounters
* Preventing duplicate active OPD encounters
* Showing active OPD action instead of duplicate check-in when an active flow exists
* Correct patient snapshot in OPD table
* Correct encounter snapshot in patient workspace
* Correct patient/encounter IDs copied from UI
* Correct flow after refresh/re-login

### Triage and vitals

There is no standalone triage frontend feature folder. Do not create a duplicate triage module unless absolutely necessary. Triage should remain integrated through OPD, emergency, patient, and shared workflow components.

Test and fix:

* Triage queue filtering
* Waiting patients
* Urgent patients
* Emergency patients
* Routine patients
* Service-only patients
* Record vitals
* Edit vitals where allowed
* Blood pressure validation
* At least one vital required
* Chief complaint
* Symptoms
* Allergies
* Pain severity
* Risk flags
* Emergency indicator
* Triage level
* Triage notes
* Abnormal vital indicators
* Assign provider
* Route to consultation
* Route to lab
* Route to radiology
* Route to lab + radiology
* Route to admission
* Route to emergency
* Route to theatre/minor procedure
* Route to discharge
* Doctor can see triage summary before review
* Nurse can triage where permitted
* Billing gates do not block emergency-safe clinical handling

---

## Duplicate and simplicity requirements

Fix all duplicate or confusing flows.

Required outcomes:

* No duplicate active OPD encounter for the same active patient visit.
* No duplicate action buttons for the same mutation in the same UI context.
* No duplicate patient registration path that bypasses duplicate detection.
* Patient OPD check-in and OPD start encounter must use the same underlying flow.
* Triage vitals must not create duplicate assessments accidentally.
* Refreshing/reopening a page must not duplicate rows.
* Repeated button clicks must be guarded against double-submit.
* Terminal OPD states should not show invalid next actions.
* Correct-stage actions should be available only to permitted roles.

---

## Role-based test matrix

For each supplied account:

1. Log in.
2. Confirm accessible modules.
3. Open Patients if permitted.
4. Open OPD if permitted.
5. Try all visible actions.
6. Confirm hidden actions are intentionally hidden.
7. Confirm unauthorized backend calls are not made from hidden actions.
8. Confirm direct unauthorized API calls return clean authorization errors.
9. Confirm no broken navigation, empty crash page, or infinite loading state.

Expected behavior examples:

* Admin roles should manage most workflows.
* Reception should handle registration, check-in, queues, and patient updates where permitted.
* Nurse should handle triage/vitals where permitted.
* Doctor should handle clinical review and disposition where permitted.
* Billing should handle consultation payment/billing gates where permitted.
* Lab/pharmacy should not see unrelated patient/OPD actions unless intentionally permitted.
* Patient portal must not access staff OPD/patient administration screens.

---

## Automated tests to add or update

### Backend tests

Add or improve tests for:

```txt
backend/src/tests/modules/patient
backend/src/tests/modules/opd-flow
backend/src/tests/modules/triage
backend/src/tests/modules/triage-assessment
backend/src/tests/modules/visit-queue
backend/src/tests/modules/vital-sign
backend/src/tests/modules/encounter
```

There are already OPD and patient-related tests, but triage route coverage appears incomplete. Add missing triage route/service/controller tests.

Cover:

* Route contracts
* Validation failures
* RBAC failures
* Tenant/facility scoping
* Duplicate prevention
* OPD stage transitions
* Triage routing
* Vitals validation
* Queue prioritization
* Patient duplicate merge/dismiss
* Emergency registration
* Soft delete or safe delete behavior
* Audit/log side effects where applicable

### Frontend tests

Add or update Flutter tests for:

```txt
frontend/test/features/patients
frontend/test/features/opd
frontend/test/shared
```

Cover:

* Patient registry loading
* Add/edit/delete patient
* Emergency registration
* Duplicate warning
* OPD check-in from patient
* Active OPD action from patient
* OPD workspace loading
* Start walk-in dialog
* Start emergency flow
* Appointment check-in
* Queue actions
* Flow actions dialog
* Vitals dialog validation
* Triage routing
* Role-based visible/hidden actions
* No duplicate actions
* Double-submit prevention
* Responsive table behavior

Use provider/repository overrides. Do not call real production services in widget tests.

---

## Manual/E2E testing expectations

Run the app locally with seeded demo data. For each supplied account, manually verify the complete visible flow.

Recommended local commands:

### Backend

```bash
cd backend
npm install
npm run prisma:generate
npm run setup:accounts
npm run db:verify:demo
npm run test:backend
npm run lint
npm run openapi:validate
```

### Frontend

```bash
cd frontend
flutter pub get
flutter analyze
flutter test
flutter run -d chrome --web-hostname=127.0.0.1 --web-port=5201 --dart-define-from-file=env/development.json.example
```

Run integration tests if supported by the environment:

```bash
flutter test integration_test
```

---

## Fix standards

When fixing issues:

* Modify only necessary files.
* Preserve existing folder structure.
* Keep naming consistent with the project.
* Do not introduce duplicate services, dialogs, pages, or tables.
* Do not hardcode tenant/facility IDs unless existing seed/test conventions require it.
* Do not hardcode passwords outside local/demo test setup.
* Do not weaken permissions to make tests pass.
* Do not hide real failures with broad try/catch blocks.
* Do not skip failing tests.
* Do not leave console logs, debug prints, or temporary scripts.

---

## Final deliverables

Return:

1. Summary of issues found.
2. Summary of fixes made.
3. Files changed, grouped by backend/frontend.
4. Tests added or updated.
5. Commands run and results.
6. Role/account test matrix showing pass/fail per account.
7. Any remaining environment-only limitations, if applicable.

The final state must satisfy:

* Patients module works end-to-end.
* OPD workspace works end-to-end.
* OPD patient flows work end-to-end.
* Triage and vitals work end-to-end.
* All supplied accounts behave correctly.
* Duplicate actions and duplicate active OPD flows are removed.
* All automated tests pass.
* No unfinished or untidy implementation remains.
