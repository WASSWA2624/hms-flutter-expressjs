# Billing: Financial Period Reports and Analytics Visuals

Give billing-entitled users period-based financial reporting (day, month, year, custom) with visuals for collections, expenditures, and profit proxies—via Billing analytics chrome and the existing Reports create/run pipeline—without weakening operational queues or inventing a general ledger.

## Context

**Current behavior**

- `/billing` is operational: queues (needs issue, pending payment, claims, approvals, overdue), timeline, receive payment, adjust/void/refund, shift/day close. Overview exposes workload counts plus **today-only** `payments_today_total` / `refunds_today_total`.
- Per-invoice financials (`computeInvoiceFinancials` / `BillingFinancials`) cover totals, adjustments, paid, refunds, and balance—not period rollups.
- Home shows `collections_today` and billing-role charts via `DashboardChartsRow` (needs `reports:read`). Billing does not deep-link into Reports analytics.
- Reports catalogs `billing_collections_open_balances` (daily collections + issued/open invoices) and `insurance_claims_aging`. Dataset dates support `today`, `this_month`, and custom `from`/`to`; no first-class **year** preset or month/year buckets.
- Widget types include line/bar/area/donut/KPI/table, but billing run previews are not a comprehensive collections / expenditure / profit suite.
- No facility expense/GL module; expenditures and profits are not standalone ledgers.

**Intended behavior**

- Authorized users **see** and **create/run** billing financial reports for money collected over day, month, year, or custom range, with charts and summary detail—not only today KPIs or metadata-only exports.
- Visuals cover **collections**, **expenditures** (billing money-out / revenue reductions), and a **profit proxy**, plus optional breakdowns where data already exists.
- Operational Billing queues, payment capture, closeouts, and claims stay unchanged unless required to expose analytics.
- Reuse Reports datasets/definitions/runs and shared charts; no parallel reporting stack.

**Definitions**

- *Collections*: completed payments in range (prefer net of refunds for “money kept”; disclose gross vs refunded when needed). Align with existing payment status aggregates.
- *Expenditures (billing scope)*: refunds in range plus applied negative adjustments / write-offs / waives. Not payroll, inventory COGS, or a new expense register.
- *Profit proxy*: collections − expenditures (label as net collections / operating surplus—not full P&L).
- *Period*: day, month, year, or custom `from`–`to` (timezone rules match existing report helpers).
- *Granularity*: daily for short ranges; monthly for year or multi-month custom spans.
- *Create report*: save/run a report definition against billing financial datasets with period, format, and visualization via existing Reports APIs/permissions.

## Requirements

1. Extend billing financial datasets (extend `billing_collections_open_balances` and/or add siblings) so period queries return collections, expenditures, and profit-proxy series at the chosen granularity; keep insurance aging complementary.
2. Support presets **day**, **month**, **year**, and **custom** `from`/`to` end-to-end (dataset range resolver, run parameters, Reports/Billing filters). Align filter enums so year/custom are not dropped.
3. Expose analytics for `billing:read` (and `reports:read` where charts/create already require it): period selector, KPI trio, and ≥2 chart types using shared dashboard/report patterns. Prefer a Billing analytics panel **or** Billing → Reports deep link pre-filtered to billing datasets—do not leave visuals only on Home.
4. Enable create/run from Reports (and Billing when entitled): dataset, period, visualization, export format. Completed runs must show visual + tabular series detail, not metadata-only previews.
5. Progressive disclosure: headline metrics + primary charts first; secondary breakdowns (method, refund vs adjustment, open invoices) without cluttering the first viewport.
6. Preserve Billing queues, payment/refund/adjust/approve/closeout, and Home KPIs; extend summaries only for period analytics.
7. Gate analytics read with `billing:read` ∩ billing module; gate chart/create-run with existing reports permissions. Unauthorized UI absent (not disabled). Backend authoritative.
8. Cover loading, empty range, error/retry, validation (invalid custom range), and success feedback. Responsive; theme tokens; light/dark.
9. Update tests for period math, metric definitions, permission presence/absence, and chart/report preview. Reuse design-system and Reports components.

## Constraints

- Reuse `backend/src/lib/reports/datasets.js`, Reports modules, `DashboardChartsRow` / widget types, and `computeInvoiceFinancials` rules—no parallel finance engines.
- Do not add a general expense/GL product; expenditures stay ledger-derived as defined.
- No unrelated queue/claims/Home refactors beyond analytics exposure.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Select day/month/year/custom and see collections for that period. | R1–R3 |
| A2 | Same view shows expenditures and profit proxy per definitions. | R1, R5 |
| A3 | ≥2 charts for authorized users; absent when unauthorized. | R3, R7 |
| A4 | Create/run billing financial report with visual + tabular results. | R4 |
| A5 | Operational queues and payment/closeout flows unchanged. | R6 |
| A6 | Invalid/empty periods show validation/empty; loads show loading. | R8 |
| A7 | Tests cover aggregation, definitions, permissions, authorized flows. | R9 |

## Relevant Files

- `backend/src/lib/reports/datasets.js`, `constants.js`; report-definition / report-run / reports-workspace
- `backend/src/lib/billing/financials.js`; `billing.service.js` overview summary
- `frontend/lib/features/billing/presentation/pages/billing_workspace_page.dart`, `billing_access.dart`, entities/DTOs
- `frontend/lib/features/reports/presentation/`; `frontend/lib/shared/dashboard/dashboard_charts_row.dart`
- Tests: reports dataset/runtime; billing + reports permission/UI tests

## Verification

- Backend: day/month/year/custom aggregation; collections − expenditures = profit proxy; refund/adjustment rules.
- Flutter: analytics visible with grants, absent without; period filters + charts; create/run preview.
- Manual `BILLING` (+ `reports:read`): switch periods, confirm KPIs/charts, run export; queues/pay still work. Light/dark and narrow viewports.
