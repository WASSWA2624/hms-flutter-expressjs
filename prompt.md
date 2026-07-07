# Pharmacy — Medication Instructions Print Layout Refinement

## Objective

Improve the **Medication instructions** printout (`_pharmacyInstructionsHtml` in `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart`) so it is patient-friendly, non-redundant, and shows clear pricing — without raw clinical abbreviations.

**Trigger:** `AppReportActionButton.print` → `printFormTemplateDocument` (pharmacy actions panel).

---

## Scope

**In:** print HTML body, helper(s) for readable prescription lines, i18n for new column/total labels.  
**Out:** print shell/header branding, dispense workflow, workspace UI tables.

---

## Requirements

### 1. Remove duplicate metadata

Drop the `PrintFormTemplate.keyValueGrid` block (Patient / Order) from `bodyHtml`. Patient name, patient ID, encounter ID, and order ref are already rendered by `buildPrintFormPatientContext` and `PrintFormContextReference` in the print header.

### 2. Replace bullet list with a medicines table

Replace `PrintFormTemplate.unorderedList` (pipe-separated single-line entries) with `PrintFormTemplate.table`.

| Column | Content |
| ------ | ------- |
| Medicine | Drug name |
| Quantity | Prescribed qty + unit (e.g. `4 tablets`) |
| Instructions | Human-readable sig (see §3) |
| Unit price | Formatted price when available; `—` when not |
| Total | Line total when price available |

Add a **grand total** row/footer below the table (sum of line totals with currency). Omit price columns/total when no priced items.

Reuse pricing helpers: `resolvePharmacyItemUnitPrice`, `resolvePharmacyItemLineTotal`, `resolvePharmacyItemCurrency`, `clinicalRequestPriceLabel` from `pharmacy_order_item_pricing_helpers.dart`.

### 3. Human-readable prescription text

Do **not** print raw codes (`BID`, `TID`, `ORAL`, etc.) in the instructions column.

- Reuse or extend `clinicalPrescriptionReadableSummary` (`clinical_prescription_display.dart`) for `PharmacyOrderItem` fields (dose, route, frequency, duration, free-text instructions).
- Map frequency codes dynamically (e.g. `BID` → “twice daily”, `TID` → “three times daily”).
- Fall back to title-cased labels for unknown codes — never expose enum/API tokens to patients.

### 4. Visual cleanup

- No badge/tag styling or pipe-delimited shorthand in the print body.
- Keep section title (`pharmacyMedicationPanelTitle` / “Medicines”).
- Preserve existing footer note and signature blocks.

---

## Implementation

| Area | Guidance |
| ---- | -------- |
| Primary file | `pharmacy_workspace_page.dart` — refactor `_pharmacyInstructionsHtml` |
| Shared logic | Extract `pharmacyOrderItemReadableSummary(PharmacyOrderItem)` if needed; avoid duplicating `_frequencyReadable` |
| i18n | Add arb keys for table headers and total label |
| Tests | Update/add `print_form_template_test.dart` or pharmacy print helper tests for HTML structure and readable frequency mapping |

---

## Done when

- [ ] Patient/order metadata appears once (header only)
- [ ] Medicines render in a structured table, not bullets
- [ ] Each line shows name, qty+unit, readable instructions, unit price, line total
- [ ] Grand total shown when pricing exists
- [ ] Frequencies/routes are patient-readable (no raw `BID`, `ORAL`, etc.)
- [ ] `flutter analyze` passes
