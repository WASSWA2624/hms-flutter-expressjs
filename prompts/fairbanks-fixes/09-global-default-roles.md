# 09 — Implement Global Default Roles

**Source:** [fairpanks-fixes.md](../fairpanks-fixes.md) → Phase 3, Step 9
**Depends on:** 06, 08
**Applies to:** development and production

## Context

Platform-defined default roles must be owned by the platform and merely consumed by tenants, following the preset model established in step 06. Relevant code: `backend/src/modules/role/`, `role-permission/`, `permission/`, `backend/scripts/sync-permission-catalog.js`, `reseed-platform-access-catalog.js`, and `frontend/lib/features/access_admin/`.

## Requirements

1. Mark platform default roles as globally owned, versioned definitions that are not tenant-scoped, and make them available to every authorized tenant.
2. Prevent tenant users from deleting a global default role, renaming it, or changing its permission set; enforce this at the API layer, not only in the UI.
3. Allow authorized administrators to assign global default roles to users within their scope.
4. Allow a tenant to derive a tenant-owned copy of a default role when it needs changes, leaving the source definition untouched (this feeds step 10).
5. Keep global role definitions synchronized with the permission catalog so a permission added to the platform propagates to the global role definition without overwriting tenant-owned roles.
6. Migrate existing per-tenant duplicates of default roles onto the global definitions while preserving each current user assignment.
7. Surface role ownership clearly in the UI (platform vs tenant) with permission-gated actions, and hide actions the user may not perform.
8. Add tests for immutability, assignment, derivation, catalog synchronization, and cross-tenant safety.
9. Ship the change to both development and production per **Rollout** below.

## Constraints

- Reuse the preset ownership model from step 06 and the existing permission catalog; do not create a second role system.
- Never silently change the effective permissions of an already assigned user during migration; report any change that is unavoidable.
- Backend RBAC and ABAC remain authoritative.

## Acceptance Criteria

- [ ] **AC1 (R1, R3)** Global default roles are visible and assignable in every authorized tenant.
- [ ] **AC2 (R2)** Delete, rename, and permission-edit attempts by a tenant administrator are rejected by the API with the standard forbidden response.
- [ ] **AC3 (R4)** Deriving a tenant copy produces an independent role and leaves the global definition unchanged.
- [ ] **AC4 (R5)** Adding a platform permission updates global definitions without altering tenant-owned roles.
- [ ] **AC5 (R6)** After migration, every user keeps the same effective permissions, or each difference is documented and approved.
- [ ] **AC6 (R7)** Role ownership is displayed and unauthorized actions do not render.
- [ ] **AC7 (R8)** New tests pass, including the negative authorization cases.
- [ ] **AC8 (R9)** The same behavior is confirmed in development and in production after migration and deployment.

## Verification

- `npm run test:backend`, `npm run lint`, `npm run openapi:validate` in `backend/`.
- `flutter analyze`, `flutter test` in `frontend/`.
- Manual: attempt prohibited edits as a tenant administrator in both environments and confirm denial.

## Rollout — Development and Production

- Behavior must be identical under `NODE_ENV=development` and `NODE_ENV=production`; role ownership must not be relaxed locally.
- Config: document any platform-admin or catalog-sync key in `backend/env.template.txt` with dev and prod guidance and set it in both env files.
- Schema/data: apply role-ownership schema changes with `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host; run the idempotent role migration in development, then in production after backup, logging assignment counts before and after.
- Release: `python deploy/deploy-backend.py` and `python deploy/deploy-frontend.py`, then re-verify assignments in production.

## Relevant Files

- `backend/src/modules/role/`, `role-permission/`, `permission/`, `user-role/`
- `backend/scripts/sync-permission-catalog.js`, `reseed-platform-access-catalog.js`
- `backend/scripts/seeders/seed-access-pack.js`
- `frontend/lib/features/access_admin/`, `frontend/lib/core/permissions/`
- `backend/prisma/schema.prisma`, `backend/prisma/migrations/`
