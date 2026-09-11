# 01 — Fix the Login Password Field

**Source:** [fairbanks-fixes.md](../fairbanks-fixes.md) → Phase 1, Step 1
**Depends on:** none
**Applies to:** development and production

## Context

The login password field intermittently stops accepting keyboard input and only recovers after a full page refresh. The failure is reproducible in the deployed web build at `https://app.hosspi.com` and in local development. The cause must be identified in the login page's widget lifecycle, focus handling, and session bootstrap — not masked by rebuilding the field.

Login UI lives in `frontend/lib/features/auth/presentation/pages/login_page.dart`, driven by `auth_controller.dart`, with session bootstrap in `frontend/lib/core/security/session_readiness.dart` and `session_controller.dart`.

## Requirements

1. Reproduce the defect deterministically and record the trigger (failed login retry, navigation away and back, autofill, session-restore rebuild, or overlay capture of focus). Document the confirmed root cause in the pull request description before changing code.
2. Stabilise the password field's identity across rebuilds: `TextEditingController` and `FocusNode` must be owned by a `State` (or an equivalently stable provider scope) and must not be recreated on controller-state changes, locale changes, or theme changes.
3. Ensure the field's `enabled`/`readOnly` state is derived from a single submit-in-flight source of truth that is always reset on success, on failure, on validation error, and on cancellation — including when the request fails with a timeout or network error.
4. Ensure no overlay, loading barrier, `AbsorbPointer`, `IgnorePointer`, or full-screen progress layer remains mounted or hit-testable after a login attempt resolves.
5. Ensure route re-entry (login → elsewhere → login) yields a fresh, focusable, editable field with cleared submit state, and that browser autofill of username or password does not detach or disable the field.
6. Preserve existing validation, error display, localization, theming, and responsive behavior; unauthorized or "no access" feedback rules must remain unchanged.
7. Add widget tests that fail on the old behavior: enter text → submit with invalid credentials → assert the field still accepts text; and navigate away and back → assert the field still accepts text.
8. Ship the fix to both development and production per **Rollout** below.

## Constraints

- Reuse the existing auth controller, form components, and design-system field widgets; do not introduce a parallel login form or a new text-field abstraction.
- Do not add `key: UniqueKey()`, forced remounts, timers, or post-frame hacks as a workaround for a lifecycle bug.
- Do not weaken password masking, autofill hints, or input validation.
- Follow `prompts/.cursor/forms.mdc`, `localization.mdc`, `theming.mdc`, and `responsiveness.mdc`.

## Acceptance Criteria

- [ ] **AC1 (R1)** The root cause is stated explicitly and matches the code change.
- [ ] **AC2 (R2, R3)** Ten consecutive failed login attempts leave the password field editable with no refresh.
- [ ] **AC3 (R3)** A login attempt that times out restores the field to an editable, enabled state.
- [ ] **AC4 (R4)** After any login outcome, no overlay intercepts pointer or keyboard input on the login form.
- [ ] **AC5 (R5)** Navigating away from and back to login yields an empty, focusable, editable password field; browser autofill leaves the field editable.
- [ ] **AC6 (R6)** Validation messages, localized strings, light/dark themes, and mobile/tablet/desktop layouts are unchanged.
- [ ] **AC7 (R7)** New widget tests fail against the pre-fix code and pass after the fix.
- [ ] **AC8 (R8)** The behavior is verified in the local build and on `https://app.hosspi.com` after deployment.

## Verification

- `flutter analyze` and `flutter test` in `frontend/`.
- New tests under `frontend/test/features/auth/`.
- Manual: Chrome (with and without saved credentials), Android APK, small/medium/large viewports, light and dark themes.

## Rollout — Development and Production

- Behavior must be identical under `NODE_ENV=development` and `NODE_ENV=production` and under both Flutter define files; no fix may depend on a development-only branch, flag, or seed.
- Config: add any new key to `backend/env.template.txt` with dev and prod guidance and set it in `.env.development` and `.env.production`; mirror frontend keys in `frontend/env/development.json.example` and `frontend/env/production.json.example`.
- Schema/data: `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host; any backfill must be idempotent and safe to re-run on live data.
- Release: `python deploy/deploy-frontend.py` (plus `deploy-backend.py`/`deploy-android.py` when those change), then repeat the acceptance checks against `https://app.hosspi.com` and `https://api.hosspi.com`.

## Relevant Files

- `frontend/lib/features/auth/presentation/pages/login_page.dart`
- `frontend/lib/features/auth/presentation/controllers/auth_controller.dart`
- `frontend/lib/features/auth/presentation/widgets/auth_page_frame.dart`, `auth_shell_layout.dart`, `auth_primary_button.dart`
- `frontend/lib/core/security/session_readiness.dart`, `session_controller.dart`, `session_manager.dart`
- `frontend/lib/shared/forms/`, `frontend/lib/shared/components/`
- `frontend/test/features/auth/`
