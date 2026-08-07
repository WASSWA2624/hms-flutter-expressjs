# Billing Reporting: Collections & Balances — Accurate Dialog Mapping

Wire all `collections` dialogs so money/counts match `buildBillingFinancialAnalytics`—no invented cashier or ledger fields.

## Context

**Catalog (`domain_reporting_catalogs.dart` → `_financeCatalog` / `collections`)**

| Report id | datasetKey today | Projection |
| --- | --- | --- |
| `collections_open_balances` | `billing_collections_open_balances` | pass-through rows + summary |
| `net_collections_trend` (chart) | `billing_collections_open_balances` | series `net_collections` / `collections` |
| `refunds_write_offs` | `billing_collections_open_balances` | rows/`summary` `refunds`, `write_offs`, `expenditures` |
| `cashier_productivity` | `null` | unavailable |

**Billing truth (`buildBillingFinancialAnalytics` → `billing_collections_open_balances`)**

- Sources: `payment` (`status ∈ {COMPLETED,REFUNDED}`, `paid_at` in range), `refund` (`refunded_at` in range via payment tenant/facility), applied negative `billing_adjustment` (`status ∈ {ISSUED,PAID,PARTIAL}`, `amount < 0`), `invoice` (`issued_at` in range).
- Columns: `date`, `collections`, `expenditures`, `profit_proxy`, `refunds`, `write_offs`, `net_collections`, `issued_invoices`, `open_invoices`.
- Formulas: `expenditures = refunds + write_offs`; `net_collections = collections − refunds`; `profit_proxy = collections − expenditures`. `write_offs = abs(negative adjustment amount)`.
- `open_invoices` counts invoices issued in range with status `DRAFT|SENT|OVERDUE` (not open balance snapshot of all unpaid).
- Breakdown: `collections_by_method` from `payment.method`.

**Schema gaps**

- No `cashier_user_id` / actor on `payment`. Do not invent cashier productivity from client guesses.
- Currency: prefer invoice/payment currency; display via `effectiveDefaultCurrencyProvider` (seeded **UGX**).

## Data contract

| Report id | Authoritative source | Required columns (keys) | Notes |
| --- | --- | --- | --- |
| `collections_open_balances` | billing series + summary | full billing columns | Dialog totals = summary for same from/to/scope |
| `net_collections_trend` | billing rows | `date`, `net_collections` (+ optional `collections`) | Chart; monthly when runner uses month granularity |
| `refunds_write_offs` | billing rows + breakdown | `date`, `refunds`, `write_offs`, `expenditures` | Do not conflate pack returns with money refunds |
| `cashier_productivity` | **gap** | — | Needs actor on payment/audit or migration; else stay unavailable |

## Requirements

1. Implement every contract row: extend billing builder/projections or keep explicit gaps—never fabricate cashier totals.
2. Keep billing formulas byte-compatible; add group-bys/filters rather than forked money math.
3. Wire `datasetKey`s; `DomainReportingDataProvider` must not mark unavailable when the dataset has rows.
4. Seed: ≥1,000 `payment` (counted statuses), ≥1,000 `invoice`, and ≥1,000 `refund` / negative applied `billing_adjustment` when those reports are dense. Diversify days, methods (≥3), amounts. Assert floors in verify/seed tests.
5. Reuse shared dialog/table/chart/export; gate `reports:read` ∩ billing/finance pack.
6. Tests: dialog summary `collections`/`net_collections` equals dataset summary for same from/to; unauthorized export absent; pharmacy billing formulas unchanged.

## Constraints

- No fake cashier columns. Follow parent `prompts/reporting-analytics.md` and pharmacy financial ledger labeling (do not mix dispense margin with `profit_proxy` without subtitle).
- Rules: `.cursor/mandatories.mdc`, `.cursor/access/demo-data.mdc`, `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Mapped reports use contract sources/formulas; cashier gap migrated or unavailable. | R1–R2 |
| A2 | Money columns format via effective default/UGX. | contract |
| A3 | ≥1,000 payments/invoices (and refunds/adjustments when mapped); trend dense for default presets. | R4 |
| A4 | Dialog totals match `buildBillingFinancialAnalytics` summary for same range/scope. | R6 |

## Relevant Files

- `backend/src/lib/reports/datasets.js` (`buildBillingFinancialAnalytics`), `constants.js`
- `domain_reporting_catalogs.dart`, `domain_reporting_data_provider.dart`
- Seed/verify: volume packs, `verify-demo-data.js`

## Verification

- Reconcile one day: collections vs summed counted payments; refunds vs `refund` rows.
- Manual: billing@ → Reporting → Collections → open balances, trend, refunds.
