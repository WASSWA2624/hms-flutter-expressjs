# 26 - Physiotherapy

## Goal
Plan a focused physiotherapy module for referrals, assessment, therapy plans, sessions, exercises, and progress review.

## Backend Routes To Align With
- `/api/v1/appointments`
- `/api/v1/encounters`
- `/api/v1/procedures`
- `/api/v1/care-plans`
- `/api/v1/clinical-notes`
- `/api/v1/follow-ups`

## Current Codebase Note
A dedicated physiotherapy backend route is not visible in the current backend. Implement only what can be supported by approved existing clinical/scheduling endpoints, or keep this as a planned module until backend support is authorized.

## Implementation Scope
1. Physiotherapy referrals/worklist.
2. Initial assessment form.
3. Therapy plan and session schedule.
4. Session notes, attendance, exercises, and progress status.
5. Outcome review and discharge from therapy.

## UX and Workflow Rules
- Keep this module self-contained.
- Use the shared workspace pattern from `10-workspace-ui.md`.
- Keep short actions in modals where safe.
- Use full pages only for complex or high-risk workflows.
- Show loading, empty, error, forbidden, offline, and success states.
- Respect tenant, facility, department/unit, role, permission, and module entitlement scope.

## Done Criteria
- Physiotherapy is represented in the product plan.
- No fake dedicated backend endpoints are used.
- If reusing clinical endpoints, mapping is documented and approved.
- A future backend task is raised for dedicated physiotherapy APIs, roles, and seed accounts if required.

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
