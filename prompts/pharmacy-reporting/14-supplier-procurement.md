# Pharmacy Reporting: Supplier & Procurement Analytics — Accurate KPIs

Implement Reporting §14 analytics from supplier/PO/receipt/inbound/price facts—distinct from Analytics chips; share basis with `04-purchasing-suppliers.md`.

## Context

**Same schema limits as purchasing:** PO headers without lines; value often via INBOUND×`buy_unit_price`; `drug.supplier_id`; 3 seeded suppliers.

**All 9 `supplier_procurement` ids unavailable.** Analytics tab must stay unchanged.

## Data contract

| Report id | Definition |
| --- | --- |
| `supplier_spend` | sum purchase_value basis by supplier in range | `supplier`, `amount` |
| `price_comparison` | current `buy_unit_price` for same drug across suppliers if multiple; else compare drugs per supplier | `drug`, `supplier`, `buy_unit_price` |
| `price_trends` (chart) | historical buy price from audit diffs or price-history table—**seed ≥2 points**; else unavailable |
| `supplier_reliability` | % POs with receipt within N days (define N=7 in code+subtitle) | `reliability_rate` percent |
| `order_fulfillment_rate` | received_qty/ordered_qty after line items exist; else proxy receipt-exists/PO-count | document proxy |
| `late_deliveries` | receipt delay &gt; N days | `delivery_days`, count |
| `purchase_frequency` | PO count by supplier | count |
| `purchase_volume` | inbound qty by supplier | `quantity` |
| `supplier_payment_status` | only with real AP/payment links; else unavailable |

## Requirements

1. Reuse purchasing dataset runners with analytics projections; do not fork conflicting spend formulas.
2. N-day threshold constant shared by reliability/late reports.
3. Seed multi-supplier spend variance + at least one late receipt.
4. Keep Analytics chips untouched.
5. Tests: spend matches purchasing purchase_value total; reliability_rate in 0–100%.

## Constraints

- `04-purchasing-suppliers.md` basis; `index.md`; shell chrome unchanged.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | KPI definitions match contract; proxies labeled. | contract |
| A2 | Currency/percent/days/qty units correct. | R2 |
| A3 | Demo spend + late delivery visible; Analytics unchanged. | R3 |

## Relevant Files

- Purchasing datasets/seed; `pharmacy_reporting_catalog.dart` procurement block; provider

## Verification

- Supplier spend sum = purchasing purchase_value for same range.
- Manual: Procurement analytics → spend, price trends, late deliveries.
