# 13 — Remove Unnecessary Pending-Payment Blocking

**Source:** [fairpanks-fixes.md](../fairpanks-fixes.md) → Phase 4, Step 13
**Depends on:** 12
**Applies to:** development and production

## Context

Services are blocked whenever payment is pending. The rule must become `Payment Pending → Service Allowed + Payment Status Recorded`, keeping only genuinely required financial or safety controls. Billing logic lives in `backend/src/modules/billing/`, `invoice/`, `payment/`, with guards such as `backend/src/middlewares/clinical-guard.middleware.js` and frontend gating under `frontend/lib/features/billing/` and the workflow action helpers in `frontend/lib/shared/`.

## Requirements

1. Inventory every place a pending, partial, or unpaid balance blocks an action across consultation, prescription, dispensing, laboratory, radiology, theatre, admission, and any other service, and record the guard location for each.
2. For each blocking rule, classify it as required (regulatory, financial-integrity, clinical-safety, or explicit business rule) or unnecessary, with a stated justification.
3. Remove unnecessary blocks so the service proceeds while the outstanding balance is recorded and visible.
4. Keep required blocks, and make each one state its reason in the response and the UI so users understand why an action is refused.
5. Record and surface payment status consistently as `Paid | Pending | Partially Paid | Waived | Refunded | Cancelled` wherever a service is performed, including lists, detail views, and printouts.
6. Ensure an unpaid service still produces a correct billable record so revenue and outstanding balances stay accurate.
7. Make the remaining required controls configurable per tenant where the business model justifies it, defaulting to permissive in both environments unless the source plan says otherwise.
8. Add tests proving each removed block no longer prevents the action and each retained block still does.
9. Ship the change to both development and production per **Rollout** below.

## Constraints

- Do not remove controls that protect financial integrity, stock integrity, clinical safety, or audit completeness.
- Reuse existing billing services and status enums; do not introduce a second payment-status vocabulary.
- Backend remains authoritative: removing a frontend gate without removing the backend gate is not a fix.

## Acceptance Criteria

- [ ] **AC1 (R1, R2)** The inventory lists every payment-related block with its classification and justification.
- [ ] **AC2 (R3)** With an outstanding balance, consultation, prescription, dispensing, laboratory, radiology, theatre, and admission all proceed.
- [ ] **AC3 (R4)** Each retained block returns and displays a specific, localized reason.
- [ ] **AC4 (R5)** Payment status renders consistently across service screens, lists, and printouts.
- [ ] **AC5 (R6)** An unpaid service appears correctly in outstanding balances and revenue records.
- [ ] **AC6 (R8)** Tests cover both removed and retained blocks and pass.
- [ ] **AC7 (R9)** The same behavior is confirmed in development and production after deployment.

## Verification

- `npm run test:backend`, `npm run lint`, `npm run openapi:validate` in `backend/`.
- `flutter analyze`, `flutter test` in `frontend/`.
- Manual: run one unpaid patient journey per service type in each environment.

## Rollout — Development and Production

- Behavior must be identical under `NODE_ENV=development` and `NODE_ENV=production`; no gate may differ by environment.
- Config: document any tenant-level control toggle in `backend/env.template.txt` or tenant settings with dev and prod guidance, and set the same defaults in both.
- Schema/data: apply payment-status schema changes with `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host; backfill statuses idempotently in both databases.
- Release: `python deploy/deploy-backend.py`, `python deploy/deploy-frontend.py`, and `python deploy/deploy-android.py`, then repeat the unpaid journeys in production.

## Relevant Files

- `backend/src/modules/billing/`, `invoice/`, `invoice-item/`, `payment/`, `billing-adjustment/`
- `backend/src/middlewares/clinical-guard.middleware.js`
- `backend/src/modules/encounter/`, `pharmacy-order/`, `dispense-log/`, `lab-order/`, `radiology-order/`, `theatre-case/`, `admission/`
- `frontend/lib/features/billing/`, `frontend/lib/shared/workflow_actions/`, `clinical_actions/`, `patient_actions/`
