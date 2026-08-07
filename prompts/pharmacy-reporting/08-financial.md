# Pharmacy Reporting: Financial Reports — Accurate Billing + Dispense Mapping

Wire `financial` reports to `billing_collections_open_balances` and pharmacy consumption profit—**declare which ledger each metric uses**.

## Context

**Billing runner** (`buildBillingFinancialAnalytics` → dataset `billing_collections_open_balances`):

- Columns: `date`, `collections`, `expenditures`, `profit_proxy`, `refunds`, `write_offs`, `net_collections`, `issued_invoices`, `open_invoices`.
- Sources: `payment` (counted statuses), `refund`, negative applied `billing_adjustment`, `invoice`.
- Breakdown includes `collections_by_method`.

**Pharmacy profit (dispense):** consumption `profit` / `amount` (retail − buy)—**not** the same as billing `profit_proxy`.

**All 14 financial catalog ids currently unmapped.** Seed: volume payments/refunds/adjustments; extended pack pharmacy `billing_entity`.

## Data contract

| Report id | Ledger | Formula / columns |
| --- | --- | --- |
| `revenue` (chart) | Prefer pharmacy-scoped collections **or** consumption `amount`—pick one; subtitle names it | series `amount`/`collections` |
| `cogs` | sum `buy_unit_price × quantity_dispensed` for DISPENSED in range | `cogs` currency |
| `gross_profit` | consumption sum `profit` (nulls as 0 only if documented) | `profit` |
| `net_profit` | gross_profit − refunds − write_offs (− expenses if included) | document each term |
| `operating_expenses` | only if expenditure source exists in billing runner; else unavailable | `expenditures` |
| `financial_discounts` | negative adjustments | `amount` |
| `taxes` | **schema gap**—migrate or unavailable |
| `supplier_payables` | AP if modeled; else unavailable (no fake) |
| `customer_receivables` | open invoice totals pharmacy-scoped | `amount` |
| `cash_flow` (chart) | billing `net_collections` / collections−refunds series | existing billing columns |
| `daily_cash_position` | end-of-day collections−refunds | `date`, `net_collections` |
| `profit_by_product_category` | consumption profit join inventory category | `category`, `profit`, `amount` |
| `profit_by_branch` | by `facility` | single facility demo OK |
| `profit_by_period` (chart) | daily/monthly profit from consumption | `profit`, `amount` |

## Requirements

1. Never mix billing `profit_proxy` and retail margin without labeling.
2. Pharmacy scope payments/invoices with `billing_entity=PHARMACY` when claiming pharmacy financials.
3. Wire datasetKeys; seed volume ≥1,000 pharmacy-scoped `payment`, ≥1,000 `invoice`, and ≥1,000 `refund`/`billing_adjustment` as mapped—enough on “today” and trailing periods for dense charts (`index.md` rule 9).
4. Reuse billing + consumption builders.
5. Tests: COGS = Σ buy×qty for fixture logs; revenue subtitle matches ledger; tax gap handled.

## Constraints

- Read-only Reporting; `index.md` rules; permissions for billing datasets.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Each metric’s ledger/formula documented in UI subtitle + code. | contract |
| A2 | Currency columns format via effective default/UGX. | R2 |
| A3 | ≥1,000 payments/invoices (and refunds when mapped); revenue/COGS/gross_profit/cash_flow dense. | R3 |

## Relevant Files

- `datasets.js` billing + consumption; Prisma payment/refund/invoice/adjustment/dispense_log; volume seed; catalog/provider

## Verification

- Reconcile one day: collections vs payments SQL; COGS vs dispense×buy.
- Manual: Financial → revenue, COGS, cash flow.
