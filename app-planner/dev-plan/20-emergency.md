# 20 - Emergency and Ambulance Module

## Goal
Support emergency arrival, rapid triage, emergency response, ambulance dispatch/trips, stabilization, billing deferral where allowed, and safe handoff into OPD, IPD, ICU, theater, referral, or discharge.

## Source of Truth
- `app-write-up.md`, `opd-flow.md`, and `ipd-flow.md` are the single product/flow source of truth for this implementation plan; backend/frontend planner files and rules are alignment references only.
- Use `app-write-up.md` for emergency and ambulance scope.
- Use `opd-flow.md` for emergency patient arrival, triage, priority doctor routing, OPD service routing, and admission/referral/completion decisions.
- Use `ipd-flow.md` for emergency admission, bed request, billing deferral, ward/ICU transfer, and inpatient handover.
- Use `01-policy.md` for rapid modal actions, permissions, and partial refresh.


## Current Implementation Baseline
- Current frontend status: `frontend/lib/features/emergency/` already has DTOs, repository, entities, controller, and `emergency_workspace_page.dart` using `AppWorkspace`, `AppListTable`, shared dialogs/forms, `AppTriageActionDialog`, report actions, print templates, and async states.
- Required adjustment: extend this emergency workspace for pending ambulance/response actions; do not create a separate emergency triage or ambulance UI shell.
- UI similarity rule: emergency arrival, acuity, dispatch, handoff, and disposition actions must use shared dialogs/triage components and update only affected case, ambulance, queue, and notification state.

## Backend Routes To Align With

Use these route families only after confirming they exist in the current backend router/API contract. If a listed route is absent, record it as a backend gap and do not create a frontend-only endpoint, fake status, or local-only workflow.
- `/api/v1/emergency-cases`
- `/api/v1/triage-assessments`
- `/api/v1/emergency-responses`
- `/api/v1/ambulances`
- `/api/v1/ambulance-dispatches`
- `/api/v1/ambulance-trips`

## Implementation Scope
1. Emergency board for active emergency cases, triage priority, arrival time, response status, current location, and next action.
2. Quick arrival/temporary registration flow for unknown or incomplete patient details.
3. Emergency triage and response actions linked to existing triage/vitals where possible.
4. Ambulance dispatch and trip status with handover into emergency reception.
5. Handoff to OPD consultation, IPD admission, ICU, theater, referral/transfer-out, or emergency discharge.

## UI and Workflow Contract
| Area | Requirement |
| --- | --- |
| Main screen | Use an emergency board with clear priority and elapsed time. Avoid dense administrative fields. |
| Quick actions | Use modals for quick arrival, update priority, record triage, assign clinician, mark response, dispatch ambulance, and handoff. |
| Patient context | Support temporary patient details, then merge/update when registration is completed by permitted staff. |
| Billing | Allow emergency billing deferral where policy/backend supports it; do not force payment before urgent care. |
| Responsiveness | Mobile and tablet must support fast touch entry; desktop shows board plus detail panel. |
| Safety | Critical actions require clear status and next destination. |

## Reusable Components and Sync Contract
- Reuse `10-workspace-ui.md` workspace layout, shared form fields, shared modal/dialog shell, responsive detail panels, status badges, search/filter/table/list controls, async state views, and permission-gated action patterns before adding module-specific widgets.
- Use or create shared components for: emergency arrival form, quick registration modal, patient context header, rapid triage panel, stabilization note form, emergency priority badge, deferred-billing indicator, and handover modal.
- Keep common form layout, field behavior, validation-error display, server-error mapping, loading state, disabled state, and duplicate-submit protection shared; keep module-specific validation and submit mapping in feature controllers/repositories.
- Keep modal actions focused and return users to the same worklist/detail context after success; refresh only backend-backed affected rows, badges, panels, queues, counters, report previews, or form sections.
- Backend/frontend sync required: emergency case, temporary/final patient registration, triage, stabilization, billing deferral, OPD/IPD handover, ambulance context where supported, notifications, and audit logs must remain traceable.
- Do not create duplicate patient, encounter, admission, order, invoice, payment, report, notification, status, or action components when an existing shared pattern can represent the same job.

## Flow Synchronization Rules
- Emergency cases must not create duplicate patient records when final registration is completed.
- Emergency triage should update clinical urgency and doctor/ICU/theater/admission queues.
- Handoff to OPD/IPD/ICU/theater must preserve source emergency case and encounter link.
- Ambulance arrival should create or update emergency reception queue without separate manual duplication.
- Billing deferral should be visible to billing without delaying emergency care.

## Access and State Rules
- Emergency clinicians, triage staff, ambulance staff, reception, billing, and admins see only permitted actions.
- Patient identity updates require proper permission and audit trail.
- After mutation, update only the emergency row, triage badge, ambulance status, destination queue, and notification badge.

## Reports and Printing
Emergency case summary, ambulance trip note, referral/transfer note, and emergency discharge summary must use generated report templates from `35-reports-audit.md`.

## Concrete Implementation Contract
| Slice | Required implementation |
| --- | --- |
| Worklist/list data | Use `AppWorkspace` + `AppListTable<EmergencyCase>` with patient/temporary ID, arrival time, triage category, stabilization status, provider/team, deferred billing flag, disposition, and next action. Use `AppSearchBar` for patient, case, urgency, team, status, and date filters. |
| Detail/display | Use emergency patient context with registration completeness, triage/stabilization, orders, treatments, billing deferral, admission/referral/discharge decision, and handover activity. |
| CRUD/UI actions | Use `AppDialog` for quick registration, triage update, stabilization note, assign team, request order, defer billing, admit, refer, discharge, handover, and emergency summary print. |
| RBAC/ABAC | Gate with `emergency:read`/`emergency:write`, patient/clinical/billing actions as needed, facility scope, and backend authorization. |
| Partial refresh | After emergency mutation update only emergency row, urgency badge, OPD/IPD source/destination queue, billing flag, order queues, reports, and notifications. |

Implementation must reuse `AppWorkspace`, `AppListTable`, `AppSearchBar`/`AppListTableSearch`, `AppDialog`, shared form fields, `AppStateView`/`AsyncStateScaffold`, and access gates before adding feature-local UI. Do not reload the full workspace after modal actions.


## Done Criteria
- Emergency staff can receive, triage, act, and hand off patients quickly.
- Emergency billing deferral and OPD/IPD routing are supported without unsafe delays.
- Ambulance dispatch/trip workflow connects to emergency arrival.
- UI is simple, responsive, and permission-aware.

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
