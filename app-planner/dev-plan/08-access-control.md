# 08 - Access Control, Permissions, and Entitlements

## Goal
Ensure every route, menu, button, modal action, report, export, print action, notification action, and API operation is controlled by roles, permissions, action rules, tenant scope, facility scope, and module subscriptions.

## Source of Truth
- `app-write-up.md`, `opd-flow.md`, and `ipd-flow.md` are the single product/flow source of truth for this implementation plan; backend/frontend planner files and rules are alignment references only.
- Use `app-write-up.md` for access expectations.
- Align frontend route/action visibility with backend role, permission, ABAC, module-subscription, and license contracts.
- Use frontend permission rules only to present allowed UI and prevent accidental access.


## Current Implementation Baseline
- Current frontend status: core access utilities already exist in `frontend/lib/core/permissions/` with `AppAccessPolicy`, `AccessRequirement`, `AppAccessGate`, `AppAccessActionGate`, roles, permissions, and module-entitlement checks.
- Required adjustment: build missing access-control admin screens by reusing those core utilities and central `AppRoutes`; do not add raw role checks inside widgets or create a new permission system.
- UI similarity rule: access-control lists must use `AppWorkspace`, `AppListTable`, `AppListTableSearch`, `AppDialog`, `AppPermissionActionList`, and shared forbidden/empty/error states.

## Backend Routes and Files

Use these route families only after confirming they exist in the current backend router/API contract. If a listed route is absent, record it as a backend gap and do not create a frontend-only endpoint, fake status, or local-only workflow.
- `/api/v1/users`
- `/api/v1/roles`
- `/api/v1/permissions`
- `/api/v1/role-permissions`
- `/api/v1/user-roles`
- `/api/v1/abac-policies`
- `/api/v1/module-subscriptions`
- `backend/src/config/permissions.js`
- `backend/src/config/roles.js`

## Scope
1. Build frontend permission mapping from backend permissions.
2. Protect routes in `AppRoutes` and router guards.
3. Hide or disable menu items the user cannot access.
4. Gate buttons, row actions, modal actions, print/export actions, and notification actions by permission.
5. Display forbidden pages or disabled states clearly.
6. Respect module subscription and license status before showing paid/disabled modules.
7. Support users with multiple roles.
8. Keep backend as final authority for authorization.
9. Apply access consistently across OPD, triage, clinical, IPD, billing, reports, and all support modules.

## Admin UX
Admins should manage:
- users;
- roles;
- permissions;
- role assignments;
- department/facility/unit/ward scope;
- active/disabled status;
- default demo accounts;
- module access where subscription allows it.

## UI Contract
| Area | Rule |
| --- | --- |
| Menus | Show only modules the user can access. |
| Screens | Guard routes and show localized forbidden state when denied. |
| Actions | Hide unavailable actions; disable only when the reason is useful to the user. |
| Modals | Open action modals only when the user can perform the action. |
| Reports | Gate report view, export, print, and audit access separately. |
| Notifications | Route notification actions only to allowed destinations. |
| Backend errors | Map `403` to safe forbidden UI and do not expose raw server details. |

## Reusable Components and Sync Contract
- Reuse `10-workspace-ui.md` workspace layout, shared form fields, shared modal/dialog shell, responsive detail panels, status badges, search/filter/table/list controls, async state views, and permission-gated action patterns before adding module-specific widgets.
- Use or create shared components for: permission matrix/table, role assignment form, user-role chips, module entitlement cards, forbidden state view, permission-gated action wrapper, and audit-safe admin modal.
- Keep common form layout, field behavior, validation-error display, server-error mapping, loading state, disabled state, and duplicate-submit protection shared; keep module-specific validation and submit mapping in feature controllers/repositories.
- Keep modal actions focused and return users to the same worklist/detail context after success; refresh only backend-backed affected rows, badges, panels, queues, counters, report previews, or form sections.
- Backend/frontend sync required: route guards, visible menus, action buttons, modal availability, report/export permissions, notification destinations, and backend permission responses must match.
- Do not create duplicate patient, encounter, admission, order, invoice, payment, report, notification, status, or action components when an existing shared pattern can represent the same job.

## Concrete Implementation Contract
| Slice | Required implementation |
| --- | --- |
| Admin lists | Users, roles, permissions, role permissions, user roles, API keys, ABAC policies, and break-glass reviews must use `AppListTable`/`AppSearchBar`. |
| Permission actions | Assign/revoke role, assign permission, activate/deactivate user, review break-glass, and API key actions must use `AppDialog` with clear consequences. |
| Route/action gates | Every route, shell destination, row action, modal submit, report/export, and notification action must use `AccessRequirement` and `AppAccessGate`/`AppAccessActionGate`. |
| ABAC/entitlements | Tenant, facility, department/unit/ward/bed scope and module entitlement must be checked before showing data or actions, and backend responses remain final. |
| Sync | Permission or role changes must update only affected users/roles, active session policy when applicable, route visibility, and destination badges. |


## Done Criteria
- Frontend and backend permission names align.
- Users only see allowed destinations and actions.
- Forbidden backend responses are handled gracefully.
- Module access follows active subscription/module entitlement state.
- Access checks are applied to reports, print actions, queue actions, and modal actions.

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

### Additional references
- `backend/src/config/permissions.js`
- `backend/src/config/roles.js`
- `frontend/lib/core/permissions/`

Respect these documents when implementing the step. Do not edit backend or frontend planner files unless a future task explicitly allows it.
