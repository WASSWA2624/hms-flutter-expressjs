# Pharmacy Reporting: Expiry & Loss Control Dialogs and Demo Seed

Implement Expiry & Loss Control dialogs with day-window, value, and reason mappings—extending inventory risk seed and shared formatters.

## Context

**Current behavior**

- Category `expiry_loss` has 8 reports. `expiring_windows` and `already_expired` filter `inventory_stock_risk`; value, damage, loss, write-offs, reasons, and breakdown remain unavailable.
- Clinical catalog already seeds wall-clock expiry offsets (expired through 180-day windows).

**Intended behavior**

- Dialogs show expiry buckets (30/60/90/180), expired stock, loss values, write-offs, adjustment reasons, and product/category/supplier loss breakdowns with currency for values and days for expiry distance.

**Definitions**

- *Expiry window:* Rows with `days_to_expiry` within 30/60/90/180 (and labeled buckets).
- *Report ids:* `expiring_windows`, `already_expired`, `expired_stock_value`, `damaged_stock_loss`, `lost_stock_loss`, `stock_write_offs`, `adjustment_reasons`, `expiry_losses_breakdown`.

## Requirements

1. Complete datasetKeys + projections for all expiry/loss ids; extend stock-risk and adjustment/write-off sources.
2. Units: `days_to_expiry` → days; expired/damage/loss/write-off values → currency; quantities → units; reason/category labels plain.
3. Period filter scopes write-offs/adjustments; expiry snapshot may be as-of “to” date—state that in subtitle.
4. Seed: batches in each window, expired value > 0, damaged/lost/write-off adjustments with reasons, supplier/category on loss rows where FK exists.
5. Reuse provider stock-risk filters and shared dialog/export; no parallel loss UI.
6. Access, responsive, themes; tests for windows + value units + seed templates.

## Constraints

- Do not invent orphan adjustment FKs; follow `.cursor/access/demo-data.mdc`.
- Follow `.cursor/mandatories.mdc`, `prompts/.cursor/prompt.mdc`, `frontend/.cursor/layouts.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | All 8 expiry/loss reports leave unavailable with seed. | R1 |
| A2 | Days/currency/qty units correct across dialogs. | R2 |
| A3 | Demo covers 30/60/90/180, expired value, and ≥1 write-off reason. | R4 |
| A4 | Shared kit + access + responsive OK. | R5–R6 |

## Relevant Files

- `.cursor/reporting-analytics.md/pharmacy-reporting.md` §7
- `pharmacy_reporting_data_provider.dart`, catalog ids
- `seed-clinical-catalog-pack.js`, pharmacy reporting seed tests
- `backend/src/lib/reports/datasets.js`
- `frontend/lib/shared/reporting/module_reporting_table.dart`

## Verification

- Tests for window filtering and expired value currency formatting.
- Manual: Expiry section → windows, write-offs, breakdown; light/dark.
