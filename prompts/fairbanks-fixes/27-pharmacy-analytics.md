# 27 — Implement Pharmacy Analytics

**Source:** [fairbanks-fixes.md](../fairbanks-fixes.md) → Phase 8, Step 27
**Depends on:** 12, 14, 16, 25, 26
**Applies to:** development and production

## Context

Pharmacy needs its own reporting and analytics. A pharmacy reporting catalog already exists (`frontend/lib/features/reports/presentation/pharmacy_reporting_catalog.dart` and related widgets); this step completes it with correct, scope-enforced data and the full report set.

## Requirements

1. Implement reports and analytics for dispensing, sales, revenue, stock, purchases, suppliers, expiry, stock adjustments, returns, fast-moving medicines, slow-moving medicines, staff activity, outstanding payments, waived payments, refunds, and prescription versus dispensing comparison.
2. Compute every metric on the backend within the requester resolved scope from step 12; the frontend must not aggregate raw data to produce totals.
3. Support filters for date range, medicine, category, supplier, staff, department, payment status, facility, and other dimensions relevant to each report, with combinations that stay internally consistent.
4. Use the shared metric definitions for revenue, outstanding balance, dispensing volume, stock value, refunds, and waivers so pharmacy figures reconcile with finance figures.
5. Render each report with explicit loading, empty, error, permission, and success states, and keep tables, filters, and dialogs compliant with the surface rules.
6. Gate every report by permission and scope so a user sees only what they are authorized to see, with unauthorized reports not rendering at all.
7. Ensure queries are indexed and paginated so a facility with large history returns within an agreed time budget; record measured timings.
8. Add backend tests for metric correctness (including waived and refunded amounts), scope enforcement, and filter combinations; add frontend tests for catalog rendering and report states.
9. Ship the change to both development and production per **Rollout** below.

## Constraints

- Reuse the existing reporting framework, pharmacy reporting catalog, and shared table and filter components.
- No report may bypass tenant isolation or scope, regardless of filter or URL parameter.
- Do not duplicate metric logic that already exists in the finance modules.

## Acceptance Criteria

- [ ] **AC1 (R1)** Every listed report exists, returns data, and matches a manually reconciled sample.
- [ ] **AC2 (R2, R6)** All aggregation happens server-side within the resolved scope, and unauthorized reports do not render or return data.
- [ ] **AC3 (R3)** Every listed filter works, including combinations, with consistent results.
- [ ] **AC4 (R4)** Pharmacy revenue, outstanding, waived, and refunded figures reconcile with the finance reports for the same period.
- [ ] **AC5 (R5)** All report states render correctly in both themes at representative viewports.
- [ ] **AC6 (R7)** Measured query timings meet the agreed budget on a large dataset.
- [ ] **AC7 (R8)** New backend and frontend tests pass.
- [ ] **AC8 (R9)** Reports return correct, scope-enforced data in development and production.

## Verification

- `npm run test:backend`, `npm run lint`, `npm run openapi:validate` in `backend/`.
- `flutter analyze`, `flutter test` in `frontend/`.
- Manual: reconcile one report per category against raw records in both environments.

## Rollout — Development and Production

- Behavior must be identical under `NODE_ENV=development` and `NODE_ENV=production`.
- Config: document any reporting cache or timeout key in `backend/env.template.txt` with dev and prod guidance and set it in both env files.
- Schema/data: add indexes and any snapshot tables with `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host; verify index creation against production data volumes.
- Release: `python deploy/deploy-backend.py`, `python deploy/deploy-frontend.py`, and `python deploy/deploy-android.py`, then re-reconcile a sample report in production.

## Relevant Files

- `backend/src/modules/reports-workspace/`, `report-definition/`, `report-run/`, `kpi-snapshot/`, `analytics-event/`
- `backend/src/modules/dispense-log/`, `pharmacy-order/`, `drug/`, `drug-batch/`, `inventory-stock/`, `stock-movement/`, `stock-adjustment/`, `purchase-order/`, `goods-receipt/`, `supplier/`, `payment/`, `refund/`, `billing-adjustment/`
- `frontend/lib/features/reports/presentation/pharmacy_reporting_catalog.dart`, `pharmacy_reporting_labels.dart`, `widgets/pharmacy_reporting_*.dart`
- `frontend/lib/shared/reporting/`
