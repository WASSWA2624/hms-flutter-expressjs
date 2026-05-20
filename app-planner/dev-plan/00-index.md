# 00 - Root Development Plan Index

## Purpose
This root development plan defines the chronological implementation order for **HOSSPI HMS** (**HOSSPI Hospital Management System**). It is focused on completing the Flutter frontend on top of the existing backend contracts and existing Flutter foundation.

The plan must guide implementation only. It must not redefine product scope, OPD flow, IPD flow, backend rules, frontend rules, access rules, report standards, or screen patterns that are already defined elsewhere.

## Source-of-Truth and Alignment Hierarchy
Use these references in this order whenever there is overlap:

| Priority | Reference | Purpose |
| --- | --- | --- |
| 1 | `app-planner/app-write-up.md` | Single product-scope source for what HOSSPI HMS does, module responsibilities, module boundaries, demo expectations, access expectations, and UX expectations. |
| 2 | `app-planner/opd-flow.md` | Single outpatient-flow source for arrival, registration, triage, billing gates, consultation, lab/radiology/pharmacy routing, result review, admission/referral, and OPD completion. |
| 3 | `app-planner/ipd-flow.md` | Single inpatient-flow source for admission, bed allocation, billing/deposit/insurance, ward handover, nursing admission, inpatient care, orders, transfer, discharge, bed release, and IPD closure. |
| 4 | Current backend and frontend contracts/rules | Alignment references for how to implement the three source files without inventing incompatible routes, permissions, statuses, components, or workflows. |
| 5 | Root `dev-plan` files | Execution sequence and module delivery scope only. |

A dev-plan file must never create a new workflow, UI pattern, data model, access model, report format, status, component family, or endpoint when it is already defined by a higher-priority reference. If a backend/frontend contract is missing, document the gap instead of inventing a frontend-only workaround.

## Naming Standard
All root `dev-plan` files must use short, descriptive, numeric names:

```text
00-name.md
01-name.md
02-name.md
03-name.md
```

Do not use suffixes such as `01A-name.md`, `01B-name.md`, or `01C-name.md`.

## Replacement Note
The previous root `dev-plan` used long names and letter suffixes. Replace the previous root `app-planner/dev-plan` contents with this numbered plan so obsolete letter-suffix files do not remain beside the new files.

## Chronological Plan
| Step | File | Focus |
| --- | --- | --- |
| 00 | `00-index.md` | Plan index, source-of-truth order, and chronological delivery order |
| 01 | `01-policy.md` | Execution policy, safe-change boundaries, modal-first UI, reports, and synchronization rules |
| 02 | `02-codebase.md` | Current backend/frontend foundation map and no-reinvention rules |
| 03 | `03-brand-shell.md` | HOSSPI HMS identity, logo, app shell, and screen shell |
| 04 | `04-api-data.md` | API contracts, repositories, DTOs, backend alignment, and targeted state updates |
| 05 | `05-auth.md` | Authentication, session, user avatar, user dropdown, and protected routing |
| 06 | `06-settings.md` | Theme, language, app bar indicators, user preferences, and general settings |
| 07 | `07-tenant-facility.md` | Tenant, facility, facility identity, departments, units, rooms, wards, and beds setup |
| 08 | `08-access-control.md` | RBAC, ABAC, permissions, module entitlements, action guards, and role-scoped UI |
| 09 | `09-demo-seed.md` | Default tenant, facility, admins, department users, catalog seed data, and demo flow data |
| 10 | `10-workspace-ui.md` | Reusable module workspace, modal actions, nested action pattern, responsive layout, and partial refresh |
| 11 | `11-patients.md` | Patient registry, lookup, demographics, identifiers, documents, and patient actions |
| 12 | `12-opd-flow.md` | Appointments, arrivals, queues, OPD encounter, billing gates, routing, and outpatient completion |
| 13 | `13-triage.md` | OPD triage, vitals, urgency, risk flags, and routing decision |
| 14 | `14-clinical.md` | Clinical consultation, notes, diagnosis, orders, prescriptions, result review, referral, and admission request |
| 15 | `15-nursing.md` | Nursing workflow, observations, medication administration, care tasks, handovers, and ward activity |
| 16 | `16-inpatient.md` | Admissions, beds, IPD encounter, ward rounds, inpatient progress, and transfers |
| 17 | `17-icu.md` | ICU stays, critical observations, alerts, ICU rounds, transfer, and ICU discharge readiness |
| 18 | `18-theater.md` | Theater/theatre workflow, anesthesia, post-op, and handover |
| 19 | `19-discharge.md` | Discharge planning, summary, clearance, instructions, patient exit, and episode closure |
| 20 | `20-emergency.md` | Emergency and ambulance workflow, urgent triage, stabilization, deferred billing, and handover |
| 21 | `21-lab.md` | Laboratory catalog, orders, samples, results, quality control, and result routing |
| 22 | `22-radiology.md` | Radiology/imaging catalog, orders, imaging studies, reports, assets, and result routing |
| 23 | `23-pharmacy.md` | Formulary, prescriptions, pharmacy orders, dispensing, returns, stock visibility, and medication handoff |
| 24 | `24-billing.md` | Billing gates, cashier workflow, invoices, payments, receipts, refunds, deposits, and reconciliation |
| 25 | `25-claims.md` | Insurance, coverage, pre-authorization, claims, approvals, rejection handling, and payer tracking |
| 26 | `26-physiotherapy.md` | Physiotherapy workflow where supported by backend contracts |
| 27 | `27-mortuary.md` | Mortuary cases, storage, custody, viewing, post-mortem, release, and billing events |
| 28 | `28-hr.md` | Human resources, staff, assignments, availability, shifts, leave, rosters, and payroll |
| 29 | `29-rooms-beds.md` | Rooms, wards, beds, bed status, bed readiness, bed assignment, cleaning, and occupancy |
| 30 | `30-biomedical.md` | Biomedical equipment registry, maintenance, calibration, incidents, downtime, recalls, and disposal |
| 31 | `31-operations.md` | Electrical, plumbing, water, power, HVAC, maintenance, safety, and operational readiness |
| 32 | `32-housekeeping.md` | Cleaning, schedules, room/bed turnover, ward cleaning, sanitation readiness, and housekeeping requests |
| 33 | `33-subscriptions.md` | Plans, subscriptions, module subscriptions, licenses, invoices, and entitlement visibility |
| 34 | `34-notifications.md` | Notifications, conversations, unread indicators, workflow alerts, and staff action routing |
| 35 | `35-reports-audit.md` | Dashboards, generated reports, print templates, exports, audit, PHI logs, and compliance evidence |
| 36 | `36-integrations.md` | API keys, integration configuration, logs, webhooks, and interoperability |
| 37 | `37-quality-release.md` | Validation, testing, release readiness, and final synchronized checklist |

## Current Implementation Strategy
- Do not rebuild the backend.
- Do not rebuild the Flutter starter foundation.
- Inspect existing frontend files before implementation and reuse working routes, shell, theme, shared components, forms, state controllers, network helpers, permissions, and localization.
- Implement only missing app-specific screens, routes, models, repositories, controllers, forms, modal actions, report templates, exports, and module workspaces.
- Align backend routes, permissions, feature flags, module subscriptions, catalogs, settings, and response formats with `app-write-up.md`, `opd-flow.md`, and `ipd-flow.md`; do not invent frontend-only backend behavior.
- Keep each module small enough to implement, test, and review independently.
- Treat steps `01` through `13` as foundation and implemented/partly implemented flow work. Future work must extend them, not replace them.
- Treat steps `14` through `37` as continuation work that must connect cleanly to patient registry, OPD, triage, clinical, IPD, billing, reports, notifications, and access control.

## Global UI Contract
- Keep screens simple, clean, readable, and fast for busy hospital staff.
- Prefer a searchable worklist, a readable detail area, and clear role-based actions.
- Use modal actions for short work such as registration edits, triage capture, order requests, payments, status changes, approvals, cancellations, printing, and confirmations.
- Use full pages only for long, risky, highly detailed, or deep-linkable workflows such as complex clinical documentation, discharge summary authoring, theater records, ICU records, claims review, payroll, and report building.
- Avoid technical backend language in staff-facing UI.
- Do not reload the whole app or whole screen after small updates. Refresh only the affected row, badge, panel, queue, notification count, report preview, or form section.
- Keep mobile, tablet, desktop, web, and large desktop layouts responsive using existing responsive utilities.

## Reusable Component Mandate
- Reuse the existing frontend shell, responsive layout, theme, localization, state, networking, permission, form, modal, and async-state foundations before adding any new UI.
- Any form, modal, patient display, queue row, status badge, search/filter bar, table/list, detail panel, billing gate, order request, report action, or confirmation pattern used in more than one screen must be implemented as a reusable component or extended from an existing reusable component.
- Do not create duplicate feature-specific widgets for the same visual or behavioral job. New shared components are allowed only when the existing shared set cannot cover a repeated app-wide need.
- Shared components must stay business-logic-light: they provide layout, state display, accessibility, responsive behavior, validation hooks, and submit-state handling; feature repositories/controllers own business rules and API calls.
- Patient-facing context must use one shared patient display pattern across OPD, triage, clinical, nursing, IPD, ICU, theater, discharge, emergency, lab, radiology, pharmacy, billing, claims, physiotherapy, and mortuary workflows.
- Backend and frontend changes must remain synchronized for routes, DTOs, statuses, permissions, module entitlements, notifications, reports, audit events, and OPD/IPD encounter/admission state.

## 2026-05-20 Implementation Tightening
The current `frontend`, `backend`, and root `app-planner` zip contents were reviewed together. These constraints now apply to every step in this root plan:

| Area | Updated rule |
| --- | --- |
| Existing Flutter foundation | Extend the current app shell, route guards, theme, localization, API client, permission gates, `AppWorkspace`, `AppListTable`, `AppDialog`, shared forms, shared action panels, report/print components, and state views. Do not replace them. |
| Existing feature work | Continue the existing feature folders for auth, profile, settings, tenant/facility setup, patients, OPD, emergency, clinical, nursing, IPD, ICU, theater, discharge, lab, radiology, pharmacy, billing, and claims. Treat them as partial implementations to complete, not prototypes to discard. |
| Missing feature work | Add remaining feature folders only where absent: access-control admin screens, HR, rooms/beds, biomedical, operations, housekeeping, subscriptions, notifications/communications, reports/audit, integrations, physiotherapy, and mortuary. Use the same feature-first structure and shared components. |
| Lists and search | Every list, queue, table, catalog, log, report list, and registry must use `frontend/lib/shared/components/app_list_table.dart` and `frontend/lib/shared/components/app_search_bar.dart` through `AppListTable` with `items` or `page: AppPage<T>`, `AppListTableSearch`, `AppSearchBar`, `AppSearchBarFilterValue`, and `AppListTableColumnVisibilityController`. |
| Modals and details | Routine CRUD, status changes, approvals, confirmations, payments, print/export options, and short detailed display must use `AppDialog`, `showAppDialog`, or `showAppWorkspaceActionDialog`; tablet/desktop detail drawers should use the existing workspace drawer/panel helpers. |
| App uniformity | All module workspaces must compose `AppWorkspace`, shared form fields, `AppStateView`/`AsyncStateScaffold`, `AppAccessGate`/`AppAccessActionGate`, and existing responsive utilities before adding local widgets. |
| Real-time UI | A backend mutation must update only the affected row, card, badge, queue count, detail panel, notification count, report preview, or form section. Preserve current filters, pagination, selected row, and scroll position. |
| Backend changes | Backend files remain read-only unless a current backend gap blocks required functionality. If a gap blocks the UI, document the exact route/schema/permission/status mismatch before making a minimal backend change in a future authorized task. |
| Access control | Users must see only routes, menu entries, rows, actions, modals, exports, reports, and notifications allowed by RBAC, ABAC, tenant/facility context, and module entitlement. Backend authorization remains final. |


## Obsolete Root Dev-Plan Files To Remove When Replacing The Folder
- `app-planner/dev-plan/index.md`
- `app-planner/dev-plan/00-execution-policy.md`
- `app-planner/dev-plan/01-app-identity-branding-and-foundation.md`
- `app-planner/dev-plan/02-backend-contract-and-data-foundation.md`
- `app-planner/dev-plan/03-authentication-session-and-user-menu.md`
- `app-planner/dev-plan/04-general-settings-and-shell-experience.md`
- `app-planner/dev-plan/05-tenant-facility-setup-and-access-control.md`
- `app-planner/dev-plan/06-workspace-patterns-and-shared-ui.md`
- `app-planner/dev-plan/07-patient-registry-opd-triage-outpatient-flow.md`
- `app-planner/dev-plan/07A-patient-registry.md`
- `app-planner/dev-plan/07B-opd-triage.md`
- `app-planner/dev-plan/07C-opd-outpatient-flow-management.md`
- `app-planner/dev-plan/08-clinical-nursing-inpatient-and-discharge.md`
- `app-planner/dev-plan/08A-clinical-module.md`
- `app-planner/dev-plan/08B-nursing-module.md`
- `app-planner/dev-plan/08C-inpatient-management.md`
- `app-planner/dev-plan/08D-icu-module.md`
- `app-planner/dev-plan/08E-theater-module.md`
- `app-planner/dev-plan/08F-discharge-module.md`
- `app-planner/dev-plan/09-pharmacy-billing-insurance-and-claims.md`
- `app-planner/dev-plan/09A-pharmacy-module.md`
- `app-planner/dev-plan/09B-billing-and-cashier-module.md`
- `app-planner/dev-plan/09C-insurance-and-claims-module.md`
- `app-planner/dev-plan/10-hr-rooms-biomedical-and-operations.md`
- `app-planner/dev-plan/10A-hr-module.md`
- `app-planner/dev-plan/10B-rooms-wards-and-beds.md`
- `app-planner/dev-plan/10C-biomedical-module.md`
- `app-planner/dev-plan/10D-operations-module.md`
- `app-planner/dev-plan/10E-housekeeping-module.md`
- `app-planner/dev-plan/11-notifications-reports-audit-and-integrations.md`
- `app-planner/dev-plan/11A-notifications-and-alerts.md`
- `app-planner/dev-plan/11B-reports-dashboards-and-audit.md`
- `app-planner/dev-plan/11C-integrations.md`
- `app-planner/dev-plan/12-final-validation-and-release-readiness.md`

## Rule References

### Product and flow references
- `app-planner/app-write-up.md`
- `app-planner/opd-flow.md`
- `app-planner/ipd-flow.md`
- `app-planner/dev-plan/01-policy.md`
- `app-planner/dev-plan/10-workspace-ui.md`

### Frontend rules
- `frontend/app-planner/app-rules/architecture.md`
- `frontend/app-planner/app-rules/project_structure.md`
- `frontend/app-planner/app-rules/navigation.md`
- `frontend/app-planner/app-rules/reusable_components.md`
- `frontend/app-planner/app-rules/responsive_adaptive_design.md`
- `frontend/app-planner/app-rules/state_management.md`
- `frontend/app-planner/app-rules/network_api.md`
- `frontend/app-planner/app-rules/permissions.md`
- `frontend/app-planner/app-rules/forms.md`
- `frontend/app-planner/app-rules/search_filtering.md`
- `frontend/app-planner/app-rules/pagination_data_tables.md`
- `frontend/app-planner/app-rules/localization_i18n.md`
- `frontend/app-planner/app-rules/performance.md`
- `frontend/app-planner/app-rules/accessibility.md`

### Backend rules
- `backend/app-planner/app-rules/api.md`
- `backend/app-planner/app-rules/api-versioning.md`
- `backend/app-planner/app-rules/response-format.md`
- `backend/app-planner/app-rules/auth-security.md`
- `backend/app-planner/app-rules/validation.md`
- `backend/app-planner/app-rules/module-creation.md`

Respect these documents when implementing the step. Do not edit backend or frontend planner files unless a future task explicitly allows it.
