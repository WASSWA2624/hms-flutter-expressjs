# Pharmacy Reporting: Management / Executive Dialogs and Demo Seed

Implement Management / Executive report dialogs as executive rollups across financial, inventory, sales, procurement, and risk—with unit-correct charts/tables and demo-ready headlines.

## Context

**Current behavior**

- Category `management_executive` has 24 reports spanning Financial / Inventory / Sales / Procurement / Risk labels. A few map to consumption or stock-risk (`mgmt_sales_trend`, `mgmt_top_products`, `mgmt_expiring`, `mgmt_expired_medicines`, `mgmt_stock_outs`); most unavailable.
- Intended as management-dashboard reports inside Reporting dialogs (not a new route).

**Intended behavior**

- Every management subcategory dialog opens with period rollups suitable for leadership review: trends as charts, rankings as tables, risk lists filtered—all unit-correct and seeded.

**Definitions**

- *Management report:* Cross-cutting rollup id prefixed `mgmt_*` in the catalog.
- *Report ids:* `mgmt_revenue`, `mgmt_expenses`, `mgmt_gross_profit`, `mgmt_net_profit`, `mgmt_profit_margin`, `mgmt_stock_value`, `mgmt_fast_moving`, `mgmt_slow_moving`, `mgmt_expiring`, `mgmt_dead_stock`, `mgmt_stock_turnover`, `mgmt_sales_trend`, `mgmt_top_products`, `mgmt_top_categories`, `mgmt_top_customers`, `mgmt_sales_by_staff_branch`, `mgmt_supplier_spend`, `mgmt_purchase_trends`, `mgmt_supplier_performance`, `mgmt_expired_medicines`, `mgmt_stock_outs`, `mgmt_controlled_medicines`, `mgmt_unusual_adjustments`, `mgmt_high_value_losses`.

## Requirements

1. Map every `mgmt_*` id to datasets/projections; prefer composing existing sales/inventory/financial/procurement/risk runners over duplicating SQL. Charts: revenue, stock turnover, sales trend, purchase trends.
2. Units: money → currency; margins → percent; stock qty → quantity; turnover days/ratios per key convention; risk labels plain.
3. Soft-refresh; empty/error; Excel/PDF by content kind; keep labels localized (Financial:/Inventory:/… prefixes may stay in catalog label or l10n).
4. Seed so each management group has demonstrable rows after `db:seed:demo` (depends on categories 01–16 seeds—implement after or extend those packs).
5. Reuse shared reporting kit exclusively; do not build a separate executive dashboard page in this prompt.
6. Access reports read ∩ pharmacy; responsive stacking of summary+chart+table; light/dark.
7. Tests: each mgmt id leaves unavailable; chart kinds; high-value losses currency; Analytics unchanged.

## Constraints

- Do not rewrite Overview management widgets outside Reporting; compose data from prior category datasets.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/demo-data.mdc`, `prompts/.cursor/prompt.mdc`, `frontend/.cursor/layouts.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | All 24 management reports map to ready/empty/error with seed. | R1 |
| A2 | Currency/percent/qty units correct across financial/inventory/sales/risk. | R2 |
| A3 | Demo shows trend charts + top lists + risk lists non-empty. | R4 |
| A4 | Composes prior datasets; shared kit + access + responsive OK. | R5–R7 |

## Relevant Files

- `.cursor/reporting-analytics.md/pharmacy-reporting.md` §17
- `pharmacy_reporting_catalog.dart` (management block), data provider
- Datasets/seed work from `01`–`16` prompts
- `frontend/lib/shared/reporting/**`
- Provider + seed verification tests

## Verification

- Provider matrix test over all `mgmt_*` ids.
- Manual: Management → sales trend, profit margin, expired medicines, high-value losses; desktop + mobile.
