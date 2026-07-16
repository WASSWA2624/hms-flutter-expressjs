# Standardize Housekeeping Screen (Tabs & Toolbar)

## Objective

Refactor the Housekeeping workspace (`/housekeeping`, `HousekeepingWorkspacePage`) so its chrome fully complies with `prompt.md`:
no dedicated screen title/header; `AppTabStrip` at the top; contextual toolbar immediately
beneath tabs; table-local actions limited to Filters and Settings; consistent naming.

## Compliance Checklist (from prompt.md)

- [ ] No dedicated screen title/header
- [ ] Shared `AppTabStrip` at top with consistent vertical padding
- [ ] Toolbar immediately under tabs via `primaryAction` / `secondaryActions`
- [ ] All former header / more-menu actions relocated into the contextual toolbar
- [ ] Toolbar actions change with the active tab
- [ ] Every screen retains at least one toolbar button overall
- [ ] Tables expose only Filters and Settings inside the table area
- [ ] Consistent button labels (l10n) across tabs

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every
step below precisely. Do not skip steps. Do not ask for clarification. Run tests and formatting
after implementation. Treat `prompt.md` as the normative layout contract.

**Scope boundary:** Restructure Housekeeping **screen chrome/layout only**. Do not rewrite
detail dialogs (`_HousekeepingDetailPanel`, `_DetailActions`), create/triage/assign forms,
repository APIs, DTOs, or realtime sync unless required to keep chrome wiring compiling.
Preserve permissions (`_HousekeepingCapabilities`), overview counts, pagination, filters,
deep links, and mutation dialogs.

**Do not invent new tab/table/search/filter chrome.** Reuse the shared components listed below.

**Audit note:** Housekeeping is **already largely compliant** with `prompt.md` (tabs +
contextual primary toolbar + table Filters/Settings + URL `?section=`). This prompt closes
the **remaining residual gaps** and hardens tests so the checklist is fully verifiable.
Do not regress the existing layout into a titled `AppWorkspace` header or a more-menu.

## Current State (from audit)

### Primary files

- Page: `frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart`
  - Public widget: `HousekeepingWorkspacePage` (`initialSection`, `initialSearch`)
  - Content: `_HousekeepingWorkspaceContent` / `_HousekeepingWorkspaceContentState`
  - Worklist body: `_HousekeepingWorklistPanel` → `AppListTable<HousekeepingWorkItem>`
  - Detail + create/assign/triage/report dialogs live in the same page file
- Controller: `frontend/lib/features/housekeeping/presentation/controllers/housekeeping_workspace_controller.dart`
  - Provider: `housekeepingWorkspaceControllerProvider`
  - Key methods: `refresh()`, `applyResource`, `applySearch`, `applyFilters`, `changePage`,
    `selectItem`, `createTask`, `createSchedule`, `createMaintenanceRequest`,
    `assignTask`, `startTask`, `completeTask`, `cancelTask`,
    `triageMaintenanceRequest`, `completeMaintenanceRequest`, `cancelMaintenanceRequest`
- Domain: `frontend/lib/features/housekeeping/domain/entities/housekeeping_entities.dart`
  - `HousekeepingSection` enum: `tasks`, `schedules`, `maintenance`
  - `HousekeepingSection.fromQueryValue` / `queryValue`
  - `HousekeepingResource`, `HousekeepingQueue`, `HousekeepingDatePreset`,
    `HousekeepingWorkspaceQuery`, `HousekeepingWorkItem`, overview/lookup types
- Repository: `frontend/lib/features/housekeeping/domain/repositories/housekeeping_repository.dart`
  + `frontend/lib/features/housekeeping/data/repositories/housekeeping_repository_impl.dart`
- Route: `AppRoutes.housekeeping` path `/housekeeping` in
  `frontend/lib/app/router/app_routes.dart`
  - Permissions: `operationsRead` / `operationsWrite`
  - Roles: `housekeepingWorkspaceRoles`
  - Module: `facilities-maintenance`
- Router builder: `frontend/lib/app/router/app_router.dart` passes
  `HousekeepingSection.fromQueryValue(state.uri.queryParameters['section'])` and
  `search` query into `HousekeepingWorkspacePage`
- Tests today:
  - `frontend/test/features/housekeeping/presentation/housekeeping_workspace_page_test.dart`
    (tabs, URL, deep link, primary tooltip swap, Filters dialog, search, detail, mobile)
  - `frontend/test/features/housekeeping/domain/housekeeping_entities_test.dart`

### Current widget tree (chrome)

1. `AsyncStateScaffold<HousekeepingWorkspaceState>` with
   `loadingTitle` / `loadingBody` and **`appBarTitle: l10n.housekeepingTitle`**
   (parameter is currently unused by `AppStateScaffold` body — still remove for Reception parity)
2. `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)` — **no** titled `AppWorkspace` header
3. `Column` → `AppTabStrip` → `SizedBox(height: theme.spacing.sm)` → optional
   `AppFailureStateView` → `_HousekeepingWorklistPanel`
4. **No** FAB / `PopupMenuButton` / overflow “more” menu on page chrome today
5. Detail/item actions stay inside dialogs (`_DetailActions` / `AppActionList`) — keep there

### Tabs (validated against code)

Enum: `HousekeepingSection` in `housekeeping_entities.dart`.
Tab ids in `AppTabStrip` use `section.name` (`tasks`, `schedules`, `maintenance`).

| # | Tab label (l10n → English) | Enum | Query `?section=` (`queryValue`) | Count source | Count tone |
|---|----------------------------|------|-----------------------------------|--------------|------------|
| 1 | `housekeepingResourceTasks` → **Tasks** | `tasks` | `tasks` | `overview.summaryValue('pending_tasks')` | warning |
| 2 | `housekeepingResourceSchedules` → **Schedules** | `schedules` | `schedules` | `overview.summaryValue('active_schedules')` | info |
| 3 | `housekeepingResourceMaintenanceRequests` → **Maintenance requests** | `maintenance` | `maintenance` | `overview.summaryValue('open_requests')` | warning |

Deep-link tab state **is already URL-backed** via `?section=…` and
`GoRouter.replace` in `_updateUrlForSection`. Keep this; do not invent a second query key.
Canonical write values must remain: `tasks` | `schedules` | `maintenance`.

Optional deep-link hardening (recommended, not blocking): accept aliases in
`HousekeepingSection.fromQueryValue` such as `maintenance-requests` /
`maintenance_requests` → `maintenance` (case-insensitive already works for canonical values).

Additional route behavior to **preserve**:
- `?search=` → `initialSearch` / search controller seed
- Tab change calls `controller.applyResource(section.resource)` and updates URL

### Current toolbar (mostly compliant)

`primaryAction` via `_primaryActionButton` (gated by `_HousekeepingCapabilities`, not
`AppAccessActionGate` — **keep** this domain capability model; do not invent a new access file):

| Tab | Current primary | Handler | Capability |
|-----|-----------------|---------|------------|
| Tasks | `housekeepingCreateTaskAction` (“Create task”), `Icons.add_task_outlined` | `_showTaskDialog` | `canManage` |
| Schedules | `housekeepingCreateScheduleAction` (“Create schedule”), `Icons.event_repeat_outlined` | `_showScheduleDialog` | `canManage` |
| Maintenance requests | `housekeepingRequestMaintenanceAction` (“Request maintenance”), `Icons.build_circle_outlined` | `_showMaintenanceRequestDialog` | `canUpdateTasks` |

`secondaryActions` today (same on every tab when `capabilities.canReport`):

- `AppReportActionButton.preview` with `housekeepingReportSummaryAction` (“Report”) →
  `_showReportPreviewDialog`

Gaps vs standardization polish:

1. Secondaries are **not** built via an explicit per-tab `_buildSecondaryActions` switch
   (Reception/HR/Claims style) — refactor for clarity even if Report remains on all tabs.
2. Report uses `AppReportActionButton` (button chrome) rather than flat
   `AppTabToolbarAction` used by HR under `AppTabStrip` — **normalize to
   `AppTabToolbarAction`** (or keep preview semantics but place a flat toolbar action that
   opens the same dialog).
3. No **Refresh** secondary (HR uses `AppWorkspaceRefreshAction` + `commonRefreshActionLabel`).
   Add Refresh on every tab so the screen never becomes actionless when write capabilities
   are denied (primary may be disabled; Refresh must remain enabled when not already refreshing).
4. `appBarTitle: l10n.housekeepingTitle` should be **removed** (Reception omits it;
   shell owns the route title).

### Current table chrome (mostly compliant)

In `_HousekeepingWorklistPanel` (`AppListTable<HousekeepingWorkItem>`):

- Settings: `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` — shared key
  (English today: **“Table settings”**). **Keep this shared key** for cross-workspace
  consistency with Reception/HR/Claims; do not invent a Housekeeping-only Settings control.
- Filters button: `advancedFilterButtonLabel: l10n.housekeepingFiltersAction` → English
  **“Filters”** ✅ already correct.
- Filters dialog title: `advancedFilterTitle: l10n.housekeepingFiltersTitle` → English
  **“Housekeeping filters”** ❌ — must become standardized **“Filters”** (match HR:
  same key for button + title).
- Search: keep `housekeepingSearchLabel` / `housekeepingSearchHint` / clear action.
- Filter groups / apply / reset / section-aware queue/status/facility/room/assignee/date:
  keep behavior; only fix the dialog **title** label.
- No stray create/report/refresh buttons in the table chrome today ✅.

### Detail-dialog actions (preserve — not screen chrome)

Keep inside detail dialogs / `_DetailActions` (do **not** promote to tab toolbar):
- Assign / Start / Complete / Cancel task
- Mark ready (backend-gap disabled)
- Triage / Complete request / Cancel request
- Readiness preview panel

### Concrete `prompt.md` gaps to close

1. Remove `appBarTitle: l10n.housekeepingTitle` from `AsyncStateScaffold` (no dedicated title chrome).
2. Align advanced filter **dialog title** to **Filters** (not “Housekeeping filters”).
3. Refactor toolbar secondaries into an explicit per-tab builder; convert Report to
   flat `AppTabToolbarAction`; add **Refresh** on every tab via
   `AppWorkspaceRefreshAction` / `commonRefreshActionLabel` →
   `housekeepingWorkspaceControllerProvider.notifier.refresh()`.
4. Guarantee ≥1 enabled toolbar affordance on every tab even when create/request
   primaries are disabled by capability (Refresh satisfies this).
5. Keep no FAB / more-menu; do not introduce `AppWorkspace(showHeader: true)`.
6. Keep table chrome limited to search + Filters + Settings.
7. Extend tests for Report/Refresh secondaries, Filters title, and no `appBarTitle` reliance.

## Reference Implementation

Read these files (do NOT modify them unless fixing shared bugs that block compliance):

- `prompt.md` (normative)
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
  — `ResponsivePage` + `AppTabStrip` + `SizedBox(height: theme.spacing.sm)` + table;
  no page title header; URL-backed `section` query; **no** `appBarTitle` on scaffold
- `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart`
  — **copy this pattern** for per-tab `primaryAction` + `secondaryActions` (Refresh via
  `AppWorkspaceRefreshAction`) and Filters button+title both labeled **Filters**
- `frontend/lib/shared/components/app_tab_strip.dart`
  — `AppTabStrip`, `AppTabItem`, `AppTabToolbarPrimary`, `AppTabToolbarAction`
- `frontend/lib/shared/layout/app_workspace.dart` — `AppWorkspace` / `showHeader` (default
  `false`); Housekeeping should continue **without** a titled workspace header
- `frontend/lib/shared/layout/app_workspace_toolbar.dart` — reference only
- `frontend/lib/shared/layout/responsive_page.dart`
- `frontend/lib/shared/components/app_list_table.dart` — `AppListTable`, `AppListTableSearch`, Settings
- `frontend/lib/shared/components/app_search_bar.dart` — Filters via `showAdvancedFilterButton` /
  `advancedFilterButtonLabel` / `filterGroups`
- `frontend/lib/shared/actions/app_workspace_refresh_action.dart` — `AppWorkspaceRefreshAction`
- `frontend/lib/core/responsive/app_breakpoints.dart` — breakpoint tokens

## Target Architecture

### Tab Configuration

| Tab Name | Route / Query | Description | Toolbar primary | Toolbar secondary |
|----------|---------------|-------------|-----------------|-------------------|
| Tasks | `/housekeeping?section=tasks` | Housekeeping task queue (default) | **Create task** — `AppTabToolbarPrimary` (`housekeepingCreateTaskAction`, `Icons.add_task_outlined`) → `_showTaskDialog`; enabled when `capabilities.canManage && !state.isSaving` | **Report** — `AppTabToolbarAction` (`housekeepingReportSummaryAction`, `Icons.assessment_outlined`) when `capabilities.canReport` → `_showReportPreviewDialog`; **Refresh** — `AppWorkspaceRefreshAction` (`commonRefreshActionLabel`) → `controller.refresh()` |
| Schedules | `/housekeeping?section=schedules` | Recurring cleaning schedules | **Create schedule** — `AppTabToolbarPrimary` (`housekeepingCreateScheduleAction`, `Icons.event_repeat_outlined`) → `_showScheduleDialog`; gated by `canManage` | Same: **Report** (if `canReport`) + **Refresh** |
| Maintenance requests | `/housekeeping?section=maintenance` | Open maintenance / facility requests | **Request maintenance** — `AppTabToolbarPrimary` (`housekeepingRequestMaintenanceAction`, `Icons.build_circle_outlined`) → `_showMaintenanceRequestDialog`; gated by `canUpdateTasks` | Same: **Report** (if `canReport`) + **Refresh** |

Notes:

- Use `AppTabToolbarPrimary` for the single right-aligned primary CTA and
  `AppTabToolbarAction` / `AppWorkspaceRefreshAction` for left-cluster secondaries
  (matches `AppTabStrip` contract).
- Rebuild toolbar on tab change (`setState` already updates `_section`).
- Disable mutation primaries when `state.isSaving` (already done).
- **Never** leave both `primaryAction == null` and empty `secondaryActions` on any tab.
  Refresh must always be present so the screen cannot become actionless.
- Do **not** put detail-scoped assign/start/complete/triage actions into the tab toolbar.
- Keep capability checks in `_capabilities` / `_HousekeepingCapabilities`
  (`operationsWrite` / housekeeping roles / `reportsRead`).

### Routing

- Keep `/housekeeping` registration in `app_router.dart` unchanged structurally.
- Keep query key **`section`** (written by `_updateUrlForSection` /
  parsed by `HousekeepingSection.fromQueryValue`).
- Canonical write values must remain: `tasks` | `schedules` | `maintenance`
- On tab tap: keep `setState` + `_updateUrlForSection(section)` +
  `controller.applyResource(section.resource)`.
- Preserve `?search=` seeding via `initialSearch`.
- When writing URL on tab change, today’s helper only writes `section` — **preserve that
  existing behavior** (do not expand URL sync scope in this chrome pass).
- Optional: harden `fromQueryValue` aliases (`maintenance-requests`, `maintenance_requests`)
  and cover in `housekeeping_entities_test.dart`.

### Page Layout

Precise widget tree for `_HousekeepingWorkspaceContentState.build`:

1. Keep `AsyncStateScaffold` + `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)`
   — **omit** `appBarTitle`; keep `loadingTitle` / `loadingBody` only for loading states.
   Do **not** add `AppWorkspace(showHeader: true)`.
2. `AppTabStrip(tabs:, selectedId: _section.name, onTabTapped:, primaryAction: <per-tab>, secondaryActions: <per-tab>)`.
3. `SizedBox(height: theme.spacing.sm)` (keep existing vertical rhythm matching Reception).
4. Optional `AppFailureStateView` when `state.lastFailure` is set.
5. Body: `_HousekeepingWorklistPanel` / `AppListTable` with **only** Filters + Settings
   (plus search) in the table chrome.
6. No FAB / floating header actions / overflow more-menu for screen actions.

### Data & State Management

- Reuse `housekeepingWorkspaceControllerProvider` / `HousekeepingWorkspaceController` —
  **no new providers**.
- Keep local `_section`, `_searchController`, `_tableColumnController`, URL updates.
- Keep section → resource mapping via `HousekeepingSection.resource`.
- Keep permission model: `_capabilities(AppAccessPolicy)` /
  `_HousekeepingCapabilities` (`canManage`, `canUpdateTasks`, `canReport`).
- Keep realtime refresh behavior in the controller unchanged.

## Implementation Steps

1. **Remove dedicated title wiring** — File:
   `frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart`
   - Delete `appBarTitle: l10n.housekeepingTitle` from `HousekeepingWorkspacePage`’s
     `AsyncStateScaffold`.
   - Do not introduce any other screen title/header widget.

2. **Make toolbar secondaries explicit + add Refresh** — same page file
   - Extract `_buildSecondaryActions(context, l10n, capabilities, state)` returning
     `List<Widget>` switching on `_section` (all three tabs share Report + Refresh today).
   - Replace `AppReportActionButton.preview` with `AppTabToolbarAction` labeled
     `l10n.housekeepingReportSummaryAction`, icon `Icons.assessment_outlined`, calling
     `_showReportPreviewDialog` when `capabilities.canReport`.
   - Add `AppWorkspaceRefreshAction` with `l10n.commonRefreshActionLabel` on every tab;
     call `ref.read(housekeepingWorkspaceControllerProvider.notifier).refresh()`;
     disable / show loading when `state.isRefreshing` if that flag is available on state
     (otherwise keep enabled and rely on existing refresh UX).
   - Wire `AppTabStrip(secondaryActions: _buildSecondaryActions(...))`.
   - Keep `_primaryActionButton` switch as-is (labels/handlers/capabilities).

3. **Fix Filters dialog title to “Filters”** — `_HousekeepingWorklistPanel`
   - Set both `advancedFilterButtonLabel` and `advancedFilterTitle` to
     `l10n.housekeepingFiltersAction` (English **Filters**).
   - Alternatively update arb `housekeepingFiltersTitle` English value to exactly
     `Filters` and keep using that key — either approach is fine; prefer using
     `housekeepingFiltersAction` for both to avoid duplicate keys.
   - Keep `columnVisibilityLabel: l10n.commonTableSettingsActionLabel`.
   - Keep search, filter groups, pagination, row → detail dialog behavior.
   - Do not add Create / Report / Refresh into table trailing actions.

4. **Optional query alias hardening** — File:
   `frontend/lib/features/housekeeping/domain/entities/housekeeping_entities.dart`
   - In `HousekeepingSection.fromQueryValue`, accept `maintenance-requests` /
     `maintenance_requests` → `maintenance`.
   - Do **not** change `queryValue` write values.
   - Update `housekeeping_entities_test.dart` accordingly.

5. **Update tests** — File:
   `frontend/test/features/housekeeping/presentation/housekeeping_workspace_page_test.dart`
   - Assert Report secondary is findable under `AppTabStrip` (tooltip/text **Report**) when
     write+report policy is used.
   - Assert Refresh secondary (`commonRefreshActionLabel` / tooltip **Refresh**) on each tab.
   - Assert primary still swaps: Create task / Create schedule / Request maintenance.
   - Assert Filters button remains **Filters**; if any test opens the dialog, expect title
     **Filters** (not “Housekeeping filters”).
   - Keep existing deep-link / URL / column / mobile tests green.
   - Do not assert a page `AppBar` titled “Housekeeping”.

6. **Format, analyze, run Housekeeping + shared tests** (see Verification Steps).

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` / `AppTabToolbarPrimary` / `AppTabToolbarAction` | `package:hosspi_hms/shared/components/app_tab_strip.dart` (via `shared/components/components.dart`) | Tabs + contextual toolbar under tabs |
| `AppListTable` / `AppListTableSearch` / column visibility | `package:hosspi_hms/shared/components/app_list_table.dart` | Worklist tables; Filters + Settings only in table chrome |
| `ResponsivePage` / `PageMaxWidth` | `package:hosspi_hms/shared/layout/responsive_page.dart` (via `shared/layout/layout.dart`) | Page shell without title header |
| `AppWorkspaceRefreshAction` | `package:hosspi_hms/shared/actions/app_workspace_refresh_action.dart` (via `shared/actions/actions.dart`) | Refresh secondary on every tab |
| `AsyncStateScaffold` | `package:hosspi_hms/shared/components/app_state_view.dart` (already used) | Loading / error / data shell — **no** `appBarTitle` |
| Breakpoints | `package:hosspi_hms/core/responsive/app_breakpoints.dart` | Follow existing ResponsivePage / mobile item builder behavior |

**Forbidden:** new custom tab bars, new header widgets, FAB for screen actions, PopupMenu /
“more” overflow for screen/header actions, duplicate Filters/Settings implementations,
promoting detail `_DetailActions` into the tab toolbar.

## Files to Create / Modify / Delete

### Modify

| File | Change |
|------|--------|
| `frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart` | Remove `appBarTitle`; contextual secondaries (Report as `AppTabToolbarAction` + Refresh); Filters title = Filters |
| `frontend/lib/features/housekeeping/domain/entities/housekeeping_entities.dart` | Optional `fromQueryValue` aliases for maintenance |
| `frontend/lib/l10n/app_en.arb` (+ generated/synced locale outputs per repo practice) | Only if you choose to change `housekeepingFiltersTitle` string instead of reusing `housekeepingFiltersAction` |
| `frontend/test/features/housekeeping/presentation/housekeeping_workspace_page_test.dart` | Assert Report/Refresh; Filters title; keep URL/tab tests |
| `frontend/test/features/housekeeping/domain/housekeeping_entities_test.dart` | Only if query aliases change |

### Do not delete

- Detail/mutation dialog private widgets in the page file
- Controller / repository / DTO layers
- `_HousekeepingCapabilities` / `_capabilities` helpers

### Create

- None required

## Cleanup: Remove Stale Code

- [ ] Remove `appBarTitle: l10n.housekeepingTitle` from `AsyncStateScaffold`
- [ ] Remove `AppReportActionButton.preview` usage from the tab strip if replaced by
      `AppTabToolbarAction` (keep `_showReportPreviewDialog`)
- [ ] Stop using `housekeepingFiltersTitle` (“Housekeeping filters”) as the advanced
      filter dialog title if the button/title both use `housekeepingFiltersAction`
- [ ] Do not leave unused imports (`app_report_actions` path) if no longer referenced
- [ ] Do not introduce a screen-level more-menu or titled `AppWorkspace` header
- [ ] Do not duplicate Create/Report/Refresh into the table chrome

## Database Migrations

No database migrations required — schema unchanged. This is a Flutter UI chrome refactor only.

## Responsive Design Requirements

- Desktop (≥1024px): full `AppTabStrip` + toolbar labels; `AppListTable` desktop columns
  via `_columnsForSection`.
- Tablet (600–1023px): horizontal scroll on tab chips (already in `AppTabStrip`); toolbar
  `Wrap` may wrap secondaries; keep Filters + Settings in table search chrome.
- Mobile (<600px): keep section `mobileItemBuilder` (`_taskMobileItem` /
  `_scheduleMobileItem` / `_maintenanceMobileItem` → `AppListItemRow`); toolbar actions
  remain visible; no separate mobile title header.
- Continue using `ResponsivePage` + `PageMaxWidth.dataHeavy`; do not add a titled app bar.

## Verification Steps

From `frontend/`:

```bash
dart format .
dart analyze --fatal-infos
flutter test test/features/housekeeping/
flutter test test/shared/
```

If l10n codegen is required after arb edits, run the project’s usual localization generation
command before analyze/tests.

## Testing Requirements

- [ ] Tab switch updates URL `section` and toolbar primary actions
- [ ] Deep link `/housekeeping?section=maintenance` (and `tasks` / `schedules`) opens correct tab
- [ ] Per-tab toolbar primary: Create task / Create schedule / Request maintenance
- [ ] Secondaries include Report (when permitted) + Refresh on every tab
- [ ] Table chrome has only Filters and Settings (plus search) — no Create/Report/Refresh in table trailing
- [ ] Filters button and dialog title are exactly **Filters**
- [ ] No screen title/header chrome remains (`appBarTitle` removed; no `AppWorkspace` title)
- [ ] At least one toolbar button exists on every tab (Refresh guarantees this)
- [ ] Permissions still gate write/report actions via `_HousekeepingCapabilities`
- [ ] Detail dialog actions still work and remain outside the tab toolbar
- [ ] Responsive layouts still work (desktop table + mobile `AppListItemRow`)
- [ ] Existing Housekeeping widget/entity tests updated and passing

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md`
- [ ] Uses `AppTabStrip` with contextual toolbar under tabs (`primaryAction` / `secondaryActions`)
- [ ] No dedicated header; no stray actions; no header more-menu
- [ ] Domain logic preserved (filters, deep links, dialogs, permissions, realtime refresh)
- [ ] Analyze clean; tests pass; stale title/report-button chrome cleaned up
