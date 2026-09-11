# 25 — Simplify the Pharmacy Journey

**Source:** [fairbanks-fixes.md](../fairbanks-fixes.md) → Phase 8, Step 25
**Depends on:** 13, 14, 15
**Applies to:** development and production

## Context

The pharmacy path `Prescription → Verification → Selection → Quantity → Pricing → Billing → Payment → Dispensing → Completion` requires too many interactions and repeats information the system already holds. The goal is fewer clicks with every control preserved.

## Requirements

1. Map the current journey step by step, counting user interactions, screens, dialogs, and confirmations from prescription arrival to completion, and record the baseline.
2. Identify every interaction that re-enters data the system already has (patient, prescriber, prescription lines, dosage, price, batch), every redundant confirmation, and every manual calculation.
3. Automate internally what does not require human judgement: default batch selection by expiry and stock policy, quantity derived from the prescription, price resolution from the price book, total calculation, and bill creation.
4. Expose only actions that genuinely need a human decision: substitution, quantity override, batch override, partial dispensing, and payment handling.
5. Preserve stock controls, financial controls, audit trails, prescription traceability, and required authorization checks; every automated default must remain visible and overridable with the override recorded.
6. Collapse the journey into the smallest number of screens or dialogs that keeps each decision clear, reusing the existing pharmacy workspace surfaces.
7. Keep the flow correct when payment is pending (step 13), when a payment is collected by the dispenser (step 15), and when a balance is waived (step 14).
8. Record the post-change interaction count and show the reduction against the baseline.
9. Add tests for the automated defaults, each override path, partial dispensing, stock decrement correctness, and audit completeness.
10. Ship the change to both development and production per **Rollout** below.

## Constraints

- Do not remove or weaken stock, expiry, controlled-substance, financial, or audit controls.
- Reuse the existing pharmacy modules and shared dispensing dialogs; do not fork the workflow.
- Automated defaults must be deterministic and explainable in the UI.
- Follow `prompts/.cursor/dialogs.mdc`, `forms.mdc`, and `tables.mdc`.

## Acceptance Criteria

- [ ] **AC1 (R1, R8)** Baseline and post-change interaction counts are recorded, and the count is measurably lower.
- [ ] **AC2 (R3)** Batch, quantity, price, totals, and bill creation are resolved automatically for a standard prescription.
- [ ] **AC3 (R4, R5)** Every automated default is visible and overridable, and each override is recorded in the audit trail.
- [ ] **AC4 (R5)** Stock decrements, expiry rules, and authorization checks behave exactly as before.
- [ ] **AC5 (R7)** Pending, staff-collected, and waived payment paths all complete correctly.
- [ ] **AC6 (R6)** The journey renders correctly in both themes at representative viewports.
- [ ] **AC7 (R9)** New tests pass.
- [ ] **AC8 (R10)** The simplified journey behaves identically in development and production after deployment.

## Verification

- `npm run test:backend`, `npm run lint`, `npm run openapi:validate` in `backend/`.
- `flutter analyze`, `flutter test` in `frontend/`.
- Manual: dispense a multi-line prescription end to end in each environment, including one substitution and one partial dispense.

## Rollout — Development and Production

- Behavior must be identical under `NODE_ENV=development` and `NODE_ENV=production`; automation defaults must not differ by environment.
- Config: document any batch-selection or pricing policy key in `backend/env.template.txt` or tenant settings with dev and prod guidance and apply the same defaults in both.
- Schema/data: apply pharmacy schema changes with `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host; run `npm run db:backfill:drug-inventory-map` style backfills idempotently in both databases where needed.
- Release: `python deploy/deploy-backend.py`, `python deploy/deploy-frontend.py`, and `python deploy/deploy-android.py`, then repeat the dispensing journeys in production.

## Relevant Files

- `backend/src/modules/pharmacy-order/`, `pharmacy-order-item/`, `pharmacy-workspace/`, `dispense-log/`, `drug/`, `drug-batch/`, `formulary-item/`, `inventory-stock/`, `stock-movement/`, `price-book-entry/`, `pricing-rule/`
- `frontend/lib/features/pharmacy/`
- `frontend/lib/shared/workflow_actions/`, `frontend/lib/shared/clinical_actions/`
