# Billing Reporting: Revenue & Adjustments — Accurate Dialog Mapping

Wire `revenue` dialogs to invoice/payment/price-book sources already in schema—declare formulas; never invent payer or price-change columns.

## Context

**Catalog (`revenue` category)**

| Report id | datasetKey today | Projection |
| --- | --- | --- |
| `issued_vs_open_invoices` | `billing_collections_open_balances` | `issued_invoices`, `open_invoices` (+ summary) |
| `price_list_changes` | `null` | unavailable |
| `payer_mix` | `null` | unavailable |

**Invoice workload (billing runner)**

- `issued_invoices`: count of invoices with `issued_at` in range.
- `open_invoices`: subset with status `DRAFT|SENT|OVERDUE` **among those issued in range** (not all-time AR).
- Do not relabel as “open AR balance” without a total_amount open-balance builder.

**Schema for gaps**

- Price list: `price_book_entry` (`unit_price`, `effective_from`/`effective_to`, `updated_at`, `catalog_type`, `payment_mode`, `is_active`)—no dedicated change-log table; use created/updated windows or migrate audit.
- Payer mix candidates: `payment.method` (already in billing `collections_by_method`), and/or invoice/item `payment_mode` / `insurance_company_id` / `coverage_plan_id`. Pick one ledger and name it in the subtitle—do not mix cash method with insurer without labeling.

## Data contract

| Report id | Authoritative source | Required columns (keys) | Notes |
| --- | --- | --- | --- |
| `issued_vs_open_invoices` | billing series + summary | `date`, `issued_invoices`, `open_invoices` | Counts; match runner definitions |
| `price_list_changes` | `price_book_entry` in range (created/updated or effective window) **or gap** | `effective_from`/`updated_at`, `unit_price`, catalog label keys | Prefer real rows; no fake diffs |
| `payer_mix` | choose: `breakdown.collections_by_method` **or** invoice/item insurer/payment_mode aggregate | `method`/`payer`, `amount` or `count` | Subtitle names ledger; currency if amount |

## Requirements

1. Implement contract rows via extending billing builder or new registered dataset keys—no parallel invoice math.
2. If open AR by outstanding balance is required later, add a separate report id + runner; do not overload `open_invoices` count semantics.
3. Wire `datasetKey`s; keep unavailable when schema/audit cannot support price-change history honestly.
4. Seed: ≥1,000 `invoice` (and ≥1,000 `payment` if payer_mix uses collections); diversify statuses and methods/payers. For price-list report, ensure enough `price_book_entry` churn in demo or keep unavailable. Assert floors where wired.
5. Reuse shared kit; finance pack permissions; loading/empty/error/success on dialogs.
6. Tests: issued/open summary parity with billing dataset; payer_mix totals equal chosen source sum; unauthorized export absent.

## Constraints

- Never present `profit_proxy` as clinical margin. Currency via effective default/UGX.
- Rules: `.cursor/mandatories.mdc`, `.cursor/access/demo-data.mdc`, `prompts/.cursor/prompt.mdc`, parent epic.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Each report uses documented source/formula; gaps unavailable. | R1–R3 |
| A2 | Count vs currency columns match unit inference keys. | contract |
| A3 | ≥1,000 invoices (and payments when payer_mix wired); issued/open dense. | R4 |
| A4 | Dialog totals match dataset summary for same from/to/scope. | R6 |

## Relevant Files

- `datasets.js` billing analytics; Prisma `invoice`, `payment`, `price_book_entry`
- `domain_reporting_catalogs.dart`, `domain_reporting_data_provider.dart`

## Verification

- Compare issued/open counts to SQL for one preset.
- Manual: billing@ → Revenue → issued vs open; confirm unavailable or wired price/payer honestly.
