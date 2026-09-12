# 07 — Verify Tenant Isolation

**Source:** [fairbanks-fixes.md](../fairbanks-fixes.md) → Phase 2, Step 7
**Depends on:** 04, 05, 06
**Applies to:** development and production

> **Gate:** No later step may be marked complete until this step passes in both environments.

## Context

Tenant isolation is the highest-priority data-integrity property in the plan. Steps 04 to 06 changed what a new tenant receives; this step proves that no data, configuration, or access crosses a tenant boundary at any layer: UI, API, authorization, and database.

## Requirements

1. Create two independent tenants (A and B), each with a facility, an administrator, and a staff user, in development and in production using the normal registration flow.
2. Verify at the UI level that patients, facilities, facility records, and transactions created in A never appear anywhere in B, including lists, search, dashboards, dropdowns, autocomplete, and reports.
3. Verify at the API level that a valid token for tenant B cannot read, update, or delete a resource belonging to tenant A by direct identifier, including friendly identifiers, and that the response is the standard not-found or forbidden result without leaking existence.
4. Verify at the authorization layer that tenant scope is enforced by `backend/src/middlewares/tenant-scope.middleware.js` and the ABAC policy layer for every module route, and produce a coverage list of routes proving enforcement.
5. Verify at the database/query level that every tenant-scoped repository query filters by tenant, and that no raw query or aggregate bypasses the filter.
6. Verify that configuration changes applied in tenant A leave tenant B unchanged, including presets adopted in step 06.
7. Add automated cross-tenant access tests to the backend suite covering read, write, delete, list, search, export, and report routes for a representative set of modules including patient, encounter, invoice, payment, dispense-log, lab-order, and facility.
8. Record the results in `backend/docs/tenant-isolation-verification.md`, including any route that could not be proven and its remediation.
9. Complete the verification in both development and production per **Rollout** below.

## Constraints

- Do not create patient or clinical records in production beyond the minimum needed for the check, and remove them afterwards with a logged cleanup.
- Do not weaken any existing guard to make a test pass; failures are defects to fix, not expectations to relax.
- Reuse existing test helpers and the established response contract.

## Acceptance Criteria

- [ ] **AC1 (R2)** No record from tenant A is visible anywhere in the tenant B interface.
- [ ] **AC2 (R3)** Every direct-identifier cross-tenant API attempt is denied and reveals nothing about the target resource.
- [x] **AC3 (R4)** The route coverage list shows tenant-scope enforcement for every tenant-scoped route, with no unenforced route remaining.
- [x] **AC4 (R5)** No repository or raw query returns cross-tenant rows.
- [ ] **AC5 (R6)** Configuration and preset changes in A leave B unchanged.
- [x] **AC6 (R7)** The automated cross-tenant test suite passes and fails when a guard is deliberately removed.
- [ ] **AC7 (R8, R9)** The verification document records passing results for both development and production.

## Verification

- `npm run test:backend` including the new cross-tenant suite.
- Manual UI sweep in both tenants at representative viewports and themes.
- Authenticated API probes against `https://api.hosspi.com` with tokens from both tenants.

## Rollout — Development and Production

- Isolation must hold identically under `NODE_ENV=development` and `NODE_ENV=production`; a pass in one environment does not satisfy this gate.
- Config: confirm tenant-scope and ABAC enforcement flags are set the same way in `.env.development` and `.env.production`, and documented in `backend/env.template.txt`.
- Schema/data: confirm both databases are at the same migration revision before verifying.
- Release: deploy the current backend and frontend with the deploy scripts before running the production pass, then clean up the verification tenants.

## Relevant Files

- `backend/src/middlewares/tenant-scope.middleware.js`, `abac.middleware.js`, `auth.middleware.js`
- `backend/src/modules/abac-policy/`, `backend/src/modules/tenant/`
- `backend/src/modules/patient/`, `encounter/`, `invoice/`, `payment/`, `dispense-log/`, `lab-order/`, `facility/`
- `backend/src/tests/middlewares/tenant-scope.middleware.test.js`, `backend/src/tests/`
- `backend/docs/` (new verification document)
