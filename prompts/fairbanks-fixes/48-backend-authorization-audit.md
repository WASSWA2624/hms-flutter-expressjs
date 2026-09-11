# 48 — Verify Backend Authorization

**Source:** [fairbanks-fixes.md](../fairbanks-fixes.md) → Phase 15, Step 48
**Depends on:** 11, 12, 31, 47
**Applies to:** development and production

## Context

Every sensitive action must be secured at the API level, independent of the UI. This step proves it for payments, refunds, waivers, roles, permissions, users, facility configuration, tenant data, reports, analytics, and exports.

## Requirements

1. Enumerate every sensitive route across the listed areas and record its required permission, scope, and tenant rule.
2. Test each route with an unauthenticated request, an authenticated request lacking the permission, a request from another tenant, and a request outside the resolved scope.
3. Confirm every denial uses the standard response contract, reveals no existence or content, and is logged.
4. Confirm that no sensitive action is reachable through an alternative path: a bulk endpoint, a report or export, a websocket event, an API key, or an import.
5. Verify API key and integration access paths carry the same permission and scope checks as interactive sessions.
6. Verify websocket and realtime channels enforce tenant and scope membership before delivering any event.
7. Fix every gap found, then re-run the full enumeration so the final result has no unproven route.
8. Add the enumeration as an automated test suite so a future route without authorization fails the build.
9. Record the results in `backend/docs/authorization-verification.md`.
10. Complete the verification in both development and production per **Rollout** below.

## Constraints

- Do not weaken a check to make a probe pass; every failure is a defect to fix.
- Production probes must be read-only or use disposable data, cleaned up afterwards.
- Reuse the existing middleware and policy layers; new checks must fit the established pattern.

## Acceptance Criteria

- [ ] **AC1 (R1)** Every sensitive route is enumerated with its permission, scope, and tenant rule.
- [ ] **AC2 (R2, R3)** All four negative cases are denied for every route, with no information leakage, and each denial is logged.
- [ ] **AC3 (R4, R5, R6)** Bulk, export, import, API key, and realtime paths enforce the same rules.
- [ ] **AC4 (R7)** Every gap found is fixed and the re-run shows no unproven route.
- [ ] **AC5 (R8)** The automated suite fails when a route is added without authorization.
- [ ] **AC6 (R9, R10)** The verification document records passing results for development and production.

## Verification

- `npm run test:backend` including the authorization suite; `npm run lint`; `npm run openapi:validate`.
- Authenticated and unauthenticated probes against `https://api.hosspi.com`.
- Review of the generated OpenAPI document against the enumeration.

## Rollout — Development and Production

- Enforcement must be identical under `NODE_ENV=development` and `NODE_ENV=production`; no environment may skip a check.
- Config: confirm authorization, API key, and realtime keys match in `.env.development` and `.env.production` semantics and are documented in `backend/env.template.txt`.
- Schema/data: confirm both databases are at the same migration revision, and that permission catalogs are synchronized in both.
- Release: `python deploy/deploy-backend.py` before the production probe set, then repeat the enumeration against production.

## Relevant Files

- `backend/src/middlewares/auth.middleware.js`, `abac.middleware.js`, `tenant-scope.middleware.js`, `session.middleware.js`, `csrf.middleware.js`, `live-access.middleware.js`, `module-entitlement.middleware.js`
- `backend/src/modules/api-key/`, `api-key-permission/`, `integration/`, `webhook-subscription/`
- `backend/src/websockets/`, `backend/src/modules/**/routes/`
- `backend/scripts/generate-openapi.js`, `backend/scripts/validate-openapi.js`
- `backend/docs/` (new authorization verification document)
