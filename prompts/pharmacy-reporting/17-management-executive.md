# Pharmacy Reporting: Management / Executive — Composed Accurate Rollups

Implement all `mgmt_*` dialogs as **compositions** of sales/inventory/financial/procurement/risk contracts—same formulas, no executive-only math.

## Context

**Already mapped**

| id | dataset | projection |
| --- | --- | --- |
| `mgmt_sales_trend` | consumption | `daily_totals` |
| `mgmt_top_products` | consumption | top 20 (align to top 10 if label says top) |
| `mgmt_expiring` / `mgmt_expired_medicines` / `mgmt_stock_outs` | stock risk | EXPIRING_SOON / EXPIRED / OOS |

**Remaining 19 ids unavailable.** Management labels prefix Financial/Inventory/Sales/Procurement/Risk in catalog strings.

## Data contract (compose—do not fork)

| id | Reuse contract from |
| --- | --- |
| `mgmt_revenue` | `08` revenue ledger |
| `mgmt_expenses` | billing `expenditures` if real |
| `mgmt_gross_profit` / `mgmt_net_profit` | `08` gross/net |
| `mgmt_profit_margin` | profit/amount percent |
| `mgmt_stock_value` | `15`/`02` stock_value |
| `mgmt_fast_moving` / `mgmt_slow_moving` / `mgmt_dead_stock` | `02` definitions |
| `mgmt_stock_turnover` (chart) | `02` turnover formula |
| `mgmt_top_categories` | sales_by_category |
| `mgmt_top_customers` | purchases_by_customer top N |
| `mgmt_sales_by_staff_branch` | staff + facility slices |
| `mgmt_supplier_spend` / `mgmt_purchase_trends` / `mgmt_supplier_performance` | `14`/`04` |
| `mgmt_controlled_medicines` | `13` stock |
| `mgmt_unusual_adjustments` | adjustments beyond σ or abs qty threshold—**document threshold** |
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

- Full catalog management block; provider; datasets from 01–16; seed packs

## Verification

- `mgmt_revenue` summary == Financial `revenue` for same range/scope.
- Manual: Management → sales trend, profit margin, high-value losses; mobile + desktop.
