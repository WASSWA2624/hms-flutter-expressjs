# 15 - Nursing Module

## Goal
Support nursing observations, medication administration, care tasks, handovers, and ward/clinical nursing activity.

## Backend Routes To Align With
- `/api/v1/nursing-notes`
- `/api/v1/medication-administrations`
- `/api/v1/vital-signs`
- `/api/v1/handovers`
- `/api/v1/nurse-rosters`
- `/api/v1/care-plans`

## Implementation Scope
1. Nursing worklist by ward, unit, patient, priority, and shift.
2. Nursing note capture.
3. Medication administration record capture.
4. Care task status updates.
5. Handover notes and shift-aware context.

## UX and Workflow Rules
- Keep this module self-contained.
- Use the shared workspace pattern from `10-workspace-ui.md`.
- Keep short actions in modals where safe.
- Use full pages only for complex or high-risk workflows.
- Show loading, empty, error, forbidden, offline, and success states.
- Respect tenant, facility, department/unit, role, permission, and module entitlement scope.

## Done Criteria
- Nurses can complete routine actions from nursing workspace.
- MAR and notes are easy to update.
- Handovers are clear.
- Ward/IPD/ICU links are permission-aware.

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
