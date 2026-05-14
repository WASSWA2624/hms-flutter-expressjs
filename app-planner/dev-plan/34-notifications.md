# 34 - Notifications and Communications

## Goal
Implement in-app notifications, unread badges, delivery state, conversations, messages, alerts, and workflow indicators.

## Backend Routes To Align With
- `/api/v1/notifications`
- `/api/v1/notification-deliveries`
- `/api/v1/conversations`
- `/api/v1/messages`
- `/api/v1/communications-workspace`

## Implementation Scope
1. App bar notification badge.
2. Notification list/panel.
3. Unread indicator logic.
4. Notification detail/actions where supported.
5. Conversation/message workspace.
6. Real-time or refresh strategy based on backend support.

## UX and Workflow Rules
- Keep this module self-contained.
- Use the shared workspace pattern from `10-workspace-ui.md`.
- Keep short actions in modals where safe.
- Use full pages only for complex or high-risk workflows.
- Show loading, empty, error, forbidden, offline, and success states.
- Respect tenant, facility, department/unit, role, permission, and module entitlement scope.

## Done Criteria
- Users see meaningful notification indicators.
- Notification actions route to the correct module.
- Unread counts update predictably.
- No noisy or duplicate alerts.

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
