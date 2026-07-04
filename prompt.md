# Lab configuration & table toolbar improvements

## Objective

Improve the Lab **Configurations** dialog (tests/panels catalog table) and apply consistent, responsive toolbar labeling across all `AppListTable` search bars.

---

## 1. Responsive labels on table search toolbars (global)

**Problem:** In table toolbars (search bar + attached actions), buttons such as **Filters**, **Table settings**, and trailing actions (e.g. **Enable test/panel**) always render as icon-only, even on large screens where space is available.

**Requirement:** Apply the same breakpoint rule used by workspace toolbars (`AppBreakpoint.showsToolbarActionLabels` — labels visible at `lg` and above, icon-only below):

| Breakpoint | Behavior |
|---|---|
| `xs` / `sm` / `md` (< 840px) | Icon only (keep current compact layout) |
| `lg` / `xl` / `xxl` (≥ 840px) | Icon **and** text label visible |

**Scope:** Implement centrally in shared components so **every** table using `AppListTable` / `AppSearchBar` benefits automatically. Do not patch individual pages.

**Affected controls:**
- Advanced filter button (`_AttachedFilterButton`)
- Table settings / column visibility action (`AppListTable._searchActions`)
- Trailing search-bar actions (`_AttachedSearchBarActionButton`, e.g. Enable test/panel)

**Key files:**
- `frontend/lib/shared/components/app_search_bar.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/core/responsive/app_breakpoints.dart` (reuse `showsToolbarActionLabels`)

**Acceptance criteria:**
- On a wide viewport, Filters / Table settings / trailing actions show icon + label.
- On narrow viewports, they remain icon-only with tooltips unchanged.
- No layout overflow or clipping in the search bar row.
- Add/update widget tests for breakpoint behavior.

---

## 2. Lab configurations — tests table columns

**Requirement:** In the configured **Tests** tab, the default visible columns must include:

| Column | Source field | Notes |
|---|---|---|
| Test name | `LabCatalogItem.name` | Already shown |
| Test code | `LabCatalogItem.code` | Already shown |
| Category | `LabCatalogItem.category` | Show stored value as-is |
| Unit price | `LabCatalogItem.unitPrice` + `LabCatalogItem.currency` | Format with currency, not raw number |

**Unit price formatting:** Use `AppFormatters.currency` (with locale + `currency` from the item, falling back to app default currency) — same pattern as billing/subscriptions pages.

**Key file:** `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart` (`_defaultColumns` for `LabCatalogItem`).

**Acceptance criteria:**
- Default columns show name, code, category, and formatted unit price (e.g. `UGX 15,000` not `15000`).
- Sorting on the price column still works numerically.

---

## 3. Verify test price edit persists (global price)

**Context:** Editing a test’s unit price (e.g. “Free liter blue cap — mass by volume in serum”) updates the **global/platform price** and the change should reflect immediately in the configurations table.

**Requirement:** Confirm the existing edit-price flow works end-to-end. Fix any gap where the table does not refresh or display the updated formatted price after save.

**Key files:**
- `frontend/lib/shared/lab_catalog/lab_catalog_dialogs.dart` (edit/enable dialogs)
- `frontend/lib/features/lab/presentation/controllers/lab_workspace_controller.dart` (`updateLabTest`, `loadFacilityCatalogConfig`)

---

## 4. Fix: enabling a panel does not appear in the panels list

**Problem:** After **Enable panel** completes successfully, the newly enabled panel is not visible when switching to the **Panels** tab.

**Requirement:** Diagnose and fix so that:
1. Enabling a panel via `LabEnableFacilityOfferingDialog` adds/refreshes the item in `state.catalogPanels`.
2. The panels table shows the enabled panel without requiring a full page reload.

**Likely areas:**
- `LabWorkspaceController.updateLabPanel` — new offerings call `loadFacilityCatalogConfig` when not already in local state; verify reload returns panels and UI re-renders.
- Backend upsert/list endpoints for facility panel offerings (if frontend refresh is correct but API omits newly enabled panels).
- `_reloadCatalogIfReady()` in `lab_workspace_page.dart` after enable dialog closes.

**Acceptance criteria:**
- Enable a panel → snackbar confirms save → switch to Panels tab → panel appears in the list with correct name, code, category, and price.

---

## Out of scope

- Changing column visibility defaults for non-lab tables.
- Redesigning the Lab Configurations dialog layout beyond the items above.

## Test plan

1. Resize browser: at ≥ 840px width, confirm table toolbar buttons show labels; below 840px, icon-only.
2. Open Lab → Reference ranges / Configurations → Tests tab: verify four core columns and formatted prices.
3. Edit a test price, save, confirm updated formatted price in the table.
4. Enable a panel, confirm it appears on the Panels tab.
5. Run affected Flutter tests (`app_breakpoints_test`, any new search-bar/table tests, lab workspace tests if touched).
