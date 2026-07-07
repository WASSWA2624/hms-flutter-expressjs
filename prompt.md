# Pharmacy — Medication Instructions Print & Prescription Detail Polish

## Objective

Polish two pharmacy prescription surfaces shown in the attached screenshots:

1. **Medication instructions** printout (triggered by **Print instructions** on prescription detail)
2. **Prescription detail** → Medicines table in the workspace dialog

Align both with HOSSPI print and workspace patterns: clear numbering, consistent pricing columns, patient-readable content, and clean table layout.

---

## Scope

| In | Out |
| -- | --- |
| Print medicines table layout (`pharmacy_instructions_print_helpers.dart`) | Print header/branding, patient context block, signatures |
| Prescription detail medicines panel (`_MedicationItemsPanel` in `pharmacy_workspace_page.dart`) | Dispense/attest/return workflow, billing gates |
| i18n for any new/changed labels | Backend/API changes |
| Widget/helper tests for print HTML and panel layout | |

---

## 1. Medication instructions printout

**Current state (screenshot):** Table has Medication, Quantity, Instructions only. No row numbers; pricing columns hidden when price is unavailable.

**Target layout:**

| # | Medication | Quantity | Instructions | Unit price | Amount |
| - | ---------- | -------- | ------------ | ---------- | ------ |
| 1 | … | … | … | … or `—` | … or `—` |
| … | | | | | |
| | | | | **Total amount sold** | **UGX …** or `—` |

### Requirements

- **Row numbering:** Add a leftmost `#` column (1-based index per medicine line).
- **Pricing columns always visible:** Show **Unit price** and **Amount** (line total) on every printout — not gated behind `showPricing`.
- **Missing values:** When unit price or line amount is unavailable, render `—` (reuse `pharmacyPrintPriceUnavailable`).
- **Currency on amounts:** Format monetary cells with currency via `clinicalRequestPriceLabel` / existing pharmacy pricing helpers (`resolvePharmacyItemUnitPrice`, `resolvePharmacyItemLineTotal`, `resolvePharmacyItemCurrency`).
- **Total row:** Append a final table row labeled **Total amount sold** (add arb key if needed; do not reuse “Grand total” prose below the table). Show the summed line totals with currency when any priced lines exist; otherwise `—`.
- **Preserve existing behavior:** Patient-readable instructions (no raw `BID`, `ORAL`, etc.), no duplicate patient/order metadata in the body, section title “Medicines”.

### Implementation notes

- Primary file: `frontend/lib/features/pharmacy/presentation/pharmacy_instructions_print_helpers.dart`
- Extend `PrintFormTemplate.table` usage (or add optional footer-row support) so the total is the **last table row**, not a separate `<p>` below the table.
- Update `frontend/test/features/pharmacy/presentation/pharmacy_instructions_print_helpers_test.dart` for numbering, always-on price columns, dash fallbacks, and total row.

---

## 2. Prescription detail — Medicines panel

**Current state (screenshot):** Panel shows **Medicines** title + descriptive subtitle; `#` column is misaligned vertically with Medication/Dose/Quantity cells.

### Requirements

- **Remove panel chrome:** Drop `title` and `description` from the medicines `AppWorkspaceDetailPanel` — show the table only (columns already convey structure).
- **Fix `#` alignment:** Row numbers must align with the top of each row’s primary content (match Dose, Quantity, Price, Actions vertical alignment). Likely fix: top-align `#` cells in `AppListTable` data rows and/or remove extra top padding in numbered cells when row content is multi-line (`_MedicationCell`).

### Implementation notes

- Primary file: `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart` (`_MedicationItemsPanel`)
- If the misalignment is shared, fix in `frontend/lib/shared/components/app_list_table.dart` without breaking other tables.

---

## Standards

- All new user-visible strings in `app_en.arb`; run codegen.
- Reuse shared printing, pricing, and clinical display helpers — no duplicate formatting logic.
- Responsive: print layout readable on A4; workspace table unchanged on mobile card layout.
- Quality gate: `dart format`, `flutter analyze`, `flutter test` (pharmacy print + relevant widget tests).

---

## Done when

- [ ] Print table: `#`, Unit price, Amount columns on every line; `—` when price missing
- [ ] Print table: final **Total amount sold** row with currency (or `—`)
- [ ] Instructions remain patient-readable; no duplicate header metadata
- [ ] Prescription detail medicines panel has no title/description
- [ ] `#` column vertically aligns with sibling cells in the medicines table
- [ ] Tests updated; analyze clean
