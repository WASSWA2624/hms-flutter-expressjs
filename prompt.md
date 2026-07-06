# Feature: Pharmacy Catalog & Stock — filter consolidation and table UX

## Goal

Refine the **Catalog and stock** panel (`/pharmacy`) so Drugs, Formulary, and Inventory tabs share a consistent toolbar pattern: one search bar with an integrated **Filter** dialog, clearer row actions, and better formulary readability. Reclaim vertical space currently consumed by standalone Storage room / Shelf dropdowns.

**Out of scope:** **Storage layout** tab — leave as-is.

## Primary file

`frontend/lib/features/pharmacy/presentation/widgets/pharmacy_catalog_panel.dart`

Reuse the existing advanced-filter pattern already used on the **Inventory** tab (`showAdvancedFilterButton`, `AppSearchBarFilterGroup`, `AppSearchBarFilterValue`) and shared components in `app_search_bar.dart` / `app_list_table.dart`.

---

## 1 — Drugs tab

### Problem

Storage room and Shelf filters render as a separate row above the search bar, wasting space and splitting filtering across two UI areas.

### Required changes

1. **Remove** the standalone `_StorageLocationFilters` row above the table.
2. **Add** an advanced filter button to the search bar (same affordance as Inventory’s “Queue filter”).
3. **Consolidate** into one filter dialog:
   - **Storage room** — choices from `state.storageLayout` (active rooms only; include “All locations”).
   - **Shelf** — choices scoped to the selected room; disabled/cleared when no room is selected.
   - **Stock status** — reuse existing drug stock-status values already supported by `PharmacyDrugQuery.stockStatus` (if exposed server-side).
4. Wire selections to existing controller methods (`applyDrugStorageFilter`, stock-status query updates) via `AppSearchBarFilterValue`.
5. Show an active-filter indicator on the filter button when room, shelf, or stock status is set.

### Row actions

Replace icon-only Edit / Delete buttons with **labeled** buttons (icon + text), e.g. “Edit” and “Delete”, using existing l10n keys (`pharmacyEditDrugAction`, `pharmacyDeleteDrugAction`). Update `_catalogRowActions` or its call sites — set `iconOnly: false` on `AppButton`.

---

## 2 — Formulary tab

### Problem

- No advanced filter; only free-text search.
- **Drug** column shows formulary IDs (`FRM-…`) instead of the linked drug’s human-readable name (see screenshot).

### Required changes

1. **Add** advanced filter to the search bar with at least:
   - **Active status** — All / Yes / No (maps to `PharmacyFormularyQuery.isActive`).
2. **Fix drug name display:**
   - Ensure the table shows the linked drug’s display name (e.g. *Acyclovir | 400 mg | Tablet*), not the formulary `display_id`.
   - If the list API omits nested `drug` data, extend the backend formulary list response (include `drug.name`, `strength`, `form`, `code`) and confirm `PharmacyFormularyItemDto` maps it to `drugDisplayName`.
   - Prefer a dedicated **Drug name** column; keep formulary ID optional or in a secondary column if needed for support staff.
3. **Labeled row actions** — same pattern as Drugs (“Edit”, “Delete”).

---

## 3 — Inventory tab

### Problem

Storage room / Shelf sit above the search bar while stock-status filters live inside the Queue filter dialog. The **Facility** column is redundant in a facility-scoped pharmacy workspace.

### Required changes

1. **Remove** the standalone `_StorageLocationFilters` row.
2. **Extend** the existing Queue filter dialog to include:
   - **Storage room** and **Shelf** (cascading, same rules as Drugs).
   - Existing **Stock status** choices (low stock, expiring soon, expired) — keep current behavior.
3. Wire room/shelf to `PharmacyInventoryStockQuery` via `applyInventoryStorageFilter`.
4. **Remove** the **Facility** column from the inventory table (`pharmacyInventoryFacilityColumnLabel`).
5. **Labeled row actions** — show “Adjust” (or existing edit label) and “Delete” with visible text, not icons alone.

---

## 4 — Storage layout tab

**No changes.** Current room list, “+ Add room”, shelf expansion, and inline actions are acceptable.

---

## Implementation rules

- **Do not** introduce a second filter UI pattern — one search bar + one filter dialog per tab.
- **Cascade** shelf options when room changes; clearing room clears shelf.
- Hide room/shelf filter groups when `storageLayout.rooms` is empty (location filters remain optional).
- Preserve existing permissions (`AppAccessActionGate`), pagination, bulk selection, and column-settings behavior.
- Add or reuse l10n keys in `frontend/lib/l10n/app_en.arb` for any new filter group labels.
- Keep backend query params aligned (`storage_room_id`, `storage_shelf_id`, `is_active`, stock-status flags).

---

## Acceptance criteria

- [ ] **Drugs:** No standalone storage filter row; room, shelf, and stock status filter from the search-bar filter dialog.
- [ ] **Formulary:** Filter dialog includes active status; table shows readable **drug name** for each row.
- [ ] **Inventory:** Room and shelf live inside Queue filter with stock status; **Facility** column removed.
- [ ] **Drugs, Formulary, Inventory:** Edit and Delete (or Adjust/Delete on inventory) buttons show visible text labels.
- [ ] **Storage layout:** Unchanged.
- [ ] Active filter state is visually indicated; Apply / Clear reset filters correctly.
- [ ] No regression to search, pagination, add/edit/delete flows, or storage-layout CRUD.
