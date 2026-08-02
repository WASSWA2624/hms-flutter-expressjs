# AppListTable: Default Cap of 100 + Viewport-Aware Progressive Rendering

**Objective:** Keep `AppListTable` as the single shared worklist surface, but stop full-list paints from freezing the UI. By default, load/hold up to **100** rows (all of them when the total is ≤ 100). Render only a **viewport-sized window** of rows (plus a small buffer), and expand that window incrementally on scroll so data arrival and row building stay invisible to the user. Apply this at the root component so every table benefits without per-feature rewrites.

## Context

No screenshots were attached; status is taken from the current codebase.

| Surface | Current behavior |
| --- | --- |
| Data source | Callers pass either `items` (full in-memory list) or `page` + `onPageChanged` (`AppPage` / `AppPageRequest`) |
| Default page size | `AppPageRequest.defaultPageSize = 20`; `AppPageRequest.maxPageSize = 100` (backend `MAX_PAGE_LIMIT`) |
| Pagination modes | `AppListTablePaginationMode.infinite` (default) appends pages near scroll end; `buttons` keeps previous/next |
| Initial loading | Full-body skeleton only when `isLoading && visibleItems.isEmpty` (`appListTableShowsInitialLoading`) |
| Load-more UX | “Loading more…” footer while appending; “All rows loaded” when infinite scroll is exhausted |
| Render capping | Optional `maxVisibleItems` + `_renderLimit` progressive reveal — **off by default** (`null`) |
| Desktop body | Material `DataTable` builds **every** `DataRow` eagerly for the current item list (plus empty spacer rows to fill height) |
| Mobile body | `ListView.separated` (better recycling), still fed the full capped/uncapped item list from state |
| Freeze root cause | Large in-memory lists (or a 100-row page) force one-frame construction of all `DataRow`s / cells; scroll-near-end also reveals in large batches when `maxVisibleItems` is set |

Raw intent: default load up to 100 entries (all if fewer exist); each table has a viewport of how many rows it can realistically show; keep updating/revealing rows inside that window so the user never notices loading; eliminate the frozen-screen feel; implement once on the shared `AppListTable` root.

## Requirements

1. **Preserve existing table chrome and APIs.** Do not redesign search, Settings, Export, column visibility/resize, sort, row numbers, go-to-top, empty/error builders, mobile item builders, or pagination mode enum. Keep `items` and `page`/`onPageChanged` contracts working. Feature call sites should keep working without mandatory rewrites; only change defaults and internal rendering unless a call site already opts into incompatible behavior.

2. **Default data window of 100.** Align the shared table’s default “how much data to hold/request for the first paint” with `AppPageRequest.maxPageSize` (**100**):
   - When total available rows ≤ 100, treat the dataset as fully loaded for that query/filter (load/show all).
   - When total > 100 (or unknown and page-sized), hold/request in chunks up to 100 for the initial window; use existing infinite scroll / `onPageChanged` to fetch further pages as the user approaches the end.
   - Do **not** raise API `limit` above `AppPageRequest.maxPageSize`. Prefer documenting/encouraging `pageSize: 100` (or `maxPageSize`) for paged tables rather than inventing a parallel page-size system inside the widget.
   - Callers that intentionally pass smaller `pageSize` (e.g. 12/20/25) must keep working; do not silently override their request size.

3. **Viewport-aware progressive rendering (default on).** Turn on progressive row reveal by default at the `AppListTable` root so large lists never mount every row in one frame:
   - Initial render count ≈ rows that fit the current table body height (from layout/`rowMinHeight`), plus a small buffer — not the full 100 unless the viewport needs that many.
   - As the user scrolls near the bottom of the **rendered** window, reveal the next batch (viewport-sized or a fixed small batch), scheduling updates so the main thread stays responsive (no multi-hundred-row single `setState` if avoidable).
   - Keep already-visible rows mounted; never blank the table during reveal or background refresh when rows already exist (preserve `appListTableShowsInitialLoading` semantics).
   - `maxVisibleItems`, if still exposed, should mean “reveal/batch size override” or remain an explicit opt-out/opt-in that does not regress current tests; default behavior must not require every feature to pass it.

4. **Invisible loading while rows already exist.** When appending pages or expanding the render window:
   - Prefer silent / low-chrome progress (existing compact “Loading more…” is acceptable at the true end of loaded data).
   - Do **not** replace the whole body with the skeleton, block the UI, or make the screen feel frozen.
   - Sort/filter/query changes may reset the render window to the viewport-sized initial batch, then expand again as needed.

5. **Apply once for all tables.** Implement in `frontend/lib/shared/components/app_list_table.dart` (and tightly related helpers/tests). Desktop `DataTable` path is the primary freeze target; mobile list path should respect the same render window so behavior stays consistent. Empty spacer-row padding (`padEmptyRows` / `_rowCountToFillHeight`) must remain correct for the **rendered** row count vs viewport height.

6. **Do not break pagination modes.** Infinite scroll continues to request `page.request.next()` near the end when `hasNextPage`. Button mode keeps previous/next. Accumulated infinite pages, row-number offsets, and “All rows loaded” stay intact.

## Constraints

- Scope is the shared `AppListTable` component (+ its unit tests). Do not mass-edit every feature workspace unless a default or API change forces a minimal call-site fix.
- Stay within backend `MAX_PAGE_LIMIT` / `AppPageRequest.maxPageSize` (100).
- No unrelated refactors (export, column memory, similarity, theming).
- Light + dark; compact and non-compact row metrics; bounded and shrink-wrapped layouts; nested ancestor scroll (existing `_reattachAncestorScrollListener`) must still trigger reveal/load-more.
- Preserve accessibility: keyboard row activation, go-to-top, scrollbars.

## Acceptance Criteria

- (R1) With ≤ 100 total rows available for the current query, the table ends in a fully loaded state (all rows reachable via progressive reveal/scroll) without requiring the user to page beyond 100.
- (R2) With > 100 rows (paged), initial hold/request stays within a 100-sized window / `maxPageSize`; further rows load via existing infinite (or button) pagination.
- (R3) Opening or updating a table with dozens/hundreds of in-memory items does **not** freeze the UI for a noticeable frame storm; first paint shows roughly a viewport of rows, then expands as the user scrolls.
- (R4) Background refresh / load-more with existing rows does **not** swap to the full-table skeleton; users keep interacting with visible rows.
- (R5) Existing chrome (search, sort, columns, export, row numbers, go-to-top, empty/error) behaves as before.
- (R6) Infinite and button pagination modes, accumulation, and row numbering still pass existing `app_list_table_test.dart` cases (update tests only where defaults intentionally change).
- (R7) Call sites that omit `maxVisibleItems` get the new progressive default; call sites that already set `maxVisibleItems` or custom `pageSize` keep sensible behavior.

## Verification

- Unit/widget tests in `frontend/test/shared/components/app_list_table_test.dart`:
  - Default progressive reveal: many `items` → only a viewport batch finds widgets initially; scroll near end reveals more.
  - Total ≤ 100 eventually fully revealable without an extra artificial hard stop below the dataset size.
  - `isLoading` with non-empty rows does not show initial skeleton.
  - Infinite scroll still requests `next()`; accumulation + row numbers unchanged.
  - Explicit `maxVisibleItems` / smaller page sizes still honored.
- Manual: any heavy workspace table (e.g. patients, pharmacy catalog, access admin) — open with a large list, confirm smooth first paint, scroll to load/reveal more, no freeze; light + dark; narrow mobile list mode.

## Relevant Files

- `frontend/lib/shared/components/app_list_table.dart` — primary implementation (`maxVisibleItems` / `_renderLimit`, scroll reveal, `DataTable` rows, infinite load-more)
- `frontend/lib/shared/data/app_pagination.dart` — `AppPageRequest.defaultPageSize` / `maxPageSize` (reference; change only if required for the default-100 story)
- `frontend/test/shared/components/app_list_table_test.dart` — extend coverage for default progressive rendering
- Call sites only if a breaking default forces a minimal fix (prefer fixing inside the shared widget)
