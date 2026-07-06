# Feature: Polish Radiology facility catalog configurations

## Goal

Fix selection, scrolling, toolbar density, and destructive-action styling in the **Radiology configurations** dialog so facility admins can manage imaging offerings efficiently. Apply reusable improvements to shared table and dialog primitives where noted.

## Context (screenshots)

The **Radiology configurations** dialog (`RADIOLOGY CONFIGURATIONS`) lists facility imaging offerings with tenant/facility scope selectors, search, modality filters, row selection, and actions (edit price, remove). Supporting dialogs:

- **Edit facility offering** — unit price + currency; footer has Cancel + Save configuration.
- **Remove procedure from facility?** — confirmation with required deletion reason; footer has Cancel + Delete imaging test.

## Primary files

| Area | Path |
|------|------|
| Configurations dialog & table | `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.configurations.dart` |
| Edit / enable dialogs | `frontend/lib/shared/radiology_catalog/radiology_catalog_dialogs.dart` |
| Delete-reason dialog (shared) | `frontend/lib/shared/lab_catalog/lab_catalog_dialogs.dart` (`LabDeleteReasonDialog`) |
| Controller / data load | `frontend/lib/features/radiology/presentation/controllers/radiology_workspace_controller.dart` |
| Shared table | `frontend/lib/shared/components/app_list_table.dart` |
| Shared search bar | `frontend/lib/shared/components/app_search_bar.dart` |
| Toolbar overflow pattern | `frontend/lib/shared/layout/app_workspace_toolbar.dart`, `app_toolbar_overflow_resolver.dart` |

**Reference:** Lab facility catalog config in `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart` (similar `AppListTable` + `AppSearchBar` usage).

---

## 1. Fix header select-all checkbox

**Bug:** The column header checkbox selects all visible rows, but clicking again does not clear the selection.

**Location:** `_offeringSelectionColumn` / `_toggleAllOfferingSelections` in `radiology_workspace_page.configurations.dart`.

**Expected behavior:**

- Unchecked → select all visible rows.
- Checked (all selected) → clear selection for all visible rows.
- Indeterminate (some selected) → select all visible rows (standard tri-state pattern).

**Note:** Tristate `Checkbox` may pass `null` when transitioning from all-selected; handle that case explicitly instead of relying on `checked ?? false` alone.

---

## 2. Style delete actions as destructive

Apply **danger color** (`theme.statusColors.danger` or `colorScheme.error`) to delete affordances in this feature:

| Surface | Element |
|---------|---------|
| Configurations table — row actions | Delete icon button (`Icons.delete_outline`) |
| Configurations toolbar | Delete selected action icon |
| Remove procedure dialog | Submit button icon (`Icons.delete_outline`) |

Do **not** recolor non-delete actions (edit, enable, refresh, etc.). Match existing destructive styling elsewhere (e.g. `clinical_request_flow_dialogs.dart`).

---

## 3. Limit search-bar toolbar to three visible actions

**Problem:** The configurations search bar currently shows too many attached buttons (filters, delete selected, enable procedure, refresh, table settings).

**Requirement:** Show a **maximum of three** icon/action buttons inline on the search bar. Move additional actions into an **overflow menu** (⋮ or equivalent), using the same interaction model as workspace toolbars (`AppWorkspaceToolbar` overflow / `PopupMenuButton`).

**Suggested priority (inline, left to right after search + filters):**

1. **Enable procedure** (when permitted)
2. **Delete selected** (when rows are selected)
3. **Refresh**

**Overflow candidates:** Table settings, and any action that does not fit the inline cap. Filters remain as the existing attached filter control—not counted toward the three-action limit.

Implement overflow support in `AppSearchBar` (or a thin wrapper) so other screens can reuse it; do not hard-code radiology-only UI in the shared component.

---

## 4. Enable scroll-to-reveal for capped tables (`AppListTable`)

**Problem:** Tables with `maxVisibleItems` (e.g. `_maxVisibleItems = 140` in radiology configurations) truncate the list. Scrolling stops with no way to see remaining rows.

**Requirement (global `AppListTable` change):**

When `maxVisibleItems` is set and total items exceed the cap:

- Make the table body scrollable (remove `NeverScrollableScrollPhysics` where it blocks scrolling in dialog contexts, or add an internal scroll controller).
- As the user scrolls near the bottom, **expand the rendered window** (e.g. load the next batch of rows) until all in-memory items are shown.
- Preserve sort, selection, and column visibility across expansion.
- Show a subtle loading indicator only if a future `onLoadMore` callback is provided; for radiology configurations the full list is already client-side—windowing is sufficient.

**Radiology configurations:** After the shared fix, allow the configurations table to scroll inside the dialog and reveal offerings beyond the initial cap.

---

## 5. Remove redundant Cancel buttons from dialogs

The dialog header **close (X)** already dismisses without saving. Remove the footer **Cancel** button from:

| Dialog | File |
|--------|------|
| Edit facility offering | `RadiologyEditFacilityOfferingDialog` |
| Remove procedure from facility | `LabDeleteReasonDialog` when used from radiology configurations |

Keep the primary action only (Save configuration / Delete imaging test). Ensure `closeEnabled` still respects in-flight saves.

*Optional follow-up (out of scope unless trivial):* apply the same pattern to `RadiologyEditFacilityOfferingDialog`'s enable-flow sibling if it also has redundant Cancel.

---

## Implementation rules

- Reuse shared components; extend `AppListTable` / `AppSearchBar` rather than one-off radiology hacks.
- Match Lab/workspace spacing, typography, and overflow-menu behavior.
- Add or adjust l10n keys in `frontend/lib/l10n/app_en.arb` only for new overflow labels.
- No backend changes unless scroll expansion later wires to server pagination (not required for this task).
- **Scope:** Radiology configurations UX + shared table/search-bar primitives. Do not change the main radiology worklist (see `prompt1.md`).

---

## Acceptance criteria

- [ ] Header select-all checkbox selects all visible rows and clears selection on second click.
- [ ] Row delete, delete-selected toolbar action, and remove-dialog submit icon use danger styling.
- [ ] Configurations search bar shows ≤ 3 inline action buttons; remaining actions accessible via overflow menu.
- [ ] Scrolling the configurations table reveals rows beyond `maxVisibleItems` until all loaded items are visible.
- [ ] `AppListTable` scroll expansion works for any consumer using `maxVisibleItems`, not only radiology.
- [ ] Edit facility offering and remove procedure dialogs have no Cancel button; close (X) and primary action still work correctly.
- [ ] Existing flows (enable procedure, edit price, batch delete, refresh, table settings, filters) continue to work.
