# Pharmacy module — Catalog and stock toolbar placement

## Goal

Relocate the **Catalog and stock** entry point on the Pharmacy worklist so it lives in the shared search/toolbar row (with Filters, Settings, Export), not as the tab-strip primary action. Keep catalog open behavior and permissions unchanged. Ensure the search bar’s trailing actions have comfortable end padding on all breakpoints.

## Current behavior (as of screenshots / code)

Route: `/pharmacy` (sections via `?section=`).

| Area | Current state |
|------|----------------|
| Tabs | Ready, Partial (`in-progress`), Pending payment, Completed, All orders — each with summary counts |
| Catalog entry | Blue **Catalog and stock** pill is `AppTabStrip.primaryAction` on every allowed worklist tab (`_catalogPrimaryAction` in `pharmacy_workspace_page.dart`) |
| Search row | `AppListTable` search bar: query field → Filters → Settings → Export. No catalog action here |
| Permissions | Catalog browse gated by `canBrowsePharmacyCatalog(policy)`; write stays inside the catalog dialog |
| Tests | Permission and workspace tests assert `_toolbarPrimary('Catalog and stock')` and often `findsNothing` for `_toolbarAction('Catalog and stock')` |

Empty Ready / Partial / Pending payment tabs and populated Completed / All orders lists are unchanged by this task.

## Intended behavior

1. **Remove** Catalog and stock from `AppTabStrip.primaryAction` on the Pharmacy desk (all five sections). The tab strip should show only section tabs and counts — no primary toolbar button for catalog.
2. **Add** Catalog and stock as a search-bar trailing action on the Pharmacy worklist `AppListTable`, at the **extreme end** of the chrome row:
   - Order: Search field → Filters → Settings → Export → **Catalog and stock**
   - Same label (`pharmacyCatalogPanelTitle`), same icon (`Icons.inventory_2_outlined`), same handler (`openPharmacyCatalogDialog`).
   - Still gated by `canBrowsePharmacyCatalog`; when browse is denied, omit the action (same as today’s omitted primary).
3. **Padding / margin:** Ensure the last control in the search/toolbar row does not sit flush against the content edge. Prefer a shared fix in `AppListTable` / `AppSearchBar` (theme spacing) so Pharmacy and other modules benefit, rather than a one-off Pharmacy hack. Must look correct on compact, medium, and expanded layouts (including when action labels collapse to icon-only).
4. **Do not change:** tab filtering, order table columns/actions, catalog dialog internals, deep-link `section=inventory` / `section=stock` dialog open, or export/filter/settings behavior.

## Implementation notes

- Primary file: `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart`
  - Drop `primaryAction: … _catalogPrimaryAction …` from `AppTabStrip`.
  - Pass catalog as `AppSearchBarAction` via `AppListTableSearch.trailingActions` (same pattern as Lab/Radiology create actions). Confirm merge order in `AppListTable._searchActions` / `buildSearchBar` so caller trailing actions render **after** Settings and Export.
- Shared chrome (if end padding is missing): `app_search_bar.dart` and/or `app_list_table.dart` — add consistent end inset for the attached action cluster.
- Update Pharmacy widget/permission tests that look for `_toolbarPrimary('Catalog and stock')` to expect the search trailing action instead (`_toolbarAction` or equivalent finder). Keep browse-denied cases asserting the control is absent.

## Acceptance criteria

- [ ] No Catalog and stock button on the tab strip for any Pharmacy section.
- [ ] Catalog and stock appears in the search bar after Filters, Settings, and Export when catalog browse is allowed.
- [ ] Tapping it still opens the existing catalog/stock dialog.
- [ ] When browse is denied, the action is hidden.
- [ ] Trailing search actions have visible end margin/padding; no flush edge on phone, tablet, or desktop widths.
- [ ] Existing Pharmacy permission and workspace tests updated and passing for the new placement.
