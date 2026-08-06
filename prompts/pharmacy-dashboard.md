# Prescribe Dialog Compact Medicines Table

Tighten the Create Order / Prescribe medicines table: narrower chrome columns, wider wrapping medicine names with brand, short Qty/Unit/Amount labels, always-visible duration unit, and reliable horizontal scroll—without changing catalog pick, billing APIs, or submit pipelines.

## Context

**Current behavior**

- Clinical Prescribe and Pharmacy Create order share `ClinicalPrescriptionActionDialog` with an editable priced table.
- Checkbox, quantity, and quantity-unit columns were too wide; dose unit and price/amount could clip without a usable bottom scrollbar.
- Medicine cells showed identity text without wrapping; quantity fields used full “Quantity” / “Quantity unit” / “Line total” labels.

**Intended behavior**

- Compact default columns: checkbox-only select, flexible wrapping **Medicine** (`Generic (Brand) - strength`), content-fitted **Qty**, **Unit**, dose amount, dose unit, duration, **Duration unit**, price, **Amount**, actions.
- Other columns use fixed content widths; Medicine is the only flexible column and absorbs leftover dialog width.
- Table content wider than the dialog scrolls horizontally with a bottom scrollbar; **xs/sm** use expandable mobile cards; **md+** use the dense table with breakpoint-scaled column widths.
- Dialog max width scales by breakpoint; tablet tables use icon-only row actions.
- Quantity stays default **0** and must be positive to submit; Edit/Delete stay labeled.
- No speech-to-text (mic) on search or inline editors; validation uses the top banner only (no clipped cell error text); banner and field errors clear on typing.

## Requirements

1. Set fixed/preferred column widths so select, Qty, Unit, and Duration stay narrow; Medicine and Dose unit stay fully readable.
2. Show medicine as `clinicalPrescriptionDrugIdentityLabel` with soft wrap (up to 3 lines).
3. Rename column headers to **Qty**, **Unit**, and **Amount**; keep field semantics for a11y.
4. Always show Duration unit beside Duration; keep route/frequency/instructions optional via Settings.
5. Use dense inline editors without floating labels so cells fit their columns.
6. Preserve horizontal scroll at the bottom of the table viewport and responsive dialog sizing.
7. Update tests for new headers, brand identity, duration unit, and semantic field lookup.

## Constraints

- Reuse `ClinicalPrescriptionActionDialog` for Clinical and Pharmacy walk-in—no second prescribe UI.
- Follow `.cursor/mandatories.mdc` and `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion |
| --- | --- |
| A1 | Select column is checkbox-width; Medicine wraps with generic and brand when present. |
| A2 | Headers show Qty, Unit, Amount; Duration unit is visible by default. |
| A3 | Dose unit and price/amount remain fully readable; table scrolls horizontally when needed. |
| A4 | Clinical and Pharmacy share the same table behavior; existing validation still blocks qty ≤ 0. |
| A5 | Tests cover compact labels, brand identity, duration unit, prices, and validation. |

## Relevant Files

- `frontend/lib/shared/clinical_actions/dialogs/clinical_prescription_action_dialog.dart`
- `frontend/lib/shared/clinical_actions/clinical_prescription_display.dart`
- Tests: `frontend/test/shared/clinical_actions/clinical_prescription_action_dialog_test.dart`
