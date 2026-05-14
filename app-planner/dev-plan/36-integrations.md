# 36 - Integrations and Interoperability

## Goal
Manage API keys, integration configuration, integration logs, webhook subscriptions, and interoperability status.

## Backend Routes To Align With
- `/api/v1/api-keys`
- `/api/v1/api-key-permissions`
- `/api/v1/integrations`
- `/api/v1/integration-logs`
- `/api/v1/webhook-subscriptions`
- `/api/v1/interop`

## Implementation Scope
1. Integration dashboard.
2. API key list and permission visibility.
3. Integration configuration form where supported.
4. Webhook subscription management.
5. Integration logs and status.
6. Interop status and troubleshooting.

## UX and Workflow Rules
- Keep this module self-contained.
- Use the shared workspace pattern from `10-workspace-ui.md`.
- Keep short actions in modals where safe.
- Use full pages only for complex or high-risk workflows.
- Show loading, empty, error, forbidden, offline, and success states.
- Respect tenant, facility, department/unit, role, permission, and module entitlement scope.

## Done Criteria
- Integration access is restricted.
- Sensitive values are not exposed.
- Logs are searchable.
- External connectivity status is clear.

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
