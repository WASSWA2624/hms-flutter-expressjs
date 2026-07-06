# Feature: Refine Pharmacy Add/Edit Drug dialog

## Goal

Redesign the **Add drug** / **Edit drug** dialog in the Pharmacy catalog so it is scannable, supports any common medication type, and reuses existing shared form components. Guided selects should reduce free-text errors for form, strength, and inventory units; prices must persist with currency; stock fields should read as one logical group.

## Current state (problem)

The dialog in `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_catalog_panel.dart` (`_DrugEditDialog`) is a single vertical stack of plain `AppTextField`s (see screenshots):

| Issue | Detail |
|-------|--------|
| **Layout** | 11+ full-width fields with no grouping; hard to scan on desktop |
| **Free-text everywhere** | Form, strength, and inventory unit are unstructured text |
| **Pricing** | Pharmacy and facility prices are raw number fields—no currency picker |
| **Stock UX** | Inventory unit appears before quantity; unit and reorder are disconnected from form context |
| **Labels** | Most fields render as “(optional)” via `AppFieldLabel` even when business rules require them |
| **Dialog chrome** | No dialog icon; Cancel / Add drug actions have no leading icons |
| **Edit parity** | Edit path updates identity/pricing only; add path includes stock—keep that split |

Backend already accepts `currency` on drug setup (`setupPharmacyDrugSchema`) and facility offering currency; the UI does not wire them yet.

## Reference implementation

Mirror patterns from catalog dialogs that already use structured forms:

| Pattern | Reference |
|---------|-----------|
| Currency + amount | `AppCurrencyAmountField` in `frontend/lib/shared/components/app_currency_amount_field.dart`; used in `lab_catalog_dialogs.dart`, `radiology_catalog_dialogs.dart` |
| Two-column rows | `AppResponsiveFieldRow.two` in `frontend/lib/shared/forms/app_responsive_field_row.dart` |
| Grouped sections | `AppFormSection` in `frontend/lib/shared/forms/app_form_section.dart` |
| Selects | `AppSelectField` (already used in `_FormularyCreateDialog` in the same file) |
| Searchable catalog pick | `LabSearchableTextField` in `frontend/lib/shared/lab_catalog/` when a combobox-with-custom-entry is needed |
| Dialog shell | `AppDialog` with `icon`, `maxWidth`, `scrollable`, action `leadingIcon`s |

**Primary file to change:** `pharmacy_catalog_panel.dart` (`_DrugEditDialog`).

**Domain / API (wire through if extended):**

- `PharmacyDrugInput`, `PharmacyDrugUpdateInput`, `PharmacyFacilityOfferingInput` — `pharmacy_entities.dart`
- `setupPharmacyDrugSchema` — `backend/src/modules/pharmacy-workspace/schemas/pharmacy-workspace.schema.js`
- Clinical drug examples — `backend/scripts/seeders/seed-clinical-catalog-pack.js` (forms, strengths, units)

## Form layout

Use `AppFormSection` with short section titles. On wide viewports, place related fields on one row via `AppResponsiveFieldRow.two`; collapse to single column on narrow widths.

### Section 1 — Drug identity

| Field | Component | Required | Notes |
|-------|-----------|----------|-------|
| Drug name | `AppTextField` | Yes | Only required field on add |
| Drug code | `AppTextField` | No | Optional internal/SKU code |

Row: **name** (wider) + **code**.

### Section 2 — Formulation

| Field | Component | Required | Notes |
|-------|-----------|----------|-------|
| Form | `AppSelectField` with searchable/custom entry | No | Predefined dosage forms; allow “Other” → free text |
| Strength | `AppSelectField` or searchable combobox | No | Suggestions filtered by selected form |

**Predefined forms** (store canonical value; display *Full name (short)* where a short form exists):

Tablet, Capsule, Chewable Tablet, Syrup, Suspension, Injection, Ampoule, Vial, Cream, Ointment, Gel, Drops, Inhaler, Suppository, Patch, Powder, Solution, Lotion, Spray, Other.

**Form → default inventory units** (suggest first; user can override):

| Form family | Suggested units |
|-------------|-----------------|
| Solid oral (tablet, capsule, chewable) | tablet (`tab`), capsule (`cap`), strip, box |
| Liquid oral (syrup, suspension, solution) | bottle (`btl`), millilitre (`mL`), litre (`L`) |
| Injectable (injection, ampoule, vial) | ampoule (`amp`), vial, box |
| Topical (cream, ointment, gel, lotion) | tube, jar, gram (`g`) |
| Inhaler / drops / spray | inhaler, bottle (`btl`), pack |
| Other | unit, box, pack |

**Strength suggestions** (examples per form; include common clinical strengths from seeder data):

- Tablet/Capsule: `250 mg`, `500 mg`, `5 mg`, `10 mg`, `20 mg`, `40 mg`, `81 mg`, `400 mg`, `625 mg`, etc.
- Injection/Vial: `1 g`, `500 mg`, `75 mg/3 mL`, `10 mg/mL`, `100 IU/mL`, etc.
- Syrup: `125 mg/5 mL`, `250 mg/5 mL`, `2 mg/5 mL`, etc.

When the user picks a form, pre-select the most likely unit and refresh strength options. Changing form should not clear name/code.

Row: **form** + **strength**.

Extract form/unit/strength catalogs to a small shared module (e.g. `frontend/lib/features/pharmacy/presentation/pharmacy_drug_catalog_options.dart`) so the dialog and future prescription flows can reuse them.

### Section 3 — Pricing

| Field | Component | Required | Notes |
|-------|-----------|----------|-------|
| Pharmacy price | `AppCurrencyAmountField` | No | Persist `unit_price` + `currency` |
| Facility price | `AppCurrencyAmountField` | No | Persist via `PharmacyFacilityOfferingInput` with `currency` |

Row: **pharmacy price** + **facility price** (side by side on desktop).

Default currency: tenant/facility default or `appDefaultCurrencyCode` (`UGX`). Reuse `appCurrencyOptions` from the shared amount field.

### Section 4 — Initial stock *(add flow only; hidden on edit)*

| Field | Component | Required | Notes |
|-------|-----------|----------|-------|
| Initial stock | `AppTextField` (digits only) | No | Quantity **before** unit |
| Inventory unit | `AppSelectField` with full + short label | No | e.g. `Tablet (tab)`, `Bottle (btl)`, `Vial` |
| Reorder alert at | `AppTextField` (digits only) | No | Quantity threshold in selected units |

Row: **initial stock** + **inventory unit**; **reorder alert at** full width or paired with a helper caption explaining it is a quantity threshold.

Helper text (muted): reorder alerts fire when on-hand quantity falls at or below this value.

### Section 5 — Batch & shelf life *(add flow only)*

| Field | Component | Required | Notes |
|-------|-----------|----------|-------|
| Batch number | `AppTextField` | Conditional | Required when expiry date is set (matches backend `superRefine`) |
| Manufacturing date | `AppDateField` | No | New field—add to schema/API if not present |
| Expiry date | `AppDateField` | No | Existing field |
| Expiry alert lead | `AppSelectField` or numeric + unit | No | e.g. `90 days`, `3 months`, `6 months` before expiry |

Row: **batch number** + **manufacturing date**; row: **expiry date** + **expiry alert lead**.

**Expiry alert lead** drives proactive stock risk alongside quantity reorder: e.g. “alert 90 days before expiry” means the drug surfaces in expiring-soon filters even if quantity is healthy. Wire to backend if a per-drug or per-batch lead field does not exist yet; otherwise store on the initial batch metadata created during setup.

## Dialog chrome

- `AppDialog` `icon`: `Icons.medication_outlined`
- `maxWidth`: ~720–860 (match lab catalog dialogs)
- `scrollable: true`
- Actions:
  - **Cancel** — `AppButton.tertiary` with `leadingIcon: Icons.close`
  - **Add drug** / **Save** — `AppButton.primary` with `leadingIcon: Icons.add` / `Icons.save_outlined`
- Mark required fields with `isRequired: true` so labels do not show spurious “(optional)”

## Backend parity

- Send `currency` with pharmacy `unit_price` and facility offering `unit_price`.
- If adding `manufactured_at` and `expiry_alert_lead_days` (or equivalent), extend:
  - `setupPharmacyDrugSchema`
  - `pharmacy-workspace.service.js` drug setup path
  - `PharmacyDrugInput.toSetupJson()`
  - DTO/entity mapping
- Do not client-only invent fields the API cannot persist.
- Keep existing rule: `expiry_date` without `batch_number` is rejected.

## Implementation rules

- **Reuse shared components** from `frontend/lib/shared/`—do not fork raw `TextField` markup.
- **No new visual language**—match Lab/Radiology catalog dialog spacing and `AppFormSection` density.
- **Localization:** add/adjust keys in `frontend/lib/l10n/app_en.arb` for section titles, unit labels (`{full} ({short})`), form labels, expiry lead options, and helper copy.
- **Scope:** `_DrugEditDialog` and supporting constants/helpers only; drug worklist table and inventory adjust dialog are out of scope unless a tiny shared unit catalog is extracted.
- **Validation:** name required on add; positive integers for stock/reorder; positive amounts for prices; batch required when expiry is set.

## Acceptance criteria

- [ ] Add drug dialog uses grouped `AppFormSection`s with responsive two-column rows—not a flat 11-field stack.
- [ ] Form, strength, and inventory unit use guided selects (with custom entry where needed); options show full name and short form where applicable.
- [ ] Selecting a form updates suggested units and strength options without clearing other fields.
- [ ] Pharmacy and facility prices use `AppCurrencyAmountField`; currency is saved with the price.
- [ ] Initial stock appears before inventory unit; reorder alert follows as a quantity threshold in the chosen unit.
- [ ] Batch, manufacturing date, expiry date, and expiry alert lead are grouped; batch is required when expiry is set.
- [ ] Required vs optional labels are correct (drug name required; others optional unless conditional).
- [ ] Dialog has a title icon; Cancel and primary action have leading icons.
- [ ] Edit drug dialog still updates identity/pricing only (no stock section).
- [ ] New or extended fields are persisted via backend schema/API—not UI-only.
- [ ] Shared pharmacy drug catalog options are reusable outside this dialog.
