# 36 - Integrations and Interoperability

## Goal
Manage API keys, integration configuration, integration logs, webhook subscriptions, interoperability status, external system health, and secure integration operations without exposing sensitive values to unauthorized users.

## Source of Truth
- Use `app-write-up.md` for integration scope.
- Use `01-policy.md` for permissions, simple UI, reports, generated exports, and partial refresh.
- Use frontend/backend security and network/API rules for sensitive values, logs, and error handling.

## Backend Routes To Align With
- `/api/v1/api-keys`
- `/api/v1/api-key-permissions`
- `/api/v1/integrations`
- `/api/v1/integration-logs`
- `/api/v1/webhook-subscriptions`
- `/api/v1/interop`

## Implementation Scope
1. Integration dashboard with status, enabled integrations, recent errors, webhooks, and API key summary.
2. API key list with masked values, permission scope, created/last-used metadata where available, and status.
3. Modal actions for create API key, rotate key, revoke key, update permissions, configure integration, enable/disable integration, create/update webhook, and test connection where supported.
4. Integration logs with search/filter and safe error display.
5. Interoperability status view for external system readiness.

## UI and Workflow Contract
| Area | Requirement |
| --- | --- |
| Main screen | Use simple status cards and lists: active, warning, failed, disabled. |
| Sensitive values | Show secrets only once where backend supports it; otherwise mask. Never print or log secrets in UI. |
| Actions | Use modals for key/webhook/integration updates and confirmations. |
| Logs | Show staff/admin-friendly status and error summaries; keep raw technical payloads restricted or hidden. |
| Responsiveness | Mobile supports status and simple actions; desktop supports dashboard plus log/detail panel. |

## Flow Synchronization Rules
- Integration status should update badges/cards without reloading the app.
- Webhook or API-key changes must update only the affected integration/key/log item.
- Integration failures should create notifications for permitted admins only.
- Integrations must not bypass tenant, facility, permission, module entitlement, or audit rules.

## Access and State Rules
- Only permitted platform/tenant/admin users can manage integrations and API keys.
- Sensitive logs and secrets require separate permission checks.
- After mutation, refresh only the affected key, webhook, integration card, log row, and notification badge.

## Reports and Printing
Integration status reports, API key permission summaries, webhook delivery summaries, and integration audit extracts must use generated report templates from `35-reports-audit.md`. Sensitive values must never appear in printed/exported output unless explicitly permitted and safe.

## Done Criteria
- Integration access is restricted and secure.
- Sensitive values are masked and not exposed after creation.
- Logs are searchable and understandable.
- Integration status updates are targeted and auditable.

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
