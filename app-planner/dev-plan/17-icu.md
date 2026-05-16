# 17 - ICU Module

## Goal
Manage ICU admission, ICU bed assignment, intensive observations, alerts, ICU rounds, escalation, transfer-out, and ICU discharge readiness while keeping critical information visible and uncluttered.

## Source of Truth
- Use `app-write-up.md` for ICU module scope.
- Use `ipd-flow.md` for ICU transfers, bed movement, inpatient orders, billing, and discharge readiness.
- Use `opd-flow.md` when emergency/OPD triage routes a patient directly toward ICU through approved admission flow.
- Use `01-policy.md` for role access, responsive UI, and partial state updates.

## Backend Routes To Align With
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
