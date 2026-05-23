You are working on the HOSSPI Hospital Management System codebase. The archive contains these main project folders:

* `app-planner`
* `backend`
* `frontend`

Convert the current inconsistent workspace behavior into a clear, synchronized, patient-friendly HMS workflow.

## 1. Problem to Solve

The app UI is improving, but multiple workspaces show inconsistent counts, confusing sidebar badges, duplicate patient rows, and incorrect workflow states.

The main issues are:

* Sidebar badges, summary cards, and visible table rows often use different definitions.
* Some badges double-count the same patient/work item.
* Patient-related modules sometimes count encounters/orders instead of unique patients without making that clear.
* OPD and Clinical still show “Doctor needed” / “Waiting Doctor Assignment” even when a valid provider is already assigned.
* Lab and Radiology default lists show orders, causing the same patient to appear multiple times.
* HR, Communications, and Integrations show sidebar counts that are not clearly tied to visible page cards.
* Empty states and zero-count states must remain simple and clear.
* Backend/database logic and frontend UI logic must use the same source of truth.
* Real-time refresh must keep sidebar badges, summary cards, rows, and detail panels synchronized.

The goal is to make the HMS extremely simple, clear, correct, robust, and professional. A user should always understand:

* what each count means;
* whether the count is for patients, encounters, orders, tasks, alerts, or failures;
* what each patient/work item’s current state is;
* what action should happen next.

## 2. Project Architecture to Preserve

Preserve the existing architecture, folder structure, naming conventions, coding style, and UI patterns.

### Backend

The backend is an Express + Prisma project using CommonJS modules and a module-based structure:

```text
backend/src/modules/<module>/
  controllers/
  repositories/
  routes/
  schemas/
  services/
```

Relevant backend areas to inspect and modify only where required:

```text
backend/prisma/schema.prisma
backend/src/app/router.js
backend/src/lib/opd-active-encounter.js
backend/src/lib/patient-query-filters.js
backend/src/lib/websocket/
backend/src/modules/patient/
backend/src/modules/encounter/
backend/src/modules/opd-flow/
backend/src/modules/emergency-case/
backend/src/modules/emergency-response/
backend/src/modules/admission/
backend/src/modules/ipd-flow/
backend/src/modules/bed/
backend/src/modules/bed-assignment/
backend/src/modules/icu-stay/
backend/src/modules/nursing-note/
backend/src/modules/discharge-summary/
backend/src/modules/clinical-note/
backend/src/modules/lab-workspace/
backend/src/modules/lab-order/
backend/src/modules/lab-sample/
backend/src/modules/lab-result/
backend/src/modules/radiology-workspace/
backend/src/modules/radiology-order/
backend/src/modules/radiology-result/
backend/src/modules/pharmacy-workspace/
backend/src/modules/billing/
backend/src/modules/insurance-claim/
backend/src/modules/hr-workspace/
backend/src/modules/communications-workspace/
backend/src/modules/integration/
backend/src/modules/integration-log/
backend/src/modules/housekeeping-workspace/
backend/src/modules/biomedical-workspace/
backend/src/modules/mortuary-workspace/
```

Follow existing backend patterns:

* services own business logic;
* repositories own database access;
* controllers wrap HTTP responses using existing response helpers;
* schemas validate inputs with existing conventions;
* use tenant/facility/deleted filters consistently;
* keep audit, permissions, module entitlement, and websocket behavior intact.

### Frontend

The frontend is a Flutter/Riverpod app using GoRouter, shared workspace UI components, localization, and feature-first folders.

Relevant frontend areas to inspect and modify only where required:

```text
frontend/lib/app/router/app_router.dart
frontend/lib/app/router/app_routes.dart
frontend/lib/core/network/api_endpoints.dart
frontend/lib/core/realtime/realtime_event_groups.dart
frontend/lib/core/realtime/realtime_events.dart
frontend/lib/shared/layout/app_workspace.dart
frontend/lib/shared/components/app_list_table.dart
frontend/lib/shared/components/app_search_bar.dart
frontend/lib/shared/components/app_status_text.dart
frontend/lib/shared/components/app_state_view.dart
frontend/lib/shared/components/app_patient_detail_dialog.dart
frontend/lib/shared/components/opd_encounter_dialog.dart
frontend/lib/shared/opd_actions/
frontend/lib/shared/clinical_actions/
frontend/lib/features/patients/
frontend/lib/features/opd/
frontend/lib/features/emergency/
frontend/lib/features/clinical/
frontend/lib/features/ipd/
frontend/lib/features/rooms_beds/
frontend/lib/features/icu/
frontend/lib/features/nursing/
frontend/lib/features/discharge/
frontend/lib/features/lab/
frontend/lib/features/radiology/
frontend/lib/features/pharmacy/
frontend/lib/features/billing/
frontend/lib/features/claims/
frontend/lib/features/physiotherapy/
frontend/lib/features/theater/
frontend/lib/features/operations/
frontend/lib/features/housekeeping/
frontend/lib/features/biomedical/
frontend/lib/features/mortuary/
frontend/lib/features/hr/
frontend/lib/features/communications/
frontend/lib/features/integrations/
frontend/lib/l10n/
frontend/test/
```

Follow existing frontend patterns:

* Riverpod controllers own presentation state and actions.
* Repositories own API coordination.
* UI must not call HTTP directly.
* Reuse `AppWorkspace`, `AppWorkspaceSummaryCard`, `AppWorkspaceDetailPanel`, `AppListTable`, `AppListTableSearch`, `AppSearchBar`, `AppDialog`, `AppStateView`, `AsyncStateScaffold`, shared form fields, access gates, and status badges.
* Do not create duplicate shells, tables, search bars, dialog systems, permission wrappers, or app-wide components.
* Keep UI theme-aware, responsive, accessible, localized, and consistent with the existing screenshots.

### Planner Files to Read

Use these as product/flow references. Do not edit planner files unless a verified codebase gap requires a small documentation update.

```text
app-planner/app-write-up.md
app-planner/opd-flow.md
app-planner/ipd-flow.md
app-planner/dev-plan/10-workspace-ui.md
app-planner/dev-plan/11-patients.md
app-planner/dev-plan/12-opd-flow.md
app-planner/dev-plan/14-clinical.md
app-planner/dev-plan/16-inpatient.md
app-planner/dev-plan/17-icu.md
app-planner/dev-plan/20-emergency.md
app-planner/dev-plan/21-lab.md
app-planner/dev-plan/22-radiology.md
app-planner/dev-plan/23-pharmacy.md
app-planner/dev-plan/24-billing.md
app-planner/dev-plan/25-claims.md
app-planner/dev-plan/26-physiotherapy.md
app-planner/dev-plan/27-mortuary.md
app-planner/dev-plan/28-hr.md
app-planner/dev-plan/29-rooms-beds.md
app-planner/dev-plan/30-biomedical.md
app-planner/dev-plan/31-operations.md
app-planner/dev-plan/32-housekeeping.md
app-planner/dev-plan/36-integrations.md
```

## 3. Global Count and Badge Rules

Implement one consistent rule across the app:

1. Sidebar badges must represent actionable workload for that module.
2. A sidebar badge must never silently double-count the same patient/work item.
3. If a badge counts patients, it must count unique patients.
4. If a badge counts encounters, orders, alerts, tasks, or failures, the label/card must make that explicit.
5. Summary cards must use the same backend-backed source of truth as the worklist they filter.
6. Clicking a summary card must filter to rows that match that count.
7. Zero badges should normally be hidden unless the existing component already intentionally shows zero.
8. Do not fix count problems with frontend-only guesses while backend summary logic remains inconsistent.
9. Prefer backend-calculated counts for module summaries and sidebar badge values.
10. Keep real-time updates targeted: update only affected rows, badges, cards, and detail panels instead of reloading the whole app unnecessarily.

## 4. Screenshot-Based UI Requirements to Preserve

The coding agent may not have screenshots, so preserve these written UI requirements:

### App shell

* The app uses a left sidebar with grouped navigation.
* Sidebar groups include areas such as Overview, Patient access, Inpatient care, Clinical services, Diagnostics and medication, Revenue cycle, Facility operations, and Administration.
* The top bar shows the HOSSPI HMS logo/title, online/offline status, notification badge, and user avatar initials.
* Preserve this shell layout.

### Workspace pattern

Each workspace should keep the current clean structure:

1. Page title with icon.
2. Optional “Live sync” or online status chip where currently used.
3. Right-aligned primary and secondary actions such as Refresh, Add patient, Start OPD encounter, Quick arrival, Request imaging, Formulary and stock.
4. Compact summary cards with icon, count, label, and chevron when clickable.
5. Search/filter bar above the table.
6. Table/card worklist with clear row states.
7. Empty state panel when no matching records exist.

### Current screenshot details that must be handled

* Patients screen currently shows `Patient registry`, cards for `All patients` and `Active patients`, and a patient table with `Patient no.`, `Patient`, `Age / sex`, `Phone / ID`, and `Alerts`.
* OPD screen currently shows `OPD flow`, summary cards like `All Patients`, `All OPD Patients`, `Active OPD`, `Vitals needed`, `Doctor needed`, `With doctor`, `Lab pending`, `Imaging pending`, `Pharmacy pending`, `Decision needed`, `Admission pending`, and `Discharged today`.
* OPD row problem: Wilson Wasswa shows `Doctor needed` / `Waiting Doctor Assignment` while `Jordan Demo` is already assigned as staff/provider. This must be corrected.
* Emergency screen currently shows `Emergency`, `Live sync`, cards for `All emergency records`, `Active`, `Critical`, and `Ambulance`, with one visible critical ambulance case. The sidebar must not show `2` for one case just because the same case is both active and ambulance-related.
* Clinical workspace currently shows `All active work`, `Waiting review`, and `Urgent`. Wilson must not remain `Waiting Doctor Assignment` if a valid provider is assigned. IPD patients requiring clinical action must remain visible in Clinical.
* IPD empty state should remain simple: `No admissions`.
* ICU empty state should remain simple: `No ICU patients`.
* Pharmacy empty state should remain simple: `No pharmacy orders`.
* Lab currently shows order rows, including duplicate patients when one patient has multiple lab orders. The default view must show patients first.
* Radiology currently shows order rows, including duplicate patients when one patient has multiple imaging orders. The default view must show patients first.
* HR, Communications, and Integrations sidebar badges currently feel ambiguous because badge values do not clearly match cards. Define and align them.

## 5. Specific Implementation Requirements

### 5.1 Patients Registry

Inspect and correct:

```text
backend/src/modules/patient/services/patient-workspace.service.js
backend/src/modules/patient/controllers/patient.controller.js
frontend/lib/features/patients/
```

Requirements:

* `All patients` means all non-deleted registered patients in the active tenant/facility scope.
* `Active patients` means unique non-deleted patients with at least one open encounter.
* Use `encounter.status == OPEN` and `deleted_at == null` as the base definition of an active encounter.
* Do not use `patient.is_active` as the active-patient clinical workload definition unless the UI explicitly labels it as “Active registry records” or similar.
* When the `Active patients` card is selected, the displayed list/filter must correspond to the active-patient count.
* Ensure patient search, pagination, selected patient detail, and real-time refresh still work.
* Preserve the current visual layout of the patient registry.

If there is ambiguity between “active registry record” and “active patient with open encounter,” implement clear naming so users are not misled.

### 5.2 OPD Flow

Inspect and correct:

```text
backend/src/modules/opd-flow/
frontend/lib/features/opd/
frontend/lib/shared/opd_actions/
frontend/lib/app/router/app_router.dart
```

Requirements:

* OPD sidebar badge must count unique active OPD patients/work items, not duplicate appointment + queue + encounter rows for the same patient.
* Closed OPD encounters must not count as active OPD workload.
* `All OPD Patients` should count unique patients with OPD history/OPD encounters.
* `Active OPD` should count unique patients with open OPD encounters.
* If a patient has both an appointment/visit queue entry and an open OPD flow for the same current visit, count that patient once.
* Summary cards and OPD table filters must use the same definitions.
* Avoid showing `Doctor needed` when `encounter.provider_user_id` is set and the assigned provider passes the project’s provider/doctor assignment rules.
* If a provider is already assigned while the flow stage is still `WAITING_DOCTOR_ASSIGNMENT`, automatically normalize the display/workflow state to `WAITING_DOCTOR_REVIEW` / `With doctor` or the existing equivalent next state.
* Preserve `assignDoctor`, `doctorReview`, `recordVitals`, `payConsultation`, `disposition`, and correction workflows.
* Do not break the existing active OPD encounter lock behavior.

Important known code area:

* `backend/src/modules/opd-flow/services/opd-flow.service.js` contains OPD stages, `resolveOpdDisplayState`, `resolvePostVitalsStage`, `assignDoctor`, and summary count logic.
* `frontend/lib/features/opd/domain/entities/opd_entities.dart` currently derives `workloadCount` from appointments + queue + active flows; review this because it can double-count the same patient.

### 5.3 Emergency

Inspect and correct:

```text
backend/src/modules/emergency-case/
backend/src/modules/emergency-response/
frontend/lib/features/emergency/
frontend/lib/app/router/app_router.dart
```

Requirements:

* Emergency sidebar badge must count unique active emergency cases/patients requiring action.
* Do not calculate sidebar workload as `activeCount + ambulanceCount` if the same emergency case can be both active and ambulance-related.
* Summary cards must match the emergency board:

  * `All emergency records`
  * `Active`
  * `Critical`
  * `Ambulance`
* The visible board rows must match the selected card/filter.
* `Awaiting response` is acceptable only when no response has actually been recorded.
* A critical active ambulance case should display as one case in the sidebar workload, not two.
* Preserve quick arrival, triage, response, ambulance dispatch/trip, handoff, print, and live sync behavior.

### 5.4 Clinical Workspace

Inspect and correct:

```text
frontend/lib/features/clinical/
frontend/lib/shared/clinical_actions/
backend/src/modules/encounter/
backend/src/modules/admission/
backend/src/modules/opd-flow/
backend/src/modules/ipd-flow/
```

Requirements:

* Clinical worklist must show active clinical work from open encounters, OPD flows, triage flows, and admitted IPD patients that still need clinical action.
* Deduplicate rows by encounter/patient context using the existing `deduplicateClinicalWorklistEntries` pattern.
* Wilson-like cases must not show `Waiting Doctor Assignment` when a valid provider is already assigned.
* An admitted IPD patient should not disappear from Clinical if there is still active clinical work.
* Summary cards must match the worklist:

  * `All active work`
  * `Waiting review`
  * `Urgent`
  * `Results ready`
  * `In consultation`
* Sidebar clinical badge must use a clear workload definition and must not double-count one row across multiple categories unless the UI clearly labels it as category total. Prefer unique actionable clinical work items.

### 5.5 IPD, Rooms and Beds, ICU, Nursing, Discharge

Inspect and verify:

```text
frontend/lib/features/ipd/
frontend/lib/features/rooms_beds/
frontend/lib/features/icu/
frontend/lib/features/nursing/
frontend/lib/features/discharge/
backend/src/modules/admission/
backend/src/modules/ipd-flow/
backend/src/modules/bed/
backend/src/modules/bed-assignment/
backend/src/modules/icu-stay/
backend/src/modules/nursing-note/
backend/src/modules/discharge-summary/
```

Requirements:

* Counts, sidebar badges, summary cards, table rows, and empty states must correspond to the same source of truth.
* Empty IPD must show a clear `No admissions` state.
* Empty ICU must show a clear `No ICU patients` state.
* Confirm admitted/transferred/discharged patients move correctly between IPD, Rooms/Beds, ICU, Nursing, Discharge, Clinical, and Housekeeping.
* Do not invent patient rows when the backend has no matching active data.
* Do not remove valid rows just because they are admitted if they still require active module work.

### 5.6 Lab

Inspect and modify:

```text
backend/src/modules/lab-workspace/
backend/src/modules/lab-order/
backend/src/modules/lab-sample/
backend/src/modules/lab-result/
frontend/lib/features/lab/
frontend/lib/app/router/app_router.dart
```

Requirements:

* The default Lab workspace view must be patient-based, not order-based.
* If one patient has multiple lab orders, show one patient row by default.
* The patient row should aggregate:

  * patient name;
  * patient/MRN identifier;
  * encounter identifier where available;
  * number of active lab orders;
  * tests/panels summary;
  * sample status;
  * processing/result/release status;
  * next action.
* Existing order-level workflow must remain available after selecting a patient or through a clear `Patients / Orders` toggle.
* If adding a toggle, default to `Patients`.
* Order view must be clearly labeled as orders and may keep the existing order table.
* Sidebar badge should count unique actionable lab patients by default, not raw orders, unless the label explicitly says orders.
* Summary cards must clearly distinguish patient counts from order counts.
* Preserve existing actions:

  * create lab order;
  * collect sample;
  * receive sample;
  * reject sample;
  * release result;
  * reverse workflow;
  * QC log behavior.
* Preserve live sync for lab workflow/result events.

If the current `/api/v1/lab/workbench` endpoint cannot safely support patient grouping with correct pagination/counts, extend it following existing backend patterns instead of doing unreliable frontend-only grouping.

### 5.7 Radiology

Inspect and modify:

```text
backend/src/modules/radiology-workspace/
backend/src/modules/radiology-order/
backend/src/modules/radiology-result/
frontend/lib/features/radiology/
frontend/lib/app/router/app_router.dart
```

Requirements:

* The default Radiology workspace view must be patient-based, not order-based.
* If one patient has multiple imaging orders, show one patient row by default.
* The patient row should aggregate:

  * patient name;
  * patient/MRN identifier;
  * encounter identifier where available;
  * number of active imaging orders;
  * study/test summary;
  * priority;
  * billing/authorization state;
  * reporting/release state;
  * next action.
* Existing order-level workflow must remain available after selecting a patient or through a clear `Patients / Orders` toggle.
* If adding a toggle, default to `Patients`.
* Order view must be clearly labeled as orders and may keep the existing order table.
* Sidebar badge should count unique actionable radiology patients by default, not raw orders, unless the label explicitly says orders.
* Summary cards must clearly distinguish patient counts from order counts.
* Preserve existing actions:

  * request imaging;
  * start/complete imaging;
  * create/update/finalize report;
  * amend/release result where supported;
  * PACS/imaging study behavior.
* Preserve live sync for radiology workflow/result events.

If the current `/api/v1/radiology/workbench` endpoint cannot safely support patient grouping with correct pagination/counts, extend it following existing backend patterns instead of doing unreliable frontend-only grouping.

### 5.8 Pharmacy

Inspect and verify:

```text
backend/src/modules/pharmacy-workspace/
backend/src/modules/pharmacy-order/
frontend/lib/features/pharmacy/
```

Requirements:

* Pharmacy currently looks acceptable but must be checked for the same consistency rules.
* Completed/empty states must be clear.
* Sidebar badge must reflect actionable pharmacy workload, not completed-only state unless clearly labeled.
* Preserve formulary/stock access, dispensing, return/cancel behavior, and live sync.

### 5.9 Billing and Claims

Inspect and verify:

```text
backend/src/modules/billing/
backend/src/modules/insurance-claim/
frontend/lib/features/billing/
frontend/lib/features/claims/
```

Requirements:

* Sidebar badges must represent actionable billing/claims workload.
* Summary cards must match visible invoices/claims/work queues.
* Do not duplicate charges or claims just to make counts match.
* Preserve payment, invoice, refund, approval, claim submission/resubmission, and reporting behavior.

### 5.10 Physiotherapy and Theatre

Inspect and verify:

```text
frontend/lib/features/physiotherapy/
frontend/lib/features/theater/
backend/src/modules/theatre-case/
backend/src/modules/theatre-flow/
```

Requirements:

* Workflows must show the correct patients, statuses, and next actions.
* Sidebar badges and summary cards must match visible actionable work.
* Preserve the existing spelling/naming conventions used in code paths, including `theater` on frontend and `theatre-*` backend modules where already present.

### 5.11 Operations, Housekeeping, Biomedical, Mortuary

Inspect and verify:

```text
frontend/lib/features/operations/
frontend/lib/features/housekeeping/
frontend/lib/features/biomedical/
frontend/lib/features/mortuary/
backend/src/modules/housekeeping-workspace/
backend/src/modules/biomedical-workspace/
backend/src/modules/mortuary-workspace/
backend/src/modules/equipment-work-order/
backend/src/modules/maintenance-request/
```

Requirements:

* Each module must display cleanly.
* Sidebar badges must represent actionable work.
* Summary cards must match visible records.
* Empty states must be clear and not misleading.
* Housekeeping must stay synchronized with bed/room readiness where applicable.
* Biomedical and operations must not mix total inventory/assets with actionable overdue/fault/maintenance workload unless labels are explicit.

### 5.12 HR

Inspect and correct:

```text
backend/src/modules/hr-workspace/
frontend/lib/features/hr/
frontend/lib/app/router/app_router.dart
```

Requirements:

* Define what the HR sidebar badge represents.
* Recommended definition: actionable HR workload only, such as pending leave requests, swap requests, draft rosters, unassigned shifts, payroll draft runs, and overdue shifts.
* Do not let `totalStaff` drive the sidebar badge.
* HR summary cards and work items must make it clear whether a number is total staff or actionable work.
* If the sidebar shows `1`, the page must have a clearly corresponding actionable item/card/filter for that `1`.

### 5.13 Communications

Inspect and correct:

```text
backend/src/modules/communications-workspace/
backend/src/modules/notification/
backend/src/modules/notification-delivery/
backend/src/modules/conversation/
frontend/lib/features/communications/
frontend/lib/app/router/app_router.dart
```

Requirements:

* Define and align:

  * top notification bell badge;
  * Communications sidebar badge;
  * Communications summary cards.
* Recommended definitions:

  * top notification bell = unread notifications/alerts;
  * Communications sidebar badge = total communication items requiring attention, such as unread threads + unread notifications/alerts + failed deliveries;
  * templates must not count as workload unless explicitly shown as template management work.
* Avoid confusing combinations where sidebar shows one number while cards show unrelated numbers such as unread alerts and failed deliveries.
* Summary labels must clearly distinguish:

  * unread messages;
  * unread threads;
  * unread alerts/notifications;
  * failed deliveries;
  * templates.
* Preserve conversations, notifications, deliveries, templates, read-state updates, and live sync behavior.

### 5.14 Integrations

Inspect and correct:

```text
backend/src/modules/integration/
backend/src/modules/integration-log/
backend/src/modules/api-key/
backend/src/modules/api-key-permission/
backend/src/modules/webhook-subscription/
frontend/lib/features/integrations/
frontend/lib/app/router/app_router.dart
```

Requirements:

* Define what the Integrations sidebar badge represents.
* Recommended definition: unique integration items requiring attention, such as warning + failed items.
* Do not confuse active integrations/API keys/log rows with warning/failure workload.
* Summary cards must clearly label:

  * active;
  * warning;
  * failed;
  * disabled;
  * logs/API keys/webhooks if shown.
* Avoid double-counting one failed log as both warning and failed unless displayed as a category total with clear labels.
* Preserve secrets masking, API key security, webhook configuration, logs, permissions, and integration status behavior.

## 6. Real-Time Synchronization Requirements

Review and update as needed:

```text
frontend/lib/core/realtime/realtime_event_groups.dart
frontend/lib/core/realtime/realtime_events.dart
backend/src/lib/websocket/
```

Requirements:

* Mutations that affect counts must trigger the correct frontend refresh group.
* Sidebar badges must update after relevant changes without requiring full page reload.
* Patients, OPD, Emergency, Clinical, Lab, Radiology, Pharmacy, IPD, Billing, Claims, HR, Communications, Integrations, Housekeeping, Biomedical, and Mortuary must update consistently.
* Do not introduce noisy polling if existing websocket/targeted refresh patterns can handle the update.
* Avoid full workspace reloads after modal actions when updating only the affected row/card is enough.

## 7. UI/UX Requirements

* Keep the interface simple and uncluttered.
* Do not add unnecessary dashboards, tabs, or nested navigation.
* Prefer patient-based workload views in patient-facing clinical modules.
* Use clear labels: `patients`, `encounters`, `orders`, `tasks`, `alerts`, `failures`, `templates`.
* Do not show order counts as patient counts.
* Do not show active workload counts that include completed/closed/cancelled records.
* Preserve existing search/filter/table behavior.
* Use clear empty states:

  * “No admissions”
  * “No ICU patients”
  * “No pharmacy orders”
  * equivalent clear states for other modules.
* Make row next-action text match the real workflow state.
* Use existing localization patterns. Add/update localization keys where new labels are introduced.
* Keep desktop table and mobile card behavior consistent with `AppListTable`.

## 8. Implementation Limits

* Modify only files required for this task.
* Do not rewrite entire modules.
* Do not replace the app shell, router, state-management approach, API client, shared component system, or backend module architecture.
* Do not create fake frontend-only data to make counts appear correct.
* Do not change unrelated UI styling.
* Do not introduce new third-party packages unless absolutely necessary.
* Do not alter authentication, authorization, tenant scoping, or subscription/module entitlement behavior except where needed to keep counts scoped correctly.
* Do not remove files unless you verify they are unused and safe to delete.
* If a raw requirement is unclear, preserve the known requirement and verify the missing detail from the codebase before implementation.

## 9. Code Cleanup

Review for safe cleanup only where directly related to this task.

Allowed:

* remove duplicated count helpers made obsolete by a single source of truth;
* remove dead local UI grouping/count code after replacing it with backend-backed summaries;
* remove unused imports, unreachable branches, and obsolete helper functions.

Not allowed:

* broad formatting churn across unrelated files;
* deleting unrelated modules;
* refactoring entire folder structures;
* renaming files unless required and verified.

If files/folders must be deleted or renamed, include a `.ps1` PowerShell script that performs the operation safely using correct relative paths. The script must not delete unrelated files.

## 10. Testing and Verification

Add or update targeted tests where the codebase already has similar tests.

### Backend verification

Run:

```bash
cd backend
npm run lint
npm run test:backend
```

Add/update focused backend tests where relevant, especially for:

* patient workspace active-patient count;
* OPD summary counts and provider-assigned state normalization;
* emergency workload count uniqueness;
* lab patient-based workbench count/grouping if backend is extended;
* radiology patient-based workbench count/grouping if backend is extended;
* HR/communications/integrations summary/badge count definitions if backend summaries change.

### Frontend verification

Run:

```bash
cd frontend
dart format .
flutter analyze
flutter test
```

Add/update focused frontend tests where relevant, especially for:

* `app_router.dart` sidebar badge definitions;
* OPD controller/workload count;
* emergency controller/workload count;
* clinical worklist status/count behavior;
* lab patient/order toggle or patient-based worklist display;
* radiology patient/order toggle or patient-based worklist display;
* HR/communications/integrations badge-summary alignment;
* localization/hardcoded text tests if new labels are added.

All linter/analyzer issues must be cleared.

## 11. Expected Deliverable

Return a zipped archive containing only the files and folders that were created or updated.

Requirements for the returned archive:

* Preserve correct relative project directories.
* Do not include the full repository.
* Do not include `node_modules`, build folders, caches, generated temporary files, logs, or unrelated assets.
* Include only changed/created source files, tests, localization files, and required scripts.
* If any files/folders must be deleted or renamed, include one or more `.ps1` PowerShell scripts that safely perform those operations using correct relative paths.
* The `.ps1` scripts must be conservative and must not delete unrelated files.

Before returning the archive, confirm that:

* sidebar badges match the defined workload counts;
* summary cards match visible filters/lists;
* patient-facing modules do not duplicate the same patient unless the view is explicitly order/encounter based;
* OPD and Clinical no longer show doctor assignment as pending when a valid provider is assigned;
* Lab and Radiology default to patient-based workload views while preserving order-level detail/workflow;
* linter/analyzer/test issues introduced by this task are fixed.
