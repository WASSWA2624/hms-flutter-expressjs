# Refine patient lab request flow

## Context

Entry point: **Patient detail → Quick actions → Request lab** (`ClinicalLabOrderActionDialog`).

Current behavior uses a compact modal with a dropdown-style catalog picker (`ClinicalLabRequestCatalogDialog`). Replace that picker with the standard **`AppListTable`** pattern used elsewhere (e.g. patient registry, lab enable-offering dialog in `lab_catalog_dialogs.dart`).

## 1. Request Lab dialog (main modal)

Update `ClinicalLabOrderActionDialog`:

- Open **maximized by default** (`AppDialog.initialMaximized: true`).
- **Remove the Cancel button**; closing via the dialog X / backdrop is sufficient.
- Add a **leading icon** to the primary **Request lab** action button (match existing icon usage, e.g. `Icons.science_outlined`).
- Keep the existing flow: help text → **Add items** / **Review billing** toolbar → summary bar (item count + total price) → selected-items panel → submit.

## 2. Choose lab tests dialog (Add items)

Replace the current search dropdown in `ClinicalLabRequestCatalogDialog` with a table-based multi-select picker.

### Layout

- Maximized dialog titled **Choose lab tests**.
- **Segmented control** at top: **Individual tests** | **Lab panels** (keep current tab behavior).
- Below: **`AppListTable`** with the standard toolbar:
  - Search bar (name, code, category, specimen, status)
  - **Advanced filters**
  - **Table settings** (column visibility)
- Footer: **Done** only (no per-row Add button required if checkbox selection is used).

### Data scope

- Show **only catalog items configured for the current facility** (`facilityOfferingsOnly: true` — already passed from the main dialog).
- Include both **lab tests** and **lab panels**, switched by the segmented control.

### Table columns

| Column | Source |
|--------|--------|
| Full name | `ClinicalActionCatalogOption.name` |
| Short name / code | `ClinicalActionCatalogOption.code` |
| Test type | `ClinicalActionCatalogOption.category` (e.g. Chemistry) |
| Price | `ClinicalActionCatalogOption.unitPrice` + currency |

Add a trailing **checkbox column** for selection. Toggling a checkbox adds/removes the item from the pending lab request list in the parent dialog.

### Selection UX

- Show a **selected count** (e.g. “3 selected”) in the dialog header or above the table.
- **Sort order**: selected rows **pinned to the top**; unselected rows below.
- **Visual treatment**: selected rows use a distinct highlight (reuse existing `AppListTable` row-color patterns where available).
- Prevent duplicate selections (keep current duplicate guard).
- Persist selections when switching between **Individual tests** and **Lab panels** tabs within the same session.

## 3. Implementation notes

- Reuse **`AppListTable`**, **`AppListTableSearch`**, and **`AppListTableColumnVisibilityController`** — do not introduce a one-off table widget.
- Follow patterns in `lab_catalog_dialogs.dart` (`LabEnableOfferingDialog`) for maximized catalog dialogs with search + filters.
- Wire selection state back to `ClinicalLabOrderActionDialog` so the main dialog’s summary bar and selected-items panel update live.
- Add/adjust l10n keys in `app_en.arb` for any new labels (column headers, selection count).
- Add widget tests covering: default maximized main dialog, checkbox multi-select, selected-first sort order, and facility-only filtering.

## 4. Out of scope

- Billing dialog changes.
- Backend/API changes (use existing `onSearchLabTests` callback).
- Radiology or other clinical request flows (apply the same pattern only if explicitly requested later).
