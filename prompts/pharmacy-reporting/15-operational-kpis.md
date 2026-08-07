# Pharmacy Reporting: Operational KPIs Dialogs and Demo Seed

Implement Operational KPIs report dialogs as demo-ready KPI cards/tables with today and period metrics, correct units, and seeded headline numbers.

## Context

**Current behavior**

- Category `operational_kpis` has 14 reports. Some map to throughput/stock-risk/consumption (`kpi_prescriptions`, low/OOS/near-expiry/expired value, top selling); many still unavailable (today sales/profit, transactions, stock value, credit/payables, top profitable, slow-moving).
- KPI dialogs should summarize “what happened” for the operational layer called out in the reporting doc.

**Intended behavior**

- Each KPI button opens a dialog focused on that metric (summary + supporting rows) with today-aware presets where labeled “today”, otherwise selected period; units correct for money/qty/count.

**Definitions**

- *KPI report:* Single-metric-forward projection with optional top-N breakdown.
- *Report ids:* `total_sales_today`, `todays_profit`, `kpi_prescriptions`, `kpi_transactions`, `current_stock_value`, `low_stock_items`, `kpi_out_of_stock`, `near_expiry_value`, `expired_stock_value_kpi`, `outstanding_customer_credit`, `outstanding_supplier_payments`, `top_selling_medicines`, `top_profitable_medicines`, `kpi_slow_moving`.

## Requirements

1. Complete datasetKeys + projections for all KPI ids; reuse consumption/stock-risk/throughput; add today sales/profit and receivables/payables mappings.
2. Units: sales/profit/stock/expiry/credit/payable values → currency; low/OOS/slow lists qty → quantity; prescriptions/transactions → count; top-N sort by amount/profit.
3. “Today” reports force today range even if another preset was last used—or reset preset to today when opened (document chosen UX and keep consistent).
4. Seed so today’s sales/profit and each risk/credit KPI are non-zero in demo after seed.
5. Reuse shared dialog/summary/breakdown rendering; no separate KPI dashboard framework inside Reporting.
6. Access, responsive (summary + table stack on xs), light/dark.
7. Tests: today coercion; top-10 limit; unit formatting; Analytics unchanged.

## Constraints

- Do not replace Analytics insight chips; KPIs live under Reporting catalog buttons.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/demo-data.mdc`, `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | All 14 KPI reports map to ready/empty/error with seed. | R1 |
| A2 | Currency/qty/count units correct; top lists capped. | R2 |
| A3 | Demo “today” sales/profit and risk KPIs non-empty. | R4 |
| A4 | Shared kit + responsive access; Analytics untouched. | R5–R7 |

## Relevant Files

- `.cursor/reporting-analytics.md/pharmacy-reporting.md` §15
- `pharmacy_reporting_catalog.dart`, data provider (existing top/risk filters)
- Seed clinical/volume packs
- `frontend/lib/shared/reporting/module_reporting_data.dart`
- Provider tests

## Verification

- Tests for today range and top_profitable_medicines.
- Manual: KPIs → today sales, low stock, top selling; xs + dark.
