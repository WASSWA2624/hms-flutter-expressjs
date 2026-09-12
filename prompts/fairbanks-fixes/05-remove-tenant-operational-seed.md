# 05 — Remove Patient and Transactional Data From Tenant Initialization

**Source:** [fairbanks-fixes.md](../fairbanks-fixes.md) → Phase 2, Step 5
**Depends on:** 04
**Applies to:** development and production

## Context

Tenant creation must yield `Configuration + Presets + Empty Operational Data`. The audit from step 04 lists every forbidden insert; this step removes those inserts from the creation path and cleans up tenants that already received them.

## Requirements

1. Remove every forbidden insert identified in `backend/docs/tenant-initialization-audit.md` from the tenant and facility creation paths, including indirect calls into demo, filler, and volume seeders.
2. Keep allowed configuration and preset provisioning intact and working; a new tenant must still receive its master data.
3. Make demo or sample data an explicit, separately invoked, permission-gated action that is never reachable from the normal registration or tenant-creation flow in any environment.
4. Add an automated post-creation assertion that a newly created tenant has zero patients, visits, encounters, consultations, prescriptions, lab orders, radiology orders, bills, payments, invoices, dispensing transactions, and any other patient-linked record; fail tenant creation loudly in tests if the assertion breaks.
5. Write an idempotent cleanup script that reports, and on explicit confirmation removes, seeded operational rows for existing tenants, honoring `backend/scripts/demo-safety.js` and defaulting to dry-run.
6. Extend `backend/scripts/verify-onboarding-e2e.js` (or an equivalent check) to assert the empty-operational-data invariant end to end.
7. Ship the change to both development and production per **Rollout** below, including the cleanup of existing production tenants.

## Constraints

- Do not delete production rows without a dry-run report, an explicit confirmation flag, and a verified backup.
- Do not remove master-data presets while removing operational seeding.
- Reuse existing seeder structure and the established script conventions in `backend/scripts/`.
- Preserve tenant-scoping on every query used by the cleanup script.

## Acceptance Criteria

- [x] **AC1 (R1, R2)** A newly created tenant contains its configuration and presets and zero rows in every forbidden table.
- [x] **AC2 (R4)** The automated assertion covers patients, visits, orders, prescriptions, bills, payments, dispensing transactions, and other patient-linked records, and is executed by the test suite.
- [x] **AC3 (R3)** No registration or tenant-creation path can trigger demo or filler seeding in development or production.
- [x] **AC4 (R5)** The cleanup script reports affected rows per tenant in dry-run and removes only confirmed targets when run with the confirmation flag.
- [x] **AC5 (R6)** The onboarding end-to-end check passes with the empty-operational-data assertion enabled.
- [x] **AC6 (R7)** A tenant created on `https://api.hosspi.com` after deployment satisfies the same zero-row table, and pre-existing production tenants are cleaned or documented as exceptions.

## Verification

- `npm run test:backend` including the new assertion tests.
- Dry-run then confirmed run of the cleanup script on development; dry-run reviewed before any production run.
- Manual: create a tenant in each environment and confirm every operational list renders its empty state.

## Rollout — Development and Production

- Behavior must be identical under `NODE_ENV=development` and `NODE_ENV=production`; seeding must not differ by environment except for the explicitly gated demo action.
- Config: document any demo-gating variable in `backend/env.template.txt` with dev and prod guidance and confirm production keeps demo seeding disabled.
- Schema/data: run the cleanup script against the development database first, then, after backup, against production; both runs must be logged with counts.
- Release: `python deploy/deploy-backend.py`, then create a verification tenant in production and confirm the zero-row result.

## Relevant Files

- `backend/src/modules/tenant/services/`, `backend/src/modules/facility/services/`
- `backend/prisma/seed.js`, `backend/scripts/seeders/`
- `backend/scripts/demo-safety.js`, `backend/scripts/seed-demo-data.js`, `backend/scripts/clear-demo-data.js`
- `backend/scripts/verify-onboarding-e2e.js`, `backend/scripts/verify-demo-data.js`
- `backend/src/tests/` (new assertions)
