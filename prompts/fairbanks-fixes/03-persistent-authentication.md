# 03 — Implement Persistent Authentication

**Source:** [fairbanks-fixes.md](../fairbanks-fixes.md) → Phase 1, Step 3
**Depends on:** 01, 02
**Applies to:** development and production

## Context

Sessions are lost too easily: users are logged out mid-workflow, and reopening the app forces re-authentication. The frontend already has a session layer (`frontend/lib/core/security/`) with `secure_session_storage.dart`, `session_refresh_service.dart`, and `session_refresh_coordinator.dart`; the backend has `user-session` and `auth` modules plus `session.middleware.js`. This step makes session persistence and renewal reliable rather than replacing the architecture.

1. Requirements
1. Persist session tokens through the existing secure storage layer on every supported platform (web, Android, Windows), and document the storage mechanism used per platform.
2. Restore the session during startup before the first authenticated route renders, with a deterministic readiness state so no screen flashes an unauthenticated view for a valid session.
3. Implement refresh-token renewal with a single-flight coordinator: concurrent 401 responses trigger one refresh, queued requests replay after it succeeds, and a failed refresh logs out once.
4. Treat access-token expiry as a normal, recoverable event; only an invalid or revoked refresh token, an explicit logout, or a configured security policy may end the session.
5. Protect active workflows: a transient network failure, a 5xx, or a timeout must never clear stored credentials or drop in-progress form data.
6. Implement secure logout that revokes the server-side session, clears secure storage and caches, and isolates any per-user cached data via `session_isolation.dart`.
7. Make session lifetime policy explicit and configurable (access-token TTL, refresh-token TTL, idle timeout, absolute timeout), enforced identically in both environments.
8. Add tests: cold-start restore, expiry-then-refresh, concurrent-request refresh, refresh failure, logout revocation, and offline tolerance.
9. Ship the change to both development and production per **Rollout** below.

## Constraints

- Reuse the existing session classes and interceptors; do not add a second token store or a parallel HTTP client.
- Never persist tokens in plain preferences, in URLs, or in logs.
- Backend stays authoritative: a revoked or expired refresh token must be rejected server-side regardless of client state.
- Keep offline and sync behavior in `frontend/lib/core/sync/` working.

## Acceptance Criteria

- [ ] **AC1 (R1, R2)** Closing and reopening the app ten times restores the session automatically each time, with no login prompt and no unauthenticated flash.
- [ ] **AC2 (R3)** With the access token forcibly expired, five concurrent requests trigger exactly one refresh call and all five succeed.
- [ ] **AC3 (R4, R5)** A simulated backend outage during an active workflow does not log the user out; requests resume after recovery.
- [ ] **AC4 (R6)** After logout, stored tokens are gone, the server session is revoked, and cached data from the previous user is unreachable.
- [ ] **AC5 (R7)** Configured TTL and idle policy values are enforced identically in development and production and documented in `backend/env.template.txt`.
- [ ] **AC6 (R8)** The journey `Login → Dispense → Wait → Navigate → Close App → Reopen App → Continue` completes without re-authentication.
- [ ] **AC7 (R9)** The journey passes on the development stack and against the production hosts.

## Verification

- `flutter analyze`, `flutter test`; backend `npm run test:backend`.
- Integration coverage under `frontend/integration_test/` for cold-start restore.
- Manual: browser refresh and new tab, Android APK background-kill-reopen, Windows desktop restart.

## Rollout — Development and Production

- Behavior must be identical under `NODE_ENV=development` and `NODE_ENV=production`; no session behavior may depend on a development-only branch or a relaxed local policy.
- Config: add TTL, idle, absolute-timeout, and token/cookie keys to `backend/env.template.txt` with dev and prod guidance, then set them in `.env.development` and `.env.production`; mirror any frontend define in `frontend/env/development.json.example` and `frontend/env/production.json.example`.
- Schema/data: apply session-table changes with `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host.
- Release: `python deploy/deploy-backend.py`, `python deploy/deploy-frontend.py`, `python deploy/deploy-android.py`, then repeat the acceptance checks in production.

## Relevant Files

- `frontend/lib/core/security/` (all session files)
- `frontend/lib/core/storage/secure/app_secure_storage.dart`, `storage_providers.dart`
- `frontend/lib/core/network/api_interceptors.dart`, `connection_retry_interceptor.dart`, `api_client.dart`
- `frontend/lib/bootstrap.dart`, `frontend/lib/app/`
- `backend/src/modules/auth/`, `backend/src/modules/user-session/`
- `backend/src/middlewares/session.middleware.js`, `auth.middleware.js`
