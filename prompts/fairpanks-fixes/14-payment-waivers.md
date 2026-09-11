# 14 — Implement Payment Waivers

**Source:** [fairpanks-fixes.md](../fairpanks-fixes.md) → Phase 4, Step 14
**Depends on:** 12, 13
**Applies to:** development and production

## Context

Authorized users must be able to waive an outstanding payment so the balance settles to zero with a full audit trail, and financial reporting must distinguish waived amounts from paid, pending, partially paid, refunded, and cancelled amounts.

## Requirements

1. Add a waiver capability to the billing domain that settles all or part of an outstanding balance without recording cash received.
2. Create a dedicated permission for waiving payments, assignable through the role system, and enforce it at the API layer under the hierarchy rules of step 11.
3. Require a mandatory reason and record the authorizing user, timestamp, amount waived, scope (invoice, item, or balance), tenant, and facility.
4. Set the outstanding balance to zero for a full waiver and to the correct remainder for a partial waiver, and mark the transaction financially settled.
5. Represent waived amounts as a distinct status and a distinct ledger entry so revenue is not overstated and outstanding balances are not understated.
6. Write an immutable audit-trail entry for every waiver, including any reversal, with before and after values.
7. Support reversal of a waiver by an authorized user with its own reason and audit entry, where the source plan and accounting rules allow it.
8. Surface waiver state in billing screens, patient ledgers, receipts, and printouts, and include `Waived` in the status vocabulary everywhere it appears.
9. Add backend tests for authorization, full and partial waivers, balance math, reporting classification, audit entries, and reversal; add frontend tests for the waiver dialog states.
10. Ship the change to both development and production per **Rollout** below.

## Constraints

- Reuse the existing billing, invoice, payment, and accounting modules and the chart of accounts; do not model a waiver as a fake payment.
- Never allow a waiver without a recorded reason and authorizing user.
- Unauthorized waiver UI must not render; the backend must reject unauthorized waiver requests regardless of UI state.

## Acceptance Criteria

- [ ] **AC1 (R1, R4)** A full waiver zeroes the balance and a partial waiver leaves the exact remainder.
- [ ] **AC2 (R2)** Only holders of the waiver permission can waive; others are rejected by the API.
- [ ] **AC3 (R3, R6)** Every waiver records reason, authorizer, amount, scope, timestamp, tenant, and facility, and appears in the audit trail with before and after values.
- [ ] **AC4 (R5)** Financial reports distinguish `Paid | Pending | Partially Paid | Waived | Refunded | Cancelled`, and waived amounts are excluded from cash revenue.
- [ ] **AC5 (R7)** An authorized reversal restores the balance and writes its own audit entry.
- [ ] **AC6 (R8)** Waiver state renders in billing screens, ledgers, receipts, and printouts.
- [ ] **AC7 (R9)** New backend and frontend tests pass.
- [ ] **AC8 (R10)** Waivers behave identically in development and production after deployment.

## Verification

- `npm run test:backend`, `npm run lint`, `npm run openapi:validate` in `backend/`.
- `flutter analyze`, `flutter test` in `frontend/`.
- Manual: waive a full and a partial balance in each environment and reconcile the financial report.

## Rollout — Development and Production

- Behavior must be identical under `NODE_ENV=development` and `NODE_ENV=production`.
- Config: document any accounting mapping key in `backend/env.template.txt` with dev and prod guidance and set it in both env files.
- Schema/data: apply waiver tables and status changes with `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host; seed the waiver permission into the permission catalog in both databases with `npm run` catalog sync scripts.
- Release: `python deploy/deploy-backend.py`, `python deploy/deploy-frontend.py`, and `python deploy/deploy-android.py`, then re-run the waiver checks in production.

## Relevant Files

- `backend/src/modules/billing/`, `billing-adjustment/`, `invoice/`, `invoice-item/`, `payment/`, `chart-account/`
- `backend/src/modules/permission/`, `role-permission/`, `audit-log/`
- `backend/scripts/sync-permission-catalog.js`
- `frontend/lib/features/billing/`, `frontend/lib/features/accounts/`
- `frontend/lib/core/permissions/app_permission.dart`
