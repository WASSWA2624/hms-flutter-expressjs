You are working on the HOSSPI Hospital Management System codebase from `hms.zip`.

The archive contains these main folders:

```text
app-planner/
backend/
frontend/
```

Your task is to perform an end-to-end HMS codebase review and implement only safe, necessary, directly verifiable improvements. The goal is to make the app more professional, fast, consistent, responsive, maintainable, and suitable for real healthcare workflows.

## 1. Problem to Solve

Review the full HMS workflow from login to daily hospital operations:

* login/session restoration;
* navigation/sidebar/top bar;
* patient registration and patient lookup;
* OPD, emergency, clinical, IPD, ICU, nursing, discharge, lab, radiology, pharmacy, billing, claims, HR, operations, housekeeping, biomedical, mortuary, communications, reports, integrations, settings, and subscriptions;
* forms, tables, reports, dialogs, filters, modals, empty states, and detail panels;
* frontend/backend API contracts;
* backend routes, controllers, services, repositories, schemas, middleware, Prisma models, validation, error handling, security, and websocket updates.

Identify and fix gaps that are clearly supported by the codebase, especially:

* frontend API calls that do not match backend routes, request bodies, query params, response shapes, or error structures;
* UI screens showing raw technical values, enum names, IDs, unclear status text, or confusing labels instead of human-friendly healthcare language;
* duplicated frontend components, repeated form/table/modal/search logic, or one-off UI patterns where shared components already exist;
* slow workflows, unnecessary steps, poor patient turnaround, unnecessary reloads, repeated API calls, repeated rendering, inefficient queries, or state not refreshing after mutations;
* inconsistent sidebar badges, summary cards, filters, visible table rows, and workload counts;
* forms with unclear validation, cramped layout, missing loading/error/success states, or inconsistent behavior;
* reports that are hard to read, badly structured, or not useful to healthcare users;
* backend code that violates the existing route → controller → service → repository → Prisma pattern;
* missing Zod validation, weak error handling, tenant/facility scoping issues, security gaps, or inconsistent response handling.

Where a gap is confirmed and safe to fix, implement the fix. Where a gap is real but too broad or risky for this task, document it clearly in the review report without rewriting unrelated modules.

## 2. Sources to Inspect First

Read these before modifying code:

```text
app-planner/app-write-up.md
app-planner/opd-flow.md
app-planner/ipd-flow.md
app-planner/prompt.md
app-planner/dev-plan/00-index.md
app-planner/dev-plan/01-policy.md
app-planner/dev-plan/02-codebase.md
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
app-planner/dev-plan/27-mortuary.md
app-planner/dev-plan/28-hr.md
app-planner/dev-plan/29-rooms-beds.md
app-planner/dev-plan/30-biomedical.md
app-planner/dev-plan/31-operations.md
app-planner/dev-plan/32-housekeeping.md
app-planner/dev-plan/35-reports-audit.md
app-planner/dev-plan/36-integrations.md
frontend/app-planner/app-rules/
backend/app-planner/app-rules/
```

Use `app-planner/prompt.md` as an additional requirements source because it records existing UI/workflow observations that may not be available as screenshots to the coding agent. Verify every requirement against the current code before changing implementation.

## 3. Architecture to Preserve

Preserve the existing architecture, folder structure, naming conventions, coding style, and UI patterns.

### Backend

The backend is Node.js + Express + Prisma using CommonJS.

Preserve this module pattern:

```text
backend/src/modules/<module>/
  controllers/
  repositories/
  routes/
  schemas/
  services/
```

Backend rules:

* use CommonJS only;
* keep the route → controller → service → repository → Prisma layer order;
* controllers must use existing response helpers from `backend/src/lib/response/`;
* schemas must use Zod validation;
* repositories own Prisma access and query composition;
* services own business logic, workflow orchestration, authorization-sensitive decisions, audit behavior, and cross-module coordination;
* preserve tenant scope, facility scope, soft-delete filters, module entitlements, RBAC/ABAC behavior, audit logging, PHI protection, and websocket behavior;
* do not expose Prisma internals, stack traces, secrets, or PHI in API errors;
* do not edit `.env`, logs, generated caches, or unrelated deployment files.

Important backend areas:

```text
backend/src/app/router.js
backend/src/server.js
backend/src/config/
backend/src/middlewares/
backend/src/lib/
backend/src/websockets/
backend/prisma/schema.prisma
backend/docs/api/v1/openapi.yaml
backend/src/modules/auth/
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
backend/src/modules/pharmacy-order/
backend/src/modules/billing/
backend/src/modules/insurance-claim/
backend/src/modules/reports-workspace/
backend/src/modules/report-definition/
backend/src/modules/report-run/
backend/src/modules/hr-workspace/
backend/src/modules/communications-workspace/
backend/src/modules/notification/
backend/src/modules/notification-delivery/
backend/src/modules/conversation/
backend/src/modules/integration/
backend/src/modules/integration-log/
backend/src/modules/api-key/
backend/src/modules/webhook-subscription/
backend/src/modules/housekeeping-workspace/
backend/src/modules/biomedical-workspace/
backend/src/modules/mortuary-workspace/
backend/src/modules/theatre-case/
backend/src/modules/theatre-flow/
```

### Frontend

The frontend is Flutter + Riverpod + GoRouter.

Preserve this structure:

```text
frontend/lib/
  app/
  core/
  features/
  l10n/
  shared/
```

Frontend rules:

* Riverpod controllers own presentation state and user actions;
* repositories own API coordination;
* UI must not call HTTP directly;
* DTOs/mappers must stay in data layer;
* domain entities must stay UI-safe and testable;
* use `go_router` routes from `frontend/lib/app/router/`;
* use shared components instead of recreating local versions;
* keep screens responsive, theme-aware, accessible, and localized;
* add or update localization keys when visible labels change;
* avoid hardcoded user-facing strings where localization patterns already exist.

Required shared UI patterns to reuse:

```text
frontend/lib/shared/layout/app_workspace.dart
frontend/lib/shared/layout/responsive_page.dart
frontend/lib/shared/layout/responsive_shell_scaffold.dart
frontend/lib/shared/components/app_list_table.dart
frontend/lib/shared/components/app_search_bar.dart
frontend/lib/shared/components/app_status_text.dart
frontend/lib/shared/components/app_state_view.dart
frontend/lib/shared/components/app_dialog.dart
frontend/lib/shared/components/app_button.dart
frontend/lib/shared/forms/
frontend/lib/shared/actions/
frontend/lib/shared/opd_actions/
frontend/lib/shared/clinical_actions/
frontend/lib/shared/printing/
```

Important frontend areas:

```text
frontend/lib/app/router/app_router.dart
frontend/lib/app/router/app_routes.dart
frontend/lib/core/network/api_endpoints.dart
frontend/lib/core/network/
frontend/lib/core/security/
frontend/lib/core/realtime/
frontend/lib/core/utils/app_display.dart
frontend/lib/features/auth/
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
frontend/lib/features/reports/
frontend/lib/features/settings/
frontend/lib/features/subscriptions/
frontend/lib/l10n/
frontend/test/
```

## 4. Required Review Report

Create a new file:

```text
app-planner/hms-end-to-end-review.md
```

The report must include:

* issue title;
* severity: `Critical`, `High`, `Medium`, or `Low`;
* affected area/module;
* relevant frontend/backend files;
* what is wrong;
* user/workflow impact;
* recommended fix;
* status: `Fixed in this task`, `Documented only`, or `Needs product decision`.

Do not use the report as a substitute for fixing clear, safe defects. Fix what is directly verifiable and within scope.

## 5. UI/UX Requirements

Preserve the current HOSSPI HMS shell and workspace style:

* left sidebar with grouped navigation;
* groups such as Overview, Patient access, Inpatient care, Clinical services, Diagnostics and medication, Revenue cycle, Facility operations, and Administration;
* top bar with HOSSPI HMS identity/logo, online/offline status, notification badge, and user avatar initials;
* workspace pages using title/icon, optional live-sync/status chip, right-aligned actions, summary cards, search/filter area, table/card worklist, detail panel where useful, and clear empty state;
* desktop table behavior and mobile card behavior through `AppListTable`;
* clean spacing, non-congested layouts, readable labels, consistent actions, and simple healthcare-friendly wording.

Use clear labels that identify what is being counted or displayed:

* patients;
* encounters;
* orders;
* tasks;
* alerts;
* failures;
* templates;
* staff;
* rooms;
* beds;
* invoices;
* claims.

Do not show raw enum/status values directly. Convert values such as `WAITING_DOCTOR_ASSIGNMENT`, `IN_PROGRESS`, `PENDING_RELEASE`, `FAILED`, or similar technical states into localized, human-friendly text.

Preserve clear empty states where already defined, including:

```text
No admissions
No ICU patients
No pharmacy orders
```

Use equivalent clear empty states in other modules.

## 6. Specific Implementation Requirements

### 6.1 Frontend/Backend API Integration

Audit and fix API contract mismatches between:

```text
frontend/lib/core/network/api_endpoints.dart
frontend/lib/features/**/data/repositories/
frontend/lib/features/**/data/dtos/
backend/src/app/router.js
backend/src/modules/**/routes/
backend/src/modules/**/schemas/
backend/src/modules/**/controllers/
backend/docs/api/v1/openapi.yaml
```

Requirements:

* every frontend endpoint must match a backend route;
* every request body/query/param must match backend Zod schemas;
* every DTO mapper must match backend response data;
* UI must handle backend errors through existing `AppFailure` and network failure mapping;
* avoid raw `DioException` or raw backend problem details reaching widgets;
* if backend response shape changes, update DTOs, tests, and OpenAPI generation/validation where applicable;
* do not create frontend-only fake data to hide backend/API gaps.

### 6.2 Login, Session, and Navigation Flow

Inspect:

```text
frontend/lib/features/auth/
frontend/lib/core/security/
frontend/lib/app/router/
backend/src/modules/auth/
backend/src/modules/user-session/
backend/src/middlewares/auth.middleware.js
backend/src/middlewares/session.middleware.js
```

Requirements:

* login, logout, registration, email verification, password change, token/session refresh, and protected route guards must work consistently;
* unauthorized/expired sessions must redirect safely without loops;
* forbidden routes must show clear access feedback;
* tenant/facility setup requirements must not trap users in unclear navigation states;
* top bar, sidebar, notification badge, and profile actions must stay consistent after login/logout/session refresh.

### 6.3 Sidebar Badges, Summary Cards, and Worklists

Across all workspaces:

* sidebar badges must represent actionable workload for that module;
* badges must not silently double-count the same patient/work item;
* if a count is patient-based, count unique patients;
* if a count is order/task/alert/failure-based, label it clearly;
* summary cards must match the same source of truth as the visible worklist filters;
* clicking a summary card must filter to rows that match that card;
* closed, completed, cancelled, deleted, or discharged records must not count as active workload unless explicitly labeled;
* hide zero badges unless the existing component intentionally displays zero;
* prefer backend-calculated summary counts over frontend guesses;
* if a frontend count is derived locally, ensure it is deduplicated, tested, and clearly consistent with displayed rows.

Important areas:

```text
frontend/lib/app/router/app_router.dart
frontend/lib/features/*/domain/entities/
frontend/lib/features/*/presentation/controllers/
frontend/lib/features/*/presentation/pages/
backend/src/modules/*-workspace/
```

### 6.4 Patient Registry

Inspect:

```text
backend/src/modules/patient/
frontend/lib/features/patients/
```

Requirements:

* `All patients` should mean all non-deleted registered patients in the active tenant/facility scope;
* `Active patients` should clearly mean either active registry records or patients with open encounters; if ambiguity exists, rename labels so users are not misled;
* patient search, pagination, detail view, documents, allergies, contacts, identifiers, guardians, duplicate detection, and real-time refresh must remain stable;
* patient rows must show human-friendly identifiers and demographics, not raw technical values;
* preserve the current patient registry layout and shared components.

### 6.5 OPD Flow

Inspect:

```text
backend/src/modules/opd-flow/
backend/src/modules/visit-queue/
backend/src/modules/appointment/
frontend/lib/features/opd/
frontend/lib/shared/opd_actions/
```

Requirements:

* OPD counts must not double-count the same patient across appointment, queue, triage, and active flow records;
* closed/terminal OPD encounters must not count as active OPD workload;
* `All OPD Patients`, `Active OPD`, `Vitals needed`, `Doctor needed`, `With doctor`, `Lab pending`, `Imaging pending`, `Pharmacy pending`, `Decision needed`, `Admission pending`, and `Discharged today` must match real data and filters;
* do not show `Doctor needed` or `Waiting Doctor Assignment` when a valid provider is already assigned;
* preserve workflows for starting an OPD encounter, assigning doctor/provider, recording vitals, consultation review, billing, orders, disposition, admission, discharge, and corrections;
* do not break active OPD encounter locking.

### 6.6 Emergency and Ambulance

Inspect:

```text
backend/src/modules/emergency-case/
backend/src/modules/emergency-response/
backend/src/modules/ambulance/
backend/src/modules/ambulance-dispatch/
backend/src/modules/ambulance-trip/
frontend/lib/features/emergency/
```

Requirements:

* emergency sidebar badge must count unique active emergency cases/patients requiring action;
* a case that is both active and ambulance-related must count once unless the UI explicitly shows category totals;
* `All emergency records`, `Active`, `Critical`, and `Ambulance` summary cards must match visible filters;
* `Awaiting response` must only appear when no response has actually been recorded;
* preserve quick arrival, triage, response, ambulance dispatch/trip, handoff, print, and live sync behavior.

### 6.7 Clinical, IPD, ICU, Nursing, Discharge, Rooms/Beds

Inspect:

```text
backend/src/modules/encounter/
backend/src/modules/admission/
backend/src/modules/ipd-flow/
backend/src/modules/bed/
backend/src/modules/bed-assignment/
backend/src/modules/icu-stay/
backend/src/modules/nursing-note/
backend/src/modules/discharge-summary/
frontend/lib/features/clinical/
frontend/lib/features/ipd/
frontend/lib/features/rooms_beds/
frontend/lib/features/icu/
frontend/lib/features/nursing/
frontend/lib/features/discharge/
frontend/shared/clinical_actions/
```

Requirements:

* active clinical work must remain visible when action is still needed;
* admitted IPD patients must not disappear from Clinical if clinical action is still required;
* duplicate rows must be deduplicated by the correct patient/encounter/admission context;
* statuses and next actions must reflect the real workflow;
* transfers/discharges must correctly update IPD, Rooms/Beds, ICU, Nursing, Discharge, Clinical, and Housekeeping;
* empty states must be clear and not misleading;
* preserve existing shared clinical action dialogs and panels.

### 6.8 Lab

Inspect:

```text
backend/src/modules/lab-workspace/
backend/src/modules/lab-order/
backend/src/modules/lab-sample/
backend/src/modules/lab-result/
frontend/lib/features/lab/
```

Requirements:

* default Lab workbench view should be patient-based where the current code supports it;
* if one patient has multiple lab orders, default view should show one patient row with aggregated order/test/sample/result state;
* order-level workflow must remain available through selection or a clear Patients/Orders view toggle;
* sidebar badge should count unique actionable lab patients by default unless explicitly labeled as orders;
* preserve create lab order, collect sample, receive sample, reject sample, release result, reverse workflow, QC log behavior, and live sync;
* if backend support for patient grouping is incomplete, extend the existing workbench endpoint using current backend patterns instead of unreliable frontend-only grouping.

### 6.9 Radiology

Inspect:

```text
backend/src/modules/radiology-workspace/
backend/src/modules/radiology-order/
backend/src/modules/radiology-result/
backend/src/modules/imaging-study/
backend/src/modules/imaging-asset/
backend/src/modules/pacs-link/
frontend/lib/features/radiology/
```

Requirements:

* default Radiology workbench view should be patient-based where the current code supports it;
* if one patient has multiple imaging orders, default view should show one patient row with aggregated order/study/report state;
* order-level workflow must remain available through selection or a clear Patients/Orders view toggle;
* sidebar badge should count unique actionable radiology patients by default unless explicitly labeled as orders;
* preserve request imaging, assign/start/complete imaging, create/update/finalize report, result addendum/finalization flows, PACS/imaging asset behavior, and live sync;
* if backend support for patient grouping is incomplete, extend the existing workbench endpoint using current backend patterns instead of unreliable frontend-only grouping.

### 6.10 Pharmacy, Billing, Claims, Reports

Inspect:

```text
backend/src/modules/pharmacy-workspace/
backend/src/modules/pharmacy-order/
backend/src/modules/billing/
backend/src/modules/invoice/
backend/src/modules/payment/
backend/src/modules/refund/
backend/src/modules/insurance-claim/
backend/src/modules/reports-workspace/
backend/src/modules/report-definition/
backend/src/modules/report-run/
frontend/lib/features/pharmacy/
frontend/lib/features/billing/
frontend/lib/features/claims/
frontend/lib/features/reports/
frontend/lib/shared/printing/
frontend/lib/shared/components/app_report_actions.dart
```

Requirements:

* pharmacy, billing, claims, and reports must show actionable, readable, human-friendly records;
* summary cards must match visible invoices/orders/claims/reports;
* preserve payment, invoice, refund, approval, claim submission/resubmission, report run/export/print behavior;
* reports must be readable, useful, and not cluttered;
* use existing print/report components and templates;
* do not duplicate charges, claims, or orders to force count alignment.

### 6.11 HR, Communications, Integrations

Inspect:

```text
backend/src/modules/hr-workspace/
backend/src/modules/communications-workspace/
backend/src/modules/notification/
backend/src/modules/notification-delivery/
backend/src/modules/conversation/
backend/src/modules/integration/
backend/src/modules/integration-log/
backend/src/modules/api-key/
backend/src/modules/webhook-subscription/
frontend/lib/features/hr/
frontend/lib/features/communications/
frontend/lib/features/integrations/
```

Requirements:

* HR sidebar badge should represent actionable HR workload, not total staff, unless clearly labeled;
* Communications must clearly distinguish notification bell count, communications sidebar badge, unread messages, unread threads, unread alerts/notifications, failed deliveries, and templates;
* Integrations sidebar badge should represent unique items requiring attention, such as warnings/failures, not total integrations/API keys/log rows;
* preserve conversations, notifications, delivery states, templates, read-state updates, secrets masking, API key security, webhook setup, integration logs, permissions, and live sync.

### 6.12 Operations, Housekeeping, Biomedical, Mortuary, Theatre, Physiotherapy

Inspect:

```text
backend/src/modules/housekeeping-workspace/
backend/src/modules/biomedical-workspace/
backend/src/modules/mortuary-workspace/
backend/src/modules/equipment-work-order/
backend/src/modules/maintenance-request/
backend/src/modules/theatre-case/
backend/src/modules/theatre-flow/
frontend/lib/features/operations/
frontend/lib/features/housekeeping/
frontend/lib/features/biomedical/
frontend/lib/features/mortuary/
frontend/lib/features/theater/
frontend/lib/features/physiotherapy/
```

Requirements:

* worklists must show correct records, statuses, next actions, and empty states;
* sidebar badges must reflect actionable workload;
* Housekeeping must stay synchronized with room/bed readiness where applicable;
* Biomedical and Operations must not confuse total assets/inventory with actionable overdue/fault/maintenance workload unless labels are explicit;
* preserve the existing spelling split: frontend uses `theater`, backend modules use `theatre-*`.

## 7. Performance and Real-Time Requirements

Inspect:

```text
frontend/lib/core/realtime/
backend/src/lib/websocket/
backend/src/websockets/
frontend/lib/app/router/app_router.dart
frontend/lib/features/*/presentation/controllers/
```

Requirements:

* create/update/delete/approve/reject/status-change actions must update affected rows, summary cards, badges, detail panels, and notification counts without requiring full page reload;
* use existing websocket/targeted refresh patterns where possible;
* avoid noisy polling;
* avoid unnecessary full workspace reloads after modal actions;
* preserve filters, pagination, selected rows, and scroll position after successful actions;
* avoid loading heavy full workspace state only to compute sidebar badges if a lighter existing summary source can be used safely;
* do not introduce broad new state-management systems.

## 8. Reusable Components and Duplication

Audit for duplicate local implementations of:

* tables/lists;
* search bars;
* form fields;
* dialogs/modals;
* buttons;
* status badges;
* patient headers/context cards;
* permission wrappers;
* report/print actions;
* pagination helpers;
* error/empty/loading state views.

Use existing shared components where possible. Do not create another app-wide component system.

Safe cleanup is allowed only when directly related:

* remove unused imports;
* remove dead helper functions;
* remove duplicated local UI/count logic after replacing it with a shared or backend-backed source;
* remove unreachable branches.

Avoid broad formatting churn and unrelated refactors.

## 9. Backend Quality Requirements

For any backend files changed:

* validate inputs through Zod schemas;
* preserve tenant/facility/deleted filters;
* preserve audit logging and permission checks;
* preserve module entitlement behavior;
* use response helpers consistently;
* keep Prisma access inside repositories except documented transaction orchestration;
* avoid N+1 queries where clear aggregation or include/select can solve the issue;
* update or add focused tests for changed logic;
* update OpenAPI generation/validation if route contracts change.

## 10. Frontend Quality Requirements

For any frontend files changed:

* keep API logic in repositories;
* keep DTO parsing/mapping in data layer;
* keep UI state/actions in Riverpod controllers;
* keep widgets clean and reusable;
* localize all visible labels;
* use `AppDisplay`, `AppFormatters`, `AppStatusText`, or equivalent existing utilities for human-friendly display;
* keep screens responsive across mobile, tablet, and desktop;
* preserve keyboard, mouse, touch, and screen-reader usability;
* prevent duplicate form submissions;
* show clear loading, empty, error, validation, success, and forbidden states.

## 11. Scope Limits

Do not:

* rewrite the whole application;
* replace the app shell, router, API client, Riverpod state model, backend architecture, Prisma setup, or shared component system;
* change unrelated styling;
* introduce new third-party packages unless absolutely necessary;
* modify `.env`, logs, build outputs, caches, `node_modules`, generated temporary files, or unrelated assets;
* delete or rename files unless verified safe and required;
* invent requirements not supported by the codebase or planner files;
* create fake frontend-only data to hide backend problems;
* change authentication, authorization, tenant scoping, facility scoping, or subscription/module entitlement behavior except where required to fix confirmed defects.

If a raw requirement is incomplete or unclear, preserve the known requirement and explicitly mark the missing detail in `app-planner/hms-end-to-end-review.md` as `Needs product decision`.

## 12. Testing and Verification

Run and fix issues introduced by this task.

Backend:

```bash
cd backend
npm run lint
npm run test:backend
npm run openapi:validate
```

Frontend:

```bash
cd frontend
dart format .
flutter analyze
flutter test
```

Add or update focused tests where similar tests already exist, especially for:

* API DTO/repository contract changes;
* route/sidebar badge definitions;
* patient registry active/all counts;
* OPD workload counts and provider-assigned display state;
* emergency unique workload count;
* clinical worklist deduplication/status behavior;
* lab patient/order workbench behavior;
* radiology patient/order workbench behavior;
* HR/communications/integrations badge-summary alignment;
* form validation and submission behavior;
* localized/human-friendly status labels;
* report display/export behavior where changed.

All linter/analyzer issues must be cleared.

## 13. Deliverable

Return a zipped archive containing only the files and folders that were created or updated.

Archive requirements:

* preserve correct relative project directories;
* include changed source files, tests, localization files, OpenAPI/docs files if updated, and `app-planner/hms-end-to-end-review.md`;
* do not include the full repository;
* do not include `node_modules`, build outputs, caches, logs, `.env`, generated temporary files, or unrelated assets.

If any files or folders must be deleted or renamed, include one or more PowerShell scripts in the archive, for example:

```text
scripts/safe-delete-unused-hms-files.ps1
scripts/safe-rename-hms-files.ps1
```

The `.ps1` scripts must:

* use correct relative paths;
* check that each target exists before acting;
* affect only verified files/folders;
* not delete unrelated files;
* be conservative and easy to review.

Before returning the archive, confirm through the changed code and review report that:

* frontend API calls match backend routes and contracts;
* visible UI labels are human-friendly;
* sidebar badges, summary cards, and filters use clear, consistent definitions;
* patient-facing workflows avoid duplicate patient rows unless the view is explicitly order/encounter based;
* forms, reports, dialogs, tables, filters, modals, and empty states follow existing shared UI patterns;
* mutations refresh relevant UI sections in real time or through targeted refresh;
* backend changes follow the existing module architecture;
* all linter/analyzer issues introduced by this task are fixed.
