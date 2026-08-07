# Pharmacy Reporting: Inventory / Stock Dialogs and Demo Seed

Implement all Inventory / Stock report dialogs with quantity, value, risk, and movement mappings plus demo stock diversity—reusing shared reporting and existing `inventory_stock_risk`.

## Context

**Current behavior**

- Category `inventory_stock` has 20 reports. Several already filter `inventory_stock_risk` (`current_stock_quantity`, expired/near-expiry, over/under/out-of-stock). Stock value, movements, turnover, reorder, fast/slow/dead stock remain unavailable.
- Clinical catalog seed already builds wall-clock expiry batches and mixed quantities (`PHARMACY_REPORT_RISK_BATCH_TEMPLATES`, `resolveDemoStockQuantity`).

**Intended behavior**

- Every inventory subcategory dialog shows period-aware stock snapshots or movement history with correct units (stock qty in pack units, value in currency, turnover/days as days or ratios, risk states as plain labels).
- Demo seed keeps out-of-stock, low, overstock, expired, near-expiry, and healthy rows visible for demos.

**Definitions**

- *Stock quantity:* On-hand pack/UOM counts (`quantity`, reorder fields)—format as quantity units.
- *Stock value:* `quantity × cost/price` monetary columns.
- *Report ids:* `current_stock_quantity`, `stock_value`, `opening_closing_stock`, `stock_received`, `stock_issued`, `stock_adjustments`, `damaged_stock`, `lost_stock`, `expired_stock`, `near_expiry_stock`, `overstock`, `understock`, `out_of_stock`, `reorder_level`, `reorder_quantity`, `stock_turnover`, `fast_moving`, `slow_moving`, `dead_stock`, `stock_movement_history`.

## Requirements

1. Map every inventory report id to a dataset + provider projection (extend `inventory_stock_risk` and/or stock-movement runners). Opening/closing and movement history must use real `inventory_stock` / stock movement entities.
2. Column keys must trigger correct formatters: `quantity`/`reorder_*` → units; `value`/`amount` → currency; `days_to_expiry`/`stock_turnover` days or ratio per key convention; `risk_state` plain.
3. Keep `stock_turnover` as chart; others table unless catalog says otherwise. Soft-refresh on period; empty when filter yields zero rows.
4. Extend demo seed so each risk bucket and at least one movement/adjustment/damage/loss path exists; reorder level/qty populated on demo drugs. Deterministic; demo-gated.
5. Reuse shared dialog/table/chart/export and existing stock-risk filters in the provider—do not fork inventory UI.
6. Permissions, responsiveness (dense table → narrow list/cards if kit already does), light/dark, localized copy.
7. Tests: projections for risk filters + new movement/value reports; seed helper coverage; unauthorized export absent.

## Constraints

- Do not rebuild catalog chrome; do not seed production.
- Prefer existing inventory modules over new stock services.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/demo-data.mdc`, `prompts/.cursor/prompt.mdc`, `frontend/.cursor/layouts.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | All 20 inventory report dialogs map to ready/empty/error—not unavailable—with seed present. | R1 |
| A2 | Qty/value/days/risk columns show correct units/labels. | R2 |
| A3 | Demo shows OOS, low, overstock, expiry windows, and ≥1 movement path. | R4 |
| A4 | Shared kit + access + responsive themes reused. | R5–R7 |

## Relevant Files

- `.cursor/reporting-analytics.md/pharmacy-reporting.md` §2
- `pharmacy_reporting_catalog.dart`, `pharmacy_reporting_data_provider.dart`
- `backend/src/lib/reports/datasets.js` (`runInventoryDataset`)
- `backend/scripts/seeders/seed-clinical-catalog-pack.js`
- `backend/src/tests/scripts/seed-clinical-catalog-pharmacy-reporting.test.js`
- `frontend/lib/shared/reporting/**`

## Verification

- Dataset/provider tests for each inventory report id and unit keys.
- `db:verify:demo` (or targeted seed tests) asserts risk + movement diversity.
- Manual: Inventory section → stock value, movements, turnover, risk filters; xs + dark.
