# Pharmacy Reporting: Operational KPIs — Accurate Headline Metrics

Map each KPI button to a single authoritative metric from consumption, throughput, stock risk, or billing—**today means calendar today in facility TZ/UTC consistently**.

## Context

**Already mapped**

- `kpi_prescriptions` → throughput
- `low_stock_items` / `kpi_out_of_stock` / `near_expiry_value` / `expired_stock_value_kpi` → stock risk filters (note: value KPIs currently filter rows but **may still lack `value` column**—add buy-cost value)
- `top_selling_medicines` → consumption top 20 (UI says top 10—**cap at 10** for this id)

**Unmapped:** today sales/profit, transactions, stock value, credit/payables, top profitable, slow-moving.

**Seed:** risk qty profiles + batches; dispenses in clinical/volume; “today” needs dispenses with `dispensed_at` on seed day (wall clock).

## Data contract

| Report id | Metric |
| --- | --- |
| `total_sales_today` | consumption `summary.amount` for **today** range only |
| `todays_profit` | consumption `summary.profit` today (nulls handled) |
| `kpi_prescriptions` | throughput `orders_created` today or selected period—match dialog preset |
| `kpi_transactions` | same as orders_created **or** payment count—subtitle picks one; prefer orders for pharmacy ops |
| `current_stock_value` | Σ qty×buy across stock (not only risk rows) |
| `low_stock_items` | risk LOW+CRITICAL list |
| `kpi_out_of_stock` | qty≤0 |
| `near_expiry_value` / `expired_stock_value_kpi` | Σ qty×buy on EXPIRING_SOON / EXPIRED rows |
| `outstanding_customer_credit` | open pharmacy invoice sum |
| `outstanding_supplier_payments` | AP if real; else unavailable |
| `top_selling_medicines` | top **10** by amount |
| `top_profitable_medicines` | top 10 by `profit` (exclude null profit) |
| `kpi_slow_moving` | same definition as inventory slow_moving |

**Today UX:** opening these ids forces `ModuleReportingPeriodPreset.today` (or equivalent range) so labels match data.

## Requirements

1. Fix top-10 vs top-20 mismatch for `top_selling_medicines`.
2. Add value columns for expiry KPIs at buy cost.
3. Seed volume under default `SEED_RECORD_COUNT`: ≥1,000 dispenses/`paid_at` including **today**, plus stock/invoice volume so every KPI dialog is dense after `db:seed:demo` (`index.md` rule 9).
4. Reuse existing filters/builders.
5. Tests: today range; top 10 length; near_expiry_value = sum qty×buy fixture.

## Constraints

- Not Analytics chips; `index.md` formulas for consumption/stock.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Each KPI matches contract metric and period. | contract |
| A2 | Today KPIs use today range; values at buy cost where stated. | R2 |
| A3 | ≥1,000 fact rows feeding KPIs; today sales/profit and risk KPIs dense after seed. | R3 |

## Relevant Files

- provider top/risk filters; consumption/throughput/inventory/billing datasets; clinical/volume seed; catalog kpi block

## Verification

- Seed day: Total sales today = sum of today’s dispense amounts.
- Manual: KPIs → today sales, low stock, top selling (10 rows).
