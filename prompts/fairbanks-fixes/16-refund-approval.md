# 16 — Fix Refund Approval

**Source:** [fairbanks-fixes.md](../fairbanks-fixes.md) → Phase 4, Step 16
**Depends on:** 14, 15
**Applies to:** development and production

## Context

Refund approval is unreliable. The full path `Refund Request → Authorization → Approval → Financial Transaction → Status Update` must work, with a dedicated approval permission and complete handling of full, partial, duplicate, and failed refunds. Code lives in `backend/src/modules/refund/` with billing and payment integration.

## Requirements

1. Create a dedicated `Can Approve Refund` permission, enforced at the API layer, separate from the permission to request a refund.
2. Implement the complete state machine: requested, approved, rejected, processed, failed, and cancelled, with allowed transitions and no hidden states.
3. Support full and partial refunds against a specific payment or invoice, validating that the refundable amount never exceeds the settled amount minus prior refunds.
4. Make approval and processing atomic and idempotent so a retried approval cannot produce a second financial transaction.
5. Reject refunds on an already processed request, and surface the existing outcome instead of an error that suggests failure.
6. Handle processing failure explicitly: record the failure reason, leave the balance untouched, and allow a controlled retry.
7. Update the source payment, invoice, patient ledger, and reporting status to `Refunded` or partially refunded on success.
8. Write audit entries for request, approval, rejection, processing, failure, and retry, including actor, amount, reason, and before and after values.
9. Add backend tests for full refund, partial refund, authorized approver, unauthorized user, already-processed request, failed refund, and duplicate attempts; add frontend tests for the request and approval dialogs.
10. Ship the change to both development and production per **Rollout** below.

## Constraints

- Reuse the refund, payment, invoice, and accounting modules and the standard response contract.
- Never allow the approver and the requester to be the same user unless the business rule explicitly permits it; make that rule explicit either way.
- Unauthorized approval UI must not render, and the backend must reject unauthorized approvals.

## Acceptance Criteria

- [ ] **AC1 (R1)** Only holders of the approval permission can approve; requesters without it are rejected by the API.
- [ ] **AC2 (R2, R3)** Full and partial refunds move through the documented states and never exceed the refundable amount.
- [ ] **AC3 (R4)** A repeated approval of the same request produces exactly one financial transaction.
- [ ] **AC4 (R5)** An already-processed request returns its existing outcome rather than a misleading failure.
- [ ] **AC5 (R6)** A failed refund records the reason, leaves the balance unchanged, and can be retried.
- [ ] **AC6 (R7)** Payment, invoice, ledger, and report status reflect the refund immediately.
- [ ] **AC7 (R8)** The audit trail contains every refund lifecycle event with full context.
- [ ] **AC8 (R9)** New backend and frontend tests pass.
- [ ] **AC9 (R10)** The refund journey behaves identically in development and production after deployment.

## Verification

- `npm run test:backend`, `npm run lint`, `npm run openapi:validate` in `backend/`.
- `flutter analyze`, `flutter test` in `frontend/`.
- Manual: execute the seven refund test cases in each environment and reconcile the finance report.

## Rollout — Development and Production

- Behavior must be identical under `NODE_ENV=development` and `NODE_ENV=production`.
- Config: document any refund gateway or accounting mapping key in `backend/env.template.txt` with dev and prod guidance and set it in both env files.
- Schema/data: apply refund state and amount schema changes with `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host; backfill states for existing refunds idempotently in both databases.
- Release: `python deploy/deploy-backend.py`, `python deploy/deploy-frontend.py`, and `python deploy/deploy-android.py`, then repeat the refund cases in production with a reversible test amount.

## Relevant Files

- `backend/src/modules/refund/`, `payment/`, `invoice/`, `billing/`, `billing-adjustment/`, `chart-account/`
- `backend/src/modules/permission/`, `role-permission/`, `audit-log/`
- `frontend/lib/features/billing/`, `frontend/lib/features/accounts/`
- `backend/prisma/schema.prisma`
