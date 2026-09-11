# 04 — Audit New-Tenant Data Creation

**Source:** [fairpanks-fixes.md](../fairpanks-fixes.md) → Phase 2, Step 4
**Depends on:** 02
**Applies to:** development and production

## Context

Creating a tenant or facility currently inserts records automatically. Some of that is legitimate configuration; some is operational or patient data that must never exist in a brand-new tenant. This step produces the authoritative inventory that steps 05 and 06 act on. Relevant machinery: `backend/src/modules/tenant/`, `backend/src/modules/facility/`, `backend/prisma/seed.js`, `backend/scripts/seeders/`, and the onboarding path exercised by `backend/scripts/verify-onboarding-e2e.js`.

## Requirements

1. Trace every code path that runs when a tenant is created and when a facility is created: service methods, Prisma hooks, seeders, catalog copiers, subscription provisioning, and post-registration jobs.
2. Produce a written inventory at `backend/docs/tenant-initialization-audit.md` listing every table written during tenant/facility creation, the writing code path, the row count per new tenant, and whether rows are tenant-scoped.
3. Classify every entry as **Allowed initial configuration** (lab tests, lab panels, radiology procedures, theatre procedures, clinical diagnoses, currencies, default consultations, pharmacy/master configuration, units, departments, default roles, other approved master-data presets) or **Forbidden initial operational data** (patients, demographics, visits, consultations, prescriptions, lab orders, radiology orders, bills, payments, invoices, dispensing transactions, any patient-linked or transactional record).
4. Identify any demo or filler seeding reachable from tenant creation, including anything invoked through `backend/scripts/seeders/seed-filler-pack.js`, `seed-volume-pack.js`, or `seed-volume-extended-pack.js`, and record how it is triggered in each environment.
5. Record the same audit for the production database: run a read-only count query per candidate table for the most recently created production tenant and attach the results to the audit document.
6. List, for each forbidden entry, the exact removal target for step 05 and the cleanup required for existing tenants.
7. Ship the audit artifacts to both development and production per **Rollout** below.

## Constraints

- This step is read-only against production data; no deletion, mutation, or seeding may run against the production database here.
- Do not refactor or delete code in this step; record findings only.
- Reuse the existing demo-safety guards in `backend/scripts/demo-safety.js` when running any script.

## Acceptance Criteria

- [ ] **AC1 (R1, R2)** The audit document exists and lists every table written by tenant and facility creation with its code path.
- [ ] **AC2 (R3)** Every listed table is classified as allowed or forbidden, with no unclassified entries.
- [ ] **AC3 (R4)** Every demo, filler, and volume seeding entry point reachable from tenant creation is documented with its trigger per environment.
- [ ] **AC4 (R5)** Production counts for a recently created tenant are attached and reconciled against development counts.
- [ ] **AC5 (R6)** Each forbidden entry names its removal target and the cleanup needed for existing tenants.
- [ ] **AC6 (R7)** The audit reflects the code and data of both environments at the same commit.

## Verification

- Create a fresh tenant on the development stack and capture per-table row counts immediately afterwards.
- Read-only production verification through a reviewed query script; results attached to the audit.
- `npm run lint` in `backend/` if any tooling script is added.

## Rollout — Development and Production

- The audit must cover both environments; a finding confirmed only in development is incomplete.
- Config: note any environment variable that changes seeding behavior between `.env.development` and `.env.production` and confirm it is documented in `backend/env.template.txt`.
- Schema/data: no migrations in this step; capture the schema revision of each environment so later steps can detect drift.
- Release: no deployment is required, but the audit must state the deployed backend commit on `https://api.hosspi.com` at the time of measurement.

## Relevant Files

- `backend/src/modules/tenant/`, `backend/src/modules/facility/`
- `backend/prisma/seed.js`, `backend/prisma/schema.prisma`
- `backend/scripts/seeders/`, `backend/scripts/seed-demo-data.js`, `backend/scripts/demo-safety.js`
- `backend/scripts/verify-onboarding-e2e.js`
- `backend/docs/` (new audit document)
