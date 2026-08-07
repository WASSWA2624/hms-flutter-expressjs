# Pharmacy Reporting: Financial Reports Dialogs and Demo Seed

Wire Financial Reports dialogs to revenue, COGS, profit, tax, payables/receivables, and cash metrics with currency/% units and demo financial coverage—reusing billing/report datasets where present.

## Context

**Current behavior**

- Category `financial` has 14 reports; all unavailable in the pharmacy catalog mapping.
- Backend already has billing financial analytics helpers (`buildBillingFinancialAnalytics`) and invoice/payment/refund seed volume.

**Intended behavior**

- Each financial subcategory dialog shows period financials for pharmacy-relevant revenue and costs: money columns in tenant currency, margins as percent, cash-flow as chart series.

**Definitions**

- *Financial amount:* Revenue, COGS, profit, expense, discount, tax, payable, receivable, cash columns—currency unit.
- *Report ids:* `revenue`, `cogs`, `gross_profit`, `net_profit`, `operating_expenses`, `financial_discounts`, `taxes`, `supplier_payables`, `customer_receivables`, `cash_flow`, `daily_cash_position`, `profit_by_product_category`, `profit_by_branch`, `profit_by_period`.

## Requirements

1. Map all financial report ids to dataset runners (reuse billing financial analytics + pharmacy consumption profit where appropriate) and provider projections; charts for `revenue`, `cash_flow`, `profit_by_period`.
2. Units: all money keys currency; margin keys percent; daily position counts of txns as count if present.
3. Soft-refresh on period; empty/error states; Excel/PDF by content kind.
4. Seed demo invoices/payments/expenses/payables/receivables spanning the default presets so revenue, COGS, gross/net, tax, discounts, and cash flow are non-empty.
5. Reuse shared reporting + billing datasets; do not create a separate finance app shell.
6. Permissions reports read ∩ pharmacy (and billing read if required by API)—unauthorized absent.
7. Tests: projections + currency formatting; seed non-empty revenue/COGS; responsive dialog.

## Constraints

- Pharmacy Reporting stays read-only; no GL posting UI.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/demo-data.mdc`, `.cursor/access/permissions.mdc`, `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | All 14 financial reports map to ready/empty/error with seed. | R1 |
| A2 | Currency and percent units correct; chart exports PDF. | R2 |
| A3 | Demo yields revenue, COGS, profit, tax, cash-flow samples. | R4 |
| A4 | Reuses billing/pharmacy datasets + shared kit; access OK. | R5–R7 |

## Relevant Files

- `.cursor/reporting-analytics.md/pharmacy-reporting.md` §8
- `backend/src/lib/reports/datasets.js` (billing financial)
- `pharmacy_reporting_catalog.dart`, `pharmacy_reporting_data_provider.dart`
- Billing/payment seeders in volume packs
- `frontend/lib/shared/reporting/**`

## Verification

- Dataset tests for profit-by-period and cash-flow series.
- Manual: Financial → revenue chart, COGS, payables/receivables; xxl + dark.
