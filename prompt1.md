# AppListTable — Uniform Table / List View

## Objective

Refine **`AppListTable`** so every module worklist shares one elegant, responsive data surface: **search toolbar → table (desktop) or compact list (mobile) → pagination**. The component must feel fast, scannable, and visually consistent across Patients, Lab, Emergency, OPD, and all other workspace modules.

**Smoke URL:** `127.0.0.1:5201` — verify on **Patients** (mobile ~463px + desktop), **Lab** (patient worklist), **Emergency** (empty + populated), and **OPD** (flows table).

---

## Problems observed (screenshots)

### 1. Duplicate titles and descriptions

Some screens show a worklist title/description **twice**: once on `AppWorkspace` / `AppWorkspaceDetailPanel` and again inside `AppListTable` via `title` / `description`. Others show only the search bar (correct). Patients and Lab put section copy on the parent panel; Clinical, OPD, Physiotherapy, Claims, Discharge, and Mortuary still pass `title` / `description` into `AppListTable`.

| Symptom | Likely cause |
|---------|----------------|
| "Patient lab worklist" then search bar, or "Emergency board" + description above search | `AppWorkspaceDetailPanel` **and** `AppListTable.title` / `description` both set |
| Inconsistent vertical rhythm between modules | Mixed ownership of section headers |

### 2. Table density and header legibility

Desktop tables feel loose: row padding is generous (`dataRowMinHeight` 40 / `dataRowMaxHeight` 64) while column headers use `labelMedium` and read small relative to cell content.

| Symptom | Likely cause |
|---------|----------------|
| Too much whitespace between rows | `_DesktopListTable` row height constants |
| Headers hard to scan | `headingTextStyle` / `_DataColumnHeader` typography |

### 3. Sort state is easy to miss

Sortable columns exist, but the active sort column and direction are not prominent enough. There is no default sort on first open.

| Symptom | Likely cause |
|---------|----------------|
| User cannot tell which column is sorted | Subtle `swap_vert` vs arrow styling only |
| Rows appear in arbitrary order until user clicks | `_sortColumnKey` starts `null` |

### 4. Search feels laggy or “reloads” the table

When typing in the search field, some pages set `isLoading: state.isRefreshing*` on `AppListTable`, which swaps the entire worklist for `_DefaultListTableLoading` even though client-side filtering is synchronous.

| Symptom | Likely cause |
|---------|----------------|
| Table disappears / skeleton while typing | `isLoading` tied to controller refresh, not initial load |
| Perceived lag between keystroke and filtered rows | Unnecessary loading overlay on in-memory filter |

### 5. Mobile list rows are too tall and noisy

On `xs` / `sm` breakpoints, `AppListTable` switches to `_MobileListTable` + per-module `mobileItemBuilder`. Patient mobile rows stack hospital, MRN, age/sex, phone, visit, status, alerts, and badges — most of which belong in the detail dialog.

| Symptom | Likely cause |
|---------|----------------|
| One patient fills most of the viewport | `AppListItemRow.details` lists every desktop column |
| Cards feel cluttered vs desktop table | No shared mobile density contract |

---

## Target UX

### A. Single shared component — toolbar only inside `AppListTable`

`AppListTable` (`frontend/lib/shared/components/app_list_table.dart`) is the **only** table/list primitive for module worklists ([`ui-workspace.mdc`](frontend/.cursor/ui-workspace.mdc) forbids hand-rolled tables).

**Layout contract:**

```
┌─────────────────────────────────────────────────────────────┐
│ AppWorkspace / AppWorkspaceDetailPanel                      │
│   title + description (section copy lives HERE only)        │
├─────────────────────────────────────────────────────────────┤
│ AppListTable                                                │
│   ┌─────────────────────────────────────────────────────┐   │
│   │ TOOLBAR: AppSearchBar                               │   │
│   │   • search input (global, all visible fields)       │   │
│   │   • filter → advanced-filter modal / filter sheet   │   │
│   │   • settings → column-visibility dialog             │   │
│   └─────────────────────────────────────────────────────┘   │
│   TABLE (md+)  or  COMPACT LIST (xs/sm)                     │
│   pagination footer                                         │
└─────────────────────────────────────────────────────────────┘
```

**Rules:**

- **Remove** `title` and `description` from every `AppListTable` call site. Section titles belong on `AppWorkspace` or `AppWorkspaceDetailPanel` only.
- Stop rendering `_ListTableTitle` in `AppListTable` (deprecate the props or ignore them with a debug assert in tests). Do not duplicate panel headers inside the table.
- Toolbar is **only** `AppSearchBar` (via `AppListTableSearch.buildSearchBar` + column settings action). No extra headings between toolbar and data.
- Default **five visible data columns** (plus `#` index) — already enforced by `_maxVisibleTableColumns` / `appListTableDefaultVisibleColumns`; keep this as the default, with settings dialog exposing the full `columnChoices` set.

**Golden references:**

| Pattern | File |
|---------|------|
| No duplicate table title; search toolbar only | `patient_registry_page.dart` → `_PatientList` |
| Title/description on parent panel, not table | `lab_workspace_page.dart` → `AppWorkspaceDetailPanel` + `AppListTable` |
| Column settings + advanced filter modal | `patient_registry_page.dart`, `lab_workspace_page.dart` |

**Migrate call sites** that still pass `title` / `description` into `AppListTable`:

`clinical_workspace_page.dart`, `opd_workspace_page.dart`, `physiotherapy_workspace_page.dart`, `claims_workspace_page.dart`, `discharge_workspace_page.dart`, `mortuary_workspace_page.dart`, `integrations_workspace_page.dart`, and any other grep hit for `AppListTable` + `title:`.

### B. Desktop table — tighter, more legible

Adjust `_DesktopListTable` only (centralized — no per-module table styling):

| Token | Current | Target direction |
|-------|---------|------------------|
| `headingRowHeight` | 52 / 56 | Slightly shorter; headers must not dominate |
| `dataRowMinHeight` / `dataRowMaxHeight` | 40–64 / 38–56 | Reduce vertical padding ~15–20%; rows should fit 2-line cells without excess air |
| Header typography | `labelMedium`, w800 | Bump to `titleSmall` or `labelLarge`; active sort column uses `colorScheme.primary` + underline or weight step |
| Cell typography | `bodyMedium`, w500 | Keep; ensure contrast with headers |

**Sorting:**

- On first build, default `_sortColumnKey` to the **first sortable data column** (skip `#`). If none sortable, leave unsorted.
- Click header: toggle ascending ↔ descending on same column; switch column resets to ascending.
- Active sort must be obvious: primary color label, directional arrow (`arrow_upward` / `arrow_downward`), `Semantics.selected`, and tooltip (`Sorted by …, ascending`).
- Sort applies to **filtered** items before pagination (existing `_sortedItems` path).

### C. Search — instant client filter, no false loading

| Behavior | Spec |
|----------|------|
| Client-side search | `AppListTable` already filters via `ValueListenableBuilder` on `search.controller` + `matcher`. Results must update on every keystroke with **no** debounce inside the shared component. |
| `isLoading` | Use **only** for initial page load or explicit server refresh (skeleton / `loadingBuilder`). **Never** set `isLoading` from search `onChanged` or while filtering in-memory data. |
| `AppListTableSearch.isLoading` | Reserve for remote/search-as-you-type API calls; do not wire to routine list refresh flags. |
| Global search | `matcher` must search across all user-meaningful fields (name, IDs, phone, status labels — not raw UUIDs). Multi-token AND matching stays (`_tableSearchTokens`). |
| Empty search results | Show module `emptyBuilder` or a dedicated “no matches” state — not a loading spinner. |
| Server-backed lists | Debounce **network** queries in the controller ([`ui-patterns.mdc`](frontend/.cursor/ui-patterns.mdc)); keep already-fetched rows visible while refetching (subtle toolbar indicator, not full-table replacement). |

**Audit:** grep `isLoading: state.isRefreshing` on `AppListTable` and split into `isLoading` (first load) vs inline refresh indicator.

### D. Mobile list — compact summary rows

On `AppListTableDisplayMode.adaptive`, `xs` / `sm` → `_MobileListTable`; `md+` → `_DesktopListTable` ([`app_breakpoints.dart`](frontend/lib/core/responsive/app_breakpoints.dart)).

**Mobile row contract** (enforce via shared helpers, not one-off layouts):

| Show on list row | Hide (detail dialog / drawer) |
|------------------|-------------------------------|
| Primary label (patient name, case title) | Secondary IDs beyond one display ref |
| One identifier line (MRN / order no.) | Full ID chains (`PAT… \| ENC… \| LAB…`) |
| Highest-priority status or alert chip | Visit history, billing, full alert breakdown |
| Optional: one contextual badge (e.g. OPD / Emergency) | Facility name when single-facility tenant |

**Implementation:**

- Prefer `AppListItemRow` / `AppListItemText` from `app_list_item_text.dart` with **at most 3 `details` widgets** (excluding title/subtitle).
- Trim `_PatientMobileRow`, lab mobile builders, OPD `_OpdMobileRow`, etc., to the contract; full data on `onRowSelected` → existing detail dialog.
- Reduce mobile vertical padding in `_NumberedMobileListItem` if rows still feel tall after content trim.
- Keep row tap target ≥ 48dp; chevron trailing affordance unchanged.

### E. Column settings and filters (unchanged behavior, uniform placement)

| Control | Behavior |
|---------|----------|
| **Filter** | `showAdvancedFilterButton` → module-specific filter modal (`AppDialog` / `AppSearchBar` filter sheet). Active state when `hasActiveFilters`. |
| **Settings** | Gear icon → `_ColumnVisibilityDialog` / `AppListTableColumnVisibilityController.settingsAction`. Default visible set = first five choosable columns. `alwaysVisible` columns cannot be hidden. |
| **Pagination** | `_AppPaginationControls` footer; disabled while client-side search narrows the current page (`disablePagination` path). |

---

## Scope & constraints

- **Shared component first** — all visual/density/sort/search behavior changes live in `app_list_table.dart` (+ small shared mobile helpers). Migrate call sites only to remove duplicate titles and slim `mobileItemBuilder`s.
- **No new table abstraction** — do not fork `DataTable` per module ([`ui-workspace.mdc`](frontend/.cursor/ui-workspace.mdc)).
- **No behavior regression** — pagination, selection, column persistence, filter payloads, and API queries unchanged.
- **Follow project rules:** `frontend/.cursor/components.mdc`, `design-system.mdc`, `ui-patterns.mdc`, `ui-feedback.mdc`, `localization_i18n.mdc`.
- **Localize** any new user-facing strings via `app_en.arb`; Emergency hard-coded strings are out of scope unless touched incidentally.
- **Theme tokens only** — no hard-coded colors or ad-hoc `TextStyle` in feature pages.

---

## Acceptance criteria

1. **Patients** (desktop): table shows search toolbar only (no inner “Patient registry” title); headers legible; default sort on first data column; active sort visually obvious.
2. **Patients** (mobile ~463px): each row shows name + one ID + one status/alert max; tap opens detail dialog with full fields.
3. **Lab** worklist: no duplicate panel/table titles; dense multi-line cells remain readable at reduced row height.
4. **Emergency** board: empty state unchanged; when populated, matches toolbar + table/list contract.
5. **Search typing** on Patients (client filter): rows filter instantly; table body **never** swaps to loading skeleton while typing.
6. Grep: **zero** `AppListTable` call sites pass non-null `title` or `description` (section copy on parent panel only).
7. `frontend/test/shared/components/app_list_table_test.dart` passes; add tests for default sort column, sort indicator state, and “search does not show loading overlay.”
8. Manual smoke on `127.0.0.1:5201` at **463px**, **768px**, and **1280px** widths for Patients + Lab.

---

## Out of scope (this pass)

- Replacing `DataTable` with a custom painted grid.
- Server-side search API redesign or new backend endpoints.
- `AppWorkspaceDetailDrawer` layout changes.
- Emergency module localization (unless required by compile after title removal).
- Pagination page-size preferences or user-saved column presets beyond current dialog.
- Non-worklist tables (report previews, admin pickers, inline forms).
