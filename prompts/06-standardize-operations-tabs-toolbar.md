# Standardize Operations Screen (Tabs & Toolbar)

## Objective

Refactor the Operations workspace (`/operations`, `OperationsWorkspacePage`) so its chrome fully complies with `prompt.md`:
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

**Do not invent new tab/table/search/filter chrome.** Reuse the shared components listed below.
**Preserve all Operations domain logic** (work-item queue filters by status, assets panel,
create/assign/status/service-log/note dialogs, report dialogs, permissions, counts, realtime
refresh via `operationsWorkspaceControllerProvider`, deep-link `section` / `search` / `requestId`).
This refactor is layout/chrome only.

## Current State (from audit)

### Primary files

- Page: `frontend/lib/features/operations/presentation/pages/operations_workspace_page.dart`
  - Public widget: `OperationsWorkspacePage` (`initialQuery: OperationsWorkspaceQuery`)
  - Content: `_OperationsWorkspaceContent` / `_OperationsWorkspaceContentState`
  - Queue body: `_OperationsQueuePanel` → `AppListTable<OperationsWorkItem>`
  - Assets body: `_OperationsAssetsPanel` → `AppListTable<OperationsAsset>`
  - Detail dialog: `_openRequestDetailDialog` → `_OperationsDetailPanel` / `_OperationsDetailBody`
    / `_OperationsActionPanel` (row/detail scoped — **keep out of screen tab toolbar**)
  - Dialogs in the same page file: create request, assign, status update, service log, notes,
    operations report, request report
- Controller: `frontend/lib/features/operations/presentation/controllers/operations_workspace_controller.dart`
  - Provider: `operationsWorkspaceControllerProvider`
  - Key methods: `refresh()`, `applySearch(String)`, `applyStatus(String)`, `clearFilters()`,
    `applyFilters(...)`, `changePage(...)`, `selectItem(...)`, `createRequest(...)`,
    `assignSelected(...)`, `updateSelectedStatus(...)`, `addServiceLog(...)`,
    `appendSelectedNote(...)`
- Domain: `frontend/lib/features/operations/domain/entities/operations_entities.dart`
  - Tabs: `OperationsDeskSection` — `allRequests`, `open`, `inProgress`, `completed`, `assets`
  - Deep link: `OperationsWorkspaceQuery.fromUri` parses:
    - `section` | `panel` | `tab`
    - `search` | `q`
    - `requestId` | `request_id` | `id`
  - Status constants: `operationsMaintenanceStatuses`
  - Priority / category lists: `operationsRequestPriorities`, `operationsRequestCategories`
- Repository: `frontend/lib/features/operations/data/repositories/operations_repository_impl.dart`
  (`operationsRepositoryProvider`)
- Routes: `AppRoutes.operations` path `/operations` in `frontend/lib/app/router/app_routes.dart`
  - Builder in `frontend/lib/app/router/app_router.dart` passes
    `OperationsWorkspaceQuery.fromUri(state.uri)` into `OperationsWorkspacePage(initialQuery: …)`
- Write gate (page-local today):

```dart
static const AccessRequirement _mutationRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[AppPermissions.operationsWrite],
  activeModules: <String>['facilities-maintenance'],
);
```

Used via `appAccessPolicyProvider` → `canMutate` (not yet wrapped in `AppAccessActionGate`).

- Tests today:
  - `frontend/test/features/operations/presentation/operations_workspace_page_test.dart`
    (tab strip, deep links, Assets switch, Create request visibility)
  - `frontend/test/features/operations/presentation/operations_workspace_controller_test.dart`
  - `frontend/test/features/operations/domain/operations_workspace_query_test.dart`
  - `frontend/test/features/operations/data/operations_dtos_test.dart`

### Current widget tree (chrome)

```
AsyncStateScaffold<OperationsWorkspaceState>
  (appBarTitle: l10n.operationsTitle — loading/error only; not success chrome)
  └── AppWorkspace(
        title: l10n.operationsTitle,
        leadingIcon: AppRouteIcons.operations,
        showHeader: false (default),
        toolbar: appWorkspaceToolbarWithLabels(
          summaryNotifications: _summaryNotifications(...),  // DUPLICATE tab nav
          secondary: [Report AppButton.secondary],
          primary: canMutate ? Create request AppButton.primary : null,
          onRefresh: controller.refresh,
        )
        // ↑ Even with showHeader:false, AppWorkspace STILL renders AppWorkspaceToolbar
        //   ABOVE the body (see app_workspace.dart else-branch).
      )
        └── body: Column
              ├── optional AppFailureStateView
              ├── AppTabStrip(tabs only — NO primaryAction / secondaryActions)
              ├── SizedBox(height: theme.spacing.sm)
              └── _OperationsQueuePanel | _OperationsAssetsPanel
```

### Tabs (validated against code + l10n)

| # | Tab label (l10n → EN) | Enum member | Query `section` written by `_sectionToQueryValue` | Accepted by `_sectionFromQuery` |
|---|----------------------|-------------|---------------------------------------------------|----------------------------------|
| 1 | `operationsAllRequestsSummaryLabel` → **All requests** | `allRequests` | `all` | default / anything else (incl. empty → all) |
| 2 | `operationsOpenSummaryLabel` → **Open** | `open` | `open` | `open` |
| 3 | `operationsInProgressSummaryLabel` → **In progress** | `inProgress` | `in-progress` | `in-progress` |
| 4 | `operationsCompletedSummaryLabel` → **Completed** | `completed` | `completed` | `completed` |
| 5 | `operationsAssetsSummaryLabel` → **Assets** | `assets` | `assets` | `assets` |

Deep-link tab state **is already URL-backed** via `?section=…` and `GoRouter.replace` in
`_updateUrlForSection`. Keep this; do **not** invent a second query key.

`requestId` is parsed by `OperationsWorkspaceQuery` but **not applied** in `_applyDeepLink`
today (only section filter + search). Wire it during this refactor (see Implementation Steps).

### Current toolbar / header actions (gaps)

Actions live on **`AppWorkspaceToolbar` above the tabs**, not on `AppTabStrip`:

| Action | Current location | l10n key | Notes |
|--------|------------------|----------|-------|
| Create request | Workspace toolbar primary (`AppButton.primary`) | `operationsCreateRequestAction` | Gated by `canMutate`; same on every tab |
| Report | Workspace toolbar secondary (`AppButton.secondary`) | `operationsOpenReportAction` | Opens `_showOperationsReportDialog` |
| Refresh | Workspace toolbar via `onRefresh` | `commonRefreshActionLabel` (via `appWorkspaceToolbarWithLabels`) | |
| Summary notification chips | Workspace toolbar `summaryNotifications` | same labels as tabs | Duplicate tab navigation — **remove from chrome** |
| Global fault / housekeeping | Likely via `appWorkspaceToolbarWithLabels` defaults | shared workspace globals | Do **not** reintroduce into Operations tab toolbar unless Reception/HR pattern requires them; prefer `AppTabStrip` only |
| Overflow / “more” menu | Possible via `AppWorkspaceToolbar` overflow resolver when many actions | — | **Forbidden** for screen actions per `prompt.md` |

`AppTabStrip` currently has **no** `primaryAction` / `secondaryActions`.

### Current table chrome (gaps)

**Queue tabs** (`_OperationsQueuePanel`):

- Search: yes (`operationsSearchLabel` / `operationsSearchHint`)
- Filters: yes, but label is `operationsFiltersLabel` → **"Operations filters"** (must become **"Filters"**)
- Settings: `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` → **"Table settings"** (must become **"Settings"**)
- No Refresh / Create / Report inside table trailing (good) — those belong in tab toolbar

**Assets tab** (`_OperationsAssetsPanel`):

- **No** search, **no** Filters button
- Settings only (`commonTableSettingsActionLabel`)
- Violates “tables expose Filters and Settings”

### Concrete `prompt.md` gaps to close

1. **Toolbar is above tabs** (`AppWorkspace` + `appWorkspaceToolbarWithLabels`), not under `AppTabStrip`.
2. Dedicated title/leading still passed into `AppWorkspace` (`title`, `leadingIcon`) even though `showHeader` defaults to false — remove `AppWorkspace` chrome entirely; use `ResponsivePage` like Reception / HR / Housekeeping.
3. Toolbar actions do not swap via `AppTabStrip.primaryAction` / `secondaryActions`.
4. Summary notification chips duplicate tabs — remove `_summaryNotifications` from screen chrome.
5. Table Filters label is not standardized **"Filters"**; Settings label is not **"Settings"**.
6. Assets table lacks Filters (and search chrome consistency).
7. Write actions use raw `canMutate` boolean instead of `AppAccessActionGate` (align with Reception).
8. `requestId` deep link parsed but unused — apply it (open detail) without inventing new chrome.
9. Possible workspace overflow “more” menu must not remain for screen actions — every former header action becomes a visible `AppTabToolbarPrimary` / `AppTabToolbarAction`.

## Reference Implementation

Read these files (do NOT modify them unless fixing shared bugs that block compliance):

- `prompt.md` (normative)
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` — canonical no-header + `AppTabStrip` layout
- `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart` — **copy this pattern** for per-tab `primaryAction` + `secondaryActions` builders
- `frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart` — sibling facilities screen with contextual primary under tabs
- `frontend/lib/shared/components/app_tab_strip.dart` — `AppTabStrip`, `AppTabItem`, `AppTabToolbarPrimary`, `AppTabToolbarAction`
- `frontend/lib/shared/layout/app_workspace.dart` — understand `showHeader` / toolbar-above-body behavior; Operations must **stop** using workspace toolbar for screen actions
- `frontend/lib/shared/layout/app_workspace_toolbar.dart` — reference only; do not keep Operations on this chrome
- `frontend/lib/shared/layout/responsive_page.dart` — target page shell
- `frontend/lib/shared/components/app_list_table.dart` — `AppListTable`, `AppListTableSearch`, column visibility → Settings
- `frontend/lib/shared/components/app_search_bar.dart` — Filters button via `filterGroups` / `advancedFilterButtonLabel`
- `frontend/lib/shared/actions/app_workspace_refresh_action.dart` — `AppWorkspaceRefreshAction` (HR uses this in secondaryActions)
- `frontend/lib/core/permissions/access_gate.dart` — `AppAccessActionGate`
- `frontend/lib/core/responsive/app_breakpoints.dart` — breakpoint tokens

## Target Architecture

### Tab Configuration

| Tab Name | Route / Query | Description | Toolbar primary | Toolbar secondary |
|----------|---------------|-------------|-----------------|-------------------|
| All requests | `/operations?section=all` | All maintenance work items (`clearFilters`) | **Create request** (`operationsCreateRequestAction`, icon `Icons.add`) gated by `AppAccessActionGate` + `_mutationRequirement` → `_showCreateRequestDialog` | **Report** (`operationsOpenReportAction`, icon `Icons.summarize_outlined`) → `_showOperationsReportDialog`; **Refresh** (`commonRefreshActionLabel`) → `controller.refresh()` |
| Open | `/operations?section=open` | Status `OPEN` | **Create request** (same as All) | **Report**; **Refresh** |
| In progress | `/operations?section=in-progress` | Status `IN_PROGRESS` | **Create request** (same) | **Report**; **Refresh** |
| Completed | `/operations?section=completed` | Status `COMPLETED` (count includes cancelled in badge; preserve existing `_sectionCount` / `applyStatus('COMPLETED')` behavior) | **Report** (`AppTabToolbarPrimary`) — read-focused completed queue | **Create request** (if write allowed, as `AppTabToolbarAction`); **Refresh** |
| Assets | `/operations?section=assets` | Facility assets list (`_OperationsAssetsPanel`) | **Create request** (preserve existing test expectation that Create remains available on Assets) | **Report**; **Refresh** |

Notes:

- Use `AppTabToolbarPrimary` for the single right-aligned primary CTA and `AppTabToolbarAction` / `AppWorkspaceRefreshAction` for left-cluster secondaries (matches `AppTabStrip` contract and HR).
- Detail-panel actions (Assign, Update status, Service log, note kinds, detail Report) stay inside the request detail dialog — **do not** promote them into the screen tab toolbar.
- Cancelled summary chip that currently jumps to Completed tab goes away with `_summaryNotifications`; tab counts already fold cancelled into Completed via `_sectionCount`.
- Guarantee ≥1 toolbar button on every tab (table above satisfies this).

### Routing

- Keep `/operations` registration in `app_router.dart` unchanged except if tests need it.
- Keep query key **`section`** (already written by `_updateUrlForSection` / parsed by `OperationsWorkspaceQuery.fromUri`).
- Canonical write values must remain: `all` | `open` | `in-progress` | `completed` | `assets`
- On tab tap: keep `_onTabChanged` → `setState` + `_updateUrlForSection` + `_applySectionFilter`.
- On deep link: keep section + search application; **also** apply `requestId` when non-empty:
  - After data is available, find matching `OperationsWorkItem` by `id` / `displayId` (mirror Reception’s `_findFlow` pattern), then call existing `_openRequestDetailDialog` with current `canMutate`.
  - Do not invent a new query key.
- Aliases already accepted by query parser: `panel` / `tab` for section, `q` for search, `request_id` / `id` for requestId — preserve.

### Page Layout

Precise widget tree:

1. Keep `AsyncStateScaffold` for loading/error (drop unnecessary dependence on `appBarTitle` for success chrome; optional: omit `appBarTitle` like Reception, or keep only for loading scaffolds — either is fine if success UI has **no** title bar).
2. Replace `AppWorkspace(...)` with `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)` wrapping a full-width `Column` (copy Reception / HR).
3. `AppTabStrip(tabs:, selectedId: _section.name, onTabTapped:, primaryAction: <per-tab>, secondaryActions: <per-tab>)`.
4. `SizedBox(height: theme.spacing.sm)` between strip and body (keep existing rhythm).
5. Optional `AppFailureStateView` for `state.lastFailure` (keep; place under strip like HR, not above tabs if that conflicts — prefer HR order: tabs → failure → body).
6. Body: `_OperationsQueuePanel` or `_OperationsAssetsPanel` — table chrome exposes **only**:
   - Search field (queue required; assets: add search if Filters need a search chrome host — use `AppListTableSearch` like queue)
   - **Filters**
   - **Settings**
7. No FAB / floating header actions / overflow more-menu / summary notification chips for screen actions.
8. No `appWorkspaceToolbarWithLabels` on this page.

### Data & State Management

Reuse (do not fork):

- `operationsWorkspaceControllerProvider` — `operations_workspace_controller.dart`
- `OperationsDeskSection` / `OperationsWorkspaceQuery` / entities — `operations_entities.dart`
- `operationsRepositoryProvider` — repository impl
- Page-local `_mutationRequirement` + prefer wrapping toolbar write CTAs in:

```dart
AppAccessActionGate(
  requirement: _mutationRequirement,
  builder: (context, isAllowed) => AppTabToolbarPrimary(... enabled: isAllowed && !state.isMutating, ...),
)
```

(Import `package:hosspi_hms/core/permissions/access_gate.dart`.)

Keep section filter behavior:

| Section | Controller call |
|---------|-----------------|
| `allRequests` | `clearFilters()` |
| `open` | `applyStatus('OPEN')` |
| `inProgress` | `applyStatus('IN_PROGRESS')` |
| `completed` | `applyStatus('COMPLETED')` |
| `assets` | no status filter change (break) |

## Implementation Steps

1. **Normalize Settings label** — File: `frontend/lib/l10n/app_en.arb`
   - Change `commonTableSettingsActionLabel` value from `"Table settings"` to `"Settings"`.
   - Keep the key name (`prompt.md` / Reception prompts cite this key).
   - Regenerate l10n (`flutter gen-l10n` or the repo’s usual generator).

2. **Normalize Operations Filters label** — File: `frontend/lib/l10n/app_en.arb`
   - Change `operationsFiltersLabel` from `"Operations filters"` to `"Filters"`.
   - Keep the key name; update `@operationsFiltersLabel` description if present.
   - Regenerate l10n.

3. **Replace AppWorkspace chrome with ResponsivePage + AppTabStrip toolbar** — File: `frontend/lib/features/operations/presentation/pages/operations_workspace_page.dart`
   - Remove `AppWorkspace`, `appWorkspaceToolbarWithLabels`, `title` / `leadingIcon` / `_summaryNotifications` usage from the page build method.
   - Build layout like HR:

```dart
return ResponsivePage(
  maxWidth: PageMaxWidth.dataHeavy,
  child: SizedBox(
    width: double.infinity,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppTabStrip(
          tabs: <AppTabItem>[ /* existing tab loop */ ],
          selectedId: _section.name,
          onTabTapped: /* existing */,
          primaryAction: _buildPrimaryAction(l10n, state, canMutate),
          secondaryActions: _buildSecondaryActions(context, l10n, state, controller),
        ),
        SizedBox(height: theme.spacing.sm),
        if (lastFailure != null) ...<Widget>[
          AppFailureStateView(failure: lastFailure, onRetry: controller.refresh),
          SizedBox(height: theme.spacing.md),
        ],
        if (_section == OperationsDeskSection.assets)
          _OperationsAssetsPanel(...)
        else
          _OperationsQueuePanel(...),
      ],
    ),
  ),
);
```

   - Add `_buildPrimaryAction` / `_buildSecondaryActions` switching on `_section` per the Tab Configuration table.
   - Primary Create request: `AppTabToolbarPrimary` + `AppAccessActionGate`.
   - Report: `AppTabToolbarAction` (or primary on Completed).
   - Refresh: prefer `AppWorkspaceRefreshAction(label: l10n.commonRefreshActionLabel, isLoading: state.isRefreshing, onPressed: …)` like HR; surface failures with existing `_showFailureIfNeeded`.
   - Delete `_summaryNotifications` method entirely once unused.
   - Remove unused imports (`AppRouteIcons` if only used for workspace leading, etc.).

4. **Queue table: keep Filters + Settings only; fix labels** — `_OperationsQueuePanel` in same page file
   - Set `advancedFilterButtonLabel` / `advancedFilterTitle` to `l10n.operationsFiltersLabel` (now **"Filters"**).
   - Keep `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` (now **"Settings"**).
   - Do **not** add Create / Report / Refresh into `AppListTableSearch.trailingActions`.
   - Preserve existing filter groups (status, priority), text filters (facility, asset), date range, and controller `applyFilters` wiring.

5. **Assets table: add Filters (+ search host) and Settings** — `_OperationsAssetsPanel`
   - Add an `AppListTableSearch<OperationsAsset>` (client-side matcher on name / tag / facility / status) so Filters/Settings share the same chrome as other tables.
   - Enable Filters with `showAdvancedFilterButton: true` and/or `filterGroups`:
     - At minimum one status group using asset statuses present in `state.assets.items` (or a fixed known set if assets reuse maintenance statuses).
     - `advancedFilterButtonLabel` / title: `l10n.operationsFiltersLabel` (**"Filters"**).
   - Keep `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` (**"Settings"**).
   - Pass a `TextEditingController` from parent content state (new `_assetsSearchController`) or construct a dedicated controller owned by the assets panel — dispose correctly.
   - Filtering may be client-side only (Assets currently loads via workspace state page); do not invent API changes.

6. **Deep-link `requestId`** — same page file
   - Extend `_applyDeepLink` to, when `query.requestId` is non-empty, locate the work item in `widget.state.workItems.items` (and/or call `controller.selectItem` / repository path already used by row open) and open `_openRequestDetailDialog`.
   - If not found after filters applied, optionally `applySearch(requestId)` then retry once — keep logic simple and deterministic; do not block the refactor on perfect fuzzy matching.
   - Preserve existing section-then-search order comment (“clearFilters cannot wipe q=”).

7. **Update widget tests** — File: `frontend/test/features/operations/presentation/operations_workspace_page_test.dart`
   - Assert Create request / Report / Refresh appear under tab strip chrome (still findable by label).
   - On Completed tab, assert Report is the primary affordance (still find Report; Create may move to secondary but must remain findable when write-allowed).
   - Keep deep-link and Assets tests green; update any assertions that assumed workspace-header structure.
   - Add assertions that Filters and Settings labels render as **"Filters"** / **"Settings"** on queue (and Assets after step 5).
   - Add a test that `requestId` deep link opens the detail dialog when the item exists (optional but preferred).

8. **Do not change** repository DTOs, API contracts, or domain entity fields except if `OperationsWorkspaceQuery` needs a tiny helper for request targeting (prefer page-local).

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` / `AppTabToolbarPrimary` / `AppTabToolbarAction` | `package:hosspi_hms/shared/components/app_tab_strip.dart` (via `components.dart`) | Tabs + contextual toolbar under tabs |
| `ResponsivePage` | `package:hosspi_hms/shared/layout/responsive_page.dart` (via `layout.dart`) | Page shell without title header |
| `AppListTable` / `AppListTableSearch` | `package:hosspi_hms/shared/components/app_list_table.dart` | Queue + Assets tables |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Gate Create request |
| `AppWorkspaceRefreshAction` | `package:hosspi_hms/shared/actions/app_workspace_refresh_action.dart` | Refresh secondary |
| `AsyncStateScaffold` | `package:hosspi_hms/shared/components/app_state_view.dart` | Loading / error shell |
| `AppFailureStateView` | shared components | Inline lastFailure |
| Theme spacing | `app_theme_extensions.dart` | `theme.spacing.sm` / `md` vertical rhythm |

**Forbidden:** new custom tab bars, new header widgets, `PopupMenuButton` / overflow “more” for screen actions, reintroducing `appWorkspaceToolbarWithLabels` on this page, summary notification chips as tab substitutes.

## Files to Create / Modify / Delete

| Action | File |
|--------|------|
| Modify | `frontend/lib/features/operations/presentation/pages/operations_workspace_page.dart` |
| Modify | `frontend/lib/l10n/app_en.arb` (`commonTableSettingsActionLabel`, `operationsFiltersLabel`) |
| Modify | Generated l10n outputs (`app_localizations*.dart`) via codegen |
| Modify | `frontend/test/features/operations/presentation/operations_workspace_page_test.dart` |
| Possibly modify | `frontend/test/features/operations/domain/operations_workspace_query_test.dart` only if query helpers change |
| Do not create | New tab/toolbar/table widget libraries |

## Cleanup: Remove Stale Code

- [ ] Remove `_summaryNotifications` and all `AppWorkspaceSummaryNotification` usages from Operations page
- [ ] Remove `AppWorkspace` + `appWorkspaceToolbarWithLabels` from Operations success chrome
- [ ] Remove unused imports (`AppRouteIcons` if unused, toolbar helpers if unused)
- [ ] Ensure no orphaned references to workspace header overflow sections on this page
- [ ] Confirm detail-dialog actions remain intact and were not duplicated into the tab toolbar

## Database Migrations

No database migrations required — schema unchanged. This is a frontend chrome/layout refactor only.

## Responsive Design Requirements

- Desktop (≥1024px / `AppBreakpoint.desktop`): full tab strip + toolbar row; dense table columns with Settings column picker.
- Tablet (600–1023px): horizontal-scroll tabs (already in `AppTabStrip`); toolbar `Wrap` for secondaries; tables may use existing responsive column behavior.
- Mobile (<600px): keep `mobileItemBuilder` list tiles for queue and assets; toolbar actions wrap; no FAB.

Follow spacing already used by Reception: `SizedBox(height: theme.spacing.sm)` under `AppTabStrip`.

## Verification Steps

```bash
cd frontend
dart format lib/features/operations test/features/operations lib/l10n
dart analyze --fatal-infos lib/features/operations test/features/operations
flutter gen-l10n
flutter test test/features/operations/
flutter test test/shared/
```

If the repo uses a root-level format/analyze script, prefer the project’s standard commands, but the above must pass for Operations.

## Testing Requirements

- [ ] Tab switch updates URL `section` query and toolbar actions (Completed primary = Report)
- [ ] Deep link `?section=open` / `?section=assets` opens correct tab (existing tests)
- [ ] Deep link `requestId` opens detail when item exists (new or extended test)
- [ ] Per-tab toolbar shows only that tab’s configured actions; no workspace toolbar above tabs
- [ ] Table chrome has only Filters and Settings (labels exactly **Filters** / **Settings**)
- [ ] No screen title/header chrome remains on success path (`AppWorkspace` title/header gone)
- [ ] At least one toolbar button exists on every tab
- [ ] Permissions still gate Create request (`operationsWrite` + `facilities-maintenance`)
- [ ] Responsive layouts still work (desktop pump at 1440×900 in existing tests; spot-check mobile builders compile)
- [ ] Domain behaviors preserved: status filters per tab, create/report dialogs, detail mutations, realtime refresh controller unchanged

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md`
- [ ] Uses `AppTabStrip` with contextual toolbar under tabs (`primaryAction` / `secondaryActions`)
- [ ] No dedicated header; no stray workspace-toolbar actions; no header more-menu for screen actions
- [ ] Domain logic preserved (queue, assets, dialogs, permissions, deep links)
- [ ] Analyze clean; tests pass; stale summary-notification / AppWorkspace toolbar code removed
- [ ] Filters / Settings labels standardized to **"Filters"** / **"Settings"**
