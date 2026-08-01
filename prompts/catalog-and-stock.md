# Pharmacy Catalog & Stock: Promote to a First-Class Desk Tab with Nested Tables

**Objective:** Promote "Catalog and stock" from a search-bar button that opens a dialog (`PharmacyCatalogPanel` in `openPharmacyCatalogDialog`) into a first-class desk section rendered inline in the pharmacy workspace strip, with nested category tabs — Drugs, Formulary, Inventory, Storage layout, and Shelves — where each nested tab renders a comprehensive `AppListTable` carrying its own Filters, Settings, Export, and context-appropriate primary action. Preserve every existing catalog CRUD flow, filter, RBAC gate, dual pricing, brand/generic naming, and `?section=` deep link unless a requirement below changes it.

## Context

Today the workspace (`pharmacy_workspace_page.dart`) renders a single desk strip of `PharmacyDeskSection` tabs (order queues + stock alerts). "Catalog and stock" is **not** a tab: it is an `AppSearchBarAction` in the `trailingActions` of the queue panel (`_PharmacyQueuePanel`, ~L777–L786) and stock panel (`_PharmacyStockPanel`, ~L558–L566) search bars, both calling `openPharmacyCatalogDialog(context, ref)` (`pharmacy_catalog_dialog.dart`). That dialog hosts `PharmacyCatalogPanel` (`pharmacy_catalog_panel.dart`), which switches over `PharmacyCatalogTab {drugs, formulary, inventory, storage}` (`pharmacy_entities.dart` L136) via `PharmacyCatalogIconTabBar` (`pharmacy_catalog_tabs.dart`) and renders:

- **Drugs** (`_DrugCatalogTab`): `AppListTable<PharmacyDrug>`; toolbar `Add drug`; row actions `Edit drug` / `Delete drug`; advanced filters (`_drugCatalogFilterGroups`: storage location + stock status); bulk delete.
- **Formulary** (`_FormularyCatalogTab`): `AppListTable<PharmacyFormularyItem>`; toolbar `Add formulary item`; row actions `Edit formulary item` / `Delete formulary item`; active filter.
- **Inventory** (`_InventoryCatalogTab`): `AppListTable<PharmacyInventoryStock>`; **no add** toolbar; row actions `Adjust stock` / `Clear stock`; storage + stock-status filters.
- **Storage** (`PharmacyStoragePanel`, `compact: true`): rooms rendered as an `ExpansionTile` list (NOT a table), each with `Add shelf` / `Edit` / `Delete` room and nested shelf `Edit` / `Delete`; a header `Add room` button. Shelves live only inside room expansions — there is no standalone Shelves view.

The catalog sub-tabs read from `PharmacyWorkspaceState` (`drugs`, `formularyItems`, `inventoryWorkbench.stocks`, `storageLayout`) via `PharmacyWorkspaceController`. Catalog CRUD is gated by `pharmacyCatalogWriteRequirement`; browse by `pharmacyCatalogBrowseRequirement` (`pharmacy_access.dart`). Deep links `?section=inventory|stock` currently open the dialog on the Inventory tab (`pharmacy_workspace_page.dart` ~L113–L124).

The desk strip is `AppTabStrip` (standard variant). `AppTabStrip` also exposes `AppTabStripVariant.nested` (`app_tab_strip.dart` L13) — a lighter underline sub-tab strip intended for exactly this kind of category tab under a desk section. Section labels/counts/icons/tones/filters come from the static helpers `_sectionLabel`, `_sectionCount`, `_sectionIcon`, `_sectionCountTone`, `_filterForSection`, `_applySectionData`, and the `PharmacyDeskSection` list from `pharmacyAllowedSections(policy)` gated per-section by `pharmacySectionTabRequirement`.

## Requirements

1. **Add a `catalog` desk section.** Introduce a new `PharmacyDeskSection.catalog` value (placed after `allOrders`, before the stock-alert sections so it groups with orders/management chrome). Give it a label from a new l10n key (reuse the existing "Catalog and stock" string `pharmacyCatalogPanelTitle`, or a shorter `pharmacyDeskCatalogLabel` = "Catalog and stock"), an icon (`Icons.inventory_2_outlined`), and an `info` count tone. It renders inline — not a dialog. Add `catalog` to `_sectionToQueryValue`/`_sectionFromQuery` as `?section=catalog`, and keep the existing `?section=inventory|stock` deep links working (route them to the new `catalog` section on its Inventory nested tab instead of opening the dialog).

2. **Gate the catalog tab like catalog browse.** In `pharmacySectionTabRequirement`, map `catalog` to `pharmacyCatalogBrowseRequirement`; in `pharmacySectionWriteRequirement`, map it to `pharmacyCatalogWriteRequirement`. The tab appears in `pharmacyAllowedSections` only when browse is allowed; hide it entirely otherwise (never render a disabled "no access" tab). Mark `catalog` as neither an order section nor a stock-alert section — extend `isStockSection`/any order-vs-stock branching so the workspace routes it to a new inline catalog panel.

3. **Render nested category tabs inline.** When `catalog` is the active desk section, render a nested `AppTabStrip` (`AppTabStripVariant.nested`) with five sub-tabs in order: **Drugs**, **Formulary**, **Inventory**, **Storage layout**, **Shelves**. Reuse `PharmacyCatalogTab` — extend the enum to `{drugs, formulary, inventory, storageLayout, shelves}` (rename `storage → storageLayout` and add `shelves`), and update `pharmacyCatalogTabDescriptors`, `state.catalogTab`, `controller.setCatalogTab`, and `prepareCatalogTab` accordingly. Persist the selected nested tab in `PharmacyWorkspaceState.catalogTab` so it survives rebuilds. Reuse the existing `_DrugCatalogTab`, `_FormularyCatalogTab`, and `_InventoryCatalogTab` table bodies unchanged in behavior.

4. **Each nested tab is a complete table with its own toolbar.** Every nested tab renders an `AppListTable` (not the dialog) exposing that table's search, Advanced **Filters**, column **Settings**, and **Export** (mirroring the active nested tab's visible columns), plus the correct primary action wired into the table toolbar:
   - **Drugs** → primary action **Add** (opens `PharmacyDrugEditDialog`); row actions **Edit** / **Delete**; keep storage-location + stock-status filters and bulk delete.
   - **Formulary** → primary action **Add** (opens the formulary item dialog); row actions **Edit** / **Delete**; keep the active/inactive filter.
   - **Inventory** → **no primary add action** (stock enters via Adjust); row actions **Adjust** / **Clear**; keep storage-location + stock-status/expiry filters.
   - **Storage layout** → primary action **Add** (Add room); render rooms as a table (`AppListTable`) with columns Room name, Code, Shelves count, Status, and row actions **Edit** / **Delete** (plus an **Add shelf** affordance per room). Reuse `openPharmacyStorageRoomDialog` and the existing create/update/delete room controller methods.
   - **Shelves** → primary action **Add** (Add shelf; prompt for the parent room, reusing `_StorageShelfDialog`); render a flattened table across all rooms with columns Shelf code, Label, Room, Status, and row actions **Edit** / **Delete**. Reuse the existing shelf dialog and create/update/delete shelf controller methods.

5. **Generic action labels.** Use generic, context-free button labels — **Add**, **Edit**, **Delete** (and **Adjust** / **Clear** for inventory) — instead of entity-suffixed labels like "Add drug", "Edit formulary item", "Delete storage room". Keep entity-specific strings for dialog titles, confirmations, and tooltips/semantic labels (accessibility), but the visible table primary/row action text must be the generic verb. Introduce shared l10n keys (`commonAddActionLabel`/`commonEditActionLabel`/`commonDeleteActionLabel` or existing equivalents) where they do not already exist.

6. **Space the row actions.** Give row action buttons consistent horizontal spacing (theme token gap, e.g. `theme.spacing.xs`) inside `_catalogRowActions` and the storage/shelf trailing rows so Edit/Delete (and Adjust/Clear) do not sit flush against each other, and keep the action column right-aligned and non-clipping at every breakpoint.

7. **Retire the dialog entry points (keep the flow).** Remove the "Catalog and stock" `AppSearchBarAction` from the queue and stock panel search bars now that it is a desk tab, and update the "Map stock" affordance (`pharmacy_workspace_page.dart` ~L1497–L1502) to navigate to the `catalog` section's Inventory tab instead of opening the dialog. You may keep `PharmacyCatalogPanel`/`openPharmacyCatalogDialog` as a thin internal reuse if convenient, but the user-facing entry is the desk tab; do not leave two competing catalog entry points on the same chrome.

8. **Backend/frontend synchronization.** Ensure the nested tables load their datasets on tab activation via the existing controller fetches (`applyDrugSearch`, `applyFormularySearch`, `applyInventorySearch`, storage layout load) with no parallel data path, refetch after every mutation, and keep pagination, sorting, and filter round-trips consistent with the backend contracts already used by the dialog (`GET /pharmacy/inventory/stock`, drug/formulary/storage endpoints under `backend/src/modules/pharmacy-workspace/**` and `facility-pharmacy-catalog/**`). Verify request params emitted by the nested filters match the backend `where`-builders (e.g. `stock_status`, `low_stock_only`, `expired_only`, `expiring_within_days`, `storage_room`/`storage_shelf`, formulary `is_active`).

## Constraints

- Reuse existing entities, controller methods, endpoints, dialogs (`PharmacyDrugEditDialog`, formulary dialog, `_InventoryAdjustDialog`, `_StorageRoomDialog`, `_StorageShelfDialog`), and design-system widgets (`AppTabStrip`, `AppListTable`, `AppListTableSearch`, `AppTabToolbarPrimary`, `AppWorkspaceStatusBadge`); introduce no parallel data paths and no new backend endpoints.
- Backend RBAC/ABAC stays authoritative. The `catalog` tab and its nested primary/row actions gate on `pharmacyCatalogBrowseRequirement` (view) and `pharmacyCatalogWriteRequirement` (write). Hide unauthorized tabs and write actions; never render disabled "no access" controls.
- Preserve all current catalog CRUD semantics, bulk-delete, dual pricing (pharmacy vs facility columns), brand/generic naming (`displayTitle` + `genericSubtitle`), stock-status/expiry badges, and the order-queue and stock-alert tabs unchanged.
- Do not change dispensing, billing, MAR, or encounter behavior (`pharmacy-flow.mdc`).
- Use theme tokens (light + dark). Keep the desk strip and nested strip horizontally responsive on mobile, tablet, and desktop with no clipping or overflow; the nested tables must scroll/paginate within the section without breaking the page shell. Define permission, loading, empty, error, success, and validation states for every nested tab.

## Acceptance Criteria

- (R1, R2) A "Catalog and stock" tab appears in the desk strip for users with catalog browse, is reachable via `?section=catalog`, opens inline (no dialog), and is hidden for users without browse. `?section=inventory|stock` still lands on the catalog tab's Inventory view.
- (R3) Selecting the catalog tab shows nested tabs Drugs / Formulary / Inventory / Storage layout / Shelves; switching nested tabs preserves selection and loads the correct dataset.
- (R4) Each nested tab renders a complete table with working Filters, Settings, and Export, and the correct primary action: Add on Drugs, Formulary, Storage layout, and Shelves; none on Inventory. Storage layout and Shelves render as tables (not only expansions) with accurate row/action columns.
- (R5) All visible primary/row action buttons read generic verbs (Add / Edit / Delete, Adjust / Clear); dialog titles and confirmations keep their descriptive wording.
- (R6) Row actions are evenly spaced, right-aligned, and never clip or overflow at any viewport, in light and dark themes.
- (R7) The old "Catalog and stock" search-bar buttons no longer appear; Map stock routes to the catalog Inventory tab; there is exactly one catalog entry point.
- (R8) Every catalog mutation (drug/formulary/inventory/room/shelf create/update/delete/adjust) refetches and reflects immediately, and nested filter params match the backend contracts with no console/network errors.

## Verification

- Extend Dart tests: `pharmacy_workspace_page_test.dart` (new `catalog` section, nested tab rendering, deep-link routing, dialog buttons removed), `pharmacy_workbench_query_test.dart` / catalog filter tests (nested filter params), `pharmacy_access_test.dart` and per-tab permission tests (catalog tab gated by browse; write actions gated by catalog write), and the catalog/storage layout widget tests (Storage layout + Shelves tables, generic action labels, action spacing).
- Run `flutter analyze`, `flutter test`, and backend Jest (`pharmacy-workspace.service.test.js` and catalog/storage schema tests) to confirm no regressions.
- Manually verify: the catalog tab opens inline; all five nested tabs render complete tables with Filters/Settings/Export and correct add/edit/delete/adjust/clear actions; generic labels; even action spacing; light + dark themes; responsive with no overflow on mobile/tablet/desktop; unauthorized users see neither the tab nor write actions; and every mutation refetches.

## Relevant Files

- `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart` (`_sectionLabel`, `_sectionCount`, `_sectionIcon`, `_sectionCountTone`, `_filterForSection`, `_applySectionData`, `_sectionToQueryValue`, `_sectionFromQuery`, catalog/stock search-bar `trailingActions`, Map stock affordance, section content routing)
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_catalog_panel.dart` (`_DrugCatalogTab`, `_FormularyCatalogTab`, `_InventoryCatalogTab`, `_catalogToolbar`, `_catalogRowActions`, filter groups)
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_catalog_tabs.dart` (`pharmacyCatalogTabDescriptors`, `PharmacyCatalogIconTabBar` / nested strip)
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_storage_panel.dart` (rooms + shelves → Storage layout and Shelves tables, `_StorageRoomDialog`, `_StorageShelfDialog`)
- `frontend/lib/features/pharmacy/presentation/pharmacy_catalog_dialog.dart` (`openPharmacyCatalogDialog` — retire/repoint entry)
- `frontend/lib/features/pharmacy/domain/entities/pharmacy_entities.dart` (`PharmacyDeskSection`, `PharmacyDeskSectionX`, `PharmacyCatalogTab`)
- `frontend/lib/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart` (`setCatalogTab`, `prepareCatalogTab`, catalog fetch/mutation methods)
- `frontend/lib/features/pharmacy/presentation/pharmacy_access.dart` (`pharmacySectionTabRequirement`, `pharmacySectionWriteRequirement`, `pharmacyAllowedSections`)
- `frontend/lib/shared/components/app_tab_strip.dart` (`AppTabStripVariant.nested`)
- `frontend/lib/l10n/app_en.arb` (new `pharmacyDeskCatalogLabel`, Shelves nested-tab label, generic `common*ActionLabel` keys)
- `backend/src/modules/pharmacy-workspace/**`, `backend/src/modules/facility-pharmacy-catalog/**` (contract parity for nested filters/mutations)
