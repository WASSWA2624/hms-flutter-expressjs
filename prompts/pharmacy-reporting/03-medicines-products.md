# Pharmacy Reporting: Medicines & Products Dialogs and Demo Seed

Deliver Medicines & Products report dialogs from catalog drug/batch attributes with strength, UOM, price, and status fields correctly typed—reusing pharmacy catalog entities and shared reporting UI.

## Context

**Current behavior**

- Category `medicines_products` lists 16 attribute-oriented reports; all `datasetKey`s are null → unavailable.
- Pharmacy catalog already stores name, generic/brand, category, strength, form, UOM, batch, dates, sell/buy price, barcode, controlled/Rx flags, storage via drug/inventory models and catalog UI.

**Intended behavior**

- Each subcategory opens a dialog listing medicines (or batch rows) for the selected attribute slice, filterable by period where dates apply (manufacturing/expiry). Prices use currency; strength/UOM stay as labeled plain/quantity fields; margins as percent.

**Definitions**

- *Catalog report:* Row-per-drug or row-per-batch projection of pharmacy catalog fields—not a POS ledger.
- *Report ids:* `medicine_name`, `generic_brand_name`, `medicine_category`, `strength`, `dosage_form`, `unit_of_measure`, `batch_lot`, `manufacturing_date`, `expiry_date`, `selling_price`, `purchase_price`, `profit_per_unit`, `profit_margin`, `barcode`, `prescription_controlled_status`, `storage_requirements`.

## Requirements

1. Introduce or extend a pharmacy catalog/products dataset; set `datasetKey` on all medicines report ids; project columns relevant to each button (e.g. selling_price emphasizes sell columns; batch_lot emphasizes lot/expiry).
2. Units: `selling_price`/`purchase_price`/`profit_per_unit` → currency; `profit_margin` → percent; strength/UOM/form/name/barcode/status/storage → plain with clear headers; batch qty if present → quantity units.
3. Period filter applies to manufacturing/expiry windows where meaningful; otherwise show current catalog snapshot and document in subtitle. Loading/empty/error/ready via shared dialog.
4. Seed demo drugs covering brand+generic, multiple categories/forms/UOMs, batches with mfg/expiry, sell≠buy prices (non-zero margin), barcodes, Rx and controlled flags, storage notes.
5. Reuse drug/inventory read paths and shared reporting components; do not rebuild Catalog CRUD inside Reporting.
6. Gate browse with pharmacy + reports read; responsive table; theme tokens; light/dark.
7. Tests: each report id returns mapped columns; margin/price units; seed has controlled + Rx examples; export gated.

## Constraints

- Do not require Analytics; do not duplicate Suppliers CRUD (`prompts/pharmacy-suppliers.md`).
- Follow `.cursor/mandatories.mdc`, `.cursor/access/demo-data.mdc`, `prompts/.cursor/prompt.mdc`, `.cursor/flows/pharmacy-flow.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | All 16 medicines report dialogs show catalog-mapped rows (or empty), not unavailable. | R1 |
| A2 | Price/margin/UOM fields use correct units and labels. | R2 |
| A3 | Demo catalog includes priced batches, controlled/Rx, varied forms/UOMs. | R4 |
| A4 | Shared kit reused; Catalog CRUD unchanged; responsive + access OK. | R5–R7 |

## Relevant Files

- `.cursor/reporting-analytics.md/pharmacy-reporting.md` §3
- `pharmacy_reporting_catalog.dart`, `pharmacy_reporting_data_provider.dart`
- Pharmacy drug/inventory entities & repositories
- `backend/src/lib/reports/datasets.js`, clinical catalog seeder
- `frontend/lib/shared/reporting/module_reporting_table.dart`

## Verification

- Provider tests per report id column projection.
- Seed tests: demo drugs expose sell/buy/margin and controlled flag.
- Manual: Medicines section → selling price, batch/lot, controlled status; narrow width.
