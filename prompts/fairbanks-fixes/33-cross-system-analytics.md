# 33 — Implement Core Cross-System Analytics

**Source:** [fairbanks-fixes.md](../fairbanks-fixes.md) → Phase 9, Step 33
**Depends on:** 27, 28, 31, 32
**Applies to:** development and production

## Context

Once module analytics are correct, higher-level analytics must combine facilities, clinical, pharmacy, laboratory, radiology, theatre, finance, HR, inventory, procurement, and patient activity using one consistent set of metric definitions.

## Requirements

1. Publish a single metric dictionary defining revenue, outstanding balance, service volume, patient volume, dispensing volume, stock value, refunds, waivers, and staff activity, including inclusions, exclusions, and the period rule for each.
2. Implement cross-system analytics that read from the module sources through the shared definitions, so a figure shown at the cross-system level equals the sum of its module-level components for the same filters.
3. Enforce scope and tenant isolation exactly as in step 31 for every combined query, including drill-down into a module report.
4. Support drill-down from a cross-system figure to the underlying module report with the filter set carried across intact.
5. Keep performance acceptable on large datasets using indexed queries, pagination, and pre-aggregation where justified; document any snapshot or materialization and its refresh rule.
6. Show data freshness on every analytic that is not computed live, including snapshot time and refresh cadence.
7. Reconcile cross-system output against module reports and raw records for at least one full period, and record the reconciliation.
8. Add backend tests for definition consistency, cross-module aggregation, scope enforcement, and drill-down filter fidelity.
9. Ship the change to both development and production per **Rollout** below.

## Constraints

- Do not redefine a metric locally; every figure references the dictionary.
- No pre-aggregation may cross tenant or scope boundaries or serve a cached value to a different scope.
- Reuse the existing KPI snapshot and analytics event modules where they fit.

## Acceptance Criteria

- [ ] **AC1 (R1, R2)** Every cross-system figure equals the sum of its module components for identical filters.
- [ ] **AC2 (R3)** Scope and tenant isolation hold for every combined query and drill-down.
- [ ] **AC3 (R4)** Drill-down opens the module report with the same filters applied.
- [ ] **AC4 (R5, R6)** Performance meets the agreed budget and every non-live analytic displays its freshness.
- [ ] **AC5 (R7)** The reconciliation for a full period matches, with any variance explained.
- [ ] **AC6 (R8)** New tests pass.
- [ ] **AC7 (R9)** Figures reconcile in development and production.

## Verification

- `npm run test:backend`, `npm run lint`, `npm run openapi:validate` in `backend/`.
- `flutter analyze`, `flutter test` in `frontend/`.
- Manual: reconcile one cross-system dashboard against module reports in each environment.

## Rollout — Development and Production

- Behavior must be identical under `NODE_ENV=development` and `NODE_ENV=production`.
- Config: document snapshot refresh cadence, scheduler, and cache keys in `backend/env.template.txt` with dev and prod guidance and set them in both env files; ensure the production scheduler actually runs on the deployed host.
- Schema/data: create snapshot tables and indexes with `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host; backfill snapshots idempotently in both databases and record the run.
- Release: `python deploy/deploy-backend.py`, `python deploy/deploy-frontend.py`, and `python deploy/deploy-android.py`, then re-reconcile in production.

## Relevant Files

- `backend/src/modules/kpi-snapshot/`, `analytics-event/`, `dashboard-widget/`, `dashboard-workspace/`, `reports-workspace/`
- `backend/src/modules/billing/`, `payment/`, `refund/`, `dispense-log/`, `lab-order/`, `radiology-order/`, `theatre-case/`, `inventory-stock/`, `purchase-order/`, `staff-profile/`, `patient/`
- `frontend/lib/shared/dashboard/`, `frontend/lib/shared/reporting/`
- `frontend/lib/features/reports/presentation/widgets/reports_overview_dashboard.dart`, `reports_overview_mapper.dart`
