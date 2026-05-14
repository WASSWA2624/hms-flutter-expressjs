# 04 - API and Data Foundation

## Goal
Prepare the Flutter frontend to consume the existing backend safely and consistently.

## Current State
- Backend APIs are mounted under `/api/v1`.
- Public health endpoints exist outside versioned routes.
- The frontend has a network client foundation, failure mapping, connectivity status, result wrappers, and repository pattern examples.
- `frontend/lib/core/network/api_endpoints.dart` currently contains only a sample helper.

## Scope
1. Expand `ApiEndpoints` with HMS endpoint helpers grouped by module.
2. Keep endpoint strings centralized; do not scatter raw API paths inside widgets.
3. Create feature-level DTOs, mappers, repositories, and controllers only when each module is implemented.
4. Map backend response formats into stable frontend domain models.
5. Handle pagination, search, filters, sorting, errors, forbidden states, and validation errors consistently.
6. Keep sensitive tokens in secure/session storage and never in widgets.
7. Respect backend tenant scope, facility scope, module entitlement, and permissions.

## Endpoint Groups To Prepare
- Auth/session
- Tenant/facility structure
- Users, roles, permissions, ABAC policies
- Patients, appointments, queues, triage, OPD/IPD flows
- Clinical, nursing, ICU, theater, discharge
- Lab, radiology, pharmacy, billing, claims
- HR, rooms/beds, biomedical, operations, housekeeping, mortuary
- Subscriptions, notifications, reports, audit, integrations

## Avoid
- Do not invent endpoints that are not in the backend route map.
- Do not call APIs directly from widgets.
- Do not bypass repository/data-source layers.
- Do not expose raw server errors to users.

## Done Criteria
- Endpoint constants/helpers are centralized.
- Feature repositories use the existing API client.
- DTO/domain mapping is explicit.
- Common API errors render as clear localized UI states.

## Rule References
### Frontend rules
- `frontend/app-planner/app-rules/network_api.md`
- `frontend/app-planner/app-rules/repository_pattern_example.md`
- `frontend/app-planner/app-rules/data_modeling.md`
- `frontend/app-planner/app-rules/error_handling.md`
- `frontend/app-planner/app-rules/security.md`
- `frontend/app-planner/app-rules/pagination_data_tables.md`
### Backend rules
- `backend/app-planner/app-rules/api.md`
- `backend/app-planner/app-rules/api-versioning.md`
- `backend/app-planner/app-rules/response-format.md`
- `backend/app-planner/app-rules/validation.md`
- `backend/app-planner/app-rules/auth-security.md`
- `backend/app-planner/app-rules/rate-limiting.md`
### Additional references
- `backend/src/app/router.js`
- `frontend/lib/core/network/`

Respect these documents when implementing the step. Do not edit backend or frontend planner files unless a future task explicitly allows it.
