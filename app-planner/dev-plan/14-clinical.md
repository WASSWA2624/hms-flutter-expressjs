# 14 - Clinical Module

## Goal
Support provider consultation, documentation, diagnosis, orders, procedures, care plans, and follow-up.

## Backend Routes To Align With
- `/api/v1/encounters`
- `/api/v1/clinical-notes`
- `/api/v1/diagnoses`
- `/api/v1/procedures`
- `/api/v1/care-plans`
- `/api/v1/clinical-terms`
- `/api/v1/follow-ups`
- `/api/v1/referrals`

## Implementation Scope
1. Provider worklist from OPD/IPD/ICU/theater handoffs.
2. Consultation workspace with patient summary, triage, notes, diagnosis, procedures, care plan, and orders.
3. Clinical note templates and term search where supported.
4. Follow-up and referral actions.
5. Clear save states and audit-friendly updates.

## UX and Workflow Rules
- Keep this module self-contained.
- Use the shared workspace pattern from `10-workspace-ui.md`.
- Keep short actions in modals where safe.
- Use full pages only for complex or high-risk workflows.
- Show loading, empty, error, forbidden, offline, and success states.
- Respect tenant, facility, department/unit, role, permission, and module entitlement scope.

## Done Criteria
- Doctor can complete consultation without leaving clinical module unnecessarily.
- Clinical records map to backend contracts.
- Orders/referrals are traceable.
- Clinical UI remains readable.

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
