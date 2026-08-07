# Pharmacy Reporting: Purchasing & Suppliers Dialogs and Demo Seed

Implement Purchasing & Suppliers report dialogs from purchase orders, receipts, and supplier records with money/qty/time units and demo procurement coverage—reusing suppliers/PO APIs.

## Context

**Current behavior**

- Category `purchasing_suppliers` has 12 reports; all unavailable. Backend already has suppliers, purchase orders, and related inventory receipts; frontend suppliers work is covered by `prompts/pharmacy-suppliers.md`.
- No pharmacy Reporting projector yet for PO value, outstanding invoices, delivery time, or ordered-vs-received.

**Intended behavior**

- Each purchasing subcategory dialog loads supplier/PO-derived rows for the selected period with currency for values, quantity for ordered/received, days for delivery time, and rates/percent for performance where applicable.

**Definitions**

- *Purchase value:* Monetary PO/receipt totals in tenant currency.
- *Report ids:* `purchase_orders`, `purchases_by_supplier`, `purchase_value`, `outstanding_supplier_invoices`, `payment_history`, `supplier_pricing`, `supplier_performance`, `delivery_time`, `quantity_ordered_vs_received`, `purchase_returns`, `price_changes`, `most_used_suppliers`.

## Requirements

1. Register dataset runner(s) over existing supplier/PO/payment entities; wire every purchasing report id’s `datasetKey` + provider projection (performance remains chart).
2. Units: spend/invoice/payment/price → currency; ordered/received/returns qty → quantity; `delivery_time` → days; fulfillment/performance rates → percent; counts → count.
3. Soft-refresh on period; empty when no POs in range; error on API failure; reuse shared export rules.
4. Seed demo: multiple suppliers, POs in varied statuses, partial receipts (ordered ≠ received), outstanding payables, payment history, a return, price change events, delivery lead-time variance. Demo-gated deterministic upserts.
5. Reuse supplier module + reporting kit; do not build a second procurement workspace inside Reporting.
6. Permissions: reports read ∩ pharmacy (and existing procurement entitlements if dataset requires them)—unauthorized UI absent.
7. Tests: projections + unit keys; seed coverage for outstanding + partial receipt; responsive dialog; Analytics untouched.

## Constraints

- Do not replace PO goods-receipt flows; Reporting is read/report only.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/demo-data.mdc`, `prompts/.cursor/prompt.mdc`, `prompts/pharmacy-suppliers.md` boundaries.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | All 12 purchasing reports map to ready/empty/error with seed. | R1 |
| A2 | Currency/qty/days/percent columns format correctly. | R2 |
| A3 | Demo shows multi-supplier POs, partial receipt, outstanding invoice, payment history. | R4 |
| A4 | Shared kit + access + responsive OK; no parallel procurement UI. | R5–R7 |

## Relevant Files

- `.cursor/reporting-analytics.md/pharmacy-reporting.md` §4
- `backend/src/modules/supplier/**`, purchase-order modules
- `pharmacy_reporting_catalog.dart`, `pharmacy_reporting_data_provider.dart`
- `backend/src/lib/reports/datasets.js`, seed packs touching suppliers/POs
- `frontend/lib/shared/reporting/**`

## Verification

- Dataset tests for ordered-vs-received and outstanding payables.
- Seed/verify suppliers + PO diversity.
- Manual: Purchasing section → purchases by supplier, delivery time, performance chart; lg + dark.
