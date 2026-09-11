# 08 — Stabilize User Creation

**Source:** [fairbanks-fixes.md](../fairbanks-fixes.md) → Phase 3, Step 8
**Depends on:** 03, 07
**Applies to:** development and production

## Context

User creation fails or reports unusable errors, blocking role and permission work. The flow spans `backend/src/modules/user/`, `user-role/`, `staff-profile/`, and the access administration UI in `frontend/lib/features/access_admin/`.

## Requirements

1. Reproduce and fix each current failure in create user, assign facility or scope, assign role, activate or deactivate, edit user, and reset credentials.
2. Validate input consistently between the frontend form and the backend schema so the two never disagree about required fields, formats, or uniqueness.
3. Return backend errors in the standard response contract with field-level detail, and render them against the matching form fields instead of a generic failure message.
4. Make user creation atomic across user, staff profile, role assignment, and scope assignment; a failure must leave no partially created user.
5. Enforce that a newly created user can log in and receives exactly the access implied by the assigned roles and scope, with no implicit extra permission.
6. Refresh the user list and any dependent selectors immediately after create, edit, activate, deactivate, and credential reset.
7. Ensure credential reset issues a secure, single-use flow and never returns or logs a password.
8. Add backend tests for each operation and its failure modes, and frontend tests for validation, error rendering, and list refresh.
9. Ship the change to both development and production per **Rollout** below.

## Constraints

- Reuse the existing user module, permission catalog, dialog and form components, and the standard error contract.
- Unauthorized user-management UI must not render; do not render disabled controls as a substitute for hiding.
- Do not bypass password policy, MFA, or session revocation rules.
- Follow `prompts/.cursor/forms.mdc`, `dialogs.mdc`, `tables.mdc`, and `localization.mdc`.

## Acceptance Criteria

- [ ] **AC1 (R1)** Every listed operation succeeds for an authorized administrator.
- [ ] **AC2 (R2, R3)** Each validation and conflict failure renders a localized, field-level message derived from the backend response.
- [ ] **AC3 (R4)** An induced mid-flow failure leaves no orphaned user, staff profile, or role assignment.
- [ ] **AC4 (R5)** A created user logs in successfully and sees only the authorized surfaces.
- [ ] **AC5 (R6)** Lists and selectors reflect changes without a manual reload.
- [ ] **AC6 (R7)** Credential reset completes without exposing a password in any response or log.
- [ ] **AC7 (R8)** New backend and frontend tests pass.
- [ ] **AC8 (R9)** All operations are verified on the development stack and in production after deployment.

## Verification

- `npm run lint`, `npm run test:backend`, `npm run openapi:validate` in `backend/`.
- `flutter analyze`, `flutter test` in `frontend/`.
- Manual: full user lifecycle in both environments, both themes, representative viewports.

## Rollout — Development and Production

- Behavior must be identical under `NODE_ENV=development` and `NODE_ENV=production`; no user-management path may depend on a development-only shortcut or default account.
- Config: document password policy, reset-link TTL, and mail keys in `backend/env.template.txt` with dev and prod guidance, then set them in `.env.development` and `.env.production`.
- Schema/data: apply user and staff-profile schema changes with `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host; keep `backend/scripts/setup-default-accounts.js` safe to re-run in production.
- Release: `python deploy/deploy-backend.py` and `python deploy/deploy-frontend.py`, then repeat the lifecycle checks in production.

## Relevant Files

- `backend/src/modules/user/`, `user-role/`, `user-profile/`, `staff-profile/`, `user-mfa/`
- `backend/src/modules/access-admin-workspace/`
- `frontend/lib/features/access_admin/`
- `frontend/lib/core/permissions/`
- `backend/scripts/setup-default-accounts.js`
