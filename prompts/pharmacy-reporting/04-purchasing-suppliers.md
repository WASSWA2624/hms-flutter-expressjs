# Pharmacy Reporting: Purchasing & Suppliers — Accurate Mapping

Map purchasing reports to `supplier`, `purchase_order`, `goods_receipt`, `stock_movement`, and payments—**honest about header-only PO schema**.

## Context

**Exists:** `supplier` (`name`, `contact_email`, `phone` + `address`); `purchase_order` (`supplier_id`, `status`, `ordered_at`, optional `purchase_request_id`); `goods_receipt` (`purchase_order_id`, `status`, `received_at`); drugs may have `supplier_id`; INBOUND `stock_movement` reason `PURCHASE`.

**Does not exist:** PO/goods-receipt **line items**, PO amounts, delivery SLA fields, supplier scorecards.

**Seed:** 3 suppliers in clinical catalog; 1 PO + goods receipt in `seed-operations-pack.js`; drug `supplier_id` round-robin.

**All 12 purchasing report ids unavailable today.**

## Data contract

| Report id | Accurate approach |
| --- | --- |
| `purchase_orders` | List PO headers: `ordered_at`, `status`, `supplier` name, HFI/id |
| `purchases_by_supplier` | Count/group POs by `supplier_id`; **value** only if derived from linked INBOUND movements × `drug.buy_unit_price` or after adding PO lines |
| `purchase_value` | Same value basis as above; column `amount` currency; subtitle states basis (“stock inbound × buy_unit_price” or “PO lines”) |
| `outstanding_supplier_invoices` | Only if AP/invoice-to-supplier exists; else migrate link or unavailable—**do not invent balances** |
| `payment_history` | `payment` rows tied to supplier invoices **if** relation exists; else unavailable |
| `supplier_pricing` | Current `drug.buy_unit_price` grouped by `drug.supplier_id` | `supplier`, `drug`, `buy_unit_price`, `currency` |
| `supplier_performance` (chart) | Proxy: on-time = `goods_receipt.received_at` vs `purchase_order.ordered_at` delta days; fulfillment only after line qtys exist |
| `delivery_time` | `received_at − ordered_at` → `delivery_days` |
| `quantity_ordered_vs_received` | **Requires line qtys**—add `purchase_order_item`/`goods_receipt_item` migration+seed, or unavailable |
| `purchase_returns` | `stock_movement` OUTBOUND/ADJUSTMENT with return semantics if modeled; else unavailable |
| `price_changes` | Audit `diff_json` on drug buy/unit price **or** history table; seed ≥1 audited change |
| `most_used_suppliers` | Count POs or count drugs with `supplier_id` + inbound qty |

## Requirements

1. Prefer deriving demo-visible value from INBOUND×`buy_unit_price` until PO lines exist; when adding lines, migrate + seed and switch contract.
2. Register dataset; wire all ids; performance chart uses `delivery_days` / fulfillment_rate keys for units.
3. Seed volume: ≥1,000 `purchase_order` (and ≥1,000 goods receipts / PO lines once modeled); ≥1,000 INBOUND `stock_movement` for value basis. Keep ≥2 suppliers in the mix. Optional PO line migration if implementing ordered-vs-received (`index.md` rule 9). Supplier master catalog may stay small.
4. Reuse supplier module; Reporting read-only.
5. Tests: delivery_days non-negative; purchase_value matches sum of basis rows; no phantom invoice balances.

## Constraints

- Header-only PO must not show fake line totals. Follow `index.md`, `prompts/pharmacy-suppliers.md` boundaries, demo-safety.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Each report uses contract basis or explicit unavailable/migration. | R1 |
| A2 | Money/days/qty units correct; no fabricated AP. | contract |
| A3 | ≥1,000 POs/inbounds; multiple suppliers; receipt + inbound value path demonstrable. | R3 |

## Relevant Files

- Prisma supplier/PO/goods_receipt/stock_movement/drug; `seed-operations-pack.js`; `seed-clinical-catalog-pack.js`; datasets.js; catalog/provider

## Verification

- Trace one PO → receipt → inbound qty × buy price → dialog purchase_value.
- Manual: Purchasing → by supplier, delivery time, supplier pricing.
