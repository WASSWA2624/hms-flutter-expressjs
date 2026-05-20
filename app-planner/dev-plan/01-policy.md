# 01 - Execution Policy

## Goal
Apply the HOSSPI HMS root development plan without damaging the existing backend, frontend foundation, frontend planner, or backend planner.

Implementation must follow `app-write-up.md`, `opd-flow.md`, and `ipd-flow.md` as the single product/flow source of truth, then align with the frontend/backend rule files for implementation mechanics. The dev-plan is an execution guide only; it must not redefine existing product scope, statuses, roles, endpoints, report patterns, UI patterns, or access rules.

## Hard Boundaries
1. Only app-specific implementation should be added during future implementation tasks.
2. Do not modify backend source code unless a future task explicitly permits backend changes.
3. Do not modify frontend `app-planner/app-rules` or frontend `app-planner/dev-plan`.
4. Do not modify backend `app-planner/app-rules` or backend `app-planner/dev-plan` unless a future task explicitly asks for backend documentation updates.
5. Preserve existing folder paths unless a future implementation task explicitly approves restructuring.
6. Use existing frontend architecture, shared components, shell, theme, localization, routing, networking, state management, and permissions utilities before creating new patterns.
7. Keep features self-contained under their module/feature folders.
8. Keep screens simple, clean, responsive, permission-aware, and not congested.
9. Use modal-based actions for short forms, quick edits, approvals, requests, payments, status changes, confirmations, print options, and exports.
10. Use full-page flows only for long, risky, multi-step, data-heavy, or deep-linkable workflows.
11. Do not print visible UI screens. Print generated information using approved templates.
12. Do not reload the entire UI after a small update. Refresh only the affected data, row, badge, panel, form section, queue, or notification.

## Required Implementation Method
For every future feature task:
1. Read this policy and the relevant root dev-plan file.
2. Read `app-write-up.md` to confirm module scope and boundaries.
3. Read `opd-flow.md` when the task touches outpatient arrival, triage, consultation, lab, radiology, pharmacy, billing, referral, or admission.
4. Read `ipd-flow.md` when the task touches admission, bed allocation, nursing handover, inpatient care, transfers, orders, discharge, or bed release.
5. Read the relevant frontend and backend rules.
6. Inspect the current frontend source and reuse existing correct work, especially shared forms, modals, patient display components, status badges, lists/tables, filters, layout helpers, async states, and permission wrappers.
7. Inspect backend routes, schemas, permissions, feature flags, module entitlements, catalogs, and response contracts before wiring frontend models or actions.
8. Implement only the missing pieces.
9. Add loading, empty, error, forbidden, offline, success, validation, and duplicate-submit states.
10. Confirm responsive behavior on mobile, tablet, desktop, web, and large desktop.
11. Localize all user-facing text.
12. Run quality checks and document blockers.


## Reusable Component Standard
Before creating any new UI, search the frontend for an existing shared component or reusable pattern. Reuse or extend existing components for forms, fields, modals, patient headers, patient summary cards, queue/worklist rows, status badges, search/filter bars, tables/lists, detail panels, billing gates, order/request pickers, report/print actions, confirmation prompts, loading states, empty states, forbidden states, offline states, and error states.

Create a new shared component only when the pattern is used in multiple places or is clearly app-wide. Do not create one-off duplicates for each module. Shared components must handle layout, responsive behavior, accessibility, localization hooks, validation hooks, loading/disabled/error states, and submit-state protection; business rules, API calls, permission checks, and backend mutations remain in feature controllers/repositories.

Patient-related screens must use a shared patient context display for patient name, MRN/number, age/sex where available, alerts/allergies, current encounter/admission, status, ward/bed/location, payer/coverage where relevant, and responsible department/provider.

## Current Shared UI Baseline
The attached frontend already contains the reusable UI baseline for the remaining work:

| Baseline area | Existing shared implementation to reuse |
| --- | --- |
| Workspace shell | `AppWorkspace`, `AppWorkspaceHeader`, `AppWorkspaceSummaryCard`, `AppWorkspaceFilterBar`, `AppWorkspaceDetailPanel`, `AppWorkspacePatientContextHeader`, `AppWorkspaceActivityList`, `showAppWorkspaceActionDialog`, and `showAppWorkspaceDetailDrawer` |
| Lists and filters | `AppListTable`, `AppListTableSearch`, `AppListTableColumnVisibilityController`, `AppSearchBar`, `AppSearchBarFilterValue`, `AppSearchBarFilterGroup`, and `AppSearchBarAction` |
| Forms and dialogs | `AppDialog`, `showAppDialog`, `AppFormShell`, `AppFormSection`, shared fields, `AppConfirmActionDialog`, `AppTextActionDialog`, `AppSelectActionDialog`, and `AppTextInputActionDialog` |
| Actions and permissions | `AppActionPanel`, `AppActionList`, `AppPermissionActionList`, `AppPermissionActionItem`, `AppPermissionActionButton`, `AppAccessGate`, and `AppAccessActionGate` |
| Patient/clinical reuse | `AppPatientDetailDialog`, `AppTriageActionDialog`, `AppVitalsForm`, `AppRecordVitalsDialog`, `AppMedicationAdministrationForm`, `ClinicalActionsPanel`, and shared clinical order/action dialogs |
| Reports/printing | `AppReportActionButton`, `AppReportPreviewPanel`, `AppReportSummaryGrid`, and `PrintFormTemplate` |

Future work must use these names as the default implementation path. Create a new shared widget only after confirming none of these can cover the repeated behavior.

## Mandatory Shared Component Usage Standard
All feature implementation must use the current shared Flutter components before creating local UI. Local widgets are allowed only for feature-specific cells, summaries, or composition that cannot reasonably live in `frontend/lib/shared/`.

| UI need | Required shared anchor |
| --- | --- |
| Module page shell | `AppWorkspace`, `AppWorkspaceHeader`, summary cards, detail panels, and responsive layout helpers from `frontend/lib/shared/layout/` |
| List, table, queue, catalog, registry, report list, audit log | `AppListTable` from `frontend/lib/shared/components/app_list_table.dart`; use `items` for local data or `page: AppPage<T>` with `onPageChanged` for backend pagination |
| Search/filter attached to list data | `AppSearchBar` or `AppListTableSearch`; do not use an ad hoc `AppTextField` as a list search field when the reusable search component fits |
| CRUD, status update, approval, payment, confirmation, print/export options, and short detailed display | `AppDialog` from `frontend/lib/shared/components/app_dialog.dart` |
| Forms | `AppFormShell`, `AppFormSection`, shared field components, and `AppValidators` from `frontend/lib/shared/forms/` and `frontend/lib/shared/components/` |
| Loading, empty, error, forbidden, offline, success | `AppStateView`, `AppStateScaffold`, and existing async-state patterns |
| Route/action visibility | `AppAccessGate`, `AppAccessActionGate`, `AccessRequirement`, and `AppAccessPolicy` |
| Report/print actions | `AppReportActionButton`, `AppReportPreviewPanel`, `AppReportSummaryGrid`, and `PrintFormTemplate`; never visible-screen printing |

Existing pages that use local search fields, local dialog shells, duplicated list/table widgets, or raw permission checks must be normalized during that module's completion step.


## Backend/Frontend Synchronization Standard
Every screen, repository, DTO, status badge, queue action, modal action, notification, report action, and permission gate must map to current backend contracts and the OPD/IPD rules in `opd-flow.md` and `ipd-flow.md`. A workflow is not complete until the frontend route/action, backend endpoint/action, permission key, module entitlement, DTO fields, validation errors, audit event, notification update, and targeted UI refresh agree.

Do not create frontend-only statuses, duplicate encounter/admission records, fake billing clearances, fake order states, or local-only workflow transitions. Use the backend mutation response as the authoritative state for status, amounts, queue position, permissions, timestamps, and report/audit identifiers.

## Modal-First Action Standard
Use modals for routine work so users can complete actions without losing their place in the queue or workspace.

| Use modal for | Use full page for |
| --- | --- |
| Patient lookup, quick registration, edit contact, add allergy, add document note | Long patient profile review or document-heavy workflows |
| Check-in, queue movement, assign doctor, skip triage, cancel visit | Deep-linkable OPD board or large queue dashboards |
| Triage vitals, urgency, route decision | Complex emergency documentation that needs a larger workspace |
| Request lab/radiology/procedure, prescribe, add diagnosis, add note | Full consultation workspace when multiple sections must stay visible |
| Cash payment, refund confirmation, deposit, coverage check | Complex billing reconciliation, claims, or day-close workflows |
| Dispense, collect sample, upload result, report ready, handover, status update | Data-heavy service workspaces that require extended review |
| Print/export options and confirmation | Report builder or multi-section report authoring |

Avoid stacking many modals. If an action needs multiple small steps, use one modal with clear sections or a stepper. If a second confirmation is required, keep it lightweight and return the user to the same workspace after completion.

## Simple UI Standard
- Show only the information needed for the current role and task.
- Use one primary action per screen or patient context.
- Keep lists searchable, filterable, paginated, and easy to scan.
- Prefer clear labels such as `Waiting Doctor`, `Payment Required`, `Results Ready`, and `Ready to Discharge`; avoid raw technical codes in UI.
- Use patient headers consistently: patient name, patient number, age/sex where available, alerts/allergies, encounter/admission number, status, location, payer, and key action.
- Keep forms short and grouped by real-world task.
- Use configured catalogs for lab tests, radiology tests, medicines, services, fees, departments, wards, beds, and users. Do not hard-code these in UI.

## Access Control Standard
Every route, menu item, table row action, modal action, print/export action, notification action, and API call must respect:
- role;
- permission;
- action permission;
- tenant scope;
- facility scope;
- department/unit/ward/bed scope where applicable;
- module subscription and license entitlement;
- backend authorization response.

The frontend may hide or disable disallowed actions for usability, but backend authorization remains mandatory.

## OPD/IPD Synchronization Standard
- OPD work must attach to the current OPD encounter.
- IPD work must attach to the current IPD encounter/admission.
- Admission from OPD or emergency must preserve the source encounter link.
- Lab, radiology, pharmacy, billing, claims, nursing, reports, and notifications must update the relevant encounter/admission state without creating duplicate patient journeys.
- Service orders must route to the correct department queue and return results to the doctor only when review is required by the flow.
- Billing is a flexible gate, not a fixed step; emergency care must support deferred billing where policy allows.

## Reporting and Printing Standard
Reports must be generated from structured data, not by printing the visible UI.

Every printable report should use a shared template with:
1. facility logo;
2. facility name;
3. facility address and contacts;
4. report title;
5. patient and encounter/admission context where applicable;
6. generated date/time and generated-by information;
7. clean section headings and readable spacing;
8. page numbers for multi-page reports;
9. optional clinician/staff signature, stamp, or approval block;
10. footer notes where needed.

The template must support multiple pages, repeatable headers/footers, long tables, clinical summaries, prescriptions, receipts, discharge summaries, referrals, lab/radiology reports, patient reports, and audit/report exports.

## State Update Standard
- Controllers own presentation state and mutations.
- Repositories own data access and mapping.
- UI widgets must not call HTTP directly.
- After a mutation, refresh only the affected provider/state slice.
- Use the backend response as the authoritative current state for status, amounts, queue position, permissions, and timestamps.
- Show optimistic updates only when safe and easy to roll back.

## Real-Time and Targeted UI Synchronization Standard
For this app, “real-time” means staff see backend-backed changes without reloading the whole app, shell, or page.

| Mutation type | Required UI update |
| --- | --- |
| Create record | Insert or refresh only the affected list page/queue segment, summary count, and selected detail if relevant. |
| Edit record | Replace only the affected row/card and detail section using the backend response. |
| Status transition | Update the status badge, allowed next actions, queue position/count, related notification badge, and dependent detail panel only. |
| Payment/billing/claim update | Update the invoice/payment/claim row, billing gate badge, related encounter/admission clearance, and receipt/report preview only. |
| Order/result/dispense update | Update the order/result/dispense row, source encounter/admission panel, doctor-review queue where required, and notification badge only. |
| Report/export/print action | Update report run row, export status, print history, audit log indicator, and preview panel only. |

Implementation rules:
- Use mutation responses as the authoritative updated state whenever the backend returns the changed record or summary.
- If the backend returns only an acknowledgement, fetch the narrowest affected resource instead of refreshing the whole module.
- Preserve search query, filters, sort, pagination, selected row, expanded section, and scroll position after modal actions.
- Use WebSocket events where backend support exists; otherwise use targeted provider invalidation or lightweight polling for active queues.
- Optimistic updates are allowed only when the change is reversible and rollback is implemented.
- If backend does not expose a route, event, permission, status, or field needed for synchronization, document it as a backend gap and do not invent a frontend-only workflow.


## Small-Module Delivery Rule
Each module should be delivered in this order:
1. route and menu entry;
2. permission guard and entitlement guard;
3. empty state and dashboard/list shell;
4. list/table/card view with search, filters, pagination, and row actions;
5. detail drawer, side panel, or detail page;
6. create/edit/action modals or focused form;
7. workflow actions and status updates;
8. generated reports, exports, and print templates after the core workflow works;
9. tests and release checks.

## Quality Commands
Use the applicable frontend checks after source changes:

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Backend checks are required only when a future task explicitly allows backend changes.

## Done Criteria
A step is done when:
- existing correct work is reused;
- missing app-specific behavior is implemented;
- routes, labels, permissions, module entitlements, catalogs, settings, and API endpoints align;
- OPD/IPD transitions update the correct encounter/admission, queues, orders, billing, notifications, and reports;
- UI remains simple, clean, responsive, role-aware, localized, and module-focused;
- modals are used for routine actions and full pages only where justified;
- generated reports use the shared report template;
- targeted state refresh is used instead of unnecessary full reloads;
- tests/static checks pass or blockers are documented.

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
