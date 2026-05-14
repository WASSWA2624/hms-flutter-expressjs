# 12 - OPD and Outpatient Flow

## Goal
Manage appointments, arrivals, queues, service routing, consultation readiness, and outpatient completion.

## Backend Routes To Align With
- `/api/v1/appointments`
- `/api/v1/appointment-participants`
- `/api/v1/appointment-reminders`
- `/api/v1/provider-schedules`
- `/api/v1/availability-slots`
- `/api/v1/visit-queues`
- `/api/v1/opd-flows`
- `/api/v1/follow-ups`
- `/api/v1/referrals`

## Implementation Scope
1. Appointment and walk-in arrival lists.
2. Reception workflow for arrival, check-in, queue assignment, and service routing.
3. OPD queue board for waiting, in-service, completed, referred, admitted, and cancelled states.
4. Provider readiness view that links to triage and clinical consultation.
5. Modal-based updates for arrival, queue movement, reschedule, cancellation, and referral.

## UX and Workflow Rules
- Keep this module self-contained.
- Use the shared workspace pattern from `10-workspace-ui.md`.
- Keep short actions in modals where safe.
- Use full pages only for complex or high-risk workflows.
- Show loading, empty, error, forbidden, offline, and success states.
- Respect tenant, facility, department/unit, role, permission, and module entitlement scope.

## Done Criteria
- Reception can manage OPD without jumping to unrelated modules.
- Queue state is clear.
- Actions are permission-gated.
- OPD handoff into triage/clinical/billing/admission is traceable.

## Rule References
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
- `frontend/app-planner/app-rules/localization_i18n.md`
### Backend rules
- `backend/app-planner/app-rules/api.md`
- `backend/app-planner/app-rules/api-versioning.md`
- `backend/app-planner/app-rules/response-format.md`
- `backend/app-planner/app-rules/auth-security.md`
- `backend/app-planner/app-rules/validation.md`
- `backend/app-planner/app-rules/module-creation.md`

Respect these documents when implementing the step. Do not edit backend or frontend planner files unless a future task explicitly allows it.
