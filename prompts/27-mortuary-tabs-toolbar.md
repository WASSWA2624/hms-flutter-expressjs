# Standardize Mortuary Screen (Tabs & Toolbar)

## Objective

Refactor the Mortuary workspace (`/mortuary`, `MortuaryWorkspacePage`) so its chrome fully complies with `prompt.md`:
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

**Scope boundary:** Restructure Mortuary **screen chrome/layout only**. Do not implement the
disabled workflow mutations (receive case, assign storage, custody, viewing, post-mortem,
billing, release) unless required to keep chrome wiring compiling. Preserve permissions,
panel/resource/queue filtering, pagination, search/advanced filters, detail dialog + print,
realtime refresh, and row → detail behavior.

**Do not invent new tab/table/search/filter chrome.** Reuse the shared components listed below.

## Current State (from audit)

### Primary files

- Page: `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart`
  - Public widget: `MortuaryWorkspacePage` (no `initialQuery` today)
  - Content: `_MortuaryWorkspaceContent` / `_MortuaryWorkspaceContentState`
  - Worklist body: `_MortuaryWorklist` → `AppListTable<MortuaryWorkspaceItem>`
  - Detail dialog: `_openMortuaryDetailDialog` → `_MortuaryDetailPanel` with print action
  - Action-gap panel: `_ActionGapPanel` (disabled workflow CTAs — **keep in detail dialog**)
- Controller: `frontend/lib/features/mortuary/presentation/controllers/mortuary_workspace_controller.dart`
  - Provider: `mortuaryWorkspaceControllerProvider`
  - Key methods: `refresh()`, `applySearch`, `switchPanel`, `applyQueue`, `applyFilters`,
    `clearFilters`, `changePage`, `selectItem`
- Domain: `frontend/lib/features/mortuary/domain/entities/mortuary_entities.dart`
  - Panels: `mortuaryPanels` — `overview`, `intake`, `storage`, `custody`, `release`, `reporting`
  - Default resource map: `mortuaryDefaultResourceByPanel`
  - Queues: `mortuaryQueues` (`IDENTIFICATION_PENDING`, `STORAGE_EXCEPTIONS`, `RELEASE_READY`,
    `UNSETTLED_BILLING`, `POST_MORTEM_PENDING`)
  - Route query model: `MortuaryRouteQuery.fromUri` parses `panel|section`, `search`, `queue`, `id`
  - Workspace query: `MortuaryWorkspaceQuery` (panel, resource, queue, filters, pagination)
- Repository: `frontend/lib/features/mortuary/data/repositories/mortuary_repository_impl.dart`
  (`mortuaryRepositoryProvider`)
- Route: `AppRoutes.mortuary` path `/mortuary` in `frontend/lib/app/router/app_routes.dart`
  - Permissions: any of `mortuaryRead`, `mortuaryWrite`, `mortuaryApprove`, `mortuaryRelease`,
    `mortuaryAudit`
  - Roles: `mortuaryWorkspaceRoles`; module: `mortuary`; `requiresFacilityContext: true`
- Router builder: `frontend/lib/app/router/app_router.dart` builds
  `const MortuaryWorkspacePage()` — **does not** pass `MortuaryRouteQuery.fromUri(state.uri)` yet
- Page-level access gate: `MortuaryWorkspacePage._readRequirement` wraps `AppAccessGate`
- Write / domain permission constants (file bottom):
  `_writeRequirement`, `_storageRequirement`, `_postMortemRequirement`, `_billingRequirement`,
  `_approveRequirement`, `_releaseRequirement`, `_exportRequirement`
- Tests today:
  - `frontend/test/features/mortuary/presentation/mortuary_workspace_controller_test.dart`
    (load, queue filter contract)
  - `frontend/test/features/mortuary/data/mortuary_dtos_test.dart`
  - **No** `mortuary_workspace_page_test.dart` yet

### Current widget tree (chrome) — non-compliant

```
AppAccessGate
  └── AsyncStateScaffold<MortuaryWorkspaceState>
        appBarTitle: l10n.mortuaryTitle                    // remove
        └── _MortuaryWorkspaceContent
              └── AppWorkspace(
                    title: l10n.mortuaryTitle,             // dedicated title chrome
                    leadingIcon: AppRouteIcons.mortuary,
                    toolbar: appWorkspaceToolbarWithLabels( // ← ABOVE body (violation)
                      summaryNotifications: total_cases / identification_pending /
                        in_storage / release_ready / unsettled_billing + spotlight queues,
                      primary: Receive case (disabled),
                      onRefresh: controller.refresh,
                    ),
                    body: _MortuaryWorklist → AppListTable
                  )
```

Even with `showHeader: false`, `AppWorkspace` still mounts `AppWorkspaceToolbar` when `toolbar`
is non-null. That places summary chips + Receive case + Refresh **above** the worklist and
**outside** `AppTabStrip` — opposite of `prompt.md` (tabs first, toolbar immediately beneath tabs).

There is **no** `AppTabStrip` today. Panel switching happens only via the **Panel** filter group
inside the table Filters dialog.

### Confirmed tab inventory (panels → tabs)

Constants: `mortuaryPanels` in `mortuary_entities.dart`.
Tab ids in `AppTabStrip` must use the panel string constants.

| # | Tab label (l10n → EN) | Panel constant | Query `?panel=` | Default resource | Tab count source |
|---|----------------------|----------------|-----------------|------------------|------------------|
| 1 | `mortuaryPanelOverviewLabel` → **Overview** | `overview` | *(omit — default)* | `mortuary-cases` | `state.panels` id `overview` or `state.summaryValue('total_cases')` |
| 2 | `mortuaryPanelIntakeLabel` → **Intake** | `intake` | `intake` | `mortuary-cases` | `state.panels` id `intake` |
| 3 | `mortuaryPanelStorageLabel` → **Storage** | `storage` | `storage` | `mortuary-storage-assignments` | `state.panels` id `storage` |
| 4 | `mortuaryPanelCustodyLabel` → **Custody** | `custody` | `custody` | `mortuary-custody-events` | `state.panels` id `custody` |
| 5 | `mortuaryPanelReleaseLabel` → **Release** | `release` | `release` | `mortuary-release-authorisations` | `state.panels` id `release` |
| 6 | `mortuaryPanelReportingLabel` → **Reports** | `reporting` | `reporting` | `mortuary-post-mortem-requests` | `state.panels` id `reporting` |

Default workspace query panel: `mortuaryPanelOverview` (`MortuaryWorkspaceQuery.panel`).

### Current workspace toolbar (must relocate then remove)

From `appWorkspaceToolbarWithLabels` on the page:

1. **Summary notifications** (always listed; jump to overview or apply queue):
   - Total cases → `controller.switchPanel(overview)`
   - Identification pending / In storage / Release ready / Unsettled billing → no-op or queue apply
   - Spotlight queues (`state.spotlight`, `count > 0`) → `controller.applyQueue(queue.queue)`
2. **Receive case** — `AppPermissionActionButton` with `_writeRequirement`, **disabled**,
   tooltip `mortuaryActionsUnavailableTooltip`, `onPressed: null`
3. **Refresh** — `onRefresh: controller.refresh`, `isRefreshing: state.isRefreshing`

There is **no** overflow / more menu today — do not create one. Summary/queue chips must become
**visible** `AppTabToolbarAction`s (and/or tab count badges), never a notifications overflow.

### Current table chrome (mostly compliant)

In `_MortuaryWorklist` (`AppListTable<MortuaryWorkspaceItem>`):

- Search: `AppListTableSearch` with `mortuarySearchLabel` / `mortuarySearchHint` — keep
- Filters: `showAdvancedFilterButton: true` with
  `advancedFilterButtonLabel: l10n.mortuaryFiltersLabel` → English **"Filters"** ✅
- Settings: `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` → English **"Settings"** ✅
- Filter groups today include **Panel** (`mortuaryPanelFilterLabel`) — **remove** once tabs own
  panel selection (Biomedical pattern: panel is tab-only, not in Filters dialog)
- Other filter groups to **preserve**: Resource, Queue, Status, Identification status, Facility,
  Storage unit, Storage slot, Date preset
- No Refresh / Receive case in table trailing chrome today ✅

### Detail-dialog actions (preserve — not screen chrome)

Keep inside `_MortuaryDetailPanel` / `_ActionGapPanel` (do **not** promote to tab toolbar except
the single contextual **disabled primary** per tab listed below):
- Print documents (`_exportRequirement`) — stays in detail dialog actions
- Disabled workflow buttons in `_ActionGapPanel` (receive, assign storage, custody, viewing,
  post-mortem, billing, approve/confirm release)

### Concrete `prompt.md` gaps to close

1. **`AppWorkspace` title + toolbar above body** — dual chrome; no `AppTabStrip`.
2. **`AsyncStateScaffold.appBarTitle: mortuaryTitle`** — remove (Reception/Housekeeping omit it).
3. **Summary notification chips live above worklist** — relocate as tab-toolbar secondaries
   (conditional on `count > 0`) and/or tab count badges; remove workspace summary chrome.
4. **Receive case + Refresh live in `AppWorkspace` toolbar** — move under `AppTabStrip`.
5. **Panel selection only in Filters dialog** — promote panels to top tabs; remove Panel filter
   group from `_filterGroups`.
6. **No URL deep-link wiring** — `MortuaryRouteQuery` exists but router does not pass it; add
   `?panel=` / `?search=` / `?queue=` / `?id=` support like Biomedical/Housekeeping.
7. **No page widget tests** for chrome compliance — add `mortuary_workspace_page_test.dart`.

## Reference Implementation

Read these files (do NOT modify them unless fixing shared bugs that block compliance):

- `prompt.md` (normative)
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` —
  canonical: `ResponsivePage` + `AppTabStrip` + `SizedBox(height: theme.spacing.sm)` + table;
  **no** page `AppWorkspace` toolbar
- `frontend/lib/features/biomedical/presentation/pages/biomedical_workspace_page.dart` +
  `prompts/21-biomedical-tabs-toolbar.md` — **closest sibling**: `AppWorkspace` toolbar +
  panel-in-filters → migrate to tabs + tab-toolbar queue shortcuts
- `frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart` —
  URL-backed `?section=` tab sync pattern
- `frontend/lib/shared/components/app_tab_strip.dart` —
  `AppTabStrip`, `AppTabItem`, `AppTabToolbarPrimary`, `AppTabToolbarAction`
- `frontend/lib/shared/layout/app_workspace.dart` — stop using `AppWorkspace` for Mortuary page
  chrome (detail sub-panels like `AppWorkspaceDetailPanel` inside dialogs may remain)
- `frontend/lib/shared/layout/app_workspace_toolbar.dart` — reference only; Mortuary page must
  stop using `appWorkspaceToolbarWithLabels` for screen chrome
- `frontend/lib/shared/layout/responsive_page.dart` — `ResponsivePage`, `PageMaxWidth`
- `frontend/lib/shared/components/app_list_table.dart` — `AppListTable`, `AppListTableSearch`
- `frontend/lib/shared/components/app_search_bar.dart` — Filters via `filterGroups`
- `frontend/lib/core/permissions/access_gate.dart` — `AppAccessActionGate`, `AppPermissionActionButton`
- `frontend/lib/core/responsive/app_breakpoints.dart`

## Target Architecture

### Tab Configuration

| Tab Name | Route / Query | Description | Toolbar primary | Toolbar secondary |
|----------|---------------|-------------|-----------------|-------------------|
| Overview | `/mortuary` (default; omit `panel`) | All-case worklist | **Receive case** — `AppTabToolbarPrimary` + `AppAccessActionGate(_writeRequirement)`; **keep disabled** (`enabled: false`, tooltip `mortuaryActionsUnavailableTooltip`, icon `Icons.inbox_outlined`) until mutation ships | **Refresh** (`commonRefreshActionLabel`) + conditional queue shortcuts (below) |
| Intake | `/mortuary?panel=intake` | Newly received / identification worklist | **Receive case** (same disabled primary as Overview) | **Refresh** + queue shortcuts |
| Storage | `/mortuary?panel=storage` | Storage assignments / slot exceptions | **Assign storage** — write-gated `AppTabToolbarPrimary` (`mortuaryAssignStorageAction`, icon `Icons.inventory_2_outlined`); **keep disabled** with same unavailable tooltip | **Refresh** + queue shortcuts (especially Storage exceptions) |
| Custody | `/mortuary?panel=custody` | Custody chain-of-custody events | **Record custody** — write-gated; **keep disabled** (`mortuaryRecordCustodyAction`, icon `Icons.swap_horiz_outlined`) | **Refresh** + queue shortcuts |
| Release | `/mortuary?panel=release` | Release authorisations / billing clearance | **Approve release** — `_approveRequirement`; **keep disabled** (`mortuaryApproveReleaseAction`, icon `Icons.verified_outlined`) | **Refresh** + queue shortcuts (Release ready, Unsettled billing) |
| Reports | `/mortuary?panel=reporting` | Post-mortem / reporting requests | **Post-mortem** — `_postMortemRequirement`; **keep disabled** (`mortuaryPostMortemAction`, icon `Icons.fact_check_outlined`) | **Refresh** + queue shortcuts (Post-mortem pending) |

**Conditional queue shortcut secondaries** — each as its own visible `AppTabToolbarAction`
(never a more-menu), shown only when `count > 0`:

| Shortcut label (l10n) | Queue constant | Handler |
|-----------------------|----------------|---------|
| `mortuaryIdentificationPendingSummaryLabel` | `IDENTIFICATION_PENDING` | `controller.applyQueue(...)` + URL `?queue=IDENTIFICATION_PENDING` |
| `mortuaryInStorageSummaryLabel` | *(summary only)* | `controller.switchPanel(storage)` + URL panel update |
| `mortuaryReleaseReadySummaryLabel` | `RELEASE_READY` | `controller.applyQueue(...)` |
| `mortuaryUnsettledBillingSummaryLabel` | `UNSETTLED_BILLING` | `controller.applyQueue(...)` |
| `mortuaryQueueStorageExceptionsLabel` | `STORAGE_EXCEPTIONS` | `controller.applyQueue(...)` |
| `mortuaryQueuePostMortemPendingLabel` | `POST_MORTEM_PENDING` | `controller.applyQueue(...)` |

Use existing icons/tones from `_summaryIcon`, `_queueIcon` where helpful. Do **not** duplicate
every summary on every tab — show shortcuts relevant to the active panel when possible, but
**Refresh must appear on every tab** so the toolbar is never empty.

**Rules**

- Do **not** move Print documents from the detail dialog into the screen toolbar.
- Do **not** reintroduce `AppWorkspace` page title/header or a header more-menu.
- Disabled primaries remain visible (product signals upcoming workflows) but must not block
  Refresh from being enabled.
- Row selection → detail dialog behavior unchanged.

### Routing

- Update `app_router.dart` builder:
  ```dart
  MortuaryWorkspacePage(
    initialQuery: MortuaryRouteQuery.fromUri(state.uri),
  )
  ```
- Add `initialQuery` parameter to `MortuaryWorkspacePage` → pass into `_MortuaryWorkspaceContent`.
- Query keys (read via `MortuaryRouteQuery.fromUri`):
  - **`panel`** (alias **`section`**) — values: `overview|intake|storage|custody|release|reporting`
  - **`search`** — seed search controller + `controller.applySearch` on deep link
  - **`queue`** — `controller.applyQueue` on deep link
  - **`id`** — after workbench load, open matching item detail if found in `state.items`
- On tab tap: `setState` panel + `controller.switchPanel(panel)` + `GoRouter.replace` with
  `AppRoutes.mortuary.location(queryParameters: {if panel != overview 'panel': panel})`.
- Default tab when omitted: `overview`.
- Preserve controller semantics: `switchPanel` clears queue/status filters and resets page index
  (already implemented — do not break).
- When `applyQueue` runs from toolbar shortcut, also update URL `?queue=` (and panel if changed).

### Page Layout

Precise widget tree (match Reception/Biomedical target; no title header):

1. `AppAccessGate` → `AsyncStateScaffold<MortuaryWorkspaceState>` — **remove** `appBarTitle`
2. Inside `dataBuilder` → `_MortuaryWorkspaceContent`:
   - `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy, child: Column(...))`
   - `AppTabStrip(tabs:, selectedId: _currentPanel, onTabTapped:, primaryAction:, secondaryActions:)`
   - `SizedBox(height: theme.spacing.sm)` — match Reception vertical rhythm
   - Body: `_MortuaryWorklist` → `AppListTable` with search + **only** Filters + Settings
3. **Stop** wrapping the page body in `AppWorkspace` for screen chrome.
4. No FAB / floating header actions / overflow more-menu for screen actions.

### Data & State Management

Reuse unchanged (wire chrome only):

- `mortuaryWorkspaceControllerProvider` + all controller filter/panel/queue methods
- `MortuaryWorkspaceQuery` / `mortuaryDefaultResourceByPanel` / queue maps in controller
- Permission constants at bottom of `mortuary_workspace_page.dart`
- Print helper `_printItem` / `_reportBodyHtml` — detail dialog only
- Realtime: `RealtimeEventGroups.mortuary` in controller — preserve

Adjustments allowed:

- Local `_currentPanel` state synced with `widget.state.query.panel` and route query
- `_updateUrlForPanel`, `_applyDeepLink`, `_scheduleRouteQuery` helpers (copy Biomedical/Housekeeping)
- `_buildPrimaryAction(panel)` / `_buildSecondaryActions(panel)` helpers
- Remove `panel` from `_filterGroups`; update `_hasActiveFilters` so panel alone is not a filter

## Implementation Steps

1. **Add route query plumbing** — Files:
   `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart`,
   `frontend/lib/app/router/app_router.dart`
   - Add `MortuaryWorkspacePage({this.initialQuery, super.key})` with `MortuaryRouteQuery?`.
   - Pass `initialQuery` into `_MortuaryWorkspaceContent`.
   - Router builder passes `MortuaryRouteQuery.fromUri(state.uri)`.
   - Implement `_scheduleRouteQuery`, `_applyDeepLink` (panel, search, queue, optional id → detail).

2. **Replace `AppWorkspace` chrome with `ResponsivePage` + `AppTabStrip`** — same page file
   - Remove `AppWorkspace(title:, leadingIcon:, toolbar:, body:)` wrapper.
   - Build `AppTabStrip` from `mortuaryPanels` with labels via `_panelLabel(l10n, panel)` and
     counts from `state.panels` (fallback `0`).
   - On tab tap: update `_currentPanel`, call `controller.switchPanel(panel)`, `_updateUrlForPanel`.
   - Insert `SizedBox(height: theme.spacing.sm)` under tabs.

3. **Wire contextual tab toolbar** — same page file
   - Implement `_buildPrimaryAction(BuildContext, String panel)` per Tab Configuration table.
     Use `AppTabToolbarPrimary` + `AppAccessActionGate` / disabled state as today.
   - Implement `_buildSecondaryActions` with:
     - `AppTabToolbarAction` Refresh → `controller.refresh()` (`enabled: !state.isRefreshing`)
     - Conditional queue/summary shortcuts per table above
   - Pass into `AppTabStrip(primaryAction:, secondaryActions:)`.

4. **Remove workspace toolbar + title chrome** — same page file + scaffold
   - Delete `appWorkspaceToolbarWithLabels(...)` usage on this page.
   - Remove `AsyncStateScaffold.appBarTitle: l10n.mortuaryTitle`.
   - Do not pass `title:` / `leadingIcon:` at page level.

5. **Normalize Filters dialog (panel → tabs)** — `_MortuaryWorklist` / `_filterGroups`
   - Remove the `panel` `AppSearchBarFilterGroup` from `_filterGroups`.
   - Keep Resource, Queue, Status, Identification, Facility, Storage unit/slot, Date preset.
   - Update `_hasActiveFilters` — do not treat `panel != overview` as an active filter.
   - Keep `mortuaryFiltersLabel` (**Filters**) for button + dialog title.

6. **Preserve detail dialog + print** — same page file
   - Keep `_openMortuaryDetailDialog`, `_MortuaryDetailPanel`, `_ActionGapPanel` unchanged except
     imports moved if needed.
   - Print stays on detail `actions:` — do not add a screen-level Print toolbar button.

7. **Tests** — create `frontend/test/features/mortuary/presentation/mortuary_workspace_page_test.dart`
   - Pump `MortuaryWorkspacePage` with stubbed `mortuaryWorkspaceControllerProvider` /
     repository (follow `housekeeping_workspace_page_test.dart` / `biomedical_workspace_page_test.dart`
     harness patterns).
   - Assert all six tab labels appear (Overview, Intake, Storage, Custody, Release, Reports).
   - Assert exactly one `AppTabStrip` in the page tree.
   - Assert Refresh visible on Overview; Receive case primary visible (disabled) on Overview/Intake.
   - Assert Filters button label **Filters**; Settings via `commonTableSettingsActionLabel`.
   - Assert Filters dialog does **not** contain Panel filter group (panel is tab-only).
   - Assert tab tap updates URL `?panel=` when GoRouter harness available.
   - Keep existing controller/DTO tests green.

8. **Format / analyze / test** — run verification commands below.

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` / `AppTabToolbarPrimary` / `AppTabToolbarAction` | `package:hosspi_hms/shared/components/app_tab_strip.dart` (via `components.dart`) | Tabs + contextual toolbar |
| `AppListTable` / `AppListTableSearch` | `package:hosspi_hms/shared/components/app_list_table.dart` | Worklist; Filters + Settings only |
| `ResponsivePage` / `PageMaxWidth` | `package:hosspi_hms/shared/layout/responsive_page.dart` (via `layout.dart`) | Page shell without title header |
| `AppAccessGate` / `AppAccessActionGate` / `AppPermissionActionButton` | `package:hosspi_hms/core/permissions/access_gate.dart` | Read gate + permission-gated/disabled primaries |
| `AsyncStateScaffold` | shared components barrel | Loading / error / retry (no `appBarTitle`) |
| `AppDialog` / `AppPatientDetails` / `AppWorkspaceDetailPanel` | shared components | Detail dialog (not screen chrome) |
| `AppBreakpoints` | `package:hosspi_hms/core/responsive/app_breakpoints.dart` | Responsive behavior via `ResponsivePage` |
| l10n `commonRefreshActionLabel` / `commonTableSettingsActionLabel` / `mortuaryFiltersLabel` | `context.l10n` | Refresh + table chrome labels |

**Forbidden:** new custom tab strip, `AppWorkspace` page title header, duplicate toolbar above tabs,
table overflow menus for screen actions, reintroducing Panel inside Filters once tabs exist.

## Files to Create / Modify / Delete

### Modify

| File | Change |
|------|--------|
| `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` | `ResponsivePage` + `AppTabStrip`; contextual toolbar; remove `AppWorkspace` chrome; deep-link helpers; drop Panel filter group |
| `frontend/lib/app/router/app_router.dart` | Pass `MortuaryRouteQuery.fromUri(state.uri)` into page |

### Create

| File | Change |
|------|--------|
| `frontend/test/features/mortuary/presentation/mortuary_workspace_page_test.dart` | Tab / toolbar / Filters / URL chrome tests |

### Delete

| File / symbol | Reason |
|---------------|--------|
| Page-level `AppWorkspace(...)` wrapper + `appWorkspaceToolbarWithLabels(...)` on Mortuary page | Replaced by tab strip toolbar |
| `AsyncStateScaffold.appBarTitle` for Mortuary | No dedicated title chrome |
| `panel` filter group in `_filterGroups` | Panel selection moved to tabs |

Do **not** delete domain controllers, repositories, DTOs, or detail-dialog sections.

## Cleanup: Remove Stale Code

- [ ] Confirm no leftover `AppWorkspace` title/toolbar on Mortuary page
- [ ] Remove unused summary-notification wiring tied only to workspace toolbar
- [ ] Ensure no second toolbar row outside `AppTabStrip`
- [ ] Ensure no `PopupMenuButton` / more_vert screen actions for board-level actions
- [ ] Grep Mortuary page for `showHeader: true` / stray `mortuaryTitle` as screen header
- [ ] Panel filter group removed from Filters; tabs own panel selection

## Database Migrations

No database migrations required — schema unchanged. This is a Flutter presentation/chrome
refactor only.

## Responsive Design Requirements

Follow existing `ResponsivePage` + `AppTabStrip` + `AppListTable` behavior (same as Reception):

- **Desktop (≥1024px):** tab strip horizontal scroll if needed; toolbar shows icon+label actions;
  full column set in `_columns`
- **Tablet (600–1023px):** same layout; compact toolbar labels per `AppBreakpoint.showsToolbarActionLabels`
- **Mobile (<600px):** `AppListTable.mobileItemBuilder` (`_MortuaryMobileListItem`) remains;
  tabs scroll horizontally; toolbar wraps via `AppTabStrip`; no separate mobile title header

Do not add a mobile-only app bar title for Mortuary.

## Verification Steps

Run from `frontend/`:

```bash
dart format .
dart analyze --fatal-infos
flutter test test/features/mortuary/
flutter test test/shared/
```

## Testing Requirements

- [ ] Tab switch updates URL `?panel=<panel>` and swaps toolbar primary
- [ ] Deep link `/mortuary?panel=storage` opens Storage tab with correct default resource
- [ ] Deep link `/mortuary?queue=RELEASE_READY` applies queue filter (and panel/resource side effects)
- [ ] Per-tab toolbar shows only that tab's actions per the matrix above
- [ ] Table chrome has only Filters and Settings (plus search) — Filters label is **Filters**
- [ ] Filters dialog does not include Panel group after migration
- [ ] No screen title/header chrome remains (`AppWorkspace` title, `appBarTitle` removed)
- [ ] At least one toolbar button exists on every tab (Refresh satisfies this)
- [ ] Permissions still gate disabled write primaries via `AppAccessActionGate`
- [ ] Detail dialog Print + action-gap panel still work
- [ ] Responsive layouts still work (desktop table / mobile cards)
- [ ] Existing mortuary controller/DTO tests still pass

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md`
- [ ] Uses `AppTabStrip` with contextual toolbar under tabs (`primaryAction` / `secondaryActions`)
- [ ] No dedicated header; no stray actions; no header more-menu
- [ ] Domain logic preserved (panels, resources, queues, filters, detail, print, permissions, refresh)
- [ ] Analyze clean; tests pass; `AppWorkspace` page chrome removed
- [ ] Queue/summary shortcuts relocated from workspace toolbar to tab-toolbar secondaries
- [ ] Table area does not host Receive case / Refresh / other non-Filters/Settings actions
