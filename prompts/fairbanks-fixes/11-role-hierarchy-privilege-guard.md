# 11 — Implement Role Hierarchy and Privilege Protection

**Source:** [fairpanks-fixes.md](../fairpanks-fixes.md) → Phase 3, Step 11
**Depends on:** 09, 10
**Applies to:** development and production

## Context

Nothing currently prevents a user from granting authority beyond their own. Privilege enforcement must live in the backend so no frontend change can bypass it. The organizational model is roughly `Platform Admin → Facility/Tenant Admin → Superior Staff → Staff`, and the implementation must match the actual model in the codebase.

## Requirements

1. Define an explicit role hierarchy with a documented rank or capability model, derived from the existing organizational structure rather than invented.
2. Enforce no-privilege-escalation on the backend: a user may never create, edit, assign, or combine a role that grants a permission or scope they do not themselves hold.
3. Enforce that a user may not modify, delete, or reassign a role that outranks their own, and may not elevate another user above their own rank.
4. Apply the same guard to every mutation path: role creation, role editing, role deletion, user-role assignment, permission assignment, scope assignment, and bulk or import operations.
5. Return the standard forbidden response with a specific, localized reason so the UI can explain the denial without leaking the hierarchy of other tenants.
6. Mirror the rules in the UI by hiding actions the user cannot perform, while treating the backend as the authority.
7. Add negative tests proving escalation attempts fail: self-elevation, granting an unheld permission, editing a superior role, assigning a superior role, and cross-tenant assignment.
8. Log every denied escalation attempt to the audit trail with actor, target, attempted change, and timestamp.
9. Ship the change to both development and production per **Rollout** below.

## Constraints

- Reuse `backend/src/middlewares/abac.middleware.js`, the ABAC policy module, and the existing permission catalog; do not add a parallel authorization layer.
- The guard must run in the service or policy layer so it also covers non-HTTP entry points such as scripts and imports.
- Do not render disabled controls or routine no-access messages as a substitute for hiding unauthorized actions.

## Acceptance Criteria

- [ ] **AC1 (R1)** The hierarchy is documented and matches the implemented ranks.
- [ ] **AC2 (R2, R3)** Every escalation attempt from the list in R7 is rejected by the API even when the request is crafted directly.
- [ ] **AC3 (R4)** The guard applies to create, edit, delete, assign, permission change, scope change, and bulk or import paths.
- [ ] **AC4 (R5)** Denials return the standard contract with a localized, non-leaking reason.
- [ ] **AC5 (R6)** Unauthorized actions do not render in the UI.
- [ ] **AC6 (R8)** Denied attempts appear in the audit trail with full context.
- [ ] **AC7 (R7)** Negative tests pass and fail when the guard is deliberately disabled.
- [ ] **AC8 (R9)** The same denials are reproduced against the production API after deployment.

## Verification

- `npm run test:backend` including the escalation suite; `npm run lint`; `npm run openapi:validate`.
- `flutter analyze`, `flutter test` in `frontend/`.
- Manual: direct API probes with a lower-rank token against both environments.

## Rollout — Development and Production

- Enforcement must be identical under `NODE_ENV=development` and `NODE_ENV=production`; no environment may disable or soften the guard.
- Config: document any hierarchy or policy key in `backend/env.template.txt` with dev and prod guidance and set it in both env files.
- Schema/data: apply rank or hierarchy schema changes with `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host; backfill ranks for existing roles idempotently in both databases.
- Release: `python deploy/deploy-backend.py` and `python deploy/deploy-frontend.py`, then re-run the escalation probes in production.

## Relevant Files

- `backend/src/middlewares/abac.middleware.js`, `auth.middleware.js`, `tenant-scope.middleware.js`
- `backend/src/modules/abac-policy/`, `role/`, `role-permission/`, `user-role/`, `permission/`
- `backend/src/modules/audit-log/`
- `frontend/lib/core/permissions/access_gate.dart`, `access_policy.dart`, `access_requirement.dart`
- `frontend/lib/features/access_admin/`
