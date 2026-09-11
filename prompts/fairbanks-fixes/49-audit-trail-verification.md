# 49 — Verify Audit Trails

**Source:** [fairpanks-fixes.md](../fairpanks-fixes.md) → Phase 15, Step 49
**Depends on:** 48
**Applies to:** development and production

## Context

Important actions must record `Who | What | When | Where | Before | After | Reference`. At minimum: payments, refunds, waivers, dispensing, role changes, permission changes, user management, imports, exports, configuration changes, and sensitive report access.

## Requirements

1. Enumerate every action that must be audited, and map each to the code path that writes its audit entry.
2. Verify each entry records actor identity, action, timestamp with timezone, tenant and facility, before and after values where applicable, and a reference to the affected record.
3. Add missing audit entries for any listed action that does not write one, using the existing audit module rather than a new mechanism.
4. Ensure audit writes are part of the same transaction or a guaranteed follow-up, so a successful action cannot end without its entry.
5. Make audit entries immutable: no update or delete path from the application, and any retention or archival rule documented explicitly.
6. Ensure audit reading is permission-gated and scope-enforced, and that reading an audit entry does not leak cross-tenant data.
7. Verify sensitive report and patient-data access logging feeds the PHI access log where the regulation applies.
8. Add tests asserting an entry exists with correct content for each audited action, and that a failed action does not write a success entry.
9. Record the verification in `backend/docs/audit-verification.md`.
10. Complete the verification in both development and production per **Rollout** below.

## Constraints

- Do not log credentials, tokens, full payment instrument data, or clinical free text beyond what the audit requires.
- Reuse `backend/src/modules/audit-log/` and the realtime audit helpers; do not create a parallel log.
- Audit volume must not degrade the performance targets from step 46; measure if a hot path is affected.

## Acceptance Criteria

- [ ] **AC1 (R1, R2)** Every listed action writes an entry containing all seven required elements.
- [ ] **AC2 (R3, R4)** Previously missing entries are added, and no successful action can complete without its entry.
- [ ] **AC3 (R5)** No application path can modify or delete an audit entry, and retention is documented.
- [ ] **AC4 (R6, R7)** Audit reading is permission-gated and scope-enforced, and PHI access logging is in place where required.
- [ ] **AC5 (R8)** Tests pass, including the failed-action case.
- [ ] **AC6 (R9, R10)** The verification document records passing results for development and production.

## Verification

- `npm run test:backend`, `npm run lint` in `backend/`.
- Manual: perform one of each audited action in both environments and inspect the resulting entries.
- Performance check on the hottest audited path against the step 46 numbers.

## Rollout — Development and Production

- Auditing must be identical under `NODE_ENV=development` and `NODE_ENV=production`; no environment may disable audit writes.
- Config: document retention, archival, and log-level keys in `backend/env.template.txt` with dev and prod guidance and set them in both env files.
- Schema/data: apply audit schema changes with `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host; confirm production storage and backup cover the audit tables.
- Release: `python deploy/deploy-backend.py`, then repeat one of each audited action in production and inspect the entries.

## Relevant Files

- `backend/src/modules/audit-log/`, `phi-access-log/`, `system-change-log/`, `data-processing-log/`, `break-glass-access/`
- `backend/src/lib/realtime/`, `backend/src/middlewares/request-context.middleware.js`
- `backend/src/modules/payment/`, `refund/`, `billing-adjustment/`, `dispense-log/`, `role/`, `role-permission/`, `user/`, `user-role/`, `facility/`
- `backend/docs/` (new audit verification document)
