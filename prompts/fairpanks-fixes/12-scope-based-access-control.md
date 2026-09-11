# 12 — Add Scope-Based Access Control

**Source:** [fairpanks-fixes.md](../fairpanks-fixes.md) → Phase 3, Step 12
**Depends on:** 11
**Applies to:** development and production

## Context

Roles need a formal operating scope so later billing, clinical, and reporting work can rely on it. Every session must resolve `User → Roles → Permissions → Scope`. The scope levels are platform, tenant, facility, department, service, and individual or assigned scope.

## Requirements

1. Model scope explicitly on role assignments, supporting platform, tenant, facility, department, service, and individual levels, with a defined containment order.
2. Resolve the complete access context once per session and expose it through the existing session and permission providers, including all roles, effective permissions, and the resolved scope set.
3. Enforce scope in the backend data layer so every scoped query is filtered by the resolved scope, not merely by tenant.
4. Make scope resolution deterministic when a user holds several roles at different levels, and document the combination rule (broadest authorized scope per permission, with tenant isolation always applied).
5. Expose the resolved scope to the frontend so navigation, lists, selectors, dashboards, and default filters reflect the authorized scope without additional round trips.
6. Reject any request whose parameters attempt to widen scope beyond the resolved set, regardless of frontend filters or URL parameters.
7. Backfill scope for existing role assignments without changing the effective access of any current user, and report any assignment that cannot be resolved automatically.
8. Add tests for resolution, containment, multi-role combination, widening attempts, and the scope-filtered query layer.
9. Ship the change to both development and production per **Rollout** below.

## Constraints

- Reuse the ABAC policy module, the session layer, and `frontend/lib/core/permissions/`; do not build a parallel scope system.
- Scope enforcement must live in the service and repository layers so scripts and background jobs inherit it.
- Keep tenant isolation from step 07 intact; scope narrows access and never widens it across tenants.

## Acceptance Criteria

- [ ] **AC1 (R1, R2)** Every session resolves roles, permissions, and scope, and the resolution is observable in a debug or admin view for an authorized user.
- [ ] **AC2 (R3, R6)** A department-scoped user cannot read facility-wide data through any filter, parameter, or export.
- [ ] **AC3 (R4)** A multi-role user receives the documented combined scope, reproducibly.
- [ ] **AC4 (R5)** Navigation, lists, and default filters match the resolved scope with no extra request.
- [ ] **AC5 (R7)** After backfill, no existing user gains or loses access except where explicitly documented.
- [ ] **AC6 (R8)** New tests pass, including widening-attempt rejections.
- [ ] **AC7 (R9)** Scope behaves identically in development and production after deployment.

## Verification

- `npm run test:backend`, `npm run lint`, `npm run openapi:validate` in `backend/`.
- `flutter analyze`, `flutter test` in `frontend/`.
- Manual: exercise one user per scope level in each environment and compare visible data.

## Rollout — Development and Production

- Resolution and enforcement must be identical under `NODE_ENV=development` and `NODE_ENV=production`.
- Config: document any scope or policy cache key in `backend/env.template.txt` with dev and prod guidance and set it in both env files.
- Schema/data: apply scope schema changes with `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host; run the idempotent scope backfill in development, then in production after backup, with before and after access reports.
- Release: `python deploy/deploy-backend.py`, `python deploy/deploy-frontend.py`, and `python deploy/deploy-android.py`, then re-verify each scope level in production.

## Relevant Files

- `backend/src/modules/abac-policy/`, `role/`, `user-role/`, `department/`, `facility/`, `office-context/`
- `backend/src/middlewares/abac.middleware.js`, `tenant-scope.middleware.js`, `request-context.middleware.js`
- `frontend/lib/core/permissions/`, `frontend/lib/core/workspace/`, `frontend/lib/core/security/auth_session.dart`
- `backend/prisma/schema.prisma`, `backend/prisma/migrations/`
