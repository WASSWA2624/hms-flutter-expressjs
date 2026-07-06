# Feature: Pharmacy Catalog & Stock dialog — UI polish and full CRUD parity

## Goal

Refine the **Catalog and Stock** dialog (`openPharmacyCatalogDialog`) so all four tabs—**Drugs**, **Formulary**, **Inventory**, and **Storage layout**—share a consistent, compact layout, and every create / edit / delete flow works end-to-end against the existing pharmacy workspace API.

## Scope

Primary files:

| Area | Path |
|------|------|
| Catalog shell & tabs | `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_catalog_panel.dart` |
| Drug add/edit | `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_drug_edit_dialog.dart` |
| Storage layout | `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_storage_panel.dart` |
| Workspace state/API | `frontend/lib/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart` |
| Backend | `backend/src/modules/pharmacy-workspace/` |

Reuse existing shared patterns: `AppListTable` + `AppListTableSearch`, `AppSearchBarAction`, `AppSearchBarFilterGroup`, `AppFormSection`, `AppDialog` action icons.

---

## Global layout rules

1. **Remove redundant panel headers** inside each tab when rendered inside the catalog dialog. Drop `AppWorkspaceDetailPanel` `title` and `description` for Drugs, Formulary, Inventory, and Storage layout (the dialog title and tab bar already provide context).
2. **Move primary actions into the search bar** via `AppListTableSearch.trailingActions` (`AppSearchBarAction` with `Icons.add`). Remove the standalone `Align` primary-action row in `PharmacyCatalogPanel` for Drugs, Formulary, and Storage.
3. **All dialog footers** use icon + label buttons (`leadingIcon` on `AppButton.tertiary` / `AppButton.primary`), matching the Add/Edit room pattern in `pharmacy_storage_panel.dart`.
4. Gate write actions with existing `AppAccessActionGate` / `pharmacyWrite` permissions.

---

## Tab 1 — Drugs

### Layout

- Remove “Formulary and stock” panel title and description.
- Keep storage-room / shelf dropdown filters above the table when rooms exist.
- Place **Add drug** in the table search bar trailing actions (not above the tab content).
- Retain bulk-delete in trailing actions when rows are selected.

### Add / edit drug (`PharmacyDrugEditDialog`)

- **Add flow** must create a drug and, when initial stock is supplied, persist batch, reorder level, expiry metadata, and optional storage location.
- **Edit flow** must expose the same editable sections as add, except add-only initial-receipt fields:
  - **Always editable:** Drug identity (name, code), Formulation (form, strength), Pricing (pharmacy + facility price with currency).
  - **Also editable on edit:** Reorder level, default storage room/shelf (when catalog exists).
  - **Add-only:** Initial stock quantity, inventory unit, batch number, manufacture/expiry dates, expiry-alert lead.
- Pre-fill all edit fields from `PharmacyDrug` (and linked inventory metadata where available).
- Footer: Cancel (`Icons.close`) + Save (`Icons.save_outlined`).

### Functional checks

- Search, pagination, storage filters, row edit, row delete, and bulk delete all refresh the table and surface API errors.
- Prices display correctly in the table after save.

---

## Tab 2 — Formulary

### Layout

- Remove panel title and description.
- Move **Add formulary item** into the search bar trailing actions.

### Add / edit formulary (`_FormularyItemDialog`)

- **Replace the drug `AppSelectField` on add** with a searchable, selectable **`AppListTable<PharmacyDrug>`** inside the dialog:
  - Columns: drug name (display title), drug code.
  - Single-row selection; selected drug drives `drugId` on submit.
  - Reuse the same search hint as the Drugs tab.
- **Edit flow:** drug remains read-only (show current drug label); only **Active** toggle is editable.
- Footer icons: Cancel (`Icons.close`), primary action (`Icons.add` on add / `Icons.save_outlined` on edit).

### Functional checks

- Create, update (active flag), delete, bulk delete, search, and pagination all work.
- Formulary list shows human-readable drug title, not only internal IDs.

---

## Tab 3 — Inventory

### Layout

- Remove “Inventory stock” panel title and description.
- Keep storage-room / shelf dropdowns above the table.
- **Remove standalone `FilterChip` row** (Low stock only, Expiring soon, Expired batches).
- Move stock-status filters into the search bar filter UI using `AppSearchBarFilterGroup` (same pattern as `pharmacy_workspace_page.dart` queue filters):

| Filter choice | Maps to |
|---------------|---------|
| **All** (default) | No stock-status filter |
| Low stock only | `lowStockOnly` |
| Expiring soon | `expiringWithinDays` preset |
| Expired batches | `expiredOnly` |

- Wire `filterValue`, `hasActiveFilters`, and `onFilterChanged` to `PharmacyWorkspaceController` inventory filter methods.
- Enable `showAdvancedFilterButton` on the inventory search config.

### Adjust stock (`_InventoryAdjustDialog`)

- Ensure the form is complete: quantity delta, reorder level, reason, conditional purchase batch/expiry fields, and storage room/shelf when receiving stock.
- Footer icons on Cancel and **Adjust stock** submit.

### Functional checks

- Search, storage filters, stock-status filters, pagination, adjust, and clear/delete stock operations work and refresh the table.

---

## Tab 4 — Storage layout

### Layout

- Remove panel title and description when embedded in the catalog dialog (`showHeaderActions: false` already hides the header button—move **Add room** to a search-less toolbar or a compact top action row only if no search bar exists; prefer a single **Add room** `AppSearchBarAction` aligned with other tabs, or a minimal inline action above the room list).
- Room rows must show **name** and **code** (when set) clearly—e.g. title = name, subtitle = code.
- Shelf rows show **shelf code** and optional **label** (`displayLabel`).

### Room dialog (`_StorageRoomDialog`)

- Fields: Room name* (required), Room code (optional), Active toggle on edit.
- Icons on Cancel and Add/Save (already partially done—keep consistent).

### Shelf dialog (`_StorageShelfDialog`)

- Fields: Shelf code* (required), Label (optional), Active toggle on edit.
- Icons on Cancel and Add/Save.
- Shelf list items expose edit via tap; add shelf via room-level **+** action.

### Functional checks

- Create / edit / deactivate rooms and shelves; expansion lists refresh after save.
- Empty states for no rooms and no shelves per room.

---

## Backend parity

No new models required for this prompt. Verify existing endpoints used by `PharmacyWorkspaceController` support:

- Drug CRUD + catalog pricing fields
- Formulary CRUD
- Inventory search filters (`lowStockOnly`, `expiringWithinDays`, `expiredOnly`) and stock adjustment
- Storage room / shelf CRUD

Fix any serializer or validation gaps discovered while wiring the UI (e.g. edit drug reorder level, formulary drug display title).

---

## Localization

Add or reuse keys in `frontend/lib/l10n/app_en.arb` for:

- Inventory filter group label and choices (All, Low stock only, Expiring soon, Expired batches)
- Any new formulary drug-picker table column labels
- Storage layout labels if missing

---

## Acceptance criteria

- [ ] Drugs, Formulary, and Inventory tabs have no redundant inner title/description; Storage layout matches the same compact pattern.
- [ ] Add drug, Add formulary item, and Add room actions live in the search-bar action area (or equivalent compact affordance), not in a separate row above the table.
- [ ] Add drug and edit drug both save successfully; edit exposes identity, formulation, pricing, reorder level, and default storage location.
- [ ] Add formulary uses a selectable drug table; edit formulary toggles active status only.
- [ ] All formulary and drug dialog buttons include appropriate icons.
- [ ] Inventory stock-status filters live in the search-bar filter panel; **All** is the default; chips row is removed.
- [ ] Inventory adjust dialog is complete and persists changes.
- [ ] Storage rooms show name + code; shelves support add and edit with icon buttons on dialogs.
- [ ] No regressions to tab switching, permissions gating, or catalog dialog open/close behavior.
