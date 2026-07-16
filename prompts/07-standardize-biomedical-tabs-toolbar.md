# Standardize Biomedical Screen (Tabs & Toolbar)

## Objective

Refactor the Biomedical workspace (`/biomedical`, `BiomedicalWorkspacePage`) so its chrome fully complies with `prompt.md`:
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

**Scope boundary:** Restructure Biomedical **screen chrome/layout only**. Do not rewrite asset
detail dialogs, `_BiomedicalActionDialog` mutation forms, print helpers, repository APIs, or
realtime refresh plumbing unless required to keep chrome wiring compiling. Preserve permissions,
panel/resource filtering, pagination, search/advanced filters, queue deep-links, and row → detail
behavior.

**Do not invent new tab/table/search/filter chrome.** Reuse the shared components listed below.

## Current State (from audit)

### Primary files

- Page: `frontend/lib/features/biomedical/presentation/pages/biomedical_workspace_page.dart`
  - Public widget: `BiomedicalWorkspacePage` (`initialQuery: BiomedicalRouteQuery?`)
  - Content: `_BiomedicalWorkspaceContent` / `_BiomedicalWorkspaceContentState`
  - Single shared `AppListTable<BiomedicalAsset>` for all panels (columns swap via `_columnsForPanel`)
  - Detail + mutation dialogs live in the same file (`_openAssetDetailDialog`, `_DetailActions`,
    `_BiomedicalActionDialog`, `_openActionDialog`) — **do not** promote detail-scoped write
    actions into the screen tab toolbar
- Controller: `frontend/lib/features/biomedical/presentation/controllers/biomedical_workspace_controller.dart`
  - Provider: `biomedicalWorkspaceControllerProvider`
  - Key methods: `refresh()`, `applySearch`, `applyPanel`, `applyQueue`, `applyFilters`,
    `clearFilters`, `changePage`, `selectAsset`, plus mutation methods (`saveAsset`,
    `scheduleMaintenance`, `saveWorkOrder`, `recordCalibration`, `createFaultReport`, …)
- Domain: `frontend/lib/features/biomedical/domain/entities/biomedical_entities.dart`
  - Panels: `BiomedicalPanels` (`overview`, `registry`, `preventive`, `work-orders`,
    `compliance`, `support`, `analytics`)
  - Route query: `BiomedicalRouteQuery.fromUri` parses `panel`, `search`, `asset`
  - Default workspace query panel: `BiomedicalPanels.registry`
- Repository: `frontend/lib/features/biomedical/data/repositories/biomedical_repository_impl.dart`
  - Provider: `biomedicalRepositoryProvider`
- Route: `AppRoutes.biomedical` path `/biomedical` in `frontend/lib/app/router/app_routes.dart`
  - Roles: `biomedicalWorkspaceRoles`; module: `biomedical-engineering-suite`
- Router builder: `frontend/lib/app/router/app_router.dart` passes
  `BiomedicalRouteQuery.fromUri(state.uri)` into `BiomedicalWorkspacePage`
- Write gate (page-level constants today):
  ```dart
  static const AccessRequirement _writeRequirement = AccessRequirement(
    anyPermissions: <AppPermission>[
      AppPermissions.biomedWrite,
      AppPermissions.operationsWrite,
    ],
    activeModules: <String>['biomedical-engineering-suite'],
  );
  static const AccessRequirement _printRequirement = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.evidenceExport],
    anyPermissions: <AppPermission>[
      AppPermissions.biomedRead,
      AppPermissions.biomedWrite,
      AppPermissions.operationsRead,
      AppPermissions.operationsWrite,
    ],
    activeModules: <String>['biomedical-engineering-suite'],
  );
  ```
- Tests today:
  - `frontend/test/features/biomedical/presentation/biomedical_workspace_page_test.dart`
    (tabs, URL `panel` sync, deep link, per-panel primary tooltips, filters tooltip
    **“Biomedical filters”**, search, row detail, mobile `AppTabStrip`)
  - `frontend/test/features/biomedical/presentation/biomedical_workspace_controller_test.dart`
  - `frontend/test/features/biomedical/data/biomedical_dtos_test.dart`

### Current widget tree (chrome) — non-compliant

```
AsyncStateScaffold<BiomedicalWorkspaceState>
  └── AppWorkspace(
        title: l10n.biomedicalTitle,          // title passed; showHeader defaults false
        leadingIcon: AppRouteIcons.biomedical,
        toolbar: appWorkspaceToolbarWithLabels(  // ← renders ABOVE tabs (violation)
          summaryNotifications: Total equipment / Overdue PM / Open WOs /
                                Critical downtime / Active recalls,
          showFaultReport: false,
          onRefresh: controller.refresh,
          isRefreshing: state.isRefreshing,
        ),
        body: Column(
          AppTabStrip(
            primaryAction: _primaryActionWidget(...),  // contextual for some panels
            // secondaryActions: NOT passed
          ),
          SizedBox(height: theme.spacing.sm),
          AppListTable<BiomedicalAsset>(...),
        ),
      )
```

Even with `showHeader: false`, `AppWorkspace` still mounts `AppWorkspaceToolbar` when `toolbar`
is non-null (`app_workspace.dart` toolbar-only branch). That puts Refresh / summary notification
chips **above** the tab strip — opposite of `prompt.md` (tabs first, toolbar immediately beneath
tabs).

### Confirmed tab inventory

Constants: `BiomedicalPanels` in `biomedical_entities.dart`.
Tab ids in `AppTabStrip` use the panel string constants (not Dart enum `.name`).

| # | Tab label (l10n → EN) | `BiomedicalPanels` value | Query `?panel=` written by `_updateUrlForPanel` | Default resource (`_defaultResourceForPanel`) | Current toolbar primary |
|---|----------------------|--------------------------|--------------------------------------------------|-----------------------------------------------|-------------------------|
| 1 | `biomedicalPanelOverview` → **Overview** | `overview` | `overview` | `equipment-work-orders` | **Create work order** (`biomedicalCreateWorkOrderAction`) → `_BiomedicalActionKind.workOrder` |
| 2 | `biomedicalPanelRegistry` → **Registry** | `registry` | *(omitted — default)* | `equipment-registries` | **Register asset** (`biomedicalRegisterAssetAction`) → `_BiomedicalActionKind.asset` |
| 3 | `biomedicalPanelPreventive` → **Preventive** | `preventive` | `preventive` | `equipment-maintenance-plans` | **Schedule maintenance** (`biomedicalScheduleMaintenanceAction`) → `_BiomedicalActionKind.maintenance` |
| 4 | `biomedicalPanelWorkOrders` → **Work orders** | `work-orders` | `work-orders` | `equipment-work-orders` | **Create work order** → `_BiomedicalActionKind.workOrder` |
| 5 | `biomedicalPanelCompliance` → **Compliance** | `compliance` | `compliance` | `equipment-calibration-logs` | **Record calibration** (`biomedicalRecordCalibrationAction`) → `_BiomedicalActionKind.calibration` |
| 6 | `biomedicalPanelSupport` → **Support** | `support` | `support` | `equipment-service-providers` | **`null`** (toolbar hidden) ❌ |
| 7 | `biomedicalPanelAnalytics` → **Analytics** | `analytics` | `analytics` | `equipment-utilization-snapshots` | **`null`** (toolbar hidden) ❌ |

Default `_currentPanel` and `BiomedicalWorkspaceQuery.panel` = `BiomedicalPanels.registry`.
`_updateUrlForPanel` only writes `panel` when the panel is **not** registry.

Deep-link tab state **is already URL-backed** via `?panel=…` and
`_updateUrlForPanel` → `GoRouter.replace` + `BiomedicalRouteQuery.fromUri`. Keep and strengthen;
do not invent a second query key.

Also parsed today (preserve):
- `search` → applied into `_searchController` on deep link
- `asset` → stored on `BiomedicalRouteQuery.assetId` but **not yet applied** in `_applyDeepLink`
  (optional harden: after workbench load, open matching asset detail if found — do not invent
  new APIs; only if a matching row is already in `state.workbench.assets`)

### Current tab toolbar (gaps)

`_primaryActionForPanel` / `_primaryActionWidget` today (write-gated via `AppAccessActionGate` +
`_writeRequirement`):

| Panel | Label | Handler | Problem |
|-------|-------|---------|---------|
| `registry` | Register asset | `_openActionDialog(..., asset)` | OK as primary — keep |
| `overview` / `work-orders` | Create work order | `_openActionDialog(..., workOrder)` | OK as primary — keep |
| `preventive` | Schedule maintenance | `_openActionDialog(..., maintenance)` | OK as primary — keep |
| `compliance` | Record calibration | `_openActionDialog(..., calibration)` | OK as primary — keep |
| `support` / `analytics` | *(none)* | — | **Violates** “≥1 toolbar button” when these tabs are active |

`secondaryActions`: **empty** (not passed).

Existing widget tests explicitly assert Support/Analytics hide all write primaries — after this
refactor those tabs must still lack write primaries, but **must** show at least Refresh (and
optionally Report fault) so the toolbar is never empty.

### Current `AppWorkspace` toolbar (must relocate then remove)

From `appWorkspaceToolbarWithLabels` on the page:

1. **Refresh** — `onRefresh: controller.refresh` / `isRefreshing: state.isRefreshing`
2. **Summary notifications** (always listed; act as queue/panel jumps):
   - Total equipment → `_switchPanel(registry)` + URL update
   - Overdue PM → `_applyQueue(..., BiomedicalQueues.overduePm)`
   - Open work orders → `_applyQueue(..., BiomedicalQueues.openWorkOrders)`
   - Critical downtime → `_applyQueue(..., BiomedicalQueues.criticalDowntime)`
   - Active recalls → `_applyQueue(..., BiomedicalQueues.recallActions)`
3. **Global fault report** — explicitly `showFaultReport: false` (do **not** reintroduce the
   global workspace fault-report button; Biomedical already has domain `createFaultReport` /
   `biomedicalReportFaultAction` for an explicit Biomedical fault action if needed)

There is **no** overflow / more menu on Biomedical today — do not create one. Summary chips must
become **visible** `AppTabToolbarAction`s (or tab count badges), never a notifications overflow.

### Current table chrome (gaps)

In the page `AppListTable<BiomedicalAsset>`:

- Search: `AppListTableSearch` with `biomedicalSearchLabel` / `biomedicalSearchHint` — keep
- Filters: `showAdvancedFilterButton: true` with
  `advancedFilterButtonLabel: l10n.biomedicalFiltersLabel` → English today **“Biomedical filters”**
  (must become standardized **“Filters”**)
  - Dialog title currently also uses `biomedicalFiltersLabel` — set button label to **Filters**;
    dialog title may stay descriptive or also use **Filters** for consistency
  - Filter groups (Status / Priority / Facility / Due-date preset): **preserve** behavior;
    panel is selected via tabs only (tests assert Panel is absent from the filter dialog)
- Settings: `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` → English today
  **“Table settings”** (must become standardized **“Settings”** per `prompt.md`)
- No Refresh / Register / etc. in the table trailing chrome today (good once labels are fixed)

### Concrete `prompt.md` gaps to close

1. **`AppWorkspace` toolbar sits above tabs** — dual chrome; tabs are not the top chrome.
2. **Summary notification chips live above tabs** — relocate as visible tab-toolbar secondaries
   (conditional on count &gt; 0) and/or as tab count badges; remove workspace summary chrome.
3. **Support / Analytics have no toolbar buttons** — add Refresh (and optional Report fault) so
   every tab retains ≥1 toolbar affordance.
4. **Filters label** is “Biomedical filters”, not **Filters**.
5. **Settings label** is “Table settings”, not **Settings**.
6. **`secondaryActions` unused** — Refresh + queue shortcuts must live under tabs.
7. Tests assert filter tooltip **“Biomedical filters”** and actionless Support/Analytics —
   rewrite those expectations after chrome changes.

## Reference Implementation

Read these files (do NOT modify them unless fixing shared bugs that block compliance):

- `prompt.md` (normative)
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` —
  canonical: `ResponsivePage` + `AppTabStrip` + `SizedBox(height: theme.spacing.sm)` + table;
  **no** page `AppWorkspace` toolbar
- `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart` —
  **copy this pattern** for per-tab `primaryAction` + `secondaryActions` helpers and table
  Filters labeled with `*FiltersLabel` = `"Filters"`
- `frontend/lib/shared/components/app_tab_strip.dart` —
  `AppTabStrip`, `AppTabItem`, `AppTabToolbarPrimary`, `AppTabToolbarAction`
- `frontend/lib/shared/layout/app_workspace.dart` — `showHeader` / toolbar-only behavior (do **not**
  reintroduce page title header; Biomedical must **stop** using `AppWorkspace` for this page chrome)
- `frontend/lib/shared/layout/app_workspace_toolbar.dart` — reference only; Biomedical page must
  stop using `appWorkspaceToolbarWithLabels` for screen chrome
- `frontend/lib/shared/layout/responsive_page.dart` — `ResponsivePage`, `PageMaxWidth`
- `frontend/lib/shared/components/app_list_table.dart` — `AppListTable`, `AppListTableSearch`, Settings
- `frontend/lib/shared/components/app_search_bar.dart` — Filters via `showAdvancedFilterButton` /
  `advancedFilterButtonLabel` / `filterGroups`
- `frontend/lib/core/permissions/access_gate.dart` — `AppAccessActionGate`
- `frontend/lib/core/responsive/app_breakpoints.dart` — breakpoint tokens used by `ResponsivePage`

## Target Architecture

### Tab Configuration

| Tab Name | Route / Query | Description | Toolbar primary | Toolbar secondary |
|----------|---------------|-------------|-----------------|-------------------|
| Overview | `/biomedical?panel=overview` | Cross-cutting equipment readiness worklist | **Create work order** — `AppTabToolbarPrimary` + `AppAccessActionGate(_writeRequirement)` → `_openActionDialog(..., workOrder)` (`biomedicalCreateWorkOrderAction`, icon `Icons.build_outlined`) | **Refresh** + conditional queue shortcuts (below) |
| Registry | `/biomedical` (default; omit `panel`) | Equipment registry list | **Register asset** — write-gated → `_openActionDialog(..., asset)` (`biomedicalRegisterAssetAction`, icon `Icons.add_box_outlined`) | **Refresh** + optional **Report fault** (`biomedicalReportFaultAction`, icon `Icons.report_problem_outlined`, write-gated → `_openActionDialog(..., fault)`) + conditional queue shortcuts |
| Preventive | `/biomedical?panel=preventive` | Maintenance plans / PM due | **Schedule maintenance** — write-gated → `_openActionDialog(..., maintenance)` (`biomedicalScheduleMaintenanceAction`, icon `Icons.event_repeat_outlined`) | **Refresh** + conditional queue shortcuts (especially Overdue PM) |
| Work orders | `/biomedical?panel=work-orders` | Open / in-progress work orders | **Create work order** — write-gated (same as Overview) | **Refresh** + conditional queue shortcuts (especially Open work orders) |
| Compliance | `/biomedical?panel=compliance` | Calibration / safety / downtime / recalls | **Record calibration** — write-gated → `_openActionDialog(..., calibration)` (`biomedicalRecordCalibrationAction`, icon `Icons.speed_outlined`) | **Refresh** + conditional queue shortcuts (especially Critical downtime / Active recalls) |
| Support | `/biomedical?panel=support` | Service providers / warranty / spare parts | **Refresh** — `AppTabToolbarPrimary` (`commonRefreshActionLabel`, icon `Icons.refresh`, `isLoading: state.isRefreshing`) → `controller.refresh()` (**not** write-gated) | Optional: **Report fault** as `AppTabToolbarAction` (write-gated). No empty toolbar. |
| Analytics | `/biomedical?panel=analytics` | Utilization snapshots | **Refresh** — same as Support | *(none required)* — Refresh alone satisfies ≥1 button |

**Conditional queue shortcut secondaries** — each as its own visible `AppTabToolbarAction`
(never a more-menu / notifications overflow). Include only when the corresponding summary count
&gt; 0. Reuse existing `_applyQueue` + `BiomedicalQueues` handlers:

| When | Label (l10n) | Icon (current) | Handler |
|------|--------------|----------------|---------|
| `overduePm > 0` | `biomedicalOverduePmSummaryLabel` | `Icons.event_busy_outlined` | `_applyQueue(..., BiomedicalQueues.overduePm)` |
| `openWorkOrders > 0` | `biomedicalOpenWorkOrdersSummaryLabel` | `Icons.build_outlined` | `_applyQueue(..., BiomedicalQueues.openWorkOrders)` |
| `criticalDowntime > 0` | `biomedicalCriticalDowntimeSummaryLabel` | `Icons.power_settings_new_outlined` | `_applyQueue(..., BiomedicalQueues.criticalDowntime)` |
| `activeRecalls > 0` | `biomedicalActiveRecallsSummaryLabel` | `Icons.campaign_outlined` | `_applyQueue(..., BiomedicalQueues.recallActions)` |

**Total equipment** summary chip: do **not** keep as a toolbar button (redundant with Registry tab).
Optionally surface `totalEquipment` as `AppTabItem.count` on the Registry tab only.

Notes:

- Use `AppTabToolbarPrimary` for the single right-aligned primary CTA and `AppTabToolbarAction`
  for left-cluster secondaries (matches `AppTabStrip` contract / HR pattern).
- Rebuild toolbar on panel change (`setState` already updates `_currentPanel`).
- Disable mutation primaries when `state.isMutating` (already done).
- **Never** leave both `primaryAction == null` and empty `secondaryActions` on any tab.
- **Do not** put detail-dialog actions (Edit asset, Transfer, Start WO, Print, etc.) into the
  tab toolbar — they stay in `_DetailActions`.
- Keep write-gating only on write primaries/secondaries; Refresh must remain available to readers.

### Routing

- Keep `/biomedical` registration in `app_router.dart` unchanged.
- Keep query key **`panel`** (written by `_updateUrlForPanel` / parsed by
  `BiomedicalRouteQuery.fromUri`).
- Canonical write values must remain:
  `overview` | *(omit for registry)* | `preventive` | `work-orders` | `compliance` |
  `support` | `analytics`
- On tab tap: keep `_switchPanel(tabId)` + `_updateUrlForPanel(tabId)` (already calls
  `controller.applyPanel`).
- On deep link: keep `_applyDeepLink` for `panel` + `search`; optionally harden `asset` as noted.
- When writing URL on tab change, continue omitting `panel` for the default Registry tab.

### Page Layout

Precise widget tree for `_BiomedicalWorkspaceContentState.build`:

1. Keep outer `AsyncStateScaffold<BiomedicalWorkspaceState>` (loading only — not a screen title bar).
2. Replace page-level `AppWorkspace(title:, toolbar:, …)` with Reception-style:
   ```dart
   ResponsivePage(
     maxWidth: PageMaxWidth.dataHeavy,
     child: SizedBox(
       width: double.infinity,
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.stretch,
         children: <Widget>[
           AppTabStrip(
             tabs: …,
             selectedId: _currentPanel,
             onTabTapped: …,
             primaryAction: _primaryActionWidget(l10n, state),
             secondaryActions: _secondaryActionsForPanel(l10n, state),
           ),
           SizedBox(height: theme.spacing.sm),
           Expanded( // or non-expanded if scrollable ResponsivePage requires it —
             // match Reception: table directly under spacing; if layout needs
             // fill-height, follow AppWorkspace scrollable:false + Expanded pattern
             // already used elsewhere. Prefer Reception's simple Column + table.
             child: AppListTable<BiomedicalAsset>(...),
           ),
         ],
       ),
     ),
   )
   ```
3. **No** FAB / floating header actions / overflow more-menu for screen actions.
4. **No** `AppWorkspace(showHeader: true)` and **no** `appWorkspaceToolbarWithLabels` on this page.

### Data & State Management

Reuse without redesign:

- `biomedicalWorkspaceControllerProvider` /
  `BiomedicalWorkspaceController` —
  `frontend/lib/features/biomedical/presentation/controllers/biomedical_workspace_controller.dart`
- `BiomedicalWorkspaceState` / `BiomedicalWorkspaceQuery` / `BiomedicalPanels` /
  `BiomedicalQueues` / `BiomedicalRouteQuery` —
  `frontend/lib/features/biomedical/domain/entities/biomedical_entities.dart`
- `appAccessPolicyProvider` + existing `_writeRequirement` / `_printRequirement`
- Local UI state already on the page: `_currentPanel`, `_searchController`,
  `_tableColumnController`, `_appliedRouteSignature`

Extract small private helpers on the page state class (same file is fine):

- `_primaryActionWidget` — already exists; extend Support/Analytics Refresh case
- `_secondaryActionsForPanel(AppLocalizations, BiomedicalWorkspaceState)` → `List<Widget>`
- Keep `_applyQueue`, `_switchPanel`, `_updateUrlForPanel`, `_openActionDialog`

## Implementation Steps

1. **Replace AppWorkspace chrome with ResponsivePage + AppTabStrip toolbar** — File:
   `frontend/lib/features/biomedical/presentation/pages/biomedical_workspace_page.dart`
   - Remove `AppWorkspace(...)`, `appWorkspaceToolbarWithLabels(...)`, `title`, `leadingIcon`,
     and `_summaryNotification` / summary-notification list from screen chrome.
   - Build success content with `ResponsivePage` → `Column` → `AppTabStrip` →
     `SizedBox(height: theme.spacing.sm)` → `AppListTable`.
   - Wire `primaryAction:` / `secondaryActions:` on `AppTabStrip`.
   - Drop unused imports (`AppRouteIcons` if only used for workspace leading, etc.) after cleanup.

2. **Contextualize toolbar per panel** — same file
   - Keep existing write primaries for Overview / Registry / Preventive / Work orders / Compliance.
   - For Support and Analytics: set primary to Refresh (`commonRefreshActionLabel`) **without**
     write gate; ensure tests no longer expect a completely empty toolbar.
   - Add `_secondaryActionsForPanel`: always include Refresh on tabs that already have a write
     primary; add conditional queue shortcut actions; optionally Report fault on Registry/Support.
   - Guarantee ≥1 toolbar button on every tab.

3. **Standardize table Filters / Settings labels** — same page + l10n ARB
   - Change `biomedicalFiltersLabel` English (and other locales as needed) to exactly **`Filters`**
     in `frontend/lib/l10n/app_en.arb` (and regenerate l10n, or edit generated files if that is
     this repo’s usual flow). Use that key for `advancedFilterButtonLabel` (and prefer the same
     for `advancedFilterTitle`).
   - For Settings: update `commonTableSettingsActionLabel` English to **`Settings`** if the shared
     key is already being standardized across workspaces; **or** keep using
     `commonTableSettingsActionLabel` and ensure its displayed English is **Settings**. Do not
     invent a parallel Settings control outside `AppListTable` column visibility.
   - Preserve filter groups, apply/reset labels (`opdApplyFiltersAction` /
     `opdClearFiltersAction`), search, pagination, column visibility storage keys
     (`biomedical_$_currentPanel` / `biomedical_cw_$_currentPanel`).

4. **Preserve domain behaviors**
   - Tab → `applyPanel` + URL `panel` sync
   - Queue shortcuts still call `_applyQueue` (which may switch panel + apply queue filter)
   - Row tap → `_openAssetDetailDialog` with write/print gates unchanged
   - Mutation dialogs / print / realtime refresh unchanged
   - Access modules / permissions unchanged

5. **Update tests** — File:
   `frontend/test/features/biomedical/presentation/biomedical_workspace_page_test.dart`
   - Assert headerless chrome: no `AppWorkspace` toolbar-above-tabs / no summary notification
     chrome on the success path (or assert `AppWorkspace` is absent).
   - Keep tab labels / URL `panel=work-orders` / deep-link tests.
   - Keep Register / Create WO / Schedule / Calibration tooltip assertions on their panels.
   - Update Support/Analytics test: expect Refresh tooltip/label present; still expect write
     primaries absent.
   - Update filter test: tap **Filters** (not tooltip `Biomedical filters`).
   - Assert Settings label **Settings** if tests look for the table settings control.
   - Keep mobile `AppTabStrip` viewport test.

6. **Format / analyze / test**
   ```bash
   dart format .
   dart analyze --fatal-infos
   flutter test test/features/biomedical/
   flutter test test/shared/
   ```

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` / `AppTabToolbarPrimary` / `AppTabToolbarAction` | `package:hosspi_hms/shared/components/app_tab_strip.dart` (via `components.dart`) | Tabs + contextual toolbar under tabs |
| `ResponsivePage` / `PageMaxWidth` | `package:hosspi_hms/shared/layout/responsive_page.dart` (via `layout.dart`) | Headerless page shell |
| `AppListTable` / `AppListTableSearch` / column visibility | `package:hosspi_hms/shared/components/app_list_table.dart` | Body table; Filters + Settings only |
| `AppSearchBarFilterGroup` / filter value types | `package:hosspi_hms/shared/components/app_search_bar.dart` | Advanced Filters dialog groups |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Gate write toolbar actions |
| `AsyncStateScaffold` | shared components / layout barrel | Loading / error shell (not a title bar) |
| `AppBreakpoints` | `package:hosspi_hms/core/responsive/app_breakpoints.dart` | Via `ResponsivePage` / theme spacing |

**Forbidden:** new custom tab bars, new header title widgets, new overflow “more” menus for screen
actions, reintroducing `AppWorkspace` toolbar-above-tabs for Biomedical, duplicating
filter/settings controls outside the table search chrome, promoting detail-dialog actions into
the tab toolbar.

## Files to Create / Modify / Delete

| Action | Path |
|--------|------|
| Modify | `frontend/lib/features/biomedical/presentation/pages/biomedical_workspace_page.dart` |
| Modify | `frontend/test/features/biomedical/presentation/biomedical_workspace_page_test.dart` |
| Modify | `frontend/lib/l10n/app_en.arb` (and other locale ARBs if required) — `biomedicalFiltersLabel` → `Filters`; Settings key English → `Settings` as decided above |
| Regenerate / sync | l10n generated Dart (`app_localizations*.dart`) per project convention |
| Do **not** modify | Reception / HR / `app_tab_strip.dart` unless fixing a shared bug that blocks compliance |
| Do **not** delete | Domain dialogs, controller, repository, DTO tests |

## Cleanup: Remove Stale Code

- [ ] Remove `AppWorkspace` wrapper and `appWorkspaceToolbarWithLabels` usage from Biomedical success chrome
- [ ] Remove `_summaryNotification` helper and any unused `AppWorkspaceSummaryNotification` imports/usages on this page (after relocating queue shortcuts)
- [ ] Remove unused `AppRouteIcons` / title-only imports if orphaned
- [ ] Ensure Support/Analytics no longer leave `AppTabStrip` with empty toolbar
- [ ] Update tests that assumed “Biomedical filters” tooltip or fully actionless Support/Analytics
- [ ] Confirm no overflow / more-menu was introduced for screen actions

## Database Migrations

No database migrations required — schema unchanged. This is a Flutter UI chrome/layout refactor only.

## Responsive Design Requirements

Follow `ResponsivePage` / `PageMaxWidth.dataHeavy` and `theme.spacing.sm` rhythm already used by Reception.

- Desktop (≥1024px): full tab strip + labeled toolbar actions + multi-column `AppListTable`
- Tablet (600–1023px): horizontal-scrolling tabs; toolbar wrap via `AppTabStrip` `Wrap`; table columns respect visibility controller
- Mobile (&lt;600px): keep `mobileItemBuilder: _BiomedicalAssetListTile`; `AppTabStrip` must still render (existing test at 390×844); toolbar actions remain under tabs (may wrap)

## Verification Steps

```bash
dart format .
dart analyze --fatal-infos
flutter test test/features/biomedical/
flutter test test/shared/
```

## Testing Requirements

- [ ] Tab switch updates URL (`?panel=`) and toolbar actions
- [ ] Deep link `/biomedical?panel=work-orders` opens Work orders with Create work order primary
- [ ] Default `/biomedical` shows Registry with Register asset primary and no `panel` query
- [ ] Per-tab toolbar shows only that tab’s actions; Support/Analytics show Refresh, not write primaries
- [ ] Queue shortcut secondaries appear only when summary counts &gt; 0 and still call `_applyQueue`
- [ ] Table chrome has only Filters + Settings (labels exactly **Filters** / **Settings**)
- [ ] No screen title/header chrome remains (`AppWorkspace` header/toolbar-above-tabs gone)
- [ ] At least one toolbar button exists on every tab
- [ ] Permissions still gate write actions (`AppAccessActionGate` + `_writeRequirement`)
- [ ] Detail dialog / print / search / pagination / realtime refresh still work
- [ ] Responsive layouts still work (including mobile tab strip test)

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md`
- [ ] Uses `AppTabStrip` with contextual toolbar under tabs (`primaryAction` / `secondaryActions`)
- [ ] No dedicated header; no stray actions; no header more-menu
- [ ] Domain logic preserved (panels, queues, dialogs, permissions, deep links)
- [ ] Analyze clean; tests pass; stale chrome code removed
