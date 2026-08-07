# Pharmacy Reporting: Sales & Revenue Dialogs and Demo Seed

Wire every Sales & Revenue subcategory dialog to period-filtered sales data with correct money/quantity/count units and demo seed coverage—reusing the shared reporting kit.

## Context

**Current behavior**

- Category `sales_revenue` lists 16 reports in `pharmacyReportingCatalog()`. Only `total_sales`, `sales_by_period`, `sales_by_medicine`, and `number_of_transactions` map to `pharmacy_drug_consumption` or `pharmacy_dispense_throughput`. Others open as unavailable.
- `PharmacyReportingDataProvider` projects consumption/throughput previews; currency/quantity formatting already lives in `module_reporting_table.dart`.
- Demo dispense/billing volume exists in clinical/volume seed packs but lacks payment-method, cashier, branch, discount, refund, tax, and margin slices for reporting.

**Intended behavior**

- Every Sales & Revenue button opens an in-place dialog with presets/custom range, loading/empty/error/ready, and Excel (table) or PDF (chart) export when entitled.
- Rows map from real pharmacy dispense/billing entities (or honest empty when filtered empty)—not fake client-only numbers. Demo seed makes primary slices non-empty for default presets.

**Definitions**

- *Sales amount:* Monetary totals in tenant/facility currency (`amount`, `revenue`, `gross_*`, `net_*`, tax, discount, refund columns).
- *Sales quantity:* Pack/dispense counts (`quantity_dispensed`, transaction counts)—not currency.
- *Report ids:* `total_sales`, `sales_by_period`, `sales_by_medicine`, `sales_by_category`, `sales_by_cashier`, `sales_by_branch`, `sales_by_customer`, `sales_by_payment_method`, `discounts`, `refunds_returns`, `gross_revenue`, `net_revenue`, `profit_and_margin`, `tax_vat`, `average_transaction_value`, `number_of_transactions`.

## Requirements

1. Assign `datasetKey` (extend existing pharmacy datasets or add focused runners registered in `REPORT_DATASET_MAP`) for every Sales report id; project in `PharmacyReportingDataProvider` so dialogs leave unavailable when data can exist.
2. Map columns with unit-safe keys: money → `amount`/`revenue`/`profit`/`discount`/`tax`/`refund`; counts → `*_count` / `orders_created`; qty → `quantity_dispensed`. Pass tenant currency into table/chart formatters.
3. `sales_by_period` remains chart; others default table unless catalog already marks chart. Soft-refresh on period change; inverted custom range validation stays in the shared dialog.
4. Seed demo graphs covering: multi-day sales, category/cashier/branch/customer slices, cash/card/mobile/credit, discounts, refunds/returns, gross/net, profit margin, VAT/tax, ATV, transaction counts. Prefer extending `seed-clinical-catalog-pack` / volume pharmacy packs; keep deterministic and demo-gated.
5. Reuse `ModuleReportingReportDialog`, visualization/table/print/export, `ReportsRepository.previewDataset`, and existing l10n patterns—no parallel dialog stack.
6. Gate with existing pharmacy ∩ `reports:read`; hide export without entitlement. Responsive xs–xxl; theme tokens; light/dark; no clipped actions.
7. Tests: each sales report id loads ready or empty (not unavailable) with seeded data; unit labels on money/qty columns; unauthorized export absent; Analytics unchanged.

## Constraints

- Do not redesign Reporting catalog chrome (`prompts/pharmacy-reporting.md`).
- Do not invent POS microservices; derive from pharmacy orders, dispense logs, billing/payments already in schema.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/demo-data.mdc`, `.cursor/access/permissions.mdc`, `prompts/.cursor/prompt.mdc`, `frontend/.cursor/layouts.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | All 16 sales report dialogs leave unavailable when seed/API can supply rows. | R1 |
| A2 | Money/qty/count columns format with correct units and currency code. | R2 |
| A3 | Period presets + custom range refresh content; chart vs table export matches content kind. | R3, R5 |
| A4 | Demo seed yields non-empty primary sales slices for default presets. | R4 |
| A5 | Shared kit reused; access + responsive + themes satisfied; Analytics untouched. | R5–R7 |

## Relevant Files

- `.cursor/reporting-analytics.md/pharmacy-reporting.md` §1
- `frontend/lib/features/reports/presentation/pharmacy_reporting_catalog.dart`
- `frontend/lib/features/reports/presentation/widgets/pharmacy_reporting_data_provider.dart`
- `frontend/lib/shared/reporting/module_reporting_*.dart`
- `backend/src/lib/reports/datasets.js`, `constants` report dataset registry
- `backend/scripts/seeders/seed-clinical-catalog-pack.js`, volume pharmacy/billing seeders
- `frontend/test/features/reports/presentation/pharmacy_reporting_data_provider_test.dart`

## Verification

- Provider/dataset tests for each sales report id projection and units.
- Seed/verify: demo tenant has multi-method sales, discounts, refunds in range.
- Manual: Reporting → Sales & Revenue → each button → ready table/chart with UGX/USD (tenant) and unit headers → export; narrow + dark.
