# 29 — Define Analytics Tab Selection and Default View

**Source:** [fairbanks-fixes.md](../fairbanks-fixes.md) → Phase 9, Step 29
**Depends on:** 28
**Applies to:** development and production

## Context

When several analytics tabs are authorized, the default must match the primary role of the user: doctor to clinical, pharmacist to pharmacy, accountant or billing user to finance, HR user to HR, facility administrator to facility and operations, tenant administrator to an administrative overview. A single-scope user should see no tab navigation, and an unauthorized user no analytics content.

## Requirements

1. Define primary role for each user deterministically, using the existing role model, and document the rule including multi-role tie-breaking.
2. Map each primary role to its default analytics tab, using the report registry from step 28 rather than hardcoded screen names.
3. Select the default tab on first entry; if the mapped tab is not authorized, fall back to the highest-priority authorized tab by the documented order.
4. Remember the last tab the user selected within the session, and prefer it over the default on re-entry while the session lasts.
5. Hide tab navigation entirely when exactly one tab is authorized, and render its content directly.
6. Render no analytics content and no empty tab shell when no report is authorized.
7. Keep deep links to a specific authorized tab working, and deny deep links to unauthorized tabs.
8. Add frontend tests for default selection per primary role, fallback, single-tab rendering, no-access rendering, and deep-link handling.
9. Ship the change to both development and production per **Rollout** below.

## Constraints

- Reuse the catalog from step 28; the frontend must not infer authorization independently.
- Follow `prompts/.cursor/tabs.mdc` for tab construction, ordering, and state.
- Do not persist tab preference across users on a shared device.

## Acceptance Criteria

- [ ] **AC1 (R1, R2, R3)** Each listed role lands on its mapped default tab, with documented fallback when unauthorized.
- [ ] **AC2 (R4)** Re-entering analytics within a session restores the last selected tab.
- [ ] **AC3 (R5)** A single-scope user sees report content with no tab navigation.
- [ ] **AC4 (R6)** A user with no authorized reports sees no analytics content or empty shell.
- [ ] **AC5 (R7)** Deep links open authorized tabs and are denied for unauthorized ones.
- [ ] **AC6 (R8)** New tests pass.
- [ ] **AC7 (R9)** Behavior is identical in development and production.

## Verification

- `flutter analyze`, `flutter test` in `frontend/`.
- `npm run test:backend` if the catalog contract changes.
- Manual: sign in as one user per listed primary role in each environment.

## Rollout — Development and Production

- Behavior must be identical under `NODE_ENV=development` and `NODE_ENV=production`.
- Config: mirror any default-tab define in `frontend/env/development.json.example` and `frontend/env/production.json.example`.
- Schema/data: none expected beyond report registry metadata from step 28.
- Release: `python deploy/deploy-frontend.py` and `python deploy/deploy-android.py`, plus `python deploy/deploy-backend.py` when the catalog changes, then repeat the per-role checks in production.

## Relevant Files

- `frontend/lib/features/reports/presentation/pages/reports_workspace_page.dart`
- `frontend/lib/features/reports/presentation/controllers/reports_workspace_controller.dart`
- `frontend/lib/features/reports/presentation/reports_access.dart`, `reports_role_tailoring.dart`
- `frontend/lib/shared/routing/`, `frontend/lib/core/permissions/`
