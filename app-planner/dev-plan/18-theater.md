# 18 - Theater Module

## Goal
Manage theater/theatre bookings, case readiness, room allocation, procedure flow, anesthesia records, post-op notes, and handover back to ward, ICU, outpatient care, or discharge.

## Source of Truth
- `app-write-up.md`, `opd-flow.md`, and `ipd-flow.md` are the single product/flow source of truth for this implementation plan; backend/frontend planner files and rules are alignment references only.
- Use `app-write-up.md` for theater module responsibilities.
- Use `ipd-flow.md` for inpatient procedure routing, transfers, nursing handover, billing gates, and post-theater movement.
- Use `opd-flow.md` when OPD patients are sent for OPD procedures or theater-related services.
- Use `01-policy.md` for modal actions, permissions, responsive UI, reports, and partial refresh.

## Backend Routes To Align With

Use these route families only after confirming they exist in the current backend router/API contract. If a listed route is absent, record it as a backend gap and do not create a frontend-only endpoint, fake status, or local-only workflow.
- `/api/v1/theatre-cases`
- `/api/v1/anesthesia-records`
- `/api/v1/post-op-notes`
- `/api/v1/procedures`
- `/api/v1/transfer-requests`
- `/api/v1/invoice-items`

## Implementation Scope
1. Theater schedule and case board filtered by date, room, status, urgency, surgeon, anesthetist, and patient location.
2. Case detail with source encounter/admission, procedure, readiness checklist, billing/authorization status, room allocation, anesthesia, procedure notes, post-op notes, and handover.
3. Modal actions for schedule case, assign room/team, update readiness, change status, request supplies, complete handover, and cancel/reschedule.
4. Focused editor or full page only for complex anesthesia/procedure records when a modal would be unsafe.
5. Handoff to ward, ICU, OPD, discharge, or recovery queue based on clinical decision.

## UI and Workflow Contract
| Area | Requirement |
| --- | --- |
| Main screen | Use a clean calendar/board/list hybrid where supported, but keep the default view simple for daily cases. |
| Case row | Show patient, procedure, room, time, status, urgency, readiness, and next action. |
| Readiness | Checklist must be concise and role-aware: clinical, nursing, billing/authorization, room/equipment, consent where supported. |
| Actions | Most status updates must be modal-based with reason/notes where required. |
| Responsiveness | Mobile uses daily list; desktop may show schedule plus case detail. |
| Language | Use clear staff terms such as scheduled, ready, in theater, completed, handed over, cancelled. |

## Reusable Components and Sync Contract
- Reuse `10-workspace-ui.md` workspace layout, shared form fields, shared modal/dialog shell, responsive detail panels, status badges, search/filter/table/list controls, async state views, and permission-gated action patterns before adding module-specific widgets.
- Use or create shared components for: patient context header, theatre case card, procedure schedule list, anesthesia form, intra/post-op note sections, post-op handover modal, and theatre status badge.
- Keep common form layout, field behavior, validation-error display, server-error mapping, loading state, disabled state, and duplicate-submit protection shared; keep module-specific validation and submit mapping in feature controllers/repositories.
- Keep modal actions focused and return users to the same worklist/detail context after success; refresh only backend-backed affected rows, badges, panels, queues, counters, report previews, or form sections.
- Backend/frontend sync required: procedure/theatre case, anesthesia record, post-op notes, charges, pharmacy/lab/radiology requests, IPD/ICU/OPD destination, notifications, and reports must stay linked to the source encounter/admission.
- Do not create duplicate patient, encounter, admission, order, invoice, payment, report, notification, status, or action components when an existing shared pattern can represent the same job.

## Flow Synchronization Rules
- Theater cases must be created from approved clinical/procedure requests, admission context, or authorized OPD procedure flow.
- Billing/authorization gates must not block emergency care where emergency deferral is allowed by policy.
- Starting/completing a case must update theater board, patient location/status, nursing handover, and relevant notifications.
- Post-op destination must update IPD/ICU/OPD/discharge queues without duplicate admissions.

## Access and State Rules
- Surgeons, anesthetists, theater nurses, ward nurses, billing, and admins must see role-appropriate actions only.
- Case notes and anesthesia records require clinical permission.
- After mutation, update only the case row, room schedule slot, patient detail panel, notification badge, and destination queue.

## Reports and Printing
Theater schedule, procedure note, anesthesia record, post-op note, and handover document must use the generated report template from `35-reports-audit.md`.

## Concrete Implementation Contract
| Slice | Required implementation |
| --- | --- |
| Worklist/list data | Use `AppWorkspace` + `AppPaginatedListTable<TheaterCase>` with case number, patient, procedure, urgency, surgeon/team, theater room, scheduled time, anesthesia/post-op status, billing/clearance, and next action. Use `AppSearchBar` for patient, case, procedure, room, status, date, and team filters. |
| Detail/display | Use shared patient context with surgical request, checklist, anesthesia record, intra/post-op notes, handover, billing, and reports. Use full page only for long anesthesia/theater record authoring. |
| CRUD/UI actions | Use `AppDialog` for schedule/reschedule, checklist update, status transition, team assignment, post-op handover, cancellation, and print operation/anesthesia/handover documents. |
| RBAC/ABAC | Gate with clinical permissions, theater manager roles/modules, billing read where needed, facility/theater scope, and backend authorization. |
| Partial refresh | After mutation update only theater row, schedule slot, checklist/status badge, patient detail, IPD/OPD source state, billing badge, and notifications. |

Implementation must reuse `AppWorkspace`, `AppListTable`/`AppPaginatedListTable`, `AppSearchBar`/`AppListTableSearch`, `AppDialog`, shared form fields, `AppStateView`/`AsyncStateScaffold`, and access gates before adding feature-local UI. Do not reload the full workspace after modal actions.


## Done Criteria
- Theater workflow is consistent with OPD/IPD movement.
- Scheduling, readiness, procedure status, and handover are clear and permission-aware.
- Routine actions are modal-based; complex clinical records use focused editors only when needed.
- UI is responsive and not congested.

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
