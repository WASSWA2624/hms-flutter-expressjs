# 02 — Fix Registration False Errors

**Source:** [fairbanks-fixes.md](../fairbanks-fixes.md) → Phase 1, Step 2
**Depends on:** 01
**Applies to:** development and production

## Context

Registration can report "connection taking too long" or a generic failure while the backend has already created the user, tenant, and facility and queued the verification email. The user then retries and risks duplicate accounts, tenants, or facilities. The end-to-end transaction is `Registration Form → API → User Creation → Tenant/Facility Creation → Email Verification → Response`, spanning `backend/src/modules/auth`, `modules/tenant`, `modules/facility`, and the Flutter `register_page.dart`.

## Requirements

1. Map the registration transaction end to end and document which steps are atomic, which are asynchronous (email delivery), and where a client timeout can diverge from backend success.
2. Make registration idempotent: the client sends a stable idempotency key per registration attempt (reuse `frontend/lib/core/network/idempotency.dart`), and the backend returns the original result for a repeated key instead of creating a second user, tenant, or facility.
3. Wrap user, tenant, and facility creation in a single database transaction so a partial failure leaves no orphaned tenant or facility; email dispatch must occur after commit and must not fail the registration.
4. Return distinct, machine-readable outcome codes for: registration rejected (validation/duplicate), account created and verification email sent, account created but email delayed or failed, and request still in flight or unknown.
5. Add a registration-status lookup the client can call after a timeout so the UI can resolve the true backend state before showing any error.
6. Replace misleading frontend messaging: a timeout must trigger the status lookup and then report the actual outcome. A registration-failed message may render only when the backend confirms no account exists.
7. When the account exists but email delivery failed or is delayed, show a success state with a clear next step (resend verification) rather than an error.
8. Enforce duplicate protection at the database level (unique constraints on registration email and tenant identifiers) and map constraint violations to the existing error-response contract.
9. Add backend tests for the transaction, idempotent replay, email-failure path, and duplicate submissions; add frontend tests for the timeout-then-resolve path.
10. Ship the fix to both development and production per **Rollout** below.

## Constraints

- Reuse the existing error-response contract in `backend/src/lib/response/` and the frontend `network_failure_mapper.dart`; do not invent a new error envelope.
- Do not lengthen timeouts as the fix; the client must resolve truth, not wait longer.
- Do not log or expose credentials, tokens, or verification links in error payloads.
- Follow the localization rules for every new user-visible string.

## Acceptance Criteria

- [ ] **AC1 (R1)** The documented transaction map matches the implemented flow.
- [ ] **AC2 (R2, R8)** Submitting the same registration twice, including after a forced timeout, produces exactly one user, one tenant, and one facility.
- [ ] **AC3 (R3)** An induced failure after user creation leaves no orphaned tenant or facility row.
- [ ] **AC4 (R4, R6)** Under a forced client timeout with backend success, the UI shows success and never shows a connection or failure error.
- [ ] **AC5 (R7)** With the mail transport disabled, the UI shows account-created plus a working resend action.
- [ ] **AC6 (R5)** The status lookup returns the true state for a known registration attempt and is authorized correctly.
- [x] **AC7 (R9)** New backend and frontend tests cover all four outcome codes and pass.
- [ ] **AC8 (R10)** The flow is verified on the development stack and on the production hosts under throttled network conditions.

## Verification

- `npm run lint`, `npm run test:backend`, `npm run openapi:validate` in `backend/`.
- `flutter analyze`, `flutter test` in `frontend/`.
- Manual: throttled and mid-request-offline registration against both environments.

## Rollout — Development and Production

- Behavior must be identical under `NODE_ENV=development` and `NODE_ENV=production`; no fix may depend on a development-only branch, flag, or seed.
- Config: document any new SMTP, idempotency, or timeout key in `backend/env.template.txt` with dev and prod guidance, then set it in `.env.development` and `.env.production`; mirror frontend keys in `frontend/env/development.json.example` and `frontend/env/production.json.example`.
- Schema/data: add unique constraints via `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host; resolve pre-existing duplicates with an idempotent backfill before the constraint reaches production.
- Release: `python deploy/deploy-backend.py` and `python deploy/deploy-frontend.py`, then repeat the acceptance checks against `https://api.hosspi.com` and `https://app.hosspi.com`.

## Relevant Files

- `backend/src/modules/auth/` (controllers, services, routes, schemas)
- `backend/src/modules/tenant/`, `backend/src/modules/facility/`
- `backend/prisma/schema.prisma`, `backend/prisma/migrations/`
- `backend/src/lib/response/`, `backend/src/middlewares/error.middleware.js`
- `frontend/lib/features/auth/presentation/pages/register_page.dart`
- `frontend/lib/features/auth/data/repositories/auth_repository_impl.dart`
- `frontend/lib/core/network/idempotency.dart`, `network_failure_mapper.dart`, `api_client.dart`
