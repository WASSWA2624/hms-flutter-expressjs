# Standardize Theater Screen (Tabs & Toolbar)

## Objective

Refactor the Theater workspace (`/theater`, `TheaterWorkspacePage`) so its chrome fully complies with `prompt.md`:
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
**Preserve all Theater domain logic** (section filters by status/stage, search, advanced filters,
pagination, case detail dialog + mutation dialogs, schedule/reschedule, checklist/anesthesia/
post-op/resources/handover/finalize/cancel, permissions via `AppPermissions.clinicalWrite`,
section counts, realtime refresh via `theaterWorkspaceControllerProvider`, deep links including
`section`, `id`/`case`, `panel`, and `action=schedule`). This refactor is
**layout/chrome and label standardization only**.

## Current State (from audit)

### Primary files

- Page: `frontend/lib/features/theater/presentation/pages/theater_workspace_page.dart`
  - Public widget: `TheaterWorkspacePage` (`initialQuery: TheaterBoardQuery?`)
  - Content: `_TheaterWorkspaceContent` / `_TheaterWorkspaceContentState`
  - Table panel: `_TheaterCaseBoard` → `AppListTable<TheaterCase>`
  - Detail: `_openTheaterCaseDialog` → `_TheaterCaseDetail` / `_TheaterCaseDetailBody` /
    `_TheaterActionBar` (dialog-only row actions — **do not** promote into screen toolbar)
  - Schedule: `_showScheduleCaseDialog` → `showTheaterScheduleCaseDialog` in
    `frontend/lib/features/theater/presentation/widgets/theater_schedule_case_form.dart`
- Controller: `frontend/lib/features/theater/presentation/controllers/theater_workspace_controller.dart`
  - Provider: `theaterWorkspaceControllerProvider`
  - Key methods: `refresh()`, `applyStatus()`, `applyStage()`, `applySearch()`, `applyScheduledDate()`,
    `applyResourceFilters()`, `clearFilters()`, `changePage()`, `applyBoardQuery()`,
    `selectCase()` / `selectCaseByDisplayId()`, `scheduleCase()`, `updateCaseSchedule()`,
    `updateStage()`, `assignResource()`, `toggleChecklistItem()`, `upsertAnesthesiaRecord()`,
    `upsertPostOpNote()`, `finalizeRecord()`
- Domain: `frontend/lib/features/theater/domain/entities/theater_entities.dart`
  - Enum: `TheaterSection { scheduled, inTheater, recovery, all }`
  - Extension: `TheaterSectionX.queryValue` / `TheaterSectionX.fromQuery`
  - Query: `TheaterBoardQuery.fromUri` parses `section`, `search`/`q`, `id`/`case`/`caseId`,
    `panel`, patient/encounter/emergency ids, `action`
- Routes: `AppRoutes.theater` path `/theater` in `frontend/lib/app/router/app_routes.dart`
  - Router builder in `frontend/lib/app/router/app_router.dart`:
    `TheaterWorkspacePage(initialQuery: TheaterBoardQuery.fromUri(state.uri))`
- Tests:
  - `frontend/test/features/theater/presentation/theater_workspace_page_test.dart`
    (tabs, URL `section`, deep links, Schedule case, mobile viewport)
  - `frontend/test/features/theater/presentation/theater_workspace_controller_test.dart`
  - `frontend/test/features/theater/domain/theater_entities_test.dart`
  - `frontend/test/features/theater/data/dtos/theater_dtos_test.dart`

### Current widget tree (data state)

```
AsyncStateScaffold<TheaterWorkspaceState>(
  appBarTitle: l10n.theaterTitle,  // loading/empty chrome only
  maxWidth: PageMaxWidth.dataHeavy,
  dataBuilder → _TheaterWorkspaceContent
)
  └── AppWorkspace(
        title: theaterTitle,
        leadingIcon: AppRouteIcons.theater,
        showHeader: false (default),
        toolbar: appWorkspaceToolbarWithLabels(   // ← RENDERS ABOVE TABS (gap)
          summaryNotifications: [All cases, Scheduled, In theater, Ready, Completed],
          primary: Schedule case (clinicalWrite-gated),
          onRefresh: controller.refresh,
        ),
        body: Column(
          ├── AppTabStrip(tabs only — NO primaryAction / secondaryActions)
          ├── SizedBox(height: theme.spacing.sm)
          ├── optional AppFailureStateView
          └── _TheaterCaseBoard → AppListTable (search + Filters + Settings)
        ),
      )
```

### Tabs (validated against code + l10n)

| # | Tab label (EN / l10n key) | Enum | Query `?section=` written by `_updateUrlForSection` | Tab id (`AppTabItem.id`) | Filter applied by `_applyTabFilter` | Count |
|---|---------------------------|------|-----------------------------------------------------|--------------------------|-------------------------------------|-------|
| 1 | Scheduled (`theaterScheduledSummaryLabel`) | `scheduled` | `scheduled` | `scheduled` | `applyStatus('SCHEDULED', clearStage: true)` | `state.scheduledCount` |
| 2 | In theater (`theaterInTheaterSummaryLabel`) | `inTheater` | `in-theater` | `inTheater` | `applyStatus('IN_PROGRESS', clearStage: true)` | `state.inTheaterCount` |
| 3 | Recovery (`theaterRecoverySectionLabel`) | `recovery` | `recovery` | `recovery` | `applyStage('POST_OP', clearStatus: true)` | `state.recoveryCount` |
| 4 | All cases (`theaterAllCasesSummaryLabel`) | `all` | *(omit when `all`)* | `all` | `clearFilters()` | page total via `_pageTotal(state.cases)` |

Notes:

- Deep-link tab state **is already URL-backed** via `?section=` + `GoRouter.replace` in `_updateUrlForSection`.
  `TheaterSectionX.fromQuery` also accepts aliases (`in_theater`, `intheater`, `post-op`, `pacu`, etc.).
  **Keep this; do not invent a second tab query key.**
- Additional deep-link params (`id`/`case`, `panel`, `search`/`q`, patient/encounter/emergency ids,
  `action=schedule`) must keep working via `_handleDeepLink` / `_maybeOpenScheduleDialog`.
- Count tones today: warning for Scheduled / In theater / Recovery; info for All cases — **preserve**.

### Current toolbar / header (gaps)

1. **Workspace toolbar above tabs** via `AppWorkspace.toolbar` + `appWorkspaceToolbarWithLabels` — violates “toolbar immediately beneath tabs”.
2. **`AppTabStrip` has no `primaryAction` / `secondaryActions`** — toolbar is not under tabs and not tab-contextual.
3. **Summary notification chips** in the workspace toolbar duplicate tab counts and act as alternate
   filters (including Ready/`PRE_OP` and Completed which are **not** tabs) — remove from screen chrome.
   Tab counts + tab selection already cover Scheduled / In theater / Recovery / All cases.
   Ready and Completed remain available via table advanced Filters (status/stage groups) — do not lose that.
4. Screen actions today (must relocate into `AppTabStrip` toolbar):
   - **Schedule case** — `l10n.theaterScheduleCaseAction`, icon `Icons.add`, gated by
     `AppPermissions.clinicalWrite`, disabled while `state.isMutating` → `_showScheduleCaseDialog`
   - **Refresh** — via `onRefresh: controller.refresh` / `isRefreshing: state.isRefreshing`
5. **No overflow / “more” menu** for screen actions today (good — do not add one).
6. Row/detail actions (Reschedule, Update stage, Assign resource, Readiness, Anesthesia, Post-op,
   Handover, Finalize, Cancel) live inside the case detail dialog (`_TheaterCaseDetail` /
   `_TheaterActionBar`) — **keep them dialog-local**.

### Current table chrome (gaps)

- Search: `AppListTableSearch` with `theaterSearchLabel` / `theaterSearchHint` — keep.
- Settings: `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` → currently **"Table settings"** — must become standardized **"Settings"** (shared key).
- Filters: `advancedFilterButtonLabel` / `advancedFilterTitle` use `l10n.theaterFiltersLabel` → currently **"Theater filters"** — must become standardized **"Filters"**.
- Filter dialog already has status/stage groups + room/surgeon/anesthetist text filters + schedule-date range — **preserve behavior**; only fix labels and keep Filters inside table chrome.
- No other table header actions beyond search / Filters / Settings — keep it that way.

### Concrete `prompt.md` gaps to close

1. Replace `AppWorkspace` + above-tabs `toolbar` with Reception/HR-style headerless `ResponsivePage` + `AppTabStrip` toolbar under tabs.
2. Move Schedule case / Refresh into `AppTabStrip.primaryAction` / `secondaryActions`, **contextual per active `TheaterSection`**.
3. Remove summary notifications from screen chrome (counts stay on tabs).
4. Standardize table Filters label to **"Filters"** and Settings to **"Settings"**.
5. Guarantee ≥1 toolbar button on every tab after contextualization (including read-only users → Refresh).
6. Do not reintroduce `showHeader: true`, titled header bars, FABs, or header more-menus.

## Reference Implementation

Read these files (do NOT modify them unless fixing shared bugs that block compliance):

- `prompt.md` (normative layout contract)
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
  — headerless `ResponsivePage` + `AppTabStrip` + `SizedBox(theme.spacing.sm)` + `AppListTable`
- `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart`
  — **copy this pattern** for per-tab `primaryAction` + `secondaryActions` helpers
- `frontend/lib/shared/components/app_tab_strip.dart`
  — `AppTabStrip`, `AppTabItem`, `AppTabToolbarPrimary`, `AppTabToolbarAction`
- `frontend/lib/shared/layout/app_workspace.dart` — `showHeader` (default `false`); Theater must **stop** using `AppWorkspace` for this page chrome
- `frontend/lib/shared/layout/app_workspace_toolbar.dart` — reference only; do **not** keep `appWorkspaceToolbarWithLabels` on Theater after migration
- `frontend/lib/shared/layout/responsive_page.dart` — wrap success content like Reception/HR
- `frontend/lib/shared/components/app_list_table.dart` / `app_search_bar.dart` — Filters + Settings in table search chrome
- `frontend/lib/core/permissions/access_gate.dart` — optional `AppAccessActionGate`
- `frontend/lib/core/responsive/app_breakpoints.dart` — breakpoint tokens used by `ResponsivePage`

## Target Architecture

### Tab Configuration

| Tab Name | Route / Query | Description | Toolbar primary | Toolbar secondary |
|----------|---------------|-------------|-----------------|-------------------|
| Scheduled | `/theater?section=scheduled` | Cases with status `SCHEDULED` | **Schedule case** (`theaterScheduleCaseAction`, `Icons.add`) write-gated → `_showScheduleCaseDialog` | **Refresh** (`commonRefreshActionLabel`, `Icons.refresh`) → `controller.refresh()`, `isLoading: state.isRefreshing` |
| In theater | `/theater?section=in-theater` | Cases with status `IN_PROGRESS` | **Schedule case** (write-gated) → `_showScheduleCaseDialog` | **Refresh** |
| Recovery | `/theater?section=recovery` | Cases with stage `POST_OP` | **Schedule case** (write-gated) → `_showScheduleCaseDialog` | **Refresh** |
| All cases | `/theater` (omit `section` or treat as all) | Full board; clears status/stage filters | **Schedule case** (write-gated) → `_showScheduleCaseDialog` | **Refresh** |

Notes:

- Use `AppTabToolbarPrimary` for the single right-aligned primary CTA and `AppTabToolbarAction` for left-cluster secondaries (matches `AppTabStrip` contract / HR pattern).
- Write-gate Schedule case with existing `canWrite = accessPolicy.grants(AppPermissions.clinicalWrite)` **or** an inline `AccessRequirement(anyPermissions: [AppPermissions.clinicalWrite])` + `AppAccessActionGate` (Reception-style). Prefer enabling/disabling (or hiding when denied) consistently with today’s `enabled: !state.isMutating` when allowed.
- When `canWrite` is false: omit Schedule case primary and promote **Refresh** to `primaryAction` (or keep Refresh as the only secondary/primary) so the screen is never actionless.
- Prefer `AppTabToolbarAction` for Refresh (flat tab-toolbar style). Do **not** put Refresh / Schedule case into `AppListTableSearch.trailingActions`.
- Do **not** move row/detail dialog actions into the tab toolbar.
- Contextual requirement: toolbar widgets must be rebuilt from `_section` (switch helpers like HR’s `_buildPrimaryActionButton` / `_buildSecondaryActionWidgets`). Even if labels are the same across tabs today, wire them through per-section helpers so future tab-specific actions stay local and tests can assert the strip rebuilds on tab change. Optionally differentiate secondaries lightly if desired (e.g. still Refresh everywhere) — sameness of labels is OK as long as the strip is section-driven.
- Every tab has ≥1 toolbar button (Schedule case and/or Refresh).

### Routing

- Keep `/theater` registration in `app_router.dart` unchanged.
- Keep query key **`section`** (already written by `_updateUrlForSection` / parsed by `TheaterBoardQuery.fromUri` / `TheaterSectionX.fromQuery`).
- Canonical write values must remain:
  - *(omit for all)* | `scheduled` | `in-theater` | `recovery`
- Preserve `_updateUrlForSection`, `_applyTabFilter`, `_handleDeepLink`, `_maybeOpenScheduleDialog`, and `TheaterBoardQuery.hasRouteTargeting` / `shouldOpenScheduleDialog` behavior.
- Do **not** rename the query key to `tab`/`queue` unless also updating `TheaterBoardQuery.fromUri` + all tests — prefer keeping `section`.

### Page Layout

Precise widget tree:

1. Keep `AsyncStateScaffold<TheaterWorkspaceState>` for loading/error (drop `appBarTitle` if unused after chrome change is fine; do not invent a persistent title bar).
2. Success content: `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)` → `SizedBox(width: double.infinity)` → `Column` (**no** `AppWorkspace`).
3. `AppTabStrip(tabs:, selectedId: _section.name, onTabTapped:, primaryAction: <per-section>, secondaryActions: <per-section>)`.
4. `SizedBox(height: theme.spacing.sm)` between strip and body (keep existing vertical rhythm).
5. Optional `AppFailureStateView` for `state.lastFailure` (keep under tabs or immediately above table — same as today relative to table; do not place above `AppTabStrip`).
6. Body: `_TheaterCaseBoard` / `AppListTable<TheaterCase>` whose search chrome exposes **only**:
   - Search field
   - **Filters** (advanced filter button / dialog — existing filter groups)
   - **Settings** (column visibility)
7. No FAB / floating header actions / overflow more-menu / summary-notification toolbar chips for screen actions.

### Data & State Management

Reuse (do not fork):

- `theaterWorkspaceControllerProvider` / `TheaterWorkspaceController`
- `TheaterSection` / `TheaterSectionX` / `TheaterBoardQuery` / `TheaterWorkspaceState` / `TheaterCase`
- Permission: `appAccessPolicyProvider` + `AppPermissions.clinicalWrite`
- Existing dialog helpers on the page file + `theater_schedule_case_form.dart`

Add/adjust UI helpers only:

- `_buildPrimaryAction(...)` and `_buildSecondaryActions(...)` switching on `_section` (`TheaterSection`) per the Tab Configuration table
- Remove `appWorkspaceToolbarWithLabels` / summary-notification construction entirely once chrome no longer needs it

## Implementation Steps

1. **Normalize Settings label** — File: `frontend/lib/l10n/app_en.arb`
   - Change `commonTableSettingsActionLabel` value from `"Table settings"` to `"Settings"`.
   - Keep the key name (prompt.md cites this key).
   - Regenerate l10n (`flutter gen-l10n` or the repo’s usual generator) so `app_localizations*.dart` update.

2. **Normalize Theater Filters label** — File: `frontend/lib/l10n/app_en.arb`
   - Change `theaterFiltersLabel` value from `"Theater filters"` to `"Filters"` (mirror `hrFiltersLabel` / `roomsBedsFiltersLabel`).
   - Keep the key name; table chrome must continue to use `theaterFiltersLabel`.
   - Regenerate l10n.

3. **Replace AppWorkspace chrome with ResponsivePage + contextual AppTabStrip toolbar** — File: `frontend/lib/features/theater/presentation/pages/theater_workspace_page.dart`
   - Remove `AppWorkspace(...)`, `appWorkspaceToolbarWithLabels(...)`, `leadingIcon`, and summary notifications.
   - Build success UI like Reception/HR:
     - `ResponsivePage` → `Column` → `AppTabStrip` → spacing → failure (optional) → `_TheaterCaseBoard`.
   - Implement `_buildPrimaryAction` / `_buildSecondaryActions` per Tab Configuration.
   - Wire `primaryAction:` / `secondaryActions:` on `AppTabStrip`.
   - Keep `_applyTabFilter` / `_updateUrlForSection` / deep-link + schedule-dialog flows unchanged in behavior.
   - Keep `canWrite` gating on Schedule case; disable while `state.isMutating` as today.
   - When `!canWrite`, ensure Refresh still appears as the toolbar affordance.
   - Import `AppTabToolbarPrimary` / `AppTabToolbarAction` from shared components (already via `components.dart`).
   - Drop unused imports that only served `AppWorkspace` / `AppRouteIcons` / toolbar helpers if no longer referenced in this file.

4. **Fix table Filters / Settings labels** — same page file (`_TheaterCaseBoard`)
   - Keep `advancedFilterButtonLabel: l10n.theaterFiltersLabel` (**must render as “Filters”** after step 2).
   - Keep `advancedFilterTitle: l10n.theaterFiltersLabel` (dialog title also “Filters”).
   - Keep `advancedFilterApplyLabel: l10n.opdApplyFiltersAction`, `advancedFilterResetLabel: l10n.theaterClearFiltersAction`.
   - Keep `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` (now “Settings”).
   - Do **not** add Refresh / Schedule case / summary chips into table `trailingActions`.

5. **Update tests** — File: `frontend/test/features/theater/presentation/theater_workspace_page_test.dart`
   - Assert `AppTabStrip` still present; tab labels/counts still work.
   - Assert URL `section` updates on tab switch (existing tests).
   - Assert deep links still select correct section (existing tests).
   - Assert Schedule case / Refresh appear via tab toolbar (find by l10n text / `AppTabToolbarPrimary` / `AppTabToolbarAction`), not via `AppWorkspace` summary chrome.
   - Assert Filters button text is `Filters` and Settings control uses `Settings`.
   - Assert `AppWorkspace` is **not** used on the success path (or at least no workspace summary notification chrome).
   - Preserve focus-case deep-link dialog test and mobile viewport test.
   - Keep write-policy override so Schedule case remains visible in write-capable tests; add a read-only variant if useful to prove Refresh-only toolbar.

6. **Format / analyze / run tests** — see Verification Steps.

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` / `AppTabToolbarPrimary` / `AppTabToolbarAction` | `package:hosspi_hms/shared/components/app_tab_strip.dart` (via `components.dart`) | Tabs + contextual toolbar under tabs |
| `AppListTable` / `AppListTableSearch` / column visibility | `package:hosspi_hms/shared/components/app_list_table.dart` | Case board table; Filters + Settings only in table chrome |
| `AppSearchBar` filter groups | `package:hosspi_hms/shared/components/app_search_bar.dart` | Existing theater advanced filters |
| `ResponsivePage` | `package:hosspi_hms/shared/layout/responsive_page.dart` (via `layout.dart`) | Headerless page shell |
| `AsyncStateScaffold` | shared components / layout exports already used by page | Loading/error shell |
| `AppFailureStateView` | shared | Last-failure banner |
| `AppAccessActionGate` (optional) | `package:hosspi_hms/core/permissions/access_gate.dart` | Gate Schedule case if preferred over raw `canWrite` |
| `AppBreakpoints` | `package:hosspi_hms/core/responsive/app_breakpoints.dart` | Via `ResponsivePage` / theme spacing |

**Forbidden:** new custom tab bars, new header title widgets, new overflow “more” menus for screen actions, reintroducing `AppWorkspace` toolbar-above-tabs for Theater, duplicating filter/settings controls outside the table search chrome, promoting detail-dialog actions into the tab toolbar.

## Files to Create / Modify / Delete

| Action | Path |
|--------|------|
| Modify | `frontend/lib/features/theater/presentation/pages/theater_workspace_page.dart` |
| Modify | `frontend/lib/l10n/app_en.arb` (+ regenerated `app_localizations*.dart`) |
| Modify | `frontend/test/features/theater/presentation/theater_workspace_page_test.dart` |
| Do not modify (unless shared Settings label requires regeneration only) | Reception / HR / `app_tab_strip.dart` / router registration |
| Do not delete | Theater dialogs, controller, entities, repository, `theater_schedule_case_form.dart` |

## Cleanup: Remove Stale Code

- [ ] Remove `AppWorkspace` wrapper and `appWorkspaceToolbarWithLabels` call from `_TheaterWorkspaceContentState.build`
- [ ] Remove summary-notification list (All cases / Scheduled / In theater / Ready / Completed chips)
- [ ] Remove any now-unused imports (`AppRouteIcons` if only used for workspace leading icon; layout toolbar helpers if unused)
- [ ] Do **not** leave a duplicate Refresh or Schedule case control above the tab strip
- [ ] Do **not** leave a header more-menu
- [ ] Confirm no dead private helpers that only supported summary notifications

## Database Migrations

No database migrations required — schema unchanged. This is a Flutter UI chrome refactor only.

## Responsive Design Requirements

- Desktop (≥1024px): full `AppTabStrip` + toolbar row; table with all case-board columns; Filters + Settings in table search chrome.
- Tablet (600–1023px): horizontal-scroll tabs if needed; toolbar wraps via `AppTabStrip` `Wrap`; table remains primary.
- Mobile (<600px): keep existing `mobileItemBuilder` (`_TheaterCaseListTile`); tabs remain at top; toolbar under tabs; no separate title header; no FAB.

Follow `ResponsivePage` / `PageMaxWidth.dataHeavy` and theme spacing (`theme.spacing.sm` under tabs) already used by Reception.

## Verification Steps

Run from `frontend/`:

```bash
dart format .
dart analyze --fatal-infos
flutter test test/features/theater/
flutter test test/shared/
```

## Testing Requirements

- [ ] Tab switch updates URL (`?section=`) and rebuilds toolbar actions from `_section`
- [ ] Deep link `/theater?section=in-theater` opens In theater tab with correct filter
- [ ] Per-tab toolbar shows that tab’s primary/secondary set (Schedule case + Refresh when write-allowed)
- [ ] Read-only user still sees at least Refresh in the tab toolbar
- [ ] Table chrome has only Filters + Settings (plus search); labels are exactly **Filters** and **Settings**
- [ ] No screen title/header chrome remains on success path (`AppWorkspace` gone)
- [ ] At least one toolbar button exists on the screen
- [ ] Permissions still gate Schedule case (`clinicalWrite`)
- [ ] Case detail deep link (`id` + `panel`) and schedule deep link (`action=schedule`) still work
- [ ] Responsive layouts still work (including narrow viewport test)

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md`
- [ ] Uses `AppTabStrip` with contextual toolbar under tabs
- [ ] No dedicated header; no stray actions; no header more-menu
- [ ] Domain logic preserved (filters, counts, dialogs, deep links, realtime refresh)
- [ ] Analyze clean; tests pass; stale code removed
