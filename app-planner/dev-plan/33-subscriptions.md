# 33 - Subscription Management Module

## Goal
Manage subscription plans, active subscriptions, module subscriptions, licenses, subscription invoices, entitlement visibility, renewal state, limits, and subscription-driven access.

## Source of Truth
- `app-write-up.md`, `opd-flow.md`, and `ipd-flow.md` are the single product/flow source of truth for this implementation plan; backend/frontend planner files and rules are alignment references only.
- Use `app-write-up.md` for subscription scope.
- Use `01-policy.md` for access control, simple UI, report generation, responsive behavior, and partial state refresh.
- Use earlier access-control/dev-plan work for role/permission/entitlement guards instead of redefining them.

## Backend Routes To Align With

Use these route families only after confirming they exist in the current backend router/API contract. If a listed route is absent, record it as a backend gap and do not create a frontend-only endpoint, fake status, or local-only workflow.
- `/api/v1/subscriptions-workspace`
- `/api/v1/subscription-plans`
- `/api/v1/subscriptions`
- `/api/v1/subscription-invoices`
- `/api/v1/modules`
- `/api/v1/module-subscriptions`
- `/api/v1/licenses`

## Implementation Scope
1. Subscription workspace for plans, current subscription, module subscriptions, licenses, invoices, renewal/expiry, and entitlement state.
2. Plan/module detail with enabled modules, limits, price/invoice state, license state, and tenant/facility scope where supported.
3. Modal actions for create/update plan, activate subscription, renew, suspend, enable/disable module subscription, update license, and print invoice.
4. Subscription invoice visibility connected to billing where supported.
5. Entitlement-aware menu/module visibility across the app.

## UI and Workflow Contract
| Area | Requirement |
| --- | --- |
| Main screen | Use clean summary cards and lists: active plan, modules enabled, licenses, invoices, renewal/expiry. |
| Actions | Use modals for plan/module/subscription/license updates and confirmations. |
| Entitlements | Disabled modules should be hidden or clearly unavailable based on existing rule behavior. |
| Language | Use simple tenant/admin labels; keep licensing technical details secondary. |
| Responsiveness | Mobile shows stacked cards/lists; desktop supports summary plus detail panel. |

## Reusable Components and Sync Contract
- Reuse `10-workspace-ui.md` workspace layout, shared form fields, shared modal/dialog shell, responsive detail panels, status badges, search/filter/table/list controls, async state views, and permission-gated action patterns before adding module-specific widgets.
- Use or create shared components for: plan card, subscription status badge, module entitlement matrix, license status card, invoice/payment link panel, enable/disable module modal, and tenant entitlement summary.
- Keep common form layout, field behavior, validation-error display, server-error mapping, loading state, disabled state, and duplicate-submit protection shared; keep module-specific validation and submit mapping in feature controllers/repositories.
- Keep modal actions focused and return users to the same worklist/detail context after success; refresh only backend-backed affected rows, badges, panels, queues, counters, report previews, or form sections.
- Backend/frontend sync required: plans, subscriptions, module entitlements, licenses, tenant/facility access, menus, route guards, billing records, notifications, reports, and audit records must stay synchronized.
- Do not create duplicate patient, encounter, admission, order, invoice, payment, report, notification, status, or action components when an existing shared pattern can represent the same job.

## Flow Synchronization Rules
- Module entitlements must affect route guards, menus, actions, reports, and dashboards.
- Subscription invoice updates must synchronize with billing status where backend supports it.
- Changing module subscription should update visible navigation and feature access without full app reload where possible.
- Do not hard-code module availability in widgets; consume backend/module entitlement state.

## Access and State Rules
- Platform/tenant admins manage subscriptions according to scope.
- Facility users should not see subscription controls unless permitted.
- After mutation, refresh only the affected subscription, module entitlement, invoice, navigation availability, and notification badge.

## Reports and Printing
Subscription invoice, license summary, module entitlement summary, renewal notice, and plan comparison reports must use generated report templates from `35-reports-audit.md`.

## Done Criteria
- Subscription state controls module visibility and access consistently.
- Subscription actions are modal-based, permission-aware, and auditable.
- UI is simple for tenant/platform admins.
- Invoices/reports are generated from data.

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
