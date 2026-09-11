# 10 — Implement Custom Role Creation

**Source:** [fairbanks-fixes.md](../fairbanks-fixes.md) → Phase 3, Step 10
**Depends on:** 09
**Applies to:** development and production

## Context

Administrators need three ways to create a tenant-owned role: build from scratch, inherit and extend an existing role, and combine two or more roles. Source roles must never change. This builds on the global role ownership from step 09.

## Requirements

1. **Method A — build from scratch:** select individual permissions from the permission catalog, grouped by module, with search and clear selection state.
2. **Method B — inherit and extend:** start from an existing role, show its inherited permissions as a read-only baseline, and add permissions on top (for example nurse plus selected pharmacy permissions).
3. **Method C — combine roles:** select two or more roles and create a role whose permission set is the union of the sources (for example doctor plus administrator).
4. Guarantee that source roles are unchanged by any creation method, and record the derivation (method plus source roles) on the new role for auditability.
5. Resolve duplicates and conflicts deterministically when combining, and show the resulting effective permission list for review before saving.
6. Validate the new role against the requesting user authority from step 11 and reject any attempt to grant permissions the creator does not hold.
7. Enforce tenant ownership and unique role naming within the tenant, and allow edit and delete only for tenant-owned roles.
8. Add backend tests for each method, union correctness, source immutability, and rejection cases, plus frontend tests for the three flows and their permission, loading, empty, error, and success states.
9. Ship the change to both development and production per **Rollout** below.

## Constraints

- Reuse the permission catalog, existing role services, and the shared dialog and form components; do not build a separate permission picker per method.
- Backend must recompute and validate the effective permission set; the frontend selection is advisory only.
- Unauthorized role-management UI must not render.
- Follow `prompts/.cursor/dialogs.mdc`, `forms.mdc`, and `localization.mdc`.

## Acceptance Criteria

- [ ] **AC1 (R1)** A role built from scratch grants exactly the selected permissions.
- [ ] **AC2 (R2)** An inherited role grants the baseline plus the added permissions, and the baseline is visibly distinguished.
- [ ] **AC3 (R3, R5)** A combined role grants the exact union of its sources, with duplicates resolved and the effective list shown before saving.
- [ ] **AC4 (R4)** After any creation method, every source role is byte-for-byte unchanged, and the derivation is recorded.
- [ ] **AC5 (R6)** An attempt to include a permission the creator lacks is rejected by the API.
- [ ] **AC6 (R7)** Role names are unique per tenant, and only tenant-owned roles can be edited or deleted.
- [ ] **AC7 (R8)** New backend and frontend tests pass.
- [ ] **AC8 (R9)** All three methods work identically in development and production.

## Verification

- `npm run test:backend`, `npm run lint`, `npm run openapi:validate` in `backend/`.
- `flutter analyze`, `flutter test` in `frontend/`.
- Manual: create one role per method in each environment, assign it to a user, and confirm the effective access.

## Rollout — Development and Production

- Behavior must be identical under `NODE_ENV=development` and `NODE_ENV=production`.
- Config: no environment-specific behavior is permitted for role creation; document any new key in `backend/env.template.txt` and set it in both env files if one is introduced.
- Schema/data: apply derivation-metadata schema changes with `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host.
- Release: `python deploy/deploy-backend.py` and `python deploy/deploy-frontend.py`, then repeat the three creation flows in production.

## Relevant Files

- `backend/src/modules/role/`, `role-permission/`, `permission/`
- `backend/src/modules/access-admin-workspace/`
- `frontend/lib/features/access_admin/presentation/`
- `frontend/lib/core/permissions/app_permission.dart`, `permission_module_map.dart`
- `backend/prisma/schema.prisma`
