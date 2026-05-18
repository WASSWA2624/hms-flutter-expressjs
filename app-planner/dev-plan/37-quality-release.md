# 37 - Quality, Validation, and Release Readiness

## Goal
Confirm HOSSPI HMS is safe, usable, consistent, responsive, permission-aware, workflow-synchronized, report-ready, and prepared for staged release.

## Source of Truth
- `app-write-up.md`, `opd-flow.md`, and `ipd-flow.md` are the single product/flow source of truth for this implementation plan; backend/frontend planner files and rules are alignment references only.
- Use `app-write-up.md` to validate product scope and module boundaries.
- Use `opd-flow.md` to validate outpatient arrival, registration, triage, billing, doctor consultation, lab/radiology/pharmacy routing, result review, referral, admission, and completion.
- Use `ipd-flow.md` to validate admission, bed allocation, nursing handover, inpatient care, orders, transfer, billing, discharge, bed release, and encounter closure.
- Use `01-policy.md` to validate modal-first actions, simple UI, responsive behavior, role access, targeted UI refresh, and generated reporting.

## Validation Areas
1. App identity: HOSSPI HMS branding, logo, titles, shell labels, and facility identity.
2. Auth: login, logout, registration policy, change password, session restoration, and route guards.
3. Tenant/facility setup: organization, facility profile, departments, units, rooms, wards, beds, users, roles, and permissions.
4. Demo data: tenant, facility, admins, department users, subscriptions, modules, sample patients, OPD/IPD cases, clinical data, operations data, biomedical data, mortuary data, reports, notifications, and audit samples.
5. Access control: routes, menus, buttons, modals, exports, reports, print actions, notifications, and backend calls.
6. Module workflows: patient registry, OPD, triage, clinical, nursing, inpatient, ICU, theater, discharge, emergency, lab, radiology, physiotherapy, mortuary, pharmacy, billing, claims, HR, rooms/beds, biomedical, operations, housekeeping, subscriptions, notifications, reports, audit, and integrations.
7. OPD flow: emergency, new/walk-in, appointment, triage, billing gates, consultation, orders, pharmacy, result review, admission/referral/completion.
8. IPD flow: admission request, approval, registration, bed request/allocation, billing/deposit/insurance, ward handover, rounds, orders, transfers, discharge, final clearance, bed cleaning, closure.
9. UX: simple screens, clear forms, modal actions where appropriate, no congested dashboards, no technical backend language in staff-facing UI.
10. Responsiveness: mobile, tablet, desktop, web, and large desktop layouts using existing responsive utilities.
11. Accessibility: labels, keyboard navigation, focus, readable contrast, tap/click targets, and screen-reader-friendly controls.
12. Security: no secrets, no sensitive logs, secure session cleanup, safe errors, tenant/facility isolation, and PHI protection.
13. Offline/connectivity: clear online/offline indicators, safe retry states, and unsaved-form protection where needed.
14. Performance: paginated lists, debounced search, lazy rows, targeted state refresh, no unnecessary full reloads, no heavy build work.
15. Localization: no hard-coded user-facing text in feature widgets.
16. Reports/printing: generated multi-page template with facility logo/name/contact, patient/encounter context, clean body, page numbers, and signature blocks.
17. Testing: unit, widget, and integration coverage for core OPD/IPD and module flows.

## OPD/IPD End-to-End Scenarios
| Scenario | Must Validate |
| --- | --- |
| Emergency OPD | Quick arrival, emergency triage, billing deferral where allowed, doctor review, admission/referral/discharge. |
| New OPD patient | Registration, OPD encounter, optional billing, triage, doctor consultation, prescription/pharmacy, completion. |
| Appointment patient | Appointment verification, encounter creation, queue, consultation, orders, completion. |
| OPD lab/radiology loop | Doctor order, billing gate, department workflow, result release, return to doctor, final decision. |
| OPD to IPD | Doctor admission request, admission approval, bed allocation, billing/deposit/insurance, ward handover. |
| Inpatient care | Admission board, ward rounds, nursing tasks, lab/radiology/pharmacy orders, transfer if required. |
| Discharge | Discharge plan, summary, pharmacy, nursing, billing/insurance, documents, patient exit, bed cleaning, closure. |

## Mandatory Completion Audit
Before declaring the app complete, audit every route and module against this table:

| Audit area | Must pass |
| --- | --- |
| Shared UI reuse | List data uses `AppListTable`/`AppPaginatedListTable`; list search uses `AppSearchBar`/`AppListTableSearch`; dialogs use `AppDialog`; forms use shared fields and form shell; pages use `AppWorkspace`/responsive layout. |
| App coverage | Existing feature folders are completed and missing modules are added with the same `data/domain/presentation` architecture. |
| No congestion | Dashboards use a small number of summary cards and route to focused worklists; details are in panels/modals/sections, not one crowded screen. |
| Real-time behavior | Mutations update affected rows, detail panels, badges, queues, notifications, and report previews only; no whole-app reload or unnecessary full page reset. |
| Backend sync | Every visible action maps to backend route, DTO fields, permission, validation, status transition, audit/notification/report impact, and database-backed state. |
| RBAC/ABAC | Unauthorized users cannot see restricted routes, shell destinations, rows, fields, row actions, modals, reports, exports, notifications, or PHI details. |
| AppDialog uniformity | CRUD, status, approval, confirmation, payment, print/export, and short detailed-display actions use the same dialog shell, close behavior, button hierarchy, validation display, and submit-state protection. |
| Backend edit discipline | Backend changes are absent unless a documented blocking contract gap exists; any backend change must be minimal and directly tied to required functionality. |


## UI Consistency Checklist
- Use existing shell, routes, theme, shared components, responsive layouts, forms, tables, modals, and state views.
- Do not redesign screens that already exist and work correctly.
- Use modal/drawer actions for routine actions.
- Use full-page editors only for complex clinical, discharge, theater, ICU, payroll, or report-building tasks that cannot safely fit in a modal.
- Keep search, filters, lists, rows, patient headers, status badges, and action buttons consistent across modules.
- Ensure every mutation updates only the affected UI pieces.

## Required Frontend Commands
Run from `frontend/` after implementation work:

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Add platform-specific build checks when release work begins.

## Backend Validation
Backend validation is required only when a future task explicitly permits backend changes. For the current root planner scope, backend is read-only.

## Release Checklist
- Feature flags and subscription entitlements are configured.
- Default/demo accounts are not exposed in production builds.
- Production secrets are not committed.
- Error messages are safe and localized.
- Audit-sensitive workflows are traceable.
- Reports, exports, print previews, and downloads are permission-gated.
- OPD/IPD flows pass end-to-end scenario tests.
- User documentation and setup notes are updated.

## Reusable Components and Sync Contract
- Reuse `10-workspace-ui.md` workspace layout, shared form fields, shared modal/dialog shell, responsive detail panels, status badges, search/filter/table/list controls, async state views, and permission-gated action patterns before adding module-specific widgets.
- Use or create shared components for: component inventory checklist, duplicate-widget audit, reusable form/modal/patient-display review, backend/frontend contract checklist, OPD/IPD scenario validation cards, and responsive test matrix.
- Keep common form layout, field behavior, validation-error display, server-error mapping, loading state, disabled state, and duplicate-submit protection shared; keep module-specific validation and submit mapping in feature controllers/repositories.
- Keep modal actions focused and return users to the same worklist/detail context after success; refresh only backend-backed affected rows, badges, panels, queues, counters, report previews, or form sections.
- Backend/frontend sync required: final validation must confirm routes, DTOs, statuses, permissions, entitlements, notifications, reports, audit events, and OPD/IPD state transitions agree across frontend and backend.
- Do not create duplicate patient, encounter, admission, order, invoice, payment, report, notification, status, or action components when an existing shared pattern can represent the same job.

## Done Criteria
- All implemented modules pass static checks and tests.
- Known backend gaps are documented without inventing frontend-only workflows.
- The app can be demonstrated using safe demo data.
- OPD/IPD flows are synchronized across frontend state, backend status, queues, billing gates, orders, notifications, and reports.
- UI is simple, responsive, role-aware, uniform, and not congested.
- Production release blockers are listed clearly.

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
