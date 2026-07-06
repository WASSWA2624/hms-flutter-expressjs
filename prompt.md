# Feature: Refine Choose Imaging Study dialog layout and scrolling

## Goal

Simplify and unify the **Choose imaging study** catalog picker (`ClinicalRadiologyRequestCatalogDialog`) so order metadata, search, and the study table feel like one surface—no redundant controls, no nested scroll areas, and predictable table height up to 100 rows.

## Current state (keep)

Do not regress:

- **Dialog title:** *Choose imaging study* (`clinicalRadiologyCatalogPickerTitle`).
- **Order metadata fields:** Modality, Laterality, Priority, Body region (dropdown), Clinical note.
- **Search bar** with placeholder *Search by test, intervention, modality, region, code, or priority*.
- **Radiology filters** and **Table settings** affordances on `AppListTable`.
- **Checkbox selection** (row + header select-all), selected-row highlight, and **Confirm selected studies** action.
- **Entry point:** `showClinicalRadiologyRequestCatalogDialog` (e.g. from `clinical_radiology_order_action_dialog.dart`). Changes apply everywhere this shared dialog is used.

## Problems (from screenshots)

| Area | Current behavior | Issue |
|------|------------------|-------|
| **Filter section** | Wrapped in `ConstrainedBox` + `SingleChildScrollView` (`maxHeight: bodyHeight * 0.36`) | Metadata scrolls independently; user must scroll to see clinical note / chips while the table stays fixed |
| **Body region chips** | `_RadiologyBodyRegionChipPicker` below clinical note (e.g. Abdomen, Abdomen and pelvis, Pelvis) | Duplicates the Body region dropdown |
| **Selection counter** | `{count} selected` above the search bar | Adds noise; selection is already visible via checkboxes and row highlight |
| **Table scroll** | `Expanded` `AppListTable` always scrolls inside a fixed dialog height | Table scrolls even with few rows; does not match “grow to 100 rows, then scroll” behavior |

## Required changes

### 1. Unified scrolling (filters + table)

- Remove the **independent scroll** on the metadata section (`ConstrainedBox` + `SingleChildScrollView` around modality / laterality / priority / body region / clinical note).
- Metadata fields must be **fully visible at a glance** on typical desktop widths (no inner scrollbar for that block alone).
- When content exceeds the dialog viewport, **one scroll** should move filters, search, and table together—not two nested scroll regions.

### 2. Table height and scroll threshold (100 rows)

- The catalog table should **expand naturally** and show rows **without an internal scrollbar** while row count ≤ **100**.
- When there are **more than 100 rows**, enable scrolling (internal table scroll or unified dialog scroll—pick the approach that satisfies unified scrolling above).
- Reuse existing constants where possible: `_maxVisibleCatalogOptions = 100` and `AppListTable.maxVisibleItems` if it fits this behavior.
- Fetch limit stays at 100 unless pagination/incremental load is already wired elsewhere.

### 3. Remove duplicate body-region chips

- Delete `_RadiologyBodyRegionChipPicker` and its render branch (`bodyRegionOptions.length <= 16`).
- **Body region** remains the dropdown/searchable select only (`_bodyRegionField`).

### 4. Remove selection counter

- Remove the `{count} selected` label (`clinicalRadiologyRequestSelectedCount`) above the search bar.
- Do **not** remove checkbox selection or selected-row styling.

## Primary file

`frontend/lib/shared/clinical_actions/dialogs/clinical_radiology_request_catalog_dialog.dart`

**Related (only if needed):**

- `frontend/lib/shared/components/app_list_table.dart` — `maxVisibleItems`, scroll physics
- `frontend/lib/shared/clinical_actions/clinical_radiology_catalog_helpers.dart`
- `frontend/test/shared/clinical_actions/clinical_radiology_order_action_dialog_test.dart`
- `frontend/lib/l10n/app_en.arb` — remove or stop using `clinicalRadiologyRequestSelectedCount` if unused elsewhere

## Implementation rules

- **Reuse shared components** (`AppDialog`, `AppListTable`, `AppSelectField`, `AppTextField`, `AppSearchBar` patterns). Do not fork a radiology-only table.
- **No new visual language** — match spacing, typography, and dialog sizing used by other clinical catalog pickers.
- **Scope:** this dialog only; do not change the Lab catalog picker unless required for a shared scroll helper.
- **Mobile:** preserve responsive stacking of metadata fields; unified scroll must still work on narrow viewports.

## Acceptance criteria

- [ ] Modality, Laterality, Priority, Body region, and Clinical note are visible without a dedicated inner scrollbar on standard desktop dialog size.
- [ ] Scrolling the dialog moves metadata and table together (no nested independent scroll on the filter block).
- [ ] Table shows ≤100 rows without an internal scrollbar; scrollbar appears only when row count exceeds 100.
- [ ] Body region quick-filter chips (Abdomen, Abdomen and pelvis, Pelvis, etc.) are removed; dropdown remains.
- [ ] `{count} selected` counter is removed; checkboxes and row highlight still indicate selection.
- [ ] **Confirm selected studies** flow unchanged; dialog behavior is consistent wherever `showClinicalRadiologyRequestCatalogDialog` is called.
- [ ] Widget tests updated if they assert on removed UI (chips, selection count).
