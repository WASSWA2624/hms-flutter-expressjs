# Prescribe Dialog Editable Medicines Table

Replace the Create Order / Prescribe medicine collapsible cards with a compact editable table that shows unit price, line total, and order total—without changing catalog pick, billing APIs, or submit pipelines.

## Context

**Current behavior**

- Clinical Prescribe and Pharmacy Create order both use `ClinicalPrescriptionActionDialog`.
- Medicines were shown as collapsible cards (`_PrescriptionRxListTile`) via `AppListTableDisplayMode.list`.
- Unit price existed only as an optional unused table column; cards showed no prices or totals.

**Intended behavior**

- Default view is an **editable table**: medicine, quantity, quantity unit (read-only), dose amount, dose unit, route, frequency, **unit price**, **line total**, actions.
- Duration and instructions remain available via column settings (optional columns).
- Footer shows **order total** (sum of line totals using the active billing entity price).
- Mobile / narrow: keep expandable card rows, but surface unit price and line total on the collapsed header.
- Quantity unit stays catalog-fixed (non-editable). Dose unit stays prefilled and editable.

## Requirements

1. Use `AppListTable` in table mode (`forceCompact`) for the medicine list on Create Order / Prescribe.
2. Make quantity, dose amount, dose unit, route, and frequency editable inline in cells; keep medicine identity and quantity unit read-only.
3. Always show **unit price** and **line total** columns (entity-aware via `defaultBillingEntity` / `clinicalCatalogOptionUnitPrice`).
4. Show a table **footer total** using existing billing helpers (`clinicalRequestBillingTotal` / `clinicalRequestPriceLabel`).
5. Preserve toolbar (search, filters, settings, export, Remove selected, Add medicine, Review billing when enabled) and footer submit/cancel.
6. Preserve dosing sync/validation and submit payload shape; do not change pharmacy vs clinical create APIs.
7. Update tests for table presence, prices/totals visibility, editable qty, and existing validation.

## Constraints

- Reuse `ClinicalPrescriptionActionDialog` for Clinical and Pharmacy walk-in—no second prescribe UI.
- Follow `.cursor/mandatories.mdc` and `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion |
| --- | --- |
| A1 | Medicines render as an editable table with price and line total columns. |
| A2 | Order total footer updates when quantity changes. |
| A3 | Quantity unit remains non-editable; dose unit editable; dosing sync still works. |
| A4 | Clinical Prescribe and Pharmacy Create order share the same dialog behavior. |
| A5 | Tests cover table/prices/totals and validation. |

## Relevant Files

- `frontend/lib/shared/clinical_actions/dialogs/clinical_prescription_action_dialog.dart`
- `frontend/lib/shared/clinical_actions/clinical_request_billing_state.dart`
- `frontend/lib/shared/clinical_actions/dialogs/clinical_request_flow_dialogs.dart`
- Tests: `frontend/test/shared/clinical_actions/clinical_prescription_action_dialog_test.dart`
