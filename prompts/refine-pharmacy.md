# Pharmacy Catalog & Stock: Search-Bar Actions, Room Rename, Brand/Generic, and Overflow Fixes

**Objective:** Refine the inline Catalog and stock desk section (`?section=catalog`) so every nested table drives Add / bulk-delete from the search-bar trailing cluster (after Filters → Settings → Export), rename Storage layout → Room, tighten the checkbox column, surface brand + generic naming comprehensively in Drugs (and Settings/Filters), and eliminate the Storage layout row-action overflow — without changing order-queue, stock-alert, dispensing, billing, or catalog CRUD semantics unless a requirement below says so.

## Context

The catalog desk section is already live (`PharmacyDeskSection.catalog` → `PharmacyCatalogPanel` inline). Nested tabs are `PharmacyCatalogTab {drugs, formulary, inventory, storageLayout, shelves}` via `PharmacyCatalogIconTabBar` / `pharmacyCatalogTabDescriptors` (`pharmacy_catalog_tabs.dart`). Labels: Drugs / Formulary / Inventory / **Storage layout** / Shelves (`pharmacyCatalogTabStorage` = "Storage layout").

Today each nested tab builds a separate `_catalogToolbar` row **above** the `AppListTable` (`pharmacy_catalog_panel.dart`):
- **Drugs / Formulary / Storage layout / Shelves:** primary **Add** (`AppTabToolbarPrimary`) when write-allowed and no selection; selection mode swaps to a left-aligned bulk-delete / clear action.
- **Inventory:** no Add; selection shows **Clear selected**.
- Search bars already expose Filters, Settings, Export via `AppListTable` (`_searchActions`: Settings → Export; caller `search.trailingActions` append after Export — see `app_list_table.dart` ~L2040–L2064 and `AppListTableSearch.merge`).

Screenshots of the current UI show:
- Add / Delete selected living **outside** the search bar (separate toolbar).
- Drugs drug-name cell using `displayTitle` + optional `genericSubtitle` (`PharmacyDrug.displayTitle` / `genericSubtitle` already prefer brand then generic — `pharmacy_entities.dart`); brand/generic fields exist on the model, serializer, and `PharmacyDrugEditDialog`, but Settings/Filters are not comprehensive enough to surface all product parameters.
- Storage layout row actions (**Add** shelf + **Edit** + **Delete**) overflow the action column (**RIGHT OVERFLOWED BY 46 PIXELS**).
- Checkbox / select column (`_selectionColumn`, `id: 'select'`) consumes more horizontal space than a compact checkbox needs.

Inventory correctly has **no** Add (stock enters via Adjust) — keep that.

## Requirements

1. **Rename Storage layout → Room.** Change the nested-tab label from "Storage layout" to "Room" (update `pharmacyCatalogTabStorage` or add `pharmacyCatalogTabRoom` = "Room"; keep the enum value `storageLayout` and any `?catalogTab=` / internal ids stable). Shelves stays "Shelves". Dialog titles, empty states, and a11y strings may keep "storage room" wording where they describe the entity; the **tab label** must read "Room".

2. **Move Add into the search-bar trailing cluster.** Remove the separate `_catalogToolbar` primary Add for Drugs, Formulary, Room (storageLayout), and Shelves. Pass Add as an `AppSearchBarAction` on `AppListTableSearch.trailingActions` so it renders **after** Filters → Settings → Export (existing merge order). Visible label stays generic **Add** (`commonAddActionLabel`); tooltip/semantic stay entity-specific (`pharmacyAddDrugAction`, formulary/room/shelf add strings). Gate on `pharmacyCatalogWriteRequirement`; hide entirely when not allowed. Inventory keeps **no** Add.

3. **Move bulk selection actions into the search-bar cluster.** When one or more rows are selected, show the bulk action (**Delete selected** on Drugs/Formulary; **Clear selected** on Inventory; equivalent bulk delete if Room/Shelves gain multi-select — if they do not already, do not invent bulk delete for Room/Shelves unless selection already exists) as a search-bar trailing / leading search-section action that is **clickable** and wired to the existing confirm + controller delete/clear flows. Prefer keeping Add hidden while a selection is active (same mutually-exclusive toolbar behavior as today). Remove the orphaned above-table `_catalogToolbar` row when both Add and selection actions live in the search chrome so there is no duplicate action strip.

4. **Compact the checkbox column.** Constrain `_selectionColumn` (`id: 'select'`) to a **minimum width** that fits only the checkbox (and header select-all), with no excess padding or stretch. Use `AppListTableColumn` width / flex knobs already supported by the design system (or the narrowest safe fixed width) so the select column does not steal space from Drug name / actions at desktop or overflow at tablet.

5. **Brand + generic on Drugs (display, Settings, Filters).** Ensure the Drugs table shows **brand name** as the primary title and **generic (scientific) name** as the subtitle (reuse `displayTitle` / `genericSubtitle`; keep legacy single-`name` fallback). Settings must expose toggleable columns for brand, generic, code, form, strength, pharmacy price, facility price, storage location, reorder level, and stock status (and any other product fields already on `PharmacyDrug` / stock rows). Advanced Filters must be comprehensive and cleanly grouped: storage room/shelf, stock status, and searchable brand/generic/code/form/strength (search already hits both names — keep that; extend filter groups if brand/generic-only filters are missing). Formulary / Inventory / Room / Shelves Settings and Filters stay context-complete for their own columns (no regression).

6. **Fix Storage layout (Room) row-action overflow.** Eliminate the **RIGHT OVERFLOWED BY ~46 PIXELS** on the Room table action column. Prefer: consistent `theme.spacing.xs` gaps; generic short labels (**Add** / **Edit** / **Delete**); and/or an overflow menu / icon-only tertiary buttons on narrow widths so Add-shelf + Edit + Delete never clip. Shelves and other catalog action columns must also stay non-clipping at mobile, tablet, and desktop.

7. **Preserve catalog CRUD and RBAC.** Keep existing dialogs (`PharmacyDrugEditDialog`, formulary dialog, `_InventoryAdjustDialog`, room/shelf dialogs), controller mutations, refetch-after-mutation, and gates (`pharmacyCatalogBrowseRequirement` / `pharmacyCatalogWriteRequirement`). Do not reintroduce the old search-bar "Catalog and stock" entry on order tabs. Do not change order-queue or stock-alert tab semantics.

## Constraints

- Reuse `AppListTable`, `AppListTableSearch.trailingActions`, `AppSearchBarAction`, `_catalogRowActions`, `_selectionColumn`, and existing controller/fetch paths; introduce no parallel data path and no new backend endpoints.
- `AppListTable` already appends caller `trailingActions` **after** Settings/Export — rely on that order for Add (and selection actions if placed there).
- Backend RBAC/ABAC stays authoritative; hide unauthorized Add / Delete / Clear; never render disabled "no access" chrome.
- Theme tokens (light + dark); responsive with no clipping or overflow; define loading, empty, error, success, validation, and selection states for every nested tab.
- Do not alter dispensing, billing, MAR, or encounter behavior (`pharmacy-flow.mdc`).

## Acceptance Criteria

- (R1) Nested tab reads **Room** (not "Storage layout"); Shelves unchanged; enum/deep-link internals stable.
- (R2) Drugs, Formulary, Room, and Shelves show **Add** in the search trailing cluster after Export; Inventory has no Add; the old above-table Add toolbar is gone.
- (R3) With rows selected, Delete selected / Clear selected appears in the search-bar section, is clickable, and runs the existing bulk flows; Add is not competing in the same strip while selection is active.
- (R4) The checkbox column is only as wide as the checkbox needs; tables no longer waste a wide select column.
- (R5) Drugs show brand + generic (with legacy fallback); Settings and Filters expose the full product/parameter set for Drugs; other nested tabs keep complete Settings/Filters for their columns.
- (R6) Room (and other catalog) action columns never overflow or show the Flutter overflow stripe at any supported viewport.
- (R7) Catalog CRUD, permissions, dual pricing, and desk routing behave as before aside from the UI refinements above.

## Verification

- Extend/adjust Dart tests: `pharmacy_workspace_page_test.dart`, catalog panel / dialog layout tests, and permission tests that asserted the old `_catalogToolbar` Add / tooltip affordances — assert Add and bulk-delete live on the search trailing cluster, Room label, compact select column, and no overflow on Room actions. Cover brand/generic display if not already asserted.
- Run `flutter analyze`, `flutter test` (pharmacy suite), and confirm no new backend Jest failures (no schema change expected).
- Manually verify each nested tab at desktop/tablet/mobile, light and dark: Add after Export; selection → Delete/Clear in search chrome; Room rename; brand/generic on Drugs; Settings/Filters completeness; zero action-column overflow.

## Relevant Files

- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_catalog_panel.dart` (`_DrugCatalogTab`, `_FormularyCatalogTab`, `_InventoryCatalogTab`, `_StorageLayoutCatalogTab`, `_ShelvesCatalogTab`, `_catalogToolbar`, `_catalogRowActions`, `_selectionColumn`, filter groups)
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_catalog_tabs.dart` (`pharmacyCatalogTabDescriptors`, Room label)
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_drug_edit_dialog.dart` (brand/generic fields — preserve)
- `frontend/lib/features/pharmacy/domain/entities/pharmacy_entities.dart` (`PharmacyDrug.displayTitle` / `genericSubtitle`, `PharmacyCatalogTab`)
- `frontend/lib/shared/components/app_list_table.dart` (`AppListTableSearch.trailingActions`, `_searchActions` merge order, column width)
- `frontend/lib/l10n/app_en.arb` (Room tab label; reuse `commonAddActionLabel` / bulk-delete strings)
- `frontend/test/features/pharmacy/presentation/pharmacy_workspace_page_test.dart` and catalog/permission tests
