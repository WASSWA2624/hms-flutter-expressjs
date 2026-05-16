# 26 - Physiotherapy Module

## Goal
Manage physiotherapy referrals, assessments, therapy plans, treatment sessions, attendance, progress notes, exercise instructions, outcomes, billing gates, and clinical review.

## Source of Truth
- Use `app-write-up.md` for physiotherapy scope.
- Use `opd-flow.md` for OPD referral/service routing and completion.
- Use `ipd-flow.md` for inpatient therapy orders, ward coordination, discharge planning, and billing.
- Use `01-policy.md` for modal actions, role access, simple UI, and partial state refresh.

## Backend Routes To Align With
- `/api/v1/appointments`
- `/api/v1/encounters`
- `/api/v1/procedures`
- `/api/v1/care-plans`
- `/api/v1/clinical-notes`
- `/api/v1/follow-ups`

## Implementation Scope
1. Physiotherapy worklist for referrals, assessments due, scheduled sessions, in-progress plans, completed sessions, and follow-ups.
2. Patient therapy detail with referral reason, assessment, goals, treatment plan, session history, progress notes, and next appointment.
3. Modal actions for accept referral, schedule session, record assessment, record session, update plan, mark attendance, add progress note, and complete/close therapy episode.
4. Therapy request flow linked to clinical care plans/procedures where backend supports it.
5. Billing/authorization status display where therapy is billable.

## UI and Workflow Contract
| Area | Requirement |
| --- | --- |
| Main screen | Use a simple worklist with filters: referrals, today, missed, active plans, follow-up due, completed. |
| Session view | Show patient, appointment/session time, therapy plan, goal, status, and next action. |
| Actions | Use modals for scheduling, attendance, assessment, session note, and plan update. |
| Instructions | Exercise/home instructions should be easy to write and print/share where permitted. |
| Responsiveness | Mobile supports session actions; desktop supports worklist plus patient therapy detail. |

## Flow Synchronization Rules
- Referrals must remain linked to the source OPD encounter, IPD admission, or clinical care plan.
- Session completion must update therapy status, billing/authorization if required, and source care plan/clinical review where applicable.
- Follow-up sessions must not duplicate patients or encounters.
- Discharge planning should show outstanding therapy items where relevant.

## Access and State Rules
- Physiotherapists act within facility/department scope.
- Doctors can view therapy status and notes where permitted.
- Billing sees therapy charges/clearance only.
- After mutation, refresh only the therapy row, patient therapy detail, appointment slot, source care plan status, and notification badge.

## Reports and Printing
Therapy assessment, treatment plan, session summary, progress report, exercise instruction sheet, and referral response must use generated report templates from `35-reports-audit.md`.

## Done Criteria
- Therapy referrals and sessions are simple to manage.
- Therapy work synchronizes with OPD/IPD clinical care and billing.
- Reports/instructions are generated from data.
- UI remains clean, responsive, and permission-aware.

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
