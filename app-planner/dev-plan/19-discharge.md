# 19 - Discharge Module

## Goal
Prepare, coordinate, print, and complete safe discharge using clinical summary, medicines, nursing clearance, billing/insurance clearance, follow-up, document handover, patient exit, and bed release.

## Source of Truth
- `app-write-up.md`, `opd-flow.md`, and `ipd-flow.md` are the single product/flow source of truth for this implementation plan; backend/frontend planner files and rules are alignment references only.
- Use `app-write-up.md` for discharge module scope.
- Use `ipd-flow.md` as the primary discharge workflow reference.
- Use `opd-flow.md` for OPD completion, referral, prescription, and follow-up summaries.
- Use `01-policy.md` and `35-reports-audit.md` for modal actions, permissions, partial refresh, and generated print templates.


## Current Implementation Baseline
- Current frontend status: `frontend/lib/features/discharge/` already has DTOs, repository, entities, controller, and `discharge_workspace_page.dart` using `AppWorkspace`, `AppListTable`, shared action dialogs, clearance panels, report actions, print templates, and async states.
- Required adjustment: extend this discharge workspace; do not build a separate discharge board, clearance checklist family, or print template.
- UI similarity rule: use shared clearance/detail panels, `showAppWorkspaceActionDialog`, `AppReportActionButton`, `PrintFormTemplate`, and targeted admission/discharge/clearance refresh.

## Backend Routes To Align With

Use these route families only after confirming they exist in the current backend router/API contract. If a listed route is absent, record it as a backend gap and do not create a frontend-only endpoint, fake status, or local-only workflow.
- `/api/v1/discharge-summaries`
- `/api/v1/admissions`
- `/api/v1/encounters`
- `/api/v1/invoices`
- `/api/v1/invoice-items`
- `/api/v1/payments`
- `/api/v1/refunds`
- `/api/v1/pharmacy-orders`
- `/api/v1/bed-assignments`
- `/api/v1/housekeeping-tasks`

## Implementation Scope
1. Discharge worklist for planned, summary pending, pharmacy pending, nursing pending, billing pending, insurance pending, documents ready, and completed discharges.
2. Discharge detail with patient/admission context, diagnosis, treatment summary, medicines, instructions, follow-up, pending orders, checklist, billing, and documents.
3. Modal actions for start discharge plan, assign tasks, update checklist, request final billing, request pharmacy discharge medicines, mark document ready, confirm patient exit, and complete discharge.
4. Focused summary editor for discharge summary when content is too long for a modal.
5. Print/preview generated discharge documents using the shared template.

## UI and Workflow Contract
| Area | Requirement |
| --- | --- |
| Main screen | Use a discharge queue with clear next action, pending blocker, patient, ward/bed, consultant, and target discharge time. |
| Summary editor | Keep sections simple: final diagnosis, treatment given, medicines, advice, follow-up, warning signs, doctor/nurse signature blocks. |
| Clearance | Show checklist cards for doctor, nursing, pharmacy, billing, insurance, documents, and bed release. |
| Actions | Routine clearance updates use modals; final completion requires confirmation. |
| Printing | Print generated documents only, never the UI screen. |
| Responsiveness | Mobile should focus on checklist and summary; desktop can show queue plus detail panel. |

## Reusable Components and Sync Contract
- Reuse `10-workspace-ui.md` workspace layout, shared form fields, shared modal/dialog shell, responsive detail panels, status badges, search/filter/table/list controls, async state views, and permission-gated action patterns before adding module-specific widgets.
- Use or create shared components for: patient context header, discharge checklist, discharge summary form, clearance panel, pharmacy handoff panel, billing clearance card, instruction/follow-up form, and exit confirmation modal.
- Keep common form layout, field behavior, validation-error display, server-error mapping, loading state, disabled state, and duplicate-submit protection shared; keep module-specific validation and submit mapping in feature controllers/repositories.
- Keep modal actions focused and return users to the same worklist/detail context after success; refresh only backend-backed affected rows, badges, panels, queues, counters, report previews, or form sections.
- Backend/frontend sync required: discharge plan, summary, medicines, nursing clearance, billing/insurance clearance, reports, patient exit, bed release, housekeeping task, and episode closure must update as one discharge workflow.
- Do not create duplicate patient, encounter, admission, order, invoice, payment, report, notification, status, or action components when an existing shared pattern can represent the same job.

## Flow Synchronization Rules
- Discharge planning may start before all services are complete, but final discharge must respect required clearance rules.
- Pharmacy discharge medicines must route to pharmacy and billing where required.
- Billing/insurance finalization must update discharge readiness without closing clinical summary prematurely.
- Patient exit must trigger bed release/cleaning and notify housekeeping/bed management.
- Completed discharge must close the admission only after required clinical and financial steps are complete.

## Access and State Rules
- Doctors complete clinical summary and discharge decision.
- Nurses complete nursing discharge checklist and handover.
- Pharmacy clears medicines.
- Billing/insurance clears final financial status.
- Discharge desk or permitted role completes patient exit/document handover.
- After a clearance update, refresh only the checklist item, discharge row, admission status, bed status, and notification counters affected.

## Reports and Printing
Discharge summary, prescription, follow-up note, billing clearance, patient report, and discharge instruction sheet must use the multi-page report template from `35-reports-audit.md` with facility header, logo, contacts, page numbers, and signature blocks.

## Concrete Implementation Contract
| Slice | Required implementation |
| --- | --- |
| Worklist/list data | Use `AppWorkspace` + `AppListTable<DischargeCase>` with patient, admission, ward/bed, discharge stage, pharmacy/nursing/billing/claims clearance, summary status, and next action. Use `AppSearchBar` for patient, admission, ward, status, clearance, provider, and date filters. |
| Detail/display | Use shared inpatient patient context with discharge plan, clinical summary, medicines, instructions, nursing clearance, billing/insurance clearance, documents, exit, and bed cleaning state. |
| CRUD/UI actions | Use `AppDialog` for clearance updates, discharge instruction edits, medicine handoff, billing clearance check, final exit confirmation, print package options, and bed release request. Use full page for complex discharge summary authoring. |
| RBAC/ABAC | Gate with clinical, pharmacy, billing, operations, and ward permissions plus active inpatient entitlement and backend authorization. |
| Partial refresh | After action update only discharge row, clearance badges, source IPD admission, bed cleaning queue, pharmacy/billing queues, report preview, and notifications. |

Implementation must reuse `AppWorkspace`, `AppListTable`, `AppSearchBar`/`AppListTableSearch`, `AppDialog`, shared form fields, `AppStateView`/`AsyncStateScaffold`, and access gates before adding feature-local UI. Do not reload the full workspace after modal actions.


## Done Criteria
- Discharge is treated as a workflow, not a single button.
- Staff can see exactly what is pending and who owns it.
- Printed discharge documents are professional, multi-page safe, and generated from data.
- Admission, billing, pharmacy, nursing, housekeeping, and bed statuses remain synchronized.

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
