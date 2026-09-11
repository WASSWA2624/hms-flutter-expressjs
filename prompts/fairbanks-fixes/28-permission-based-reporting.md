# 28 — Implement Role- and Permission-Based Reporting and Analytics

**Source:** [fairbanks-fixes.md](../fairbanks-fixes.md) → Phase 9, Step 28
**Depends on:** 12, 27
**Applies to:** development and production

## Context

Reporting must be one centralized framework driven by the authenticated user permissions and scope, resolving `User → Roles → Permissions → Scope → Available Reports/Analytics`. The workspace must support zero, one, two, or many analytics tabs depending on authorization. Existing scaffolding: `frontend/lib/features/reports/` and `backend/src/modules/reports-workspace/`.

## Requirements

1. Define a single report registry where every report declares its module, required permissions, supported scopes, filters, and output formats.
2. Resolve the available report set on the backend from the requester roles, permissions, and scope, and return it as the authoritative catalog the frontend renders.
3. Render tabs dynamically from that catalog: many tabs for a broad administrator, a single scope without tab navigation for a narrow user, and no analytics content at all for an unauthorized user.
4. Ensure an unauthorized report is absent from the catalog, unreachable by direct route, and denied by its API endpoint.
5. Keep the framework module-agnostic so clinical, finance, HR, pharmacy, laboratory, radiology, theatre, inventory, and facility reports register the same way.
6. Handle catalog loading, empty, error, and permission states explicitly, including the case where a user has no authorized reports.
7. Keep the catalog current when roles, permissions, or scope change during a session, without requiring a full application restart.
8. Add backend tests for catalog resolution per role and scope and for direct-route denial, plus frontend tests for the zero, one, and many tab cases.
9. Ship the change to both development and production per **Rollout** below.

## Constraints

- Reuse the existing reports workspace, report definition module, and shared reporting widgets; do not create a second reporting stack.
- The frontend must never decide authorization; it renders what the backend catalog allows.
- Follow `prompts/.cursor/tabs.mdc`, `tables.mdc`, and `screens.mdc`.

## Acceptance Criteria

- [ ] **AC1 (R1, R2)** Every report is registered with its permissions and scopes, and the catalog endpoint returns exactly the authorized set.
- [ ] **AC2 (R3)** A broad administrator sees multiple tabs, a narrow user sees a single scope without tab navigation, and an unauthorized user sees no analytics content.
- [ ] **AC3 (R4)** Direct navigation to an unauthorized report renders nothing and the API denies the request.
- [ ] **AC4 (R5)** A report from any module registers and renders through the same framework.
- [ ] **AC5 (R6)** Loading, empty, error, permission, and no-reports states render correctly in both themes at representative viewports.
- [ ] **AC6 (R7)** A permission change is reflected in the catalog within the session.
- [ ] **AC7 (R8)** New backend and frontend tests pass.
- [ ] **AC8 (R9)** Catalog resolution is identical in development and production.

## Verification

- `npm run test:backend`, `npm run lint`, `npm run openapi:validate` in `backend/`.
- `flutter analyze`, `flutter test` in `frontend/`.
- Manual: log in as at least four users with different role and scope combinations in each environment.

## Rollout — Development and Production

- Behavior must be identical under `NODE_ENV=development` and `NODE_ENV=production`; no report may be visible only in one environment.
- Config: document any catalog cache key in `backend/env.template.txt` with dev and prod guidance and set it in both env files.
- Schema/data: apply report-definition schema changes with `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host; sync report permissions into the permission catalog in both databases.
- Release: `python deploy/deploy-backend.py`, `python deploy/deploy-frontend.py`, and `python deploy/deploy-android.py`, then repeat the multi-user catalog checks in production.

## Relevant Files

- `backend/src/modules/reports-workspace/`, `report-definition/`, `report-run/`, `report-schedule/`, `dashboard-workspace/`
- `backend/src/modules/permission/`, `role-permission/`, `abac-policy/`
- `frontend/lib/features/reports/presentation/` (workspace page, controller, access, catalogs)
- `frontend/lib/core/permissions/`, `frontend/lib/shared/reporting/`
