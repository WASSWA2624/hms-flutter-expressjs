# Refine: Add Drug dialog (`PharmacyDrugEditDialog`)

## Goal

Polish the **Add drug** modal so formulation, stock, and storage fields are clearer, use shared select components consistently, and storage location is configurable before staff assign shelves.

**Target:** `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_drug_edit_dialog.dart`  
**Catalog data:** `frontend/lib/features/pharmacy/presentation/pharmacy_drug_catalog_options.dart`  
**Shared components:** `AppSelectField`, `AppFormSection`, `AppResponsiveFieldRow` (`frontend/lib/shared/`)

---

## Keep as-is

| Section | Fields | Notes |
|---------|--------|-------|
| **Drug identity** | Drug name* · Drug code | Required name validation stays |
| **Pricing** | Pharmacy price · Facility price | `AppCurrencyAmountField` + currency picker |
| **Initial stock** | Initial stock · Inventory unit | Section layout and optional semantics |
| **Batch and shelf life** | Batch number · Manufacturing date · Expiry date · Expiry alert lead | Existing helpers and validation |

---

## Changes required

### 1 — Formulation: use `AppSelectField`, not free text

Replace `PharmacySearchableTextField` with **`AppSelectField<String>.searchable`** for both fields.

| Field | Options source | Behaviour |
|-------|----------------|-----------|
| **Form** | `pharmacyDrugFormOptions` → `pharmacyFormDisplayLabels(l10n)` | On change, call `_applyFormDefaults` to auto-set inventory unit |
| **Strength** | `pharmacyStrengthSuggestionsForForm(canonicalForm)` | Disabled or empty until a form is chosen; options are form-family presets (e.g. `500 mg`, `250 mg/5 mL`) |

Store canonical values (`option.value` for form; strength string as entered) on submit—same as today.

### 2 — Inventory unit: add icons

Extend `pharmacyInventoryUnitSelectOptions` so each `AppSelectOption` includes a **`leadingIcon`** (Material icon) for common units:

| Unit | Suggested icon |
|------|----------------|
| tablet | `Icons.medication_outlined` |
| capsule | `Icons.medication_liquid_outlined` |
| strip | `Icons.view_week_outlined` |
| box | `Icons.inventory_2_outlined` |
| bottle | `Icons.local_drink_outlined` |
| ampoule / vial | `Icons.science_outlined` |
| tube / jar | `Icons.invert_colors_outlined` |
| inhaler | `Icons.air_outlined` |
| pack | `Icons.layers_outlined` |
| mL / L / g | `Icons.scale_outlined` |
| unit (fallback) | `Icons.category_outlined` |

Icons appear in the dropdown and selected value chip.

### 3 — Reorder alert: clarify the unit

**Problem:** “Reorder alert at” accepts a number but staff cannot tell whether it is tablets, bottles, strips, etc.

**Fix:**

- Append a **dynamic suffix** to the field label or helper when an inventory unit is selected, e.g. *Reorder alert at (tablets)*.
- Update helper text to state explicitly: *Enter the threshold in the selected inventory unit. Alerts fire when on-hand quantity falls at or below this value.*
- If no inventory unit is chosen yet, show muted placeholder helper: *Select an inventory unit first.*

Localize new copy in `frontend/lib/l10n/app_en.arb`.

### 4 — Storage location: room → shelf cascade

Section **Storage location** already exists; complete the UX:

| Field | Component | Rules |
|-------|-----------|-------|
| **Storage room** | `AppSelectField<String>` | Facility catalog from `state.storageLayout.rooms` |
| **Shelf** | `AppSelectField<String>` | Filtered by selected room; disabled until room chosen; clearing room clears invalid shelf |

- Helper: *Optional—helps staff find this drug on the floor.*
- **Empty catalog:** show `pharmacyNoStorageRoomsBody` plus a compact action (e.g. *Configure storage*) that opens the storage management UI—do not leave staff with only static text.

Shelf must exist in the selected room (validated server-side). See **`prompt1.md`** for data model, API, and catalog display.

### 5 — Pharmacy overflow menu: storage configuration entry

Add a **Storage layout** action to the pharmacy workspace toolbar overflow (`pharmacy_workspace_page.dart`) so master/pharmacist users can manage rooms and shelves **without** hunting through the catalog dialog.

- Opens catalog panel on the **Storage** tab (`PharmacyCatalogTab.storage` → `PharmacyStoragePanel`), or a dedicated dialog—pick one entry point and use it consistently from the add-drug empty state.
- CRUD: add/rename/deactivate rooms; per room, add shelf codes and optional labels.
- Permissions: align with existing pharmacy write access.

---

## Out of scope (this prompt)

- Ward/inpatient `room` model (different domain).
- Warehouse map visualization.
- Full backend/storage schema—covered in **`prompt1.md`**.

---

## Acceptance criteria

- [ ] Form and Strength use `AppSelectField.searchable` with catalog presets; strength options react to selected form.
- [ ] Inventory unit options show distinct icons in the select.
- [ ] Reorder alert label/helper makes the inventory unit explicit.
- [ ] Storage room and shelf cascade correctly; both optional on add.
- [ ] Empty storage catalog offers a path to configure rooms/shelves (overflow menu + add-drug empty state).
- [ ] No regression to pricing, batch, or identity sections.
