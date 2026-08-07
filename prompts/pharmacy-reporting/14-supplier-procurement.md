# Pharmacy Reporting: Supplier & Procurement Analytics Dialogs and Demo Seed

Implement Supplier & Procurement Analytics report dialogs (Reporting catalog §14) with spend/price/reliability metrics and demo supplier performance data—distinct from Analytics tab chips.

## Context

**Current behavior**

- Category `supplier_procurement` has 9 reports; all unavailable. Overlaps conceptually with Purchasing (§4) but focuses on spend analytics, price trends, reliability, fulfillment, lateness, frequency, volume, payment status.
- Suppliers/POs exist; Analytics tab is separate and must remain unchanged.

**Intended behavior**

- Each procurement-analytics subcategory dialog shows supplier KPIs for the period with currency for spend/prices, percent for rates, days for lateness, and counts/qty for frequency/volume.

**Definitions**

- *Procurement analytics report:* Aggregate supplier performance metrics under Reporting (not Analytics chips).
- *Report ids:* `supplier_spend`, `price_comparison`, `price_trends`, `supplier_reliability`, `order_fulfillment_rate`, `late_deliveries`, `purchase_frequency`, `purchase_volume`, `supplier_payment_status`.

## Requirements

1. Map all nine report ids to datasets (may share runners with purchasing prompts but distinct projections); `price_trends` chart.
2. Units: spend/price → currency; fulfillment/reliability → percent; late delivery → days or count per column key; frequency → count; volume → quantity.
3. Soft-refresh; empty when no supplier activity; reuse shared export rules.
4. Seed multi-supplier spend variance, price changes over time, late vs on-time deliveries, fulfillment <100% for at least one supplier, payment status mix.
5. Reuse purchasing datasets/seed where possible; do not modify Analytics chips or invent a second suppliers UI.
6. Access, responsive, light/dark.
7. Tests: price_trends series; fulfillment percent formatting; Analytics unchanged.

## Constraints

- Keep Reporting vs Analytics separation; follow `prompts/pharmacy-reporting.md` shell rules.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/demo-data.mdc`, `prompts/.cursor/prompt.mdc`, coordinate with `04-purchasing-suppliers.md`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | All 9 procurement-analytics reports leave unavailable with seed. | R1 |
| A2 | Currency/percent/days/qty units correct; trends chart OK. | R2 |
| A3 | Demo shows spend variance, late delivery, partial fulfillment. | R4 |
| A4 | Analytics untouched; shared kit + access OK. | R5–R7 |

## Relevant Files

- `.cursor/reporting-analytics.md/pharmacy-reporting.md` §14
- `04-purchasing-suppliers.md` (shared seed/datasets)
- `pharmacy_reporting_catalog.dart`, data provider
- Supplier/PO modules + seeders
- `frontend/lib/shared/reporting/**`

## Verification

- Tests distinguishing purchasing list vs analytics projections.
- Manual: Procurement analytics → price trends, late deliveries; tablet + dark.
