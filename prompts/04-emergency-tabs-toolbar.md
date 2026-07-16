# Standardize Emergency Screen (Tabs & Toolbar)

## Objective

Refactor the Emergency workspace (`/emergency`, `EmergencyWorkspacePage`) so its chrome fully complies with `prompt.md`:
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

Preserve Emergency domain behavior (board scopes, triage/ambulance/handoff flows, realtime
refresh, permissions, deep links). Restructure chrome/layout only unless a small wiring fix is
required for compliance (e.g. Closed-tab toolbar emptiness, Refresh secondary).

## Current State (from audit)

### Primary files

- Page: `frontend/lib/features/emergency/presentation/pages/emergency_workspace_page.dart`
  - `EmergencyWorkspacePage` → `AsyncStateScaffold` → `_EmergencyWorkspaceContent`
- Widgets / labels / columns / detail actions:
  `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart`
  (`EmergencyText`, column builders, `EmergencyDetailPanel`, `openEmergencyDetailDialog`,
  unused leftover `scopeOptions()`)
- Dialogs: `frontend/lib/features/emergency/presentation/widgets/emergency_dialogs.dart`
  (`QuickArrivalDialog`, handoff/dispatch dialogs)
- Controller: `frontend/lib/features/emergency/presentation/controllers/emergency_workspace_controller.dart`
  (`emergencyWorkspaceControllerProvider`, `applyScope`, `applySearch`, `refresh`,
  `createQuickArrival`, realtime polling)
- Entities / query: `frontend/lib/features/emergency/domain/entities/emergency_entities.dart`
  - `EmergencyBoardTab` / `EmergencyBoardScope`: `active`, `critical`, `ambulance`, `handoff`, `closed`, `all`
  - `EmergencyWorkspaceQuery.fromUri` parses `scope|board|tab`, `id|case|…`, `search|q|…`, `panel|focus|action`
- Routes: `AppRoutes.emergency` path `/emergency` in
  `frontend/lib/app/router/app_routes.dart`; builder in
  `frontend/lib/app/router/app_router.dart` passes `EmergencyWorkspaceQuery.fromUri(state.uri)`
- Tests: `frontend/test/features/emergency/emergency_handoff_test.dart` (query/handoff coverage)

### Current widget tree (chrome)

1. `AsyncStateScaffold` (loading / error / retry — not a screen title bar)
2. `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)`
3. `Column` → `AppTabStrip` → `SizedBox(height: theme.spacing.sm)` → `AppListTable<EmergencyCaseSummary>`
4. **No** `AppWorkspace` wrapper and **no** dedicated page title/header (already aligned with Reception)

### Tabs (validated)

| # | Tab label (UI) | Enum `EmergencyBoardTab` | URL query | Count source |
|---|----------------|--------------------------|-----------|--------------|
| 1 | Active cases | `active` | `?scope=active` | `state.activeCount` |
| 2 | Critical | `critical` | `?scope=critical` | `state.criticalCount` |
| 3 | Ambulance | `ambulance` | `?scope=ambulance` | `state.ambulanceCount` |
| 4 | Handoff ready | `handoff` | `?scope=handoff` | `state.handoffCount` |
| 5 | Closed | `closed` | `?scope=closed` | `state.closedCount` |
| 6 | All | `all` | `?scope=all` | `state.allCount` |

Tab switch already calls `_updateUrlForTab` → `AppRoutes.emergency.location(queryParameters: {'scope': tab.name})` via `GoRouter.replace`, then `controller.applyScope(_boardScopeForTab(tab))`.

### Current toolbar

- `primaryAction`: `AppAccessActionGate` (`AppPermissions.emergencyWrite`) wrapping
  `AppTabToolbarPrimary(label: EmergencyText.quickArrival, icon: Icons.add_circle_outline)` →
  `_openQuickArrivalDialog` → `QuickArrivalDialog` → `createQuickArrival`
- **Omitted on Closed** (`_currentTab != EmergencyBoardTab.closed ? … : null`)
- `secondaryActions`: **none** (no Refresh in tab toolbar)
- No header overflow / FAB / more-menu for screen actions

### Table chrome

- Search via `AppListTableSearch` (`EmergencyText.searchHint`)
- Column visibility labeled with `context.l10n.commonTableSettingsActionLabel`
- **No** `filterGroups` / `textFilters` → Filters button correctly absent until real filters exist
- No other table-header actions beyond Settings (compliant if Filters stay out unless wired)

### Concrete `prompt.md` gaps

1. **Closed tab has empty toolbar** (`primaryAction: null`, no `secondaryActions`) — `AppTabStrip`
   omits the toolbar row. Screen still has Quick arrival on other tabs (satisfies “at least one
   button somewhere”), but Closed is actionless and peers (e.g. Access Admin) expose Refresh on
   every tab.
2. **Toolbar is only weakly contextual** — Quick arrival is identical on Active / Critical /
   Ambulance / Handoff / All; only Closed differs. Need an explicit per-tab matrix including a
   universal Refresh secondary.
3. **No Refresh secondary** — manual refresh exists only via `AsyncStateScaffold` retry / controller
   realtime; Access Admin pattern uses `AppTabToolbarAction` + `commonRefreshActionLabel`.
4. **Tab label consistency** — “Active cases” and “Handoff ready” are hardcoded; others use
   `EmergencyText` (`critical`, `ambulance`, `closed`, `all`). `EmergencyText.active` is `"Active"`
   and `EmergencyText.handoff` is `"Handoff"` (not the tab labels). Keep current UX labels but
   centralize them on `EmergencyText` (or dedicated constants) so naming is consistent.
5. **Dead / stale board-scope UI** — `scopeOptions()` in `emergency_workspace_widgets.dart` is a
   leftover select list for board scope; tabs replaced it. Remove if unused after grep confirmation.
6. **Deep-link `panel` parsed but not applied** — `EmergencyWorkspaceQuery.panel` is in the
   signature / `fromUri`, but `openEmergencyDetailDialog` does not focus triage/response/ambulance/handoff.
   Do **not** invent UI chrome for this; either leave as known domain follow-up **or** wire focus
   inside the existing detail dialog without adding screen-header actions.
7. **Already compliant (do not regress):** no dedicated title header; `AppTabStrip` under
   `ResponsivePage`; table limited to search + Settings; write actions gated; deep-link `?scope=`.

## Reference Implementation

Read these files (do NOT modify them unless fixing shared bugs that block compliance):

- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
  — canonical layout: `ResponsivePage` + `AppTabStrip` + `SizedBox(sm)` + `AppListTable`;
  `primaryAction` via `AppAccessActionGate` + `AppTabToolbarPrimary`; query-backed tabs
- `frontend/lib/features/access_admin/presentation/pages/access_admin_workspace_page.dart`
  — Refresh as `AppTabToolbarAction` in `secondaryActions` with `l10n.commonRefreshActionLabel`
- `frontend/lib/shared/components/app_tab_strip.dart`
  — `AppTabStrip`, `AppTabItem`, `AppTabToolbarPrimary`, `AppTabToolbarAction`
- `frontend/lib/shared/layout/app_workspace.dart` — `showHeader: false` default (Emergency does not
  need `AppWorkspace` if it keeps the Reception `ResponsivePage` pattern)
- `frontend/lib/shared/layout/responsive_page.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/core/permissions/access_gate.dart` — `AppAccessActionGate`
- `frontend/lib/core/responsive/app_breakpoints.dart`
- `prompt.md`

## Target Architecture

### Tab Configuration

| Tab Name | Route / Query | Description | Toolbar primary | Toolbar secondary |
|----------|---------------|-------------|-----------------|-------------------|
| Active cases | `/emergency?scope=active` | Open emergency cases | **Quick arrival** (`EmergencyText.quickArrival`), gated by `AppPermissions.emergencyWrite`, opens `QuickArrivalDialog` | **Refresh** (`l10n.commonRefreshActionLabel`) → `controller.refresh()` |
| Critical | `/emergency?scope=critical` | Open + critical acuity | **Quick arrival** (same as Active) | **Refresh** |
| Ambulance | `/emergency?scope=ambulance` | Cases with dispatch / trip activity | **Quick arrival** (same as Active) | **Refresh** |
| Handoff ready | `/emergency?scope=handoff` | Cases ready for handoff | **Quick arrival** (same as Active) | **Refresh** |
| Closed | `/emergency?scope=closed` | Closed / completed cases | *none* (`primaryAction: null`) — do not offer Quick arrival on closed board | **Refresh** (required so Closed is not toolbar-empty) |
| All | `/emergency?scope=all` | Full board | **Quick arrival** (same as Active) | **Refresh** |

**Rules for the matrix**

- Do **not** move case-level detail actions (Priority, Triage, Response, Dispatch, Trip, Handoff,
  Schedule in Theater, Print summary) from `EmergencyDetailPanel` / `AppActionPanel` into the
  screen toolbar — those remain row/detail scoped.
- Do **not** reintroduce a board-scope dropdown or header more-menu.
- Screen must always expose at least one toolbar control overall (Quick arrival + Refresh satisfy this).
- Closed must show Refresh so the toolbar row is not omitted on that tab.

### Routing

- Keep `/emergency` registration in `app_router.dart` / `AppRoutes.emergency`.
- Keep query key **`scope`** with values equal to `EmergencyBoardTab.name`
  (`active|critical|ambulance|handoff|closed|all`).
- Keep aliases already supported by `EmergencyWorkspaceQuery.fromUri`: `board`, `tab` → scope;
  `id`/`case`/… → case deep link; `search`/`q`/`patient`; `panel`/`focus`/`action`.
- On tab tap: continue `GoRouter.replace` to `AppRoutes.emergency.location(queryParameters: {'scope': tab.name})`
  then `applyScope`. Do not drop `scope` from the URL when switching tabs.
- Default tab when no query: `EmergencyBoardTab.active` (current behavior).

### Page Layout

Precise widget tree (match Reception; do not add a title header):

1. `AsyncStateScaffold<EmergencyWorkspaceState>(...)` (unchanged role)
2. Inside `dataBuilder` → `_EmergencyWorkspaceContent`:
   - `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy, child: SizedBox(width: infinity, child: Column(...)))`
   - `AppTabStrip(tabs:, selectedId: _currentTab.name, onTabTapped:, primaryAction:, secondaryActions:)`
   - `SizedBox(height: theme.spacing.sm)` — keep vertical rhythm identical to Reception
   - Body: single `AppListTable<EmergencyCaseSummary>` with search + **only** Settings (and Filters
     only if you add real `filterGroups`/`textFilters`; label must be exactly **Filters** via an
     existing l10n key such as `nursingAdvancedFiltersLabel` or a shared common Filters key if one
     exists — do **not** invent a third table action)
3. No FAB / floating header actions / overflow more-menu for screen actions
4. Do **not** wrap with `AppWorkspace(showHeader: true)`. If you introduce `AppWorkspace`, it must
   be `showHeader: false` and must not duplicate the tab toolbar.

### Data & State Management

Reuse as-is (adjust only call sites for toolbar Refresh):

- Provider: `emergencyWorkspaceControllerProvider` in
  `frontend/lib/features/emergency/presentation/controllers/emergency_workspace_controller.dart`
- Methods: `refresh()`, `applyScope(EmergencyBoardScope)`, `applySearch(String)`,
  `createQuickArrival(EmergencyQuickArrivalInput)`, `selectCase`, mutation helpers
- Row filtering in page `_buildRows` + server/client scope in repository
  (`emergency_repository_impl.dart`) — do not change scope semantics
- Permissions: `AccessRequirement(anyPermissions: [AppPermissions.emergencyWrite])` for Quick arrival
- Realtime: existing `RealtimeEventGroups.emergencyWorkspace` / adaptive polling — preserve

## Implementation Steps

1. **Centralize tab labels on `EmergencyText`** — File:
   `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart`
   - Add constants used by tabs, e.g. `activeCases = 'Active cases'`,
     `handoffReady = 'Handoff ready'` (keep current UX copy).
   - Point `_tabLabel` in `emergency_workspace_page.dart` at these constants for all six tabs
     so labels are not mixed hardcoded/scattered.

2. **Build contextual toolbar helpers on the page** — File:
   `frontend/lib/features/emergency/presentation/pages/emergency_workspace_page.dart`
   - Add `_buildPrimaryAction(BuildContext context)` returning:
     - `null` when `_currentTab == EmergencyBoardTab.closed`
     - otherwise the existing `AppAccessActionGate` + `AppTabToolbarPrimary` Quick arrival block
   - Add `_buildSecondaryActions(BuildContext context)` returning:
     ```dart
     <Widget>[
       AppTabToolbarAction(
         label: context.l10n.commonRefreshActionLabel,
         icon: Icons.refresh,
         enabled: !state.isRefreshingBoard,
         onPressed: state.isRefreshingBoard
             ? null
             : () => unawaited(controller.refresh()),
       ),
     ]
     ```
   - Wire into `AppTabStrip(primaryAction: …, secondaryActions: …)`.
   - Import `AppTabToolbarAction` via existing `package:hosspi_hms/shared/components/components.dart`
     (already imported). Prefer `AppTabToolbarAction` (Access Admin) over
     `AppWorkspaceRefreshAction` so Refresh sits in the left secondary cluster consistently.

3. **Keep table chrome limited to Filters + Settings** — same page file + `AppListTable`
   - Retain `columnVisibilityLabel: context.l10n.commonTableSettingsActionLabel`.
   - Do not add Export / Print / Quick arrival / Refresh into the table search trailing actions.
   - Only add Filters if implementing real filter groups; otherwise leave Filters absent (same as
     Reception). If adding Filters, use the standardized label **Filters** and keep Settings.

4. **Preserve deep-link + tab URL behavior** — same page file
   - Keep `_applyDeepLink`, `_updateUrlForTab`, `_tabFromScopeValue`, case-id → All + detail dialog.
   - Optionally: if `query.panel != none` after opening detail, scroll/focus the matching action in
     `EmergencyDetailPanel` — only if low-risk; do not block chrome work on this.

5. **Cleanup stale board-scope UI** — `emergency_workspace_widgets.dart`
   - Grep for `scopeOptions` / `EmergencyText.boardScope`. If unused, delete `scopeOptions()` and
     unused strings only if nothing else references them.

6. **Tests** — extend `frontend/test/features/emergency/`
   - Keep existing `EmergencyWorkspaceQuery.fromUri` scope tests.
   - Add widget/unit coverage where practical for: tab id → scope query value mapping helpers;
     Closed tab has no Quick arrival primary; Refresh present for all tabs (if helpers are
     testable without full widget pump; otherwise document verification via analyze + existing tests).

7. **Format / analyze / test** — run verification commands below; fix any issues introduced.

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` / `AppTabToolbarPrimary` / `AppTabToolbarAction` | `package:hosspi_hms/shared/components/app_tab_strip.dart` (via `components.dart`) | Tabs + contextual toolbar |
| `AppListTable` / `AppListTableSearch` / column visibility | `package:hosspi_hms/shared/components/app_list_table.dart` | Board table; Settings only |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Gate Quick arrival |
| `ResponsivePage` / `PageMaxWidth` | `package:hosspi_hms/shared/layout/responsive_page.dart` (via `layout.dart`) | Page shell without title header |
| `AsyncStateScaffold` | shared components barrel | Loading / error / retry |
| `AppDialog` / form fields | shared components / forms | Quick arrival + detail dialogs |
| `AppBreakpoints` | `package:hosspi_hms/core/responsive/app_breakpoints.dart` | Existing responsive behavior via `ResponsivePage` |
| l10n `commonRefreshActionLabel` / `commonTableSettingsActionLabel` | `context.l10n` | Refresh + table Settings labels |

**Forbidden:** new custom tab strip, duplicate page header, table overflow menus for screen actions,
reintroducing board-scope dropdown as chrome, moving detail `AppActionPanel` items into the tab toolbar.

## Files to Create / Modify / Delete

### Modify

| File | Change |
|------|--------|
| `frontend/lib/features/emergency/presentation/pages/emergency_workspace_page.dart` | Contextual `primaryAction` / `secondaryActions` (Refresh all tabs; Quick arrival except Closed); centralize tab labels |
| `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` | Add tab label constants; remove dead `scopeOptions()` if unused |
| `frontend/test/features/emergency/emergency_handoff_test.dart` and/or new test file | Cover scope query + toolbar matrix helpers if extracted |

### Create

| File | Change |
|------|--------|
| None required for chrome compliance | Optional small test file only if helpers are extracted |

### Delete

| File / symbol | Change |
|---------------|--------|
| `scopeOptions()` (and unused `EmergencyText.boardScope` if orphaned) | Remove after confirming no references |

## Cleanup: Remove Stale Code

- [ ] Confirm no leftover header/title widgets under Emergency presentation
- [ ] Remove unused `scopeOptions()` / board-scope select chrome
- [ ] Ensure no second toolbar row outside `AppTabStrip`
- [ ] Ensure no `PopupMenuButton` / more_vert screen actions for board-level actions
- [ ] Ensure Closed does not show Quick arrival
- [ ] Grep Emergency feature for `showHeader: true` / custom `AppBar` — none should remain for this page

## Database Migrations

No database migrations required — schema unchanged. This is a Flutter chrome/layout refactor only.

## Responsive Design Requirements

Follow existing `ResponsivePage` + `AppTabStrip` + `AppListTable` behavior (same as Reception):

- **Desktop (≥1024px / large breakpoints):** tab strip horizontal scroll if needed; toolbar shows
  icon+label actions; table columns per `_columnsForTab`; action labels per
  `AppBreakpoint.showsToolbarActionLabels`
- **Tablet (600–1023px):** same column layout; compact toolbar labels as breakpoint dictates;
  retain `SizedBox(height: theme.spacing.sm)` under tabs
- **Mobile (<600px):** `AppListTable.mobileItemBuilder` (`_mobileItemBuilder`) remains the row UI;
  tabs stay horizontally scrollable; toolbar wraps via `AppTabStrip` `Wrap`; no separate mobile title header

Do not add a mobile-only app bar title for Emergency.

## Verification Steps

Run from `frontend/`:

```bash
dart format .
dart analyze --fatal-infos
flutter test test/features/emergency/
flutter test test/shared/
```

## Testing Requirements

- [ ] Tab switch updates URL `?scope=<tab.name>` and swaps toolbar (Closed drops Quick arrival; Refresh remains)
- [ ] Deep link `/emergency?scope=critical` opens Critical tab
- [ ] Deep link `/emergency?scope=closed` opens Closed with Refresh visible and no Quick arrival
- [ ] Per-tab toolbar shows only that tab’s actions per the matrix above
- [ ] Table chrome has only Settings (and Filters only if filters were intentionally added)
- [ ] No screen title/header chrome remains
- [ ] At least one toolbar button exists on the screen (Quick arrival and/or Refresh)
- [ ] Permissions still gate Quick arrival via `AppAccessActionGate` / `emergencyWrite`
- [ ] Responsive layouts still work (desktop table / mobile cards)
- [ ] Case detail actions still work from the detail dialog (`EmergencyDetailPanel`)
- [ ] Realtime / `refresh()` still reload the board

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md`
- [ ] Uses `AppTabStrip` with contextual toolbar under tabs (`primaryAction` / `secondaryActions`)
- [ ] No dedicated header; no stray actions; no header more-menu
- [ ] Domain logic preserved (scopes, counts, dialogs, permissions, deep links)
- [ ] Analyze clean; tests pass; stale board-scope UI removed
- [ ] Closed tab is not toolbar-empty (Refresh secondary)
- [ ] Quick arrival remains the primary CTA on all non-Closed tabs
- [ ] Table area does not host Quick arrival / Refresh / other non-Filters/Settings actions
