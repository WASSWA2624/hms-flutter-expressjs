# 13 - OPD Triage

## Goal
Capture triage information before consultation and route patients safely.

## Backend Routes To Align With
- `/api/v1/triage`
- `/api/v1/triage-assessments`
- `/api/v1/vital-signs`
- `/api/v1/clinical-alerts`
- `/api/v1/clinical-alert-thresholds`

## Implementation Scope
1. Triage queue filtered by waiting/urgent/emergency status.
2. Vitals capture form.
3. Chief complaint, priority, triage notes, emergency indicators, and route decision.
4. Escalation to emergency, doctor, ICU, theater, or admission where supported.
5. Clear abnormal vital indicators.

## UX and Workflow Rules
- Keep this module self-contained.
- Use the shared workspace pattern from `10-workspace-ui.md`.
- Keep short actions in modals where safe.
- Use full pages only for complex or high-risk workflows.
- Show loading, empty, error, forbidden, offline, and success states.
- Respect tenant, facility, department/unit, role, permission, and module entitlement scope.

## Done Criteria
- Triage can be completed quickly.
- Abnormal values are visible.
- Routing decision is recorded.
- Clinical staff can see triage summary during consultation.

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
