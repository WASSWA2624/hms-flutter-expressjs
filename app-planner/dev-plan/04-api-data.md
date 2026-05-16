# 04 - API and Data Foundation

## Goal
Prepare the Flutter frontend to consume the existing backend safely, consistently, and without duplicating API or data patterns.

## Source of Truth
- `app-write-up.md`, `opd-flow.md`, and `ipd-flow.md` are the single product/flow source of truth for this implementation plan; backend/frontend planner files and rules are alignment references only.
- Align with current backend routes, permissions, feature flags, module entitlements, catalogs, and response formats; do not let API convenience change the product/flow rules above.
- `app-write-up.md` defines module scope.
- `opd-flow.md` and `ipd-flow.md` define encounter/admission movement that API state must support.
- Frontend app-rules define repository, DTO, state, error, reusable component, and network implementation mechanics.

## Current State
- Backend APIs are mounted under `/api/v1`.
- Public health endpoints exist outside versioned routes.
- The frontend has a network client foundation, failure mapping, connectivity status, result wrappers, and repository pattern examples.
- `frontend/lib/core/network/api_endpoints.dart` may still contain only starter/sample helpers and should be extended, not scattered.

## Scope
1. Expand `ApiEndpoints` with HMS endpoint helpers grouped by module.
2. Keep endpoint strings centralized; do not scatter raw API paths inside widgets.
3. Create feature-level DTOs, mappers, repositories, and controllers only when each module is implemented.
4. Map backend response formats into stable frontend domain models.
5. Handle pagination, search, filters, sorting, errors, forbidden states, and validation errors consistently.
6. Keep sensitive tokens in secure/session storage and never in widgets.
7. Respect backend tenant scope, facility scope, module entitlement, role permissions, and action permissions.
8. Support cancelable/stale requests for search, filters, queues, and large worklists.
9. After mutations, update only the affected state slice.


## Backend/Frontend Synchronization Contract
- Add or update endpoint helpers, DTOs, domain models, repositories, controllers, permission checks, and UI state together for each module slice.
- Keep raw API paths out of widgets; widgets call controllers/use-cases, controllers call repositories, and repositories call centralized API helpers.
- Treat backend mutation responses as the authoritative state for updated rows, totals, queue positions, billing status, order status, report identifiers, and timestamps.
- Do not hard-code OPD/IPD statuses or transitions outside the source flows; map backend state into localized user-facing labels and shared status badge components.
- Catalog-backed shared selects must read from backend/configured catalogs and invalidate when setup data changes.
- Permission, entitlement, feature-flag, and facility/tenant scope checks must be enforced before showing actions and again by backend calls.

## Endpoint Groups To Prepare
- Auth/session
- Tenant/facility structure
- Users, roles, permissions, ABAC policies
- Patients, appointments, queues, triage, OPD/IPD flows
- Clinical, nursing, ICU, theater, discharge
- Lab, radiology, pharmacy, billing, claims
- HR, rooms/beds, biomedical, operations, housekeeping, mortuary
- Subscriptions, notifications, reports, audit, integrations

## Catalog and Selection Rules
- Lab tests, radiology tests, drugs/formulary items, billing services, departments, units, wards, rooms, beds, providers, payment methods, and insurance plans must come from backend/configured catalogs.
- Request screens should use searchable selects and quick filters, not hard-coded lists.
- Cache catalogs carefully and invalidate them when setup data changes.

## Avoid
- Do not invent endpoints that are not in the backend route map.
- Do not call APIs directly from widgets.
- Do not bypass repository/data-source layers.
- Do not expose raw server errors to users.
- Do not duplicate patient, OPD encounter, IPD admission, order, invoice, payment, or report state outside the agreed flow.

## Done Criteria
- Endpoint constants/helpers are centralized.
- Feature repositories use the existing API client.
- DTO/domain mapping is explicit.
- Common API errors render as clear localized UI states.
- OPD/IPD status updates, order routing, billing gates, notifications, and reports are synchronized through backend responses.

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
- `frontend/app-planner/app-rules/repository_pattern_example.md`
- `frontend/app-planner/app-rules/data_modeling.md`
- `frontend/app-planner/app-rules/error_handling.md`
- `frontend/lib/core/network/`
- `backend/src/app/router.js`

Respect these documents when implementing the step. Do not edit backend or frontend planner files unless a future task explicitly allows it.
