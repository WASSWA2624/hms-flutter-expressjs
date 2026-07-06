# Feature: Pharmacy catalog dialog — tab UX, table actions, and maximized dialog

## Goal

Improve the **Catalog and stock** dialog (`openPharmacyCatalogDialog`) so tab switching is clearer and faster, primary actions and tables are tab-aware, rows support edit/delete with bulk selection, and maximized dialogs use the full workspace below the app header.

## Current state (problem)

| Gap | Detail |
|-----|--------|
| **Tab control** | `PharmacyCatalogPanel` uses a filled `SegmentedButton` for Drugs / Formulary / Inventory / Storage layout |
| **Contextual actions** | Each tab embeds its own add button inside `AppWorkspaceDetailPanel`; there is no unified, tab-driven primary action |
| **Formulary table** | Shows Drug + Active only — no edit, delete, or row selection (see screenshot) |
| **Drugs table** | Has per-row edit/delete but no multi-select or bulk delete |
| **Inventory table** | Adjust-stock action only; no edit/delete or bulk operations |
| **Tab data refresh** | `setCatalogTab` lazy-loads empty lists but does not always re-fetch; switching can feel stale |
| **Maximized dialog** | `AppDialog` + `AppDialogInsets` leave visible margins (6–16 px) on left, right, and bottom when maximized |

## Reference implementation

| Pattern | Where |
|---------|--------|
| Checkbox column + header tri-state + bulk delete toolbar action | `radiology_workspace_page.configurations.dart` (`_offeringSelectionColumn`, `AppSearchBarAction` with `destructive: true`) |
| Per-row edit/delete icon buttons | `_DrugCatalogTab` in `pharmacy_catalog_panel.dart` |
| Tab-scoped controller refresh | `PharmacyWorkspaceController.setCatalogTab` / `_refreshCatalogTabData` |
| Dialog shell | `app_dialog.dart`, `app_dialog_insets.dart`, `showAppDialog` |

## UI scope

### 1 — Replace segmented tabs with icon radio tabs

In `PharmacyCatalogPanel`, replace `SegmentedButton<PharmacyCatalogTab>` with a **flat, background-free** tab row:

| Tab | Icon (suggested) | Label |
|-----|------------------|-------|
| Drugs | `Icons.medication_outlined` | Existing l10n `pharmacyCatalogTabDrugs` |
| Formulary | `Icons.list_alt_outlined` | `pharmacyCatalogTabFormulary` |
| Inventory | `Icons.inventory_2_outlined` | `pharmacyCatalogTabInventory` |
| Storage layout | `Icons.warehouse_outlined` | `pharmacyCatalogTabStorage` |

**Visual rules:**

- No filled segment background; selected state = primary color + bottom border (and optional check/icon accent, matching screenshot).
- Icons always visible; labels visible from `md` breakpoint up (icon-only on compact widths with tooltip).
- Single selection only (radio behavior).
- Reuse existing theme tokens (`colorScheme.primary`, `outlineVariant`) — do not introduce a one-off style.

Extract to a small shared widget (e.g. `AppIconTabBar<T>`) only if another module can reuse it; otherwise keep local to pharmacy.

### 2 — Tab-aware primary action

Hoist the panel **Add** action to one place (dialog header area or top of `PharmacyCatalogPanel`) that updates with the active tab:

| Tab | Button label | Opens |
|-----|--------------|-------|
| Drugs | `pharmacyAddDrugAction` | `PharmacyDrugEditDialog` |
| Formulary | `pharmacyAddFormularyAction` | `_FormularyCreateDialog` |
| Inventory | *(none or “Receive stock” if a flow exists)* | Keep absent unless an add/receive dialog already exists |
| Storage layout | `pharmacyAddStorageRoomAction` | `_StorageRoomDialog` |

Remove duplicate add buttons from individual tab panels once the shared action is in place. Gate with existing `_writeRequirement` / `AppAccessActionGate`.

### 3 — Tab-aware tables with instant switch

On tab change:

- Swap table columns, search, filters, and empty states immediately (no blank flash).
- Trigger fetch via `setCatalogTab` for the active dataset (formulary, inventory, storage; drugs if stale).
- Prefer showing cached rows while refreshing (`isLoading` overlay on `AppListTable`, not a full-panel spinner).
- Preserve each tab’s search/filter state in `PharmacyWorkspaceState` (already partially done).

### 4 — Row actions + bulk delete (all catalog tables)

Apply consistently to **Drugs**, **Formulary**, and **Inventory** tables (Storage layout keeps its room/shelf CRUD pattern).

**Selection column (leftmost):**

- Per-row `Checkbox` + header tri-state checkbox (mirror radiology `_offeringSelectionColumn`).
- Selection is per-tab local state; clear selection when switching tabs or after successful delete.

**Actions column (rightmost):**

- **Edit** — icon-only `Icons.edit_outlined`; opens the existing edit dialog for that entity.
- **Delete** — icon-only `Icons.delete_outline`, styled with `colorScheme.error` (destructive).

**Bulk delete:**

- When ≥1 row selected, show a destructive toolbar/search-bar action (red delete icon + count label).
- Confirm via `AppDialog` before deleting.
- Delete selected IDs sequentially or add a bulk API if one exists; show snackbar on success/failure.
- Wire **formulary delete** through repository → controller (backend route exists: `DELETE /formulary-items/:id`).

| Tab | Edit | Delete | Bulk delete |
|-----|------|--------|-------------|
| Drugs | `PharmacyDrugEditDialog` | `deleteDrug` (exists) | New — loop or bulk endpoint |
| Formulary | Edit active flag / drug mapping dialog | `deleteFormularyItem` (wire frontend) | New |
| Inventory | `_InventoryAdjustDialog` or dedicated edit | Only if backend supports stock removal | Optional — adjust if no hard delete |

Formulary edit can reuse create dialog pre-filled, or a minimal inline toggle for `isActive` if full edit is out of scope — pick one and document in PR.

### 5 — Global maximized dialog layout

Update **`AppDialog`** / **`AppDialogInsets`** globally (all dialogs benefit):

- When maximized, inset padding should account for **app shell header only** — dialog fills remaining viewport width and height.
- Set maximized insets to **0** (or minimal safe-area only on mobile), not `dialogMaximizedInsetDesktop` (16 px).
- Keep normal (non-maximized) insets unchanged.
- Verify on pharmacy catalog dialog (`maxWidth: 1080`, `initialMaximized: true`) and at least one smaller confirm dialog so restore/size behavior is unchanged.

## Backend parity

| Item | Action |
|------|--------|
| Formulary delete | Add `deleteFormularyItem(String id)` to `PharmacyRepository` + impl + controller |
| Formulary update | Already exists — use for edit flow |
| Drug delete | Already wired |
| Bulk delete | Client-side loop acceptable initially; add batch endpoint only if performance requires it |

## Implementation rules

- **Reuse** `AppListTable`, `AppSearchBarAction`, `AppButton`, `AppAccessActionGate`, and radiology selection patterns — do not fork table behavior.
- **Localization:** new strings in `app_en.arb` (bulk delete label, confirm titles, tab tooltips if icon-only).
- **Permissions:** respect `pharmacyWrite` / `operationsWrite`; disable selection and destructive actions when denied.
- **Scope:** pharmacy catalog dialog + global dialog maximize fix. Do not refactor unrelated workspaces.

## Acceptance criteria

- [ ] Catalog tabs render as flat icon+label radio controls with no segment background; selected tab is visually distinct.
- [ ] Primary add action label and handler change correctly for Drugs, Formulary, and Storage layout tabs.
- [ ] Switching tabs updates title, description, table columns, and data immediately; stale tabs refresh in background.
- [ ] Drugs, Formulary, and Inventory tables have checkbox selection, row edit/delete, and bulk delete with red destructive styling.
- [ ] Formulary delete works end-to-end (API + UI + list refresh).
- [ ] Maximized `AppDialog` occupies full space below the app header with no leftover side/bottom gutter on desktop.
- [ ] Non-maximized dialogs and mobile layout behave as before.
