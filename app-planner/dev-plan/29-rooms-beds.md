# 29 - Rooms, Wards, and Beds Module

## Goal
Manage facility care spaces, wards, rooms, beds, bed classes, bed readiness, bed assignments, reservations, transfers, cleaning status, maintenance blocks, and occupancy visibility.

## Source of Truth
- Use `app-write-up.md` for rooms/wards/beds scope.
- Use `ipd-flow.md` for bed management, admission dependency, transfer, cleaning, maintenance, release, and bed status behavior.
- Use `opd-flow.md` only where OPD/admission handoff needs bed availability visibility.
- Use `01-policy.md` for modal actions, role access, responsive UI, and partial state updates.

## Backend Routes To Align With
- `/api/v1/rooms`
- `/api/v1/wards`
- `/api/v1/beds`
- `/api/v1/bed-assignments`
- `/api/v1/facilities`
- `/api/v1/departments`
- `/api/v1/units`

## Implementation Scope
1. Ward/room/bed board showing availability, reserved, occupied, cleaning, maintenance, blocked, and out-of-service states where supported.
2. Configured space management for wards, rooms, beds, classes, departments, units, and facility locations.
3. Modal actions for add/edit room or bed, reserve bed, assign bed, transfer bed, block/unblock, send to cleaning, mark available, and mark maintenance.
4. Occupancy filters by facility, ward, room type, class, gender policy, isolation need, and readiness where backend supports them.
5. Synchronization with IPD, ICU, housekeeping, operations, and discharge.

## UI and Workflow Contract
| Area | Requirement |
| --- | --- |
| Main screen | Use a simple bed board with clear status colors/labels and filters. Avoid exposing technical occupancy rules in the default view. |
| Bed detail | Show bed identity, ward/room, class, status, current patient/reservation, cleaning/maintenance notes, and history where permitted. |
| Actions | Use modals for reserve, assign, transfer, release, clean, block, and maintenance updates. |
| Responsiveness | Mobile uses grouped ward lists; desktop may use board/grid plus detail panel. |
| Integration | Bed board should be reused by IPD instead of creating a separate bed UI. |

## Flow Synchronization Rules
- Admission bed requests must consume this module’s bed availability and reservation state.
- Discharge exit must move bed to cleaning and notify housekeeping where supported.
- Cleaning completion must move bed back to available unless blocked/maintenance applies.
- Maintenance blocks must be visible to IPD/ICU admission and operations.
- Transfers must preserve bed assignment history.

## Access and State Rules
- Bed managers/admins manage bed status and assignment.
- Nurses and doctors may view bed/location state where permitted but should not get bed admin controls unless allowed.
- After mutation, refresh only the bed cell, ward occupancy summary, active admission row, housekeeping task, and notification badge affected.

## Reports and Printing
Bed occupancy, ward census, bed assignment history, cleaning readiness, and maintenance block reports must use generated report templates from `35-reports-audit.md`.

## Done Criteria
- Bed board is clear, live, and synchronized with IPD/ICU/discharge/housekeeping.
- Bed actions are modal-based and permission-aware.
- Facility structures are consumed from existing tenant/facility configuration.
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
