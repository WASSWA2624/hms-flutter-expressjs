# Fix: Enable Radiology Offering dialog — performance, responsiveness, and UX

## Goal

Make the **Enable radiology offering** dialog open quickly, stay responsive, and allow clinicians/admins to select platform catalog procedures without browser freezes. Remove redundant chrome.

## Problem (observed)

Opening the dialog from Radiology → Configurations shows a prolonged loading state (“Loading radiology catalog”), then Chrome reports **Page Unresponsive**. After waiting, a small subset of procedures may render, but row actions (**Select**) are unresponsive.

Likely causes (verify in code):

1. **Oversized initial fetch** — `searchPlatformRadiologyCatalogForOffering` calls `listRadiologyCatalogTests` without honoring the dialog `limit`; the repository hardcodes `limit: 7500`. Lab’s equivalent passes `limit` to the platform catalog query.
2. **Heavy client work** — merging thousands of platform rows with facility offerings, building filter choices, and rendering `AppListTable` with client-side `matcher` on the full result set blocks the UI isolate.
3. **Redundant dismiss control** — footer **Close** duplicates the dialog header **X**.

## Reference implementation

Mirror the Lab enable-offering pattern, which is fast and stable:

| Layer | Lab (working) | Radiology (broken) |
|-------|---------------|-------------------|
| Dialog | `frontend/lib/shared/lab_catalog/lab_catalog_dialogs.dart` → `LabEnableFacilityOfferingDialog` | `frontend/lib/shared/radiology_catalog/radiology_catalog_dialogs.dart` → `RadiologyEnableFacilityOfferingDialog` |
| Controller | `lab_workspace_controller.dart` → `searchPlatformLabCatalogForOffering` (passes `limit` to platform + offered fetches) | `radiology_workspace_controller.dart` → `searchPlatformRadiologyCatalogForOffering` |
| Repository | `listTests` / `listPanels` accept `limit` | `radiology_repository_impl.dart` → `listRadiologyCatalogTests` uses `limit: 7500` |

**Entry point:** `radiology_workspace_page.configurations.dart` → `_openEnableProcedureDialog`.

## Required changes

### 1. Efficient catalog loading (primary)

- **Respect `limit`** end-to-end: dialog (`_searchLimit = 100`) → controller → repository → API. Do not load the full platform catalog on open.
- **Server-side search**: debounced search (already 200 ms) must drive the backend query (`search` / `q` param), not client-filter thousands of rows. Initial open may load the first page only; empty search should not imply “fetch everything.”
- **Offering status merge** must stay correct but operate on the bounded result set only. Consider fetching offered IDs/codes separately (small payload) rather than re-querying large lists.
- Evaluate `searchFacilityRadiologyCatalog` (`GET …/facility-radiology-catalog/search`) or extend backend search if needed so platform + offering status can be resolved in one paginated call.

### 2. Responsive table

- Render only rows the user can act on (not-yet-offered procedures), or clearly disable offered rows without blocking interaction on selectable ones.
- Avoid synchronous work in `build` over large lists (filter choice derivation, repeated `.where` on every frame). Memoize or derive from the current page.
- Ensure `isLoading` clears so `onRowSelected` / **Select** handlers are active once data is shown.
- Keep `shrinkWrap: true` + `NeverScrollableScrollPhysics` only if row count stays bounded; otherwise use normal scroll/pagination consistent with `AppListTable` elsewhere.

### 3. Dialog UX cleanup

- **Remove the footer Close button**; header **X** (and backdrop policy via `showAppDialog`) is sufficient—match other single-purpose picker dialogs in the app.
- Preserve instructional body text, search bar, modality filter, and the price sub-dialog flow (`RadiologyEnableOfferingPriceDialog`).

## Implementation rules

- **Reuse shared components** — `AppDialog`, `AppListTable`, `AppSearchBar`, `AppWorkspaceStatePanel`; do not fork table/dialog primitives.
- **Follow Lab parity** for enable-offering data flow unless radiology backend constraints require a documented deviation.
- **Backend parity** — any search/limit/filter must be enforced server-side; do not client-filter paginated catalog results.
- **Localization** — adjust `app_en.arb` only if copy changes (e.g. empty-state hint to “search to find procedures”).
- **Scope** — this task is the enable-offering dialog and its catalog search path only; radiology worklist columns are out of scope.

## Acceptance criteria

- [ ] Dialog opens to interactive UI within a normal network round-trip (no “Page Unresponsive” on a typical catalog size).
- [ ] Initial load requests a bounded page (≤ 100 items), not the full platform catalog.
- [ ] Typing in search triggers debounced server search; results update without UI freeze.
- [ ] **Select** on an available procedure opens the price dialog; offered procedures are non-selectable or hidden.
- [ ] Footer **Close** button removed; header **X** still dismisses the dialog.
- [ ] Lab enable-offering patterns reused; no regression to facility offering upsert (`upsertRadiologyTestOffering`).
- [ ] Controller/repository tests updated if search/limit contract changes.
