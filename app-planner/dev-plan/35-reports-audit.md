# 35 - Reports, Dashboards, and Audit

## Goal
Provide dashboards, report definitions, report runs, scheduled reports, exports, audit logs, PHI access logs, and compliance evidence.

## Backend Routes To Align With
- `/api/v1/dashboard-workspace`
- `/api/v1/dashboard-widgets`
- `/api/v1/reports-workspace`
- `/api/v1/report-definitions`
- `/api/v1/report-runs`
- `/api/v1/report-schedules`
- `/api/v1/audit-logs`
- `/api/v1/phi-access-logs`
- `/api/v1/data-processing-logs`
- `/api/v1/kpi-snapshots`
- `/api/v1/analytics-events`

## Implementation Scope
1. Role-aware dashboard landing pages.
2. Reports workspace.
3. Report run and schedule views.
4. Audit log search/filter.
5. PHI access review.
6. Compliance evidence panels.

## UX and Workflow Rules
- Keep this module self-contained.
- Use the shared workspace pattern from `10-workspace-ui.md`.
- Keep short actions in modals where safe.
- Use full pages only for complex or high-risk workflows.
- Show loading, empty, error, forbidden, offline, and success states.
- Respect tenant, facility, department/unit, role, permission, and module entitlement scope.

## Done Criteria
- Reports are readable and permission-aware.
- Audit and PHI access logs are searchable.
- Dashboards summarize without replacing module workflows.

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
