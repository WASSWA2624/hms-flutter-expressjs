You are working in the HMS codebase whose main folders are:

* `app-planner/`
* `backend/`
* `frontend/`

Implement the role-based dashboard redesign shown in the attached dashboard screenshots. The dashboard must render the correct dashboard for the signed-in user’s account/role, use real database-backed data, and update when relevant backend data changes.

## Core problem

The current home dashboard is too generic. Redesign and connect the dashboards for these account types:

* Super Admin
* Tenant Admin
* Facility Admin
* Doctor
* Nurse
* Lab
* Pharmacy
* Reception
* Billing
* Operations
* HR
* Biomedical
* Housekeeping
* Ambulance
* Patient Portal

Each dashboard must visually match the provided screenshots as closely as possible while preserving the existing HMS Flutter architecture and backend dashboard workspace design.

Do not hardcode screenshot values. Use the screenshot values only as design/content examples. Actual counts, queues, alerts, activity, trends, and distributions must come from the database through the backend.

## Relevant project areas to inspect and modify

### Frontend

Inspect and modify only where required:

* `frontend/lib/features/home/`

  * `data/dtos/home_dashboard_dtos.dart`
  * `data/repositories/home_repository_impl.dart`
  * `domain/entities/home_dashboard.dart`
  * `domain/entities/home_dashboard_profiles.dart`
  * `domain/repositories/home_repository.dart`
  * `presentation/controllers/home_controller.dart`
  * `presentation/pages/home_page.dart`
* `frontend/lib/core/network/api_endpoints.dart`
* `frontend/lib/core/permissions/access_policy.dart`
* `frontend/lib/core/realtime/`

  * `realtime_refresh.dart`
  * `realtime_event_groups.dart`
  * `realtime_events.dart`
* `frontend/lib/shared/layout/`
* `frontend/lib/shared/components/`
* `frontend/lib/app/router/app_router.dart`

Reuse the existing `HomePage`, `homeControllerProvider`, `HomeDashboardRequest`, `HomeDashboardProfile`, `AppWorkspaceHeader`, shared layout, responsive shell, theme, buttons, panels, and permission patterns wherever possible.

### Backend

Inspect and modify only where required:

* `backend/src/modules/dashboard-workspace/`

  * `routes/dashboard-workspace.routes.js`
  * `controllers/dashboard-workspace.controller.js`
  * `services/dashboard-workspace.service.js`
  * `repositories/dashboard-workspace.repository.js`
  * `schemas/dashboard-workspace.schema.js`
* `backend/src/lib/dashboard/summary.js`
* `backend/src/config/roles.js`
* `backend/src/lib/websocket/`
* `backend/docs/api/v1/openapi.yaml`

The existing backend already has dashboard workspace concepts such as role profiles, summary cards, quick actions, queue previews, alerts, activity, insights, and role packs. Extend these instead of replacing them.

### App planner

Use these files as implementation guidance:

* `app-planner/dev-plan/10-workspace-ui.md`
* `app-planner/dev-plan/35-reports-audit.md`
* `app-planner/dev-plan/37-quality-release.md`
* `app-planner/app-write-up.md`

Follow the planner rules: dashboards must be clear, responsive, role-aware, not congested, and must use backend summaries or targeted queries rather than client-side counting of large datasets.

## Architecture and style rules

Preserve the current:

* Folder structure
* Naming conventions
* Flutter/Riverpod architecture
* Backend service/controller/repository structure
* Role and permission model
* Shared UI shell and theme
* Existing route structure
* Existing responsive layout approach

Do not perform unrelated rewrites, broad refactors, or visual changes outside the dashboard task.

Modify only the files required for this change.

## Required dashboard UI/UX

Implement a common dashboard layout matching the screenshots.

### Common layout

Each role dashboard must include:

1. Existing HMS app shell with top bar and side navigation.
2. Role-specific page header:

   * Role icon/initial tile
   * Dashboard title
   * Role/status pill
   * Refresh button
3. Hero panel:

   * Short role-specific description
   * Facility/tenant/branch/scope context
   * “Live dashboard” style badge
   * Dynamic “Updated …” timestamp from backend `generated_at`
4. “Today at a glance” summary cards:

   * Rounded cards
   * Small icon/initial tile
   * Metric label
   * Large metric value
   * Color-coded values for normal, success, warning, and critical states
5. Quick actions:

   * Compact outlined action buttons
   * Small icon/initial tile
   * Role-specific actions
   * Wrap cleanly on smaller screens
6. Main content:

   * Left trend chart panel
   * Right distribution/donut panel
   * Action queue panel
   * Alerts/insights panel
   * Recent activity panel

### Responsive behavior

Match the screenshots:

| Screen size | Required behavior                                                                                                                                                          |
| ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Desktop     | Persistent left navigation, wide dashboard content, summary cards in one row where possible, trend chart left and donut panel right, queue left and alerts/activity right. |
| Tablet      | Left navigation remains visible, cards wrap into fewer columns, charts and panels adapt without overflow.                                                                  |
| Mobile      | No persistent side nav, compact header, cards in two columns where possible, quick actions wrap, charts and panels stack vertically, no horizontal scrolling.              |

Verify against these viewport sizes:

* `390x844`
* `1024x768`
* `1440x1024`
* Also verify the larger doctor/nurse/lab screenshot proportions where applicable.

## Role-specific dashboard content

Use these labels, sections, and actions as the written source of truth from the screenshots. Values must be dynamic and database-backed.

| Role           | Dashboard title                | Summary cards                                                                                                                                            | Quick actions                                                                                                          | Main panels                                                                                                          |
| -------------- | ------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| Super Admin    | Platform command center        | Tenants active, Facilities active, Subscriptions at risk, Module entitlement issues, Security reviews due, Integration/API errors                        | Select tenant/facility, Create tenant, Create facility, Manage subscription, Review audit, Run report                  | Platform signal trend, Tenant mix donut, Platform review queue, Alerts and insights, Recent activity                 |
| Tenant Admin   | Organization overview          | Facilities active, Active users, Module adoption, Organization patient flow, Organization revenue, Staffing exceptions                                   | Create facility, Manage users and roles, Manage subscription, Add staff profile, Run report, Review audit              | Facilities performance trend, Module adoption donut, Organization action queue, Alerts and insights, Recent activity |
| Facility Admin | Facility operations dashboard  | Patient flow today, Appointments today, Active admissions, Occupied beds, Billing exceptions, Operational blockers                                       | Register patient, Book appointment, Check in patient, Create maintenance request, Report equipment issue, Run report   | OPD flow by hour, Bed readiness donut, Facility operations queue, Alerts and insights, Recent activity               |
| Doctor         | Clinical worklist              | Assigned consultations, Consultations in progress, Completed consultations, Active admissions, Critical lab signals, OPD notifications pending attention | Start consultation, Continue consultation, Write clinical note, Record vitals, Order lab, Order radiology              | Consultation trend, Patient acuity mix, Clinical action queue, Critical attention/alerts, Recent activity            |
| Nurse          | Nursing work dashboard         | Active inpatients, Medication administrations today, Transfer queue, Critical lab signals, Discharge pressure, OPD notifications pending attention       | Record vitals, Mark medication administered, Create handover, Route patient                                            | Medication rounds trend, Ward distribution, Nursing action queue, Alerts and insights, Recent activity               |
| Lab            | Laboratory queue               | Lab orders today, Orders in process, Pending results, Critical results, Completed orders                                                                 | Receive sample, Enter lab result, Flag critical lab, Run report                                                        | Sample throughput trend, Test mix donut, Laboratory action queue, Alerts and insights, Recent activity               |
| Pharmacy       | Pharmacy workload              | Medication orders today, Pending dispense workload, Dispensed today, Low stock pressure, Critical stock pressure                                         | Dispense medication, Record pharmacy sale, Receive pharmacy stock, Adjust pharmacy stock, Run report                   | Dispensing throughput trend, Stock pressure donut, Pharmacy action queue, Alerts and insights, Recent activity       |
| Reception      | Front desk dashboard           | Registrations today, Appointment desk queue, No-show pressure, Front billing queue, Appointments today, OPD notifications pending attention              | Register patient, Book appointment, Check in patient, Route patient                                                    | Front desk arrivals trend, Queue mix donut, Front desk action queue, Alerts and insights, Recent activity            |
| Billing        | Billing workbench              | Invoices issued today, Overdue invoices, Open balances, Collections today, Refunds today                                                                 | Create invoice, Receive payment, Process refund, Close shift, Run report                                               | Collections trend, Revenue mix donut, Billing action queue, Alerts and insights, Recent activity                     |
| Operations     | Operations readiness dashboard | Occupied beds, Total beds, Open maintenance requests, Low stock pressure, Housekeeping backlog, Facility readiness                                       | Create maintenance request, Assign maintenance, Update bed readiness, Report equipment issue, Review audit, Run report | Facility readiness trend, Bed readiness mix donut, Operations action queue, Alerts and insights, Recent activity     |
| HR             | Workforce dashboard            | Active staff profiles, Shifts today, Pending leave approvals, Staffing backlog, Unassigned shifts, Attendance rate                                       | Add staff profile, Review leave, Create shift, Publish roster, Approve roster, Run report                              | Staffing coverage trend, Workforce mix donut, Workforce action queue, Alerts and insights, Recent activity           |
| Biomedical     | Biomedical service queue       | Open work orders, Open incidents, Active downtime events, Critical service-risk indicators, High-priority work orders, Assets operational                | Acknowledge work order, Update work order, Report equipment issue, Log calibration, Schedule maintenance, Run report   | Equipment service trend, Asset service status donut, Biomedical service queue, Alerts and insights, Recent activity  |
| Housekeeping   | My cleaning tasks              | Pending tasks, Tasks in progress, Overdue tasks, Tasks completed today, Completion throughput                                                            | Start cleaning task, Complete cleaning task, Mark cleaning blocked                                                     | Cleaning throughput trend, Task mix donut, Housekeeping action queue, Alerts and insights, Recent activity           |
| Ambulance      | Ambulance dispatch board       | Dispatches today, Active trips, Critical emergencies, Fleet available, Fleet out of service                                                              | Dispatch ambulance, Update trip status, Record emergency handover                                                      | Dispatch response trend, Fleet readiness donut, Ambulance action queue, Alerts and insights, Recent activity         |
| Patient Portal | My care dashboard              | My upcoming appointments, My open bills, My prescriptions, My released results, My messages, My profile status                                           | Update own profile, View my care, Contact facility                                                                     | Care activity trend, Care summary donut, My care updates, Alerts and insights, Recent activity                       |

Keep existing support for roles that are already in the codebase but are not represented in the screenshots, such as radiology, managers, mortuary roles, and other valid roles. Do not remove or break them. If no screenshot exists for a role, preserve the existing profile or provide a safe fallback consistent with the existing architecture.

## Data and backend requirements

1. Use the existing dashboard workspace endpoint and service architecture as the primary data source.
2. Extend backend dashboard responses only as needed to support:

   * Summary cards
   * Trend chart data
   * Distribution/donut segments
   * Action queue rows
   * Alerts/insights
   * Recent activity
   * Hero/context metadata
   * Quick action IDs
3. Use targeted Prisma/database queries and aggregates on the backend.
4. Do not count large datasets on the Flutter client.
5. Scope all data correctly by role, tenant, facility, branch, department, staff profile, and patient where applicable.
6. Patient Portal must only show the signed-in patient’s own care data.
7. Prevent cross-tenant, cross-facility, and cross-patient data leakage.
8. Display empty states only when the database truly has no matching records.
9. Avoid static/demo fallback values for authenticated live dashboards.
10. Preserve tenant-context-required behavior where applicable.
11. Update OpenAPI docs if the dashboard response schema changes.

Important backend note: the existing dashboard workspace route currently excludes some roles such as `PATIENT`. Verify the current authorization and route behavior. If Patient Portal is not supported by the current endpoint, implement secure patient dashboard support using the existing dashboard architecture or a patient-safe equivalent endpoint. Do not expose admin/facility data to patients.

## Real-time update requirements

Dashboards must stay current when underlying data changes.

Implement real-time refresh using the existing frontend real-time infrastructure:

* `listenForRealtimeRefresh`
* `RealtimeEventGroups`
* `RealtimeEvents`

Use relevant existing event groups such as appointments, OPD flow, admissions, diagnostics, pharmacy, billing, emergency, operations, HR, housekeeping, biomedical, communications, patient registry, and related workspace events.

Requirements:

1. `homeControllerProvider(request)` must refresh when relevant real-time events arrive.
2. Refresh should be debounced to avoid excessive reloads.
3. Refresh should respect current tenant/facility/branch/patient scope where payload scope is available.
4. Manual refresh button must still work.
5. `generated_at` must update after successful reload.

Only add new real-time event constants/groups if existing ones cannot support the dashboard refresh cleanly.

## Frontend implementation requirements

1. Extend `HomeDashboard` entities and DTOs only as needed for chart/distribution/panel data.
2. Keep `HomeDashboardProfile` role mappings compatible with existing `AppRole` values.
3. Add missing quick-action definitions only when required by the screenshots.
4. Quick actions must navigate to existing valid HMS routes where available.
5. If a destination route does not exist, keep the action disabled or route to the safest existing relevant workspace; do not invent unrelated screens.
6. Reuse existing shared components before creating new ones.
7. If chart widgets are needed, add small, maintainable Flutter widgets in the home feature or shared components only if reusable.
8. Do not introduce a large chart dependency unless the project already uses one.
9. Ensure all dashboard text is user-friendly and does not expose backend/internal terminology.
10. Ensure loading, error, empty, and offline states remain polished.
11. Ensure accessibility labels/semantics for dashboard cards, buttons, and charts.
12. Fix the quick actions overflow/wrapping behavior on mobile.
13. If editing current quick action rendering, verify the existing `skip(4).skip(4)` behavior and correct it if it incorrectly hides actions.

## Backend implementation requirements

1. Keep controller/route/service/repository responsibilities separated.
2. Extend `ROLE_PACKS`, role profiles, and role summary builders consistently.
3. Add or update repository aggregate methods for missing metrics.
4. Ensure dashboard metrics come from real tables already used by the HMS modules.
5. Do not create duplicate dashboard logic in unrelated modules.
6. Preserve existing authorization middleware and strengthen it where needed.
7. Keep response payloads stable where possible to avoid breaking existing frontend code.
8. Add schema validation for any new query or response fields.
9. Keep all currency, percentage, and count formatting consistent with existing dashboard conventions.
10. Ensure dashboard queries are efficient and safe for production-sized datasets.

## Testing and verification

Run and/or add tests as appropriate.

### Frontend

Verify:

* `flutter analyze`
* `flutter test`
* Dashboard DTO parsing for new response fields
* Role-to-dashboard rendering for all screenshot roles
* Responsive rendering at mobile, tablet, and desktop sizes
* No Flutter overflow warnings
* Refresh button reloads data
* Real-time events reload the dashboard
* Empty/error/loading states render correctly

### Backend

Verify:

* Existing backend test command
* Existing lint command if available
* Dashboard workspace endpoint returns correct role-specific payloads
* Role scoping and authorization are correct
* Patient portal cannot access another patient’s data
* Tenant/facility users cannot access data outside their scope
* Aggregates update when database records change
* OpenAPI docs remain valid if updated

### End-to-end verification

Test login and dashboard rendering for:

* Super Admin
* Tenant Admin
* Facility Admin
* Doctor
* Nurse
* Lab
* Pharmacy
* Reception
* Billing
* Operations
* HR
* Biomedical
* Housekeeping
* Ambulance
* Patient

For each role, verify:

1. Correct dashboard title and content.
2. Correct quick actions.
3. Real database values appear.
4. Manual refresh updates values.
5. Relevant database changes update the dashboard through real-time refresh.
6. UI matches the screenshots across desktop, tablet, and mobile.
7. No unrelated role data is visible.

## Scope limits

Do not:

* Rewrite the app shell.
* Rewrite authentication.
* Rewrite routing globally.
* Replace the dashboard workspace architecture.
* Add unrelated modules.
* Refactor unrelated screens.
* Change database schema unless absolutely necessary.
* Hardcode screenshot demo values.
* Modify screenshots or planner files unless required.
* Remove support for existing roles not shown in the screenshots.
* Touch files unrelated to the dashboard implementation.

Modify only the files required for this requested change.

## Delivery requirements

Return a zipped archive containing only the files and folders that were created or updated.

All files must be placed in their correct relative project directories, for example:

* `frontend/lib/...`
* `backend/src/...`
* `backend/docs/...`
* `app-planner/...`

If any files or folders must be deleted or renamed, include one or more `.ps1` PowerShell scripts that safely perform those delete or rename operations.

The `.ps1` scripts must:

* Use correct relative paths.
* Check that paths exist before deleting or renaming.
* Avoid deleting unrelated files.
* Be safe to run from the project root.

Do not include unchanged files in the returned archive.
