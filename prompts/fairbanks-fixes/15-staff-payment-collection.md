# 15 — Allow Authorized Performing Staff to Receive Payment

**Source:** [fairpanks-fixes.md](../fairpanks-fixes.md) → Phase 4, Step 15
**Depends on:** 12, 13, 14
**Applies to:** development and production

## Context

Staff who perform a service should be able to collect payment for it when explicitly authorized, for example `Doctor → Consultation → Bill → Receive Payment`, `Pharmacist → Dispense → Bill → Receive Payment`, and `Lab Staff → Laboratory Service → Bill → Receive Payment`. The capability must be an opt-in permission, never an automatic consequence of performing a service.

## Requirements

1. Create a dedicated `Can Receive Payments` permission, assignable through the role system and enforced at the API layer.
2. Do not grant the permission implicitly to any role by service performance; assignment must be explicit.
3. Allow an authorized performer to record a payment against the bill produced by their own activity, within their resolved scope from step 12.
4. Record on every payment: patient, transaction, service, amount, payment method, receiving staff, date and time, payment reference, facility, and tenant.
5. Generate a receipt for staff-collected payments using the existing receipt template and numbering, with no separate receipt format.
6. Reconcile staff-collected payments into the same ledgers, shift-close, and day-close processes as cashier-collected payments.
7. Prevent double collection: a settled bill must reject a second payment, and concurrent attempts must resolve to exactly one recorded payment.
8. Surface collection state in the performing staff workflow so the user can see what is paid, pending, partially paid, or waived without leaving the screen.
9. Add backend tests for authorization, recording completeness, receipt generation, reconciliation, and double-collection prevention; add frontend tests for the collection dialog states.
10. Ship the change to both development and production per **Rollout** below.

## Constraints

- Reuse the existing payment, invoice, receipt, shift-close, and day-close modules; do not create a parallel payment path.
- Payment method options and references must match the existing finance configuration.
- Unauthorized collection UI must not render, and the backend must reject unauthorized collection requests.

## Acceptance Criteria

- [ ] **AC1 (R1, R2)** A performer without the permission cannot collect payment in UI or API; a performer with it can.
- [ ] **AC2 (R3)** Collection is limited to the resolved scope; out-of-scope bills are rejected.
- [ ] **AC3 (R4)** Every recorded payment contains all listed fields.
- [ ] **AC4 (R5, R6)** Receipts use the standard template and the payment reconciles in shift-close and day-close alongside cashier payments.
- [ ] **AC5 (R7)** A second payment on a settled bill is rejected, and two concurrent attempts produce exactly one payment.
- [ ] **AC6 (R8)** Collection state is visible in the performing workflow.
- [ ] **AC7 (R9)** New backend and frontend tests pass.
- [ ] **AC8 (R10)** Behavior is identical in development and production after deployment.

## Verification

- `npm run test:backend`, `npm run lint`, `npm run openapi:validate` in `backend/`.
- `flutter analyze`, `flutter test` in `frontend/`.
- Manual: doctor, pharmacist, and lab-staff collection journeys in each environment, ending with a printed receipt and a reconciled shift close.

## Rollout — Development and Production

- Behavior must be identical under `NODE_ENV=development` and `NODE_ENV=production`.
- Config: document any payment-method or receipt-numbering key in `backend/env.template.txt` with dev and prod guidance and set it in both env files.
- Schema/data: apply payment schema changes with `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host; sync the new permission into the permission catalog in both databases.
- Release: `python deploy/deploy-backend.py`, `python deploy/deploy-frontend.py`, and `python deploy/deploy-android.py`, then repeat the collection journeys in production.

## Relevant Files

- `backend/src/modules/payment/`, `invoice/`, `billing/`, `shift-close/`, `day-close/`, `chart-account/`
- `backend/src/modules/permission/`, `role-permission/`, `audit-log/`
- `frontend/lib/features/billing/`, `frontend/lib/features/pharmacy/`, `clinical/`, `lab/`
- `frontend/lib/shared/printing/templates/`
