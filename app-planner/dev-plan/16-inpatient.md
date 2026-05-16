# 16 - Inpatient Management

## Goal
Manage admitted patients, admission approval, bed allocation, ward location, inpatient progress, ward rounds, transfers, nursing coordination, billing gates, and discharge readiness according to the IPD flow.

## Source of Truth
- Use `app-write-up.md` for inpatient module boundaries.
- Use `ipd-flow.md` as the main workflow reference for admission source, bed management, billing/deposit/insurance, nursing handover, inpatient care loop, transfers, discharge, bed release, and encounter closure.
- Use `opd-flow.md` when admissions originate from OPD consultation or emergency OPD handling.
- Use `01-policy.md` for modal-first actions, permissions, responsive UI, and targeted state refresh.

## Backend Routes To Align With
- `/api/v1/admissions`
- `/api/v1/ipd-flows`
- `/api/v1/bed-assignments`
- `/api/v1/ward-rounds`
- `/api/v1/transfer-requests`
- `/api/v1/wards`
- `/api/v1/beds`

## Implementation Scope
1. Admission queue for requested, approved, waiting bed, reserved, billing deferred, admitted, transfer pending, discharge planned, and discharged patients.
2. Active IPD patient board by ward, room, bed, consultant, status, payer, priority, and pending action.
3. Bed allocation and transfer actions that consume configured wards, rooms, beds, bed classes, and occupancy status.
4. Ward-round capture and inpatient progress summary linked to clinical and nursing modules.
5. IPD handoffs into lab, radiology, pharmacy, theater, ICU, billing, housekeeping, and discharge.
6. Admission detail view that keeps source encounter, current bed, orders, billing status, notes, and discharge readiness together.

## UI and Workflow Contract
| Area | Requirement |
| --- | --- |
| Main screen | Use a role-aware IPD board with simple filters: admission queue, active patients, transfer pending, discharge planned, awaiting clearance. |
| Bed actions | Use modals for reserve bed, assign bed, change bed, transfer, waitlist, and release after discharge. |
| Admission actions | Use modals for approve/reject admission, confirm arrival, mark billing deferred, attach payer/insurance, and assign consultant. |
| Patient detail | Use readable sections for summary, bed, care team, orders, rounds, nursing, billing, transfers, and discharge. Avoid one congested page. |
| Responsiveness | Mobile shows patient list and focused detail pages; desktop can show board plus detail panel. |
| Language | Use staff-facing status labels from IPD flow, not backend enum names. |

## Flow Synchronization Rules
- Every IPD admission must link to an admission request and patient record.
- OPD-to-IPD and emergency-to-IPD transitions must preserve source encounter context.
- Bed state must change consistently: available, reserved, occupied, cleaning, maintenance, blocked.
- Billing/deposit/insurance gates must support flexible timing and emergency billing deferral.
- Transfer requests must update IPD/ICU/theater/ward queues without creating duplicate admissions.
- Discharge planning must start before final billing and bed release.

## Access and State Rules
- Admission desk, bed manager, doctors, nurses, billing, pharmacy, housekeeping, and admins must see only their permitted actions.
- Bed manager actions must not expose clinical documentation unless permitted.
- After bed assignment, transfer, or status update, refresh only the affected admission row, bed board cell, queue count, and patient detail panel.
- Use backend responses for authoritative admission and bed status.

## Reports and Printing
Admission slip, bed assignment note, transfer note, inpatient summary, ward-round summary, and discharge preparation documents must use the generated report template from `35-reports-audit.md`.

## Done Criteria
- IPD board reflects admission, bed, ward, transfer, billing, and discharge status clearly.
- OPD/emergency admissions move into IPD without duplicate patient records.
- Bed allocation and transfer workflows are quick, modal-based, and permission-aware.
- Inpatient actions synchronize with nursing, billing, pharmacy, lab, radiology, theater, ICU, housekeeping, and discharge.

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
