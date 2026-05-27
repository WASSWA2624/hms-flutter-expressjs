# 17 - ICU Module

## Goal
Manage ICU admission, ICU bed assignment, intensive observations, alerts, ICU rounds, escalation, transfer-out, and ICU discharge readiness while keeping critical information visible and uncluttered.

## Source of Truth
- `app-write-up.md`, `opd-flow.md`, and `ipd-flow.md` are the single product/flow source of truth for this implementation plan; backend/frontend planner files and rules are alignment references only.
- Use `app-write-up.md` for ICU module scope.
- Use `ipd-flow.md` for ICU transfers, bed movement, inpatient orders, billing, and discharge readiness.
- Use `opd-flow.md` when emergency/OPD triage routes a patient directly toward ICU through approved admission flow.
- Use `01-policy.md` for role access, responsive UI, and partial state updates.


## Current Implementation Baseline
- Current frontend status: `frontend/lib/features/icu/` already has DTOs, repository, entities, controller, and `icu_workspace_page.dart` using `AppWorkspace`, `AppListTable`, detail panels, report actions, print templates, and async states.
- Required adjustment: extend the existing ICU workspace and panels; do not create a second critical-care dashboard or custom ICU action shell.
- UI similarity rule: use the same workspace/list/detail/action/report pattern as IPD/clinical, with targeted ICU stay, observation, alert, and transfer-state refresh.

## Backend Routes To Align With

Use these route families only after confirming they exist in the current backend router/API contract. If a listed route is absent, record it as a backend gap and do not create a frontend-only endpoint, fake status, or local-only workflow.
- `/api/v1/icu-stays`
- `/api/v1/icu-observations`
- `/api/v1/critical-alerts`
- `/api/v1/vital-signs`
- `/api/v1/transfer-requests`
- `/api/v1/bed-assignments`

## Implementation Scope
1. ICU patient board showing current ICU patients, bed, priority, alerts, consultant, nurse, pending orders, and transfer readiness.
2. ICU stay detail with patient summary, observations, vitals trend, alerts, orders, nursing tasks, rounds, and transfer/discharge decision.
3. Modal actions for record observation, update vitals, acknowledge alert, add ICU round note, request transfer, and mark readiness.
4. Handoff support between emergency, IPD ward, theater, and ICU.
5. Clear alert display without noisy or duplicated warnings.

## UI and Workflow Contract
| Area | Requirement |
| --- | --- |
| Main screen | Use an ICU board grouped by bed/status and alert level. Keep it scannable. |
| Critical indicators | Highlight urgent alerts and abnormal readings with clear text labels; do not overcrowd rows. |
| Routine actions | Use modals for observations, alert acknowledgement, quick notes, and transfer requests. |
| Detail view | Use sections for summary, observations, orders, nursing, alerts, and transfer/discharge readiness. |
| Responsiveness | Mobile should show one patient at a time; desktop can show board plus detail panel. |
| Safety | Confirmation is required for transfer-out and ICU discharge readiness changes. |

## Reusable Components and Sync Contract
- Reuse `10-workspace-ui.md` workspace layout, shared form fields, shared modal/dialog shell, responsive detail panels, status badges, search/filter/table/list controls, async state views, and permission-gated action patterns before adding module-specific widgets.
- Use or create shared components for: patient context header, ICU stay card, critical observation form, alert banner, ICU status badge, ICU round panel, transfer/discharge readiness modal, and compact trend list.
- Keep common form layout, field behavior, validation-error display, server-error mapping, loading state, disabled state, and duplicate-submit protection shared; keep module-specific validation and submit mapping in feature controllers/repositories.
- Keep modal actions focused and return users to the same worklist/detail context after success; refresh only backend-backed affected rows, badges, panels, queues, counters, report previews, or form sections.
- Backend/frontend sync required: ICU stay, critical observations, alerts, vitals, orders, transfers, billing status, ward/bed location, notifications, and IPD admission state must update without duplicate admissions.
- Do not create duplicate patient, encounter, admission, order, invoice, payment, report, notification, status, or action components when an existing shared pattern can represent the same job.

## Flow Synchronization Rules
- ICU admission/transfer must update IPD/bed assignment state, source queue, and ICU board.
- ICU transfer-out must return the patient to ward, theater, external transfer, or discharge workflow as defined by IPD flow.
- ICU orders must route to lab, radiology, pharmacy, billing, or procedure queues without duplicate ordering screens.
- Alert acknowledgement must update only the alert, patient row, and notification badge.

## Access and State Rules
- ICU views and actions are restricted to permitted clinical, nursing, and admin roles.
- Sensitive ICU alerts should be visible only to users with clinical access.
- After mutation, refresh only the affected ICU stay, alert, observation, bed board cell, and queue counters.
- Do not reload the shell or unrelated ward lists.

## Reports and Printing
ICU observation summaries, ICU stay summaries, transfer notes, and discharge readiness notes must use the generated report template from `35-reports-audit.md`.

## Concrete Implementation Contract
| Slice | Required implementation |
| --- | --- |
| Worklist/list data | Use `AppWorkspace` + `AppListTable<IcuStay>` with patient, ICU bed, acuity, alerts, observation status, consultant, ventilation/support status where available, and next action. Use `AppSearchBar` for patient, bed, acuity, alert status, provider, and date filters. |
| Detail/display | Use shared patient context with ICU observations, critical alerts, rounds, interventions, transfer/discharge readiness, and related orders. |
| CRUD/UI actions | Use `AppDialog` for ICU admission/transfer acceptance, observation entry, alert acknowledgement, round note, transfer readiness, ICU discharge handover, and print ICU summary. |
| RBAC/ABAC | Gate with clinical/emergency/operations permissions, ICU module entitlement, ICU/ward scope, and backend authorization. |
| Partial refresh | After ICU actions update only ICU row, alert badge, observation chart/section, bed status, transfer queue, source IPD row, and notifications. |

Implementation must reuse `AppWorkspace`, `AppListTable`, `AppSearchBar`/`AppListTableSearch`, `AppDialog`, shared form fields, `AppStateView`/`AsyncStateScaffold`, and access gates before adding feature-local UI. Do not reload the full workspace after modal actions.


## Done Criteria
- ICU board is clear, responsive, and action-oriented.
- ICU observations, alerts, and transfers are traceable.
- ICU work remains synchronized with IPD, nursing, pharmacy, lab, radiology, theater, billing, and discharge.
- Access is restricted to permitted users.

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
