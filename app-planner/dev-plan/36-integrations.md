# 36 - Integrations and Interoperability

## Goal
Manage API keys, integration configuration, integration logs, webhook subscriptions, interoperability status, external system health, and secure integration operations without exposing sensitive values to unauthorized users.

## Source of Truth
- `app-write-up.md`, `opd-flow.md`, and `ipd-flow.md` are the single product/flow source of truth for this implementation plan; backend/frontend planner files and rules are alignment references only.
- Use `app-write-up.md` for integration scope.
- Use `01-policy.md` for permissions, simple UI, reports, generated exports, and partial refresh.
- Use frontend/backend security and network/API rules for sensitive values, logs, and error handling.


## Current Implementation Baseline
- Current frontend status: no dedicated `integrations` feature folder or route exists, but backend exposes API keys, key permissions, integrations, logs, webhook subscriptions, and interop routes.
- Required adjustment: create one integrations workspace following the existing feature pattern; do not expose raw secrets, raw payload dumps, or a custom technical admin shell.
- UI similarity rule: integration status, API keys, permissions, webhooks, logs, tests, and failure states must use shared workspace/list/search/dialog/form/status/action components with permission-gated actions and targeted row/log refresh.

## Backend Routes To Align With

Use these route families only after confirming they exist in the current backend router/API contract. If a listed route is absent, record it as a backend gap and do not create a frontend-only endpoint, fake status, or local-only workflow.
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

## Reusable Components and Sync Contract
- Reuse `10-workspace-ui.md` workspace layout, shared form fields, shared modal/dialog shell, responsive detail panels, status badges, search/filter/table/list controls, async state views, and permission-gated action patterns before adding module-specific widgets.
- Use or create shared components for: integration status card, API key table, masked secret display, permission-scope selector, webhook form, log table, test-connection modal, and failure status badge.
- Keep common form layout, field behavior, validation-error display, server-error mapping, loading state, disabled state, and duplicate-submit protection shared; keep module-specific validation and submit mapping in feature controllers/repositories.
- Keep modal actions focused and return users to the same worklist/detail context after success; refresh only backend-backed affected rows, badges, panels, queues, counters, report previews, or form sections.
- Backend/frontend sync required: API keys, integration config, webhook subscriptions, logs, permissions, notifications, reports, secrets masking, and audit events must stay synchronized.
- Do not create duplicate patient, encounter, admission, order, invoice, payment, report, notification, status, or action components when an existing shared pattern can represent the same job.

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

## Concrete Implementation Contract
| Slice | Required implementation |
| --- | --- |
| Worklist/list data | Use `AppWorkspace` + `AppListTable<IntegrationItem>` with integration/API key/webhook name, status, owner, scope, last run/event, error state, and next action. Use `AppSearchBar` for integration name, type, status, owner, event, and date filters. |
| Detail/display | Use integration detail with configuration summary, API keys, webhook subscriptions, logs, interop mapping, error history, and audit events; hide secrets. |
| CRUD/UI actions | Use `AppDialog` for create/edit integration, rotate/revoke API key, configure webhook, retry/suspend, view sanitized log detail, and export permitted logs. |
| RBAC/ABAC | Gate with system/admin/integration permissions, API-key permissions, tenant/facility scope, and backend authorization; never expose secrets after creation. |
| Partial refresh | After integration action update only integration row, API key status, webhook/log row, error badge, audit event indicator, and notification count. |

Implementation must reuse `AppWorkspace`, `AppListTable`, `AppSearchBar`/`AppListTableSearch`, `AppDialog`, shared form fields, `AppStateView`/`AsyncStateScaffold`, and access gates before adding feature-local UI. Do not reload the full workspace after modal actions.


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
