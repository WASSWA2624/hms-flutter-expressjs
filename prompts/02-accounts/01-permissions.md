# Accounts — Permissions

## Context

Define and wire **Accounts** RBAC/ABAC for the `/accounts` workspace (`facility-accounts` module) per `accounts.md` §9 and Prompt Definition Standards. Backend remains authoritative. Unauthorized UI, data, routes, and actions must not render. This prompt covers permission catalog keys, module entitlement, access gates, and UI omission rules — not individual tab chrome (see `03`–`09`).

## Requirements

1. Add canonical permission keys `accounts:read` and `accounts:write` to the shared permission catalog (backend `PERMISSIONS`, metadata display names/descriptions, frontend catalog alignment, seeds).
2. Map Accounts permission prefix to subscription module `facility-accounts` in the permission–module map (same pattern as `billing` → `billing-payments`).
3. Gate the `/accounts` route with (`accounts:read` ∪ `accounts:write`) ∩ `facility-accounts`. Fallback visible tab when other sections are unauthorized: **Open work**.
4. Require `accounts:write` for write actions: Journal · Post · Post all · Reverse · Void · Send · Open period · Close period · chart Add/Edit/Deactivate (chart write may also accept admin write equivalents already used elsewhere).
5. Require `accounts:write` ∩ `financial:approve` for Approve / Reject on journal posts, voids, reversals, and period close.
6. Allow Patient ledgers browse with `accounts:read` ∩ `facility-accounts`.
7. Show Pay deep-link / Pay actions only when (`billing:write`) ∩ `billing-payments`; omit when unauthorized (do not invent an accounts-only pay permission).
8. Hide unauthorized tabs and actions entirely. Do not render disabled “no access” chrome. Forbidden feedback may appear only for direct restricted URL access, stale permissions, or backend denial.
9. Align frontend `accounts_access` (or equivalent) requirements with backend authorize middleware so client and server deny the same atoms.
10. Persist permission descriptions in catalog metadata:
    - `accounts:read` — open Accounts workspace and read books data (queues, GL, patient ledgers, chart, periods).
    - `accounts:write` — create/post journals, reverse/void/send, open/close periods, and mutate chart of accounts.
11. Cover loading, empty, error, success, and validation states on gated surfaces; after permission-sensitive mutations, synchronize workspace state.
12. Keep Billing and Reporting permissions separate: Accounts must not grant `billing:*` by implication except where Pay explicitly reuses billing write ∩ `billing-payments`.

## Constraints

- Do not grant Accounts access via `hr:read` / `hr:write` alone.
- Do not render unauthorized controls as disabled placeholders.
- Do not recreate removed inventory folders; inventory atoms from presentation, routes, and tests.
- Reuse existing authorize middleware, access policy, AppAccessGate, and subscription entitlement patterns.
- No unrelated refactoring outside Accounts permission wiring.

## Acceptance Criteria

- [ ] AC1: Catalog includes `accounts:read` and `accounts:write` with metadata. (R1, R10)
- [ ] AC2: Route entry requires (`accounts:read` ∪ `accounts:write`) ∩ `facility-accounts`. (R2, R3)
- [ ] AC3: Write actions require `accounts:write`; Approve/Reject require `accounts:write` ∩ `financial:approve`. (R4, R5)
- [ ] AC4: Patient ledgers readable with `accounts:read`; Pay absent without billing write ∩ `billing-payments`. (R6, R7)
- [ ] AC5: Unauthorized tabs/actions are absent (not disabled) in UI tests. (R8, R9)
- [ ] AC6: Missing `facility-accounts` entitlement strips Accounts route and nav even if permission keys are present. (R2, R3)
- [ ] AC7: Frontend access helpers and backend authorize agree on the same gates. (R9)
- [ ] AC8: Billing cashier permissions remain distinct; Accounts does not absorb Collect due / Charge. (R12)

## Verification

- Backend permission catalog / role-map tests for new keys and module mapping.
- Frontend `accounts_access` unit tests for route, read, write, approve, Pay, and module strip.
- Widget permissions tests: unauthorized atoms absent; authorized atoms present.
- Manual check: user with only `hr:*` cannot open `/accounts`; user with accounts read can browse; write/approve combinations match §9.

## Relevant Files

- `accounts.md` (§9)
- `prompts/02-accounts/02-roles.md`
- `backend/src/config/permissions.js`
- `backend/src/config/permission-catalog-metadata.js`
- `backend/src/lib/authorization/permission-module-map.js`
- `frontend/lib/core/permissions/route_access_catalog.dart`
- `frontend/lib/features/accounts/presentation/accounts_access.dart`
- `frontend/test/features/accounts/presentation/accounts_access_test.dart`
- `frontend/test/core/permissions/route_access_catalog_test.dart`
- `backend/src/tests/config/permissions.test.js`
- `backend/src/tests/lib/authorization/permission-module-map.test.js`
