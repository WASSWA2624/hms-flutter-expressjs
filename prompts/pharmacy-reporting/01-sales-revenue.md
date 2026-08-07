# Pharmacy Reporting: Sales & Revenue — Accurate Dialog Mapping

Wire all `sales_revenue` dialogs so money/qty/counts match dispense and billing sources already in schema—no invented POS fields.

## Context

**Current mapping (`pharmacy_reporting_catalog.dart` + provider)**

| Report id | datasetKey today | Projection |
| --- | --- | --- |
| `total_sales`, `sales_by_medicine` | `pharmacy_drug_consumption` | pass-through rows |
| `sales_by_period` (chart) | `pharmacy_drug_consumption` | `breakdown.daily_totals` |
| `number_of_transactions` | `pharmacy_dispense_throughput` | pass-through (`orders_created` series) |
| All others | `null` | unavailable |

**Consumption truth (`buildPharmacyDrugConsumptionAnalytics`)**

- Source: `dispense_log` where `status=DISPENSED`, `dispensed_at` in range, tenant/facility via patient scope.
- Columns: `drug`, `quantity_dispensed`, `amount`, `profit`, `order_source` (`PHARMACY` if `encounter_id` null else `CLINICAL`; multi → `MIXED`).
- `amount = round(resolveDispenseUnitPrice × qty, 2)`; profit via `pharmacyRetailMarginUnit` (null if no `buy_unit_price`).
- Summary: `quantity_dispensed`, `amount`, `drug_count`, `profit`; breakdown `daily_totals`, `source_mix`.

**Schema gaps (do not pretend they exist on pharmacy_order)**

- No `payment_method`, cashier/`user_id`, tax/VAT, discount, facility_id on `pharmacy_order` / `dispense_log`.
- Payment method = `payment.method` (`PaymentMethodType`). Refunds = `refund`. Discounts ≈ negative applied `billing_adjustment` or invoice deltas—not pharmacy_order fields.
- Category for “sales by category” = `inventory_item.category` via `drug_inventory_map`, **not** `drug.category` (missing).

## Data contract

| Report id | Authoritative source | Required columns (keys) | Notes |
| --- | --- | --- | --- |
| `total_sales` | consumption rows + summary | `drug`, `quantity_dispensed`, `amount`, `profit` | Summary `amount` is gross dispense revenue for period |
| `sales_by_period` | `breakdown.daily_totals` | period key + `amount`, `quantity_dispensed` | Chart; monthly granularity when range uses year-style presets |
| `sales_by_medicine` | consumption rows | same as default columns | Sort by qty then amount (runner already does) |
| `sales_by_category` | consumption joined through `drug_inventory_map` → `inventory_item.category` | `category`, `quantity_dispensed`, `amount` | Enum: `MEDICATION\|SUPPLY\|EQUIPMENT\|OTHER` |
| `sales_by_cashier` | **gap** | — | Needs actor on dispense/attestation (`pharmacy_dispense_attestation.attested_by_user_id`) or migration; do not invent |
| `sales_by_branch` | consume + `facility` via patient/`inventory_stock.facility_id` scope | `facility`, `amount`, `quantity_dispensed` | Demo = 1 facility unless seed adds more |
| `sales_by_customer` | dispense → `pharmacy_order.patient_id` | `patient` (HFI/name), `amount`, `quantity_dispensed` | |
| `sales_by_payment_method` | `payment` where pharmacy-scoped (`billing_entity=PHARMACY` and/or drug invoice lines) | `method`, `amount` | Use enum values; seed already has CASH/MOBILE_MONEY/… |
| `discounts` | `billing_adjustment` amount&lt;0 applied in range, pharmacy-scoped invoices | `date`, `amount`, `reason` | `amount` currency |
| `refunds_returns` | `refund` amounts + throughput `returns` count as separate metric | `amount` (refund $) and/or `returns` (count) | Do not conflate pack returns with money refunds |
| `gross_revenue` | consumption summary `amount` | summary + rows | Alias of dispense gross; label clearly |
| `net_revenue` | gross − refunds (− discounts if included) | document formula in subtitle | Must match billing math if using payments |
| `profit_and_margin` | consumption `profit` + `amount` | `profit`, `amount`, `profit_margin` | `profit_margin = profit/amount` when amount&gt;0; skip null-profit drugs or show null |
| `tax_vat` | **gap** | — | No tax field on invoice_item/drug; migrate or unavailable |
| `average_transaction_value` | `sum(amount)/orders_created` same range | `average_transaction_value`, `orders_created`, `amount` | Align order count with throughput definition |
| `number_of_transactions` | throughput `orders_created` | existing throughput columns | Count of orders, not payments |

Currency: `effectiveDefaultCurrencyProvider`; seeded drugs/invoices use **UGX**.

## Requirements

1. Implement every row in the Data contract: extend runners/projections or record an explicit schema+migration plan for gaps (`sales_by_cashier`, `tax_vat`) before claiming ready.
2. Keep consumption/throughput formulas byte-compatible with existing analytics builders; add parameters/group-bys rather than forked pricing.
3. Wire `datasetKey`s; provider must not return unavailable when contract source has rows.
4. Seed: ensure period presets see multi-day `dispense_log` DISPENSED, `buy_unit_price` set (catalog already), pharmacy-scoped payments with ≥3 methods, ≥1 refund, ≥1 negative adjustment; extend volume seed if missing.
5. Reuse shared dialog/table/chart/export; gate `reports:read` ∩ pharmacy.
6. Tests: dialog summary `amount` equals dataset summary for same from/to; margin null when buy missing; payment-method totals equal sum of filtered payments; unauthorized export absent.

## Constraints

- No fake cashier/tax columns. Follow data accuracy rules in `index.md`. Chrome: `prompts/pharmacy-reporting.md`.
- Rules: `.cursor/mandatories.mdc`, `.cursor/access/demo-data.mdc`, `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Mapped reports use contract sources/formulas; gaps are migrated or stay unavailable with note. | R1–R2 |
| A2 | Units: `amount`/`profit` currency; `quantity_dispensed` units; `orders_created` count. | contract |
| A3 | Seeded demo: non-empty total_sales, sales_by_period, payment_method, refunds for default range. | R4 |
| A4 | Provider tests lock formula parity with `buildPharmacyDrugConsumptionAnalytics`. | R6 |

## Relevant Files

- `backend/src/lib/reports/datasets.js` (`buildPharmacyDrugConsumptionAnalytics`, throughput, billing)
- `backend/src/lib/billing/pharmacy-drug-margins.js`
- `pharmacy_reporting_catalog.dart`, `pharmacy_reporting_data_provider.dart`
- `seed-clinical-catalog-pack.js`, `seed-volume-pack.js`, `seed-volume-extended-pack.js`
- Prisma: `dispense_log`, `drug`, `payment`, `refund`, `billing_adjustment`, `inventory_item`

## Verification

- Unit: amount/profit samples match manual `unit_price×qty` / margin helper.
- Manual: Sales → Total sales summary vs Sales by medicine sum; Payment method vs billing; narrow + dark.
