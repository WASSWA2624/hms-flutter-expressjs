# Pharmacy Reporting: Management / Executive — Composed Accurate Rollups

Implement all `mgmt_*` dialogs as **compositions** of sales/inventory/financial/procurement/risk contracts—same formulas, no executive-only math.

## Context

**Composition table:** `pharmacyReportingMgmtCompositions` in `pharmacy_reporting_mgmt_sources.dart` (id → sourceReportId / datasetKey / projection). Catalog Management block is built from that list.

**All 24 `mgmt_*` mapped** — reuse named source contracts (shared datasetKey + projector fall-throughs). No executive-only math; `mgmt_controlled_medicines` composes pack 13 `controlled_medicine_stock`.

**Already dense via 01–16 seeds** for trends/tops/risk; management adds no new executive route or seed pack.

## Data contract (compose—do not fork)

| id | Reuse contract from |
| --- | --- |
| `mgmt_revenue` | `08` revenue ledger |
| `mgmt_expenses` | billing `expenditures` if real |
| `mgmt_gross_profit` / `mgmt_net_profit` | `08` gross/net |
| `mgmt_profit_margin` | profit/amount percent on gross-profit ledger |
| `mgmt_stock_value` | `15`/`02` stock_value |
| `mgmt_fast_moving` / `mgmt_slow_moving` / `mgmt_dead_stock` | `02` definitions |
| `mgmt_stock_turnover` (chart) | `02` turnover formula |
| `mgmt_top_categories` | sales_by_category top 10 |
| `mgmt_top_customers` | purchases_by_customer top 10 |
| `mgmt_sales_by_staff_branch` | sales_by_staff; branch = facility scope |
| `mgmt_supplier_spend` / `mgmt_purchase_trends` / `mgmt_supplier_performance` | `14`/`04` |
| `mgmt_controlled_medicines` | `13` stock — unavailable until pack 13 |
| `mgmt_unusual_adjustments` | leave-one-out `|qty| > mean+2σ` (n≥2); else `|qty|≥10` |
| `mgmt_high_value_losses` | damage/expiry/write-off `value` desc |

Charts: `mgmt_revenue`, `mgmt_stock_turnover`, `mgmt_sales_trend`, `mgmt_purchase_trends`.

## Requirements

1. Provider maps each `mgmt_*` to the same datasetKey/projection as its source report id where possible (shared helper table id→source).
2. Totals for a period must equal source report summaries (tolerance 0.01 for money).
3. Implement after (or with) underlying category seeds 01–16—those packs must already meet ≥1,000-row floors so management rollups are dense (`index.md` rule 9).
4. Reuse shared kit only—no new executive route.
5. Tests: matrix all `mgmt_*` leave unavailable; parity assertions vs source summaries; Analytics unchanged.

## Constraints

- `index.md` accuracy rules; no divergent COGS/revenue math.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Every mgmt id composes a named source contract. | contract |
| A2 | Money parity within 0.01 vs source dialog/dataset. | R2 |
| A3 | Underlying ≥1,000-row seeds make trends, tops, and risk lists dense. | R3 |

## Relevant Files

- `pharmacy_reporting_mgmt_sources.dart`; catalog; provider; datasets from 01–16; seed packs

## Verification

- `mgmt_revenue` summary == Financial `revenue` for same range/scope.
- Manual: Management → sales trend, profit margin, high-value losses; mobile + desktop.
