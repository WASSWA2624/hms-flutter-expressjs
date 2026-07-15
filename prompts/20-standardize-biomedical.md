# Standardize Biomedical Screen

## Objective

Refactor the Biomedical workspace to match the standardized tab-and-table layout used by the Reception workspace. The Biomedical screen currently uses a filter-dropdown panel selector (`AppSearchBarFilterGroup` with a `_panelFilterKey`) to switch between logical panels (Registry, Overview, Preventive, Work Orders, Compliance, Support, Analytics). This refactor will replace that mechanism with routable `AppTabStrip` tabs, each with its own URL query parameter, tab-specific table columns, and a contextual primary action button — matching the Reception workspace's deep-linkable tab-and-table pattern. The `AppWorkspace` toolbar with summary notifications will be preserved since it is a shared component; the change is limited to the body layout switching from a single flat worklist to a tabbed structure with per-tab column sets.

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification — all information needed is in this prompt. Run tests and formatting after implementation.

## Current State (from audit)

### Files

| File | Purpose |
|------|---------|
| `frontend/lib/features/biomedical/presentation/pages/biomedical_workspace_page.dart` | Main page widget (~2091 lines). Contains `BiomedicalWorkspacePage`, `_BiomedicalWorkspaceContent`, `_BiomedicalWorklistPanel`, `_BiomedicalDetailPanel`, `_DetailActions`, `_BiomedicalActionDialog`, and many private helpers. |
| `frontend/lib/features/biomedical/presentation/controllers/biomedical_workspace_controller.dart` | `BiomedicalWorkspaceController` — AsyncNotifier managing `BiomedicalWorkspaceState` with query-based filtering, real-time sync, adaptive polling, and mutation methods. |
| `frontend/lib/features/biomedical/domain/entities/biomedical_entities.dart` | Domain entities: `BiomedicalPanels`, `BiomedicalResources`, `BiomedicalQueues`, `BiomedicalDatePresets`, `BiomedicalWorkspaceQuery`, `BiomedicalWorkspaceState`, `BiomedicalWorkbench`, `BiomedicalSummary`, `BiomedicalAsset`, etc. |
| `frontend/lib/features/biomedical/data/dtos/biomedical_dtos.dart` | DTOs: `BiomedicalWorkbenchDto`, `BiomedicalAssetDto`, `BiomedicalMutationResultDto`, etc. |
| `frontend/lib/features/biomedical/domain/repositories/biomedical_repository.dart` | Repository interface. |
| `frontend/lib/features/biomedical/data/repositories/biomedical_repository_impl.dart` | Repository implementation with API client. |
| `frontend/lib/app/router/app_router.dart` | Route definition — simple `GoRoute` at `/biomedical` with no sub-routes, no query extraction. |
| `frontend/lib/app/router/app_routes.dart` | `AppRoutes.biomedical` — route metadata, `requiresTenantContext` is not explicitly set. |
| `frontend/test/features/biomedical/presentation/biomedical_workspace_controller_test.dart` | Controller tests. |
| `frontend/test/features/biomedical/data/biomedical_dtos_test.dart` | DTO tests. |
| `frontend/patrol_test/biomedical_flow_test.dart` | Patrol integration test. |

### Current layout/structure

- `BiomedicalWorkspacePage` wraps everything in an `AsyncStateScaffold<BiomedicalWorkspaceState>`.
- `_BiomedicalWorkspaceContent` uses `AppWorkspace` with `appWorkspaceToolbarWithLabels` providing:
  - 5 summary notification tiles (Total Equipment, Overdue PM, Open Work Orders, Critical Downtime, Active Recalls).
  - A primary "Register Asset" button in the toolbar.
  - A refresh button.
- The body is a single `_BiomedicalWorklistPanel` containing one `AppListTable<BiomedicalAsset>` with:
  - Server-side search via `onSubmitted: controller.applySearch`.
  - Filter groups including a **panel filter** (`_panelFilterKey`) to switch between panels, plus status, priority, facility, and date preset filters.
  - 8 table columns (asset_tag, equipment, category, location, risk, status, owner, next_action) — the same for all panels.
  - Server-side pagination via `onPageChanged: controller.changePage`.
  - Mobile list tile via `mobileItemBuilder`.
- Panel selection is done via a filter dropdown inside the search bar's advanced filter dialog — not via visible tabs.
- No URL deep-linking: switching panels does not update the URL.
- Row selection opens an `_BiomedicalDetailPanel` in a dialog (not inline).

### Problems/inconsistencies

1. **No routable tabs.** Panels are hidden inside the advanced filter dialog. Users cannot see which panel is active at a glance or bookmark/deep-link to a specific panel.
2. **Same columns for all panels.** The 8 columns are identical regardless of whether the user is viewing Registry, Work Orders, Compliance, or Analytics data — each panel's data has different meaningful columns.
3. **No URL update on panel switch.** Switching from Registry to Work Orders does not change the URL; deep-linking and back-button navigation are broken.
4. **No tab-specific primary action.** The "Register Asset" button is always shown regardless of the active panel; Work Orders should show "Create Work Order", Compliance should show "Record Calibration", etc.
5. **Reception uses `ResponsivePage` + `AppTabStrip`** for its tab structure. Biomedical uses `AppWorkspace` which is fine for the toolbar/summary area but the body should use the tab pattern.

## Reference Implementation

Read these files to understand the target patterns (do NOT modify them):

| File | What to extract |
|------|-----------------|
| `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` | Tab structure (`ReceptionDeskSection` enum → `AppTabStrip`), URL update via `GoRouter.of(context).replace<void>(location)` with `section` query param, tab-specific columns returned from `_columnsForSection()`, primary action button next to tab strip, `_BiomedicalWorkspaceContent` manages `_section` state and `_scheduleRouteQuery` for deep-link. |
| `frontend/lib/shared/components/app_tab_strip.dart` | `AppTabStrip` widget — constructor takes `tabs: List<AppTabItem>`, `selectedId: String`, `onTabTapped: ValueChanged<String>`. `AppTabItem` has `id`, `label`, `icon`. |
| `frontend/lib/shared/components/app_list_table.dart` | `AppListTable<T>` — accepts `items` or `page`, `columns`, `search` (`AppListTableSearch<T>`), `mobileItemBuilder`, `columnVisibilityController`, `columnVisibilityStorageKey`, `columnWidthStorageKey`, pagination controls. |
| `frontend/lib/shared/layout/app_workspace.dart` | `AppWorkspace` — provides title, leadingIcon, toolbar, body. Used for the summary notification toolbar. |
| `frontend/lib/shared/layout/responsive_page.dart` | `ResponsivePage` — wraps content with `maxWidth` constraint. |
| `frontend/lib/core/responsive/app_breakpoints.dart` | `AppBreakpoints.fromConstraints()` returns `AppBreakpoint.xs`, `sm`, `md`, `lg`, `xl`. |

## Target Architecture

### Tab Configuration

| Tab Name | Panel Constant | Route Query Value | Description | Primary Action Button |
|----------|---------------|-------------------|-------------|----------------------|
| Registry | `BiomedicalPanels.registry` | `registry` | Equipment asset registry | "Register Asset" → opens `_BiomedicalActionKind.asset` dialog |
| Overview | `BiomedicalPanels.overview` | `overview` | Cross-panel overview of active work | "Create Work Order" → opens `_BiomedicalActionKind.workOrder` dialog |
| Preventive | `BiomedicalPanels.preventive` | `preventive` | Maintenance plans and schedules | "Schedule Maintenance" → opens `_BiomedicalActionKind.maintenance` dialog |
| Work Orders | `BiomedicalPanels.workOrders` | `work-orders` | Active and completed work orders | "Create Work Order" → opens `_BiomedicalActionKind.workOrder` dialog |
| Compliance | `BiomedicalPanels.compliance` | `compliance` | Calibration, safety tests, incidents, recalls | "Record Calibration" → opens `_BiomedicalActionKind.calibration` dialog |
| Support | `BiomedicalPanels.support` | `support` | Service providers, warranty contracts, spare parts | (none — read-only reference data) |
| Analytics | `BiomedicalPanels.analytics` | `analytics` | Utilization snapshots | (none — read-only data) |

### Routing

**File to modify:** `frontend/lib/app/router/app_router.dart`

The current route is:

```dart
GoRoute(
  path: AppRoutes.biomedical.path,
  name: AppRoutes.biomedical.name,
  builder: (_, _) => const BiomedicalWorkspacePage(),
),
```

Change to extract `panel` query parameter and pass it as `initialQuery`:

```dart
GoRoute(
  path: AppRoutes.biomedical.path,
  name: AppRoutes.biomedical.name,
  builder: (_, GoRouterState state) => BiomedicalWorkspacePage(
    initialQuery: BiomedicalRouteQuery.fromUri(state.uri),
  ),
),
```

**Add `BiomedicalRouteQuery`** to `biomedical_entities.dart`:

```dart
@immutable
final class BiomedicalRouteQuery {
  const BiomedicalRouteQuery({
    this.panel = '',
    this.search = '',
    this.assetId = '',
  });

  final String panel;
  final String search;
  final String assetId;

  bool get hasRouteTargeting =>
      panel.isNotEmpty || search.isNotEmpty || assetId.isNotEmpty;

  String get signature => '$panel|$search|$assetId';

  factory BiomedicalRouteQuery.fromUri(Uri uri) {
    return BiomedicalRouteQuery(
      panel: uri.queryParameters['panel'] ?? '',
      search: uri.queryParameters['search'] ?? '',
      assetId: uri.queryParameters['asset'] ?? '',
    );
  }
}
```

### Page Layout

The widget tree structure should be:

```
BiomedicalWorkspacePage
└── AsyncStateScaffold<BiomedicalWorkspaceState>
    └── _BiomedicalWorkspaceContent (ConsumerStatefulWidget)
        └── AppWorkspace
            ├── toolbar: appWorkspaceToolbarWithLabels(...) [KEEP existing summary notifications]
            └── body: Column
                ├── Row
                │   ├── Expanded → AppTabStrip (7 tabs from BiomedicalPanels)
                │   └── AppAccessActionGate → primary action button (contextual per tab)
                ├── SizedBox(height: theme.spacing.md)
                └── AppListTable<BiomedicalAsset>
                    ├── columns: _columnsForPanel(l10n, _currentPanel)
                    ├── search: AppListTableSearch(...) with panel-specific filter groups (remove panel filter from groups)
                    ├── columnVisibilityStorageKey: 'biomedical_${_currentPanel}'
                    ├── columnWidthStorageKey: 'biomedical_cw_${_currentPanel}'
                    └── mobileItemBuilder: _BiomedicalAssetListTile
```

### Data & State Management

- **Keep** `biomedicalWorkspaceControllerProvider` and `BiomedicalWorkspaceController` unchanged. The controller already supports panel-based queries via `applyPanel(panel)` and `applyFilters(panel: ...)`.
- **Keep** `BiomedicalWorkspaceState`, `BiomedicalWorkspaceQuery`, and all entity classes unchanged.
- The page widget manages the active tab locally (as `_currentPanel` string) and calls `controller.applyPanel(panel)` when tabs change, exactly as it does today.
- Add URL update logic: when the tab changes, call `GoRouter.of(context).replace<void>(location)` with the panel as a query parameter.
- Read `initialQuery` from the route to restore the active tab on page load (deep-link support).

## Implementation Steps

### 1. Add `BiomedicalRouteQuery` entity — File: `frontend/lib/features/biomedical/domain/entities/biomedical_entities.dart`

- **Add** the `BiomedicalRouteQuery` class (shown above in the Routing section) at the end of the file, before the private helper functions.
- This class parses `panel`, `search`, and `asset` from the URL query parameters.

### 2. Update the router to pass query parameters — File: `frontend/lib/app/router/app_router.dart`

- **Modify** the biomedical `GoRoute` to extract query parameters from `state.uri` and pass them as `initialQuery` to `BiomedicalWorkspacePage`.
- **Add** import: `import 'package:hosspi_hms/features/biomedical/domain/entities/biomedical_entities.dart';` (if not already imported).
- Change:
  ```dart
  GoRoute(
    path: AppRoutes.biomedical.path,
    name: AppRoutes.biomedical.name,
    builder: (_, _) => const BiomedicalWorkspacePage(),
  ),
  ```
  To:
  ```dart
  GoRoute(
    path: AppRoutes.biomedical.path,
    name: AppRoutes.biomedical.name,
    builder: (_, GoRouterState state) => BiomedicalWorkspacePage(
      initialQuery: BiomedicalRouteQuery.fromUri(state.uri),
    ),
  ),
  ```

### 3. Add `initialQuery` parameter to `BiomedicalWorkspacePage` — File: `frontend/lib/features/biomedical/presentation/pages/biomedical_workspace_page.dart`

- **Modify** `BiomedicalWorkspacePage` to accept an optional `initialQuery` parameter of type `BiomedicalRouteQuery?`.
- Pass it through to `_BiomedicalWorkspaceContent`.

### 4. Replace panel filter with `AppTabStrip` tabs — File: `frontend/lib/features/biomedical/presentation/pages/biomedical_workspace_page.dart`

- **Add** import: `import 'package:go_router/go_router.dart';`
- **Add** import: `import 'package:hosspi_hms/app/router/app_routes.dart';`
- **Add** a `_currentPanel` state variable (type `String`, default `BiomedicalPanels.registry`) in `_BiomedicalWorkspaceContentState`.
- **Add** an `_appliedRouteSignature` string to track whether the deep-link has been applied (prevent re-application).
- **Add** `_scheduleRouteQuery()` in `initState` and `didUpdateWidget` to handle deep-link from `initialQuery`.
- **Add** `_applyDeepLink(BiomedicalRouteQuery query)` method that:
  - Maps `query.panel` to a valid `BiomedicalPanels` value.
  - Sets `_currentPanel` via `setState`.
  - Calls `controller.applyPanel(panel)`.
  - If `query.search` is non-empty, sets `_searchController.text`.
- **Add** `_updateUrlForPanel(String panel)` method that calls:
  ```dart
  final String location = AppRoutes.biomedical.location(
    queryParameters: <String, String>{
      if (panel != BiomedicalPanels.registry) 'panel': panel,
    },
  );
  GoRouter.of(context).replace<void>(location);
  ```
- **Restructure** the `body` of `AppWorkspace`:
  - Replace the direct `_BiomedicalWorklistPanel(...)` with a `Column` containing:
    1. A `Row` with:
       - `Expanded` child: `AppTabStrip` with 7 tabs from `BiomedicalPanels.values`, each with a label from localization and an icon.
       - The contextual primary action button (moved from toolbar to here).
    2. `SizedBox(height: theme.spacing.md)`
    3. The `AppListTable<BiomedicalAsset>` (moved from `_BiomedicalWorklistPanel`).
  - On tab tap: set `_currentPanel`, call `_updateUrlForPanel(panel)`, then `unawaited(controller.applyPanel(panel))`.

### 5. Add tab-specific columns — File: `frontend/lib/features/biomedical/presentation/pages/biomedical_workspace_page.dart`

- **Add** a `_columnsForPanel(AppLocalizations l10n, String panel)` method that returns different `List<AppListTableColumn<BiomedicalAsset>>` per panel:

  - **Registry** (`BiomedicalPanels.registry`): asset_tag, equipment, category, location, risk, status, owner (current columns minus next_action).
  - **Overview** (`BiomedicalPanels.overview`): asset_tag, equipment, status, priority (risk), next_action, owner.
  - **Preventive** (`BiomedicalPanels.preventive`): asset_tag, equipment, status, next_due (formatted date), owner.
  - **Work Orders** (`BiomedicalPanels.workOrders`): asset_tag, equipment, status, priority (risk), owner, next_action.
  - **Compliance** (`BiomedicalPanels.compliance`): asset_tag, equipment, category, status, next_due, next_action.
  - **Support** (`BiomedicalPanels.support`): asset_tag, equipment, category, location, status.
  - **Analytics** (`BiomedicalPanels.analytics`): asset_tag, equipment, location, status, next_action.

- **Add** a `_nextDueColumn(AppLocalizations l10n)` helper that returns an `AppListTableColumn<BiomedicalAsset>` showing `_formatDate(context, item.nextDueAt)`.

### 6. Add tab-specific primary action button — File: `frontend/lib/features/biomedical/presentation/pages/biomedical_workspace_page.dart`

- **Add** a method `_primaryActionForPanel(AppLocalizations l10n, String panel, bool canWrite, BiomedicalWorkspaceState state)` that returns `Widget?`:
  - `registry` → "Register Asset" button (existing logic).
  - `overview` → "Create Work Order" button.
  - `preventive` → "Schedule Maintenance" button.
  - `workOrders` → "Create Work Order" button.
  - `compliance` → "Record Calibration" button.
  - `support` → `null` (no action).
  - `analytics` → `null` (no action).
- **Move** the primary button from `appWorkspaceToolbarWithLabels(primary: ...)` to the `Row` next to `AppTabStrip`.
- **Set** `primary: null` in the toolbar (keep summary notifications and refresh in toolbar).

### 7. Add tab icons — File: `frontend/lib/features/biomedical/presentation/pages/biomedical_workspace_page.dart`

- **Add** `_panelIcon(String panel)` method returning `IconData`:
  - `registry` → `Icons.medical_services_outlined`
  - `overview` → `Icons.dashboard_outlined`
  - `preventive` → `Icons.event_repeat_outlined`
  - `workOrders` → `Icons.build_outlined`
  - `compliance` → `Icons.fact_check_outlined`
  - `support` → `Icons.support_agent_outlined`
  - `analytics` → `Icons.analytics_outlined`

- **Add** `_panelLabel(AppLocalizations l10n, String panel)` method returning the localized panel name. Use existing l10n keys:
  - `registry` → `l10n.biomedicalPanelRegistry`
  - `overview` → `l10n.biomedicalPanelOverview`
  - `preventive` → `l10n.biomedicalPanelPreventive`
  - `workOrders` → `l10n.biomedicalPanelWorkOrders`
  - `compliance` → `l10n.biomedicalPanelCompliance`
  - `support` → `l10n.biomedicalPanelSupport`
  - `analytics` → `l10n.biomedicalPanelAnalytics`

### 8. Update filter groups to exclude panel filter — File: `frontend/lib/features/biomedical/presentation/pages/biomedical_workspace_page.dart`

- **Remove** the `_panelFilterKey` / `_panelFilterGroup` from the `filterGroups` list in `AppListTableSearch`. The panel is now selected via tabs, not filters.
- **Remove** the `panel` handling from `_filterValue()` and `onFilterChanged`.
- **Keep** the status, priority, facility, and date preset filter groups.
- **Update** the `onFilterChanged` callback to pass the current `_currentPanel` (from tab state) instead of reading it from the filter value.

### 9. Update `columnVisibilityStorageKey` and `columnWidthStorageKey` per tab — File: `frontend/lib/features/biomedical/presentation/pages/biomedical_workspace_page.dart`

- Pass `columnVisibilityStorageKey: 'biomedical_${_currentPanel}'` and `columnWidthStorageKey: 'biomedical_cw_${_currentPanel}'` to `AppListTable` so each tab remembers its own column visibility and width settings independently.
- Create a new `AppListTableColumnVisibilityController<BiomedicalAsset>` when the tab changes (or re-sync columns on tab change).

### 10. Inline the worklist panel — File: `frontend/lib/features/biomedical/presentation/pages/biomedical_workspace_page.dart`

- **Remove** `_BiomedicalWorklistPanel` as a separate widget class.
- **Inline** its `AppListTable<BiomedicalAsset>` directly into `_BiomedicalWorkspaceContentState.build()` inside the `Column` below the tab strip row.
- This is necessary because the table configuration now depends on `_currentPanel` state which lives in `_BiomedicalWorkspaceContentState`.

### 11. Preserve existing detail panel and action dialogs — File: `frontend/lib/features/biomedical/presentation/pages/biomedical_workspace_page.dart`

- **Keep** `_BiomedicalDetailPanel`, `_DetailActions`, `_BiomedicalActionDialog`, and all their supporting code **unchanged**. The detail dialog is opened on row selection and is independent of the tab structure.
- **Keep** `_BiomedicalAssetListTile` for mobile layout.
- **Keep** all tone/label helper functions (`_toneForStatus`, `_toneForPriority`, `_labelForCode`, `_dash`, `_formatDate`, `_formatDateTime`, `_nextActionLabel`, `_labelForResource`).

### 12. Update tests — File: `frontend/test/features/biomedical/presentation/biomedical_workspace_controller_test.dart`

- **Add** or verify tests that:
  - `applyPanel()` correctly updates `query.panel`.
  - Changing panel resets pagination to first page.
  - Existing filter, search, and mutation tests still pass.

### 13. Run verification commands

After all changes:

```bash
dart format .
dart analyze --fatal-infos
flutter test test/features/biomedical/
flutter test test/shared/
```

## Shared Components — MUST Reuse

Do NOT create new implementations of these. Import and use them directly:

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` | `package:hosspi_hms/shared/components/app_tab_strip.dart` (via `components.dart` barrel) | Render the 7 biomedical tabs. Pass `tabs`, `selectedId`, `onTabTapped`. |
| `AppListTable<T>` | `package:hosspi_hms/shared/components/app_list_table.dart` (via `components.dart` barrel) | Already in use. Continue using with per-tab columns and storage keys. |
| `AppListTableSearch<T>` | Same file as `AppListTable` | Already in use. Remove panel filter group; keep other filters. |
| `AppListTableColumnVisibilityController<T>` | Same file as `AppListTable` | Already in use. Re-sync when tab changes. |
| `AppWorkspace` | `package:hosspi_hms/shared/layout/app_workspace.dart` (via `layout.dart` barrel) | Already in use. Keep for toolbar/summary notifications. Body structure changes. |
| `appWorkspaceToolbarWithLabels` | Same as `AppWorkspace` | Already in use. Remove `primary` from toolbar; keep summary notifications and refresh. |
| `AppButton.primary` | `package:hosspi_hms/shared/components/app_button.dart` (via `components.dart` barrel) | Already in use. For contextual primary action next to tab strip. |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Wrap the primary action button for permission checks (follow Reception pattern). |
| `AsyncStateScaffold<T>` | `package:hosspi_hms/shared/components/app_state_view.dart` (via `components.dart` barrel) | Already in use. Keep. |
| `AppWorkspaceSummaryNotification` | Via `layout.dart` barrel | Already in use. Keep in toolbar. |
| `GoRouter` | `package:go_router/go_router.dart` | For URL updates on tab change. |
| `AppRoutes` | `package:hosspi_hms/app/router/app_routes.dart` | For building biomedical route location with query params. |

## Files to Create

| File Path | Purpose |
|-----------|---------|
| (none) | No new files needed. All changes are modifications to existing files. |

## Files to Modify

| File Path | Changes |
|-----------|---------|
| `frontend/lib/features/biomedical/domain/entities/biomedical_entities.dart` | Add `BiomedicalRouteQuery` class for deep-link query parsing. |
| `frontend/lib/features/biomedical/presentation/pages/biomedical_workspace_page.dart` | Major refactor: add `initialQuery` param, replace panel filter with `AppTabStrip`, add tab-specific columns via `_columnsForPanel()`, add contextual primary action via `_primaryActionForPanel()`, add URL update on tab change, add deep-link restoration, remove `_BiomedicalWorklistPanel` class (inline into content state), remove panel filter from filter groups, add per-tab `columnVisibilityStorageKey` and `columnWidthStorageKey`. |
| `frontend/lib/app/router/app_router.dart` | Update biomedical `GoRoute` builder to extract query params from `state.uri` and pass `BiomedicalRouteQuery` to `BiomedicalWorkspacePage`. |

## Files to Delete (if any)

| File Path | Reason |
|-----------|--------|
| (none) | No files to delete. The `_BiomedicalWorklistPanel` widget class is removed from within the page file, not a separate file. |

## Cleanup: Remove Stale Code

After the refactor, the agent MUST remove all dead/stale code left behind:

- [ ] Remove `_BiomedicalWorklistPanel` widget class — its logic is inlined into `_BiomedicalWorkspaceContentState`.
- [ ] Remove `_panelFilterKey` constant and `_panelChoices()` function — panel selection is now via tabs.
- [ ] Remove the panel `AppSearchBarFilterGroup` from the `filterGroups` list.
- [ ] Remove panel handling from `_filterValue()` — no longer reads `_panelFilterKey` from the filter value map.
- [ ] Remove panel reading from `onFilterChanged` — panel comes from `_currentPanel` state.
- [ ] Remove unused imports across all modified files.
- [ ] Run `dart analyze` to catch any remaining unreferenced declarations and remove them.
- [ ] Verify no test files reference deleted code — update or remove stale tests.

List every file and symbol removed in a "Cleanup Summary" section at the end of the implementation.

## Database Migrations

No database migrations required — schema unchanged. This refactor only restructures the frontend UI layer (tab navigation, column sets, URL routing). The backend API, data models, and query parameters (`panel`, `resource`, `status`, `priority`, etc.) remain identical. The controller's `applyPanel()` method already sends the correct `panel` parameter to the API.

## Responsive Design Requirements

- **Desktop (≥1024px):** Full table layout with tab-specific columns visible. `AppTabStrip` renders as a horizontal tab bar with icons and labels. Primary action button positioned to the right of the tab strip in the same row. Column visibility settings gear icon in search bar.
- **Tablet (600–1023px):** Table layout with compact column widths (`_defaultCompactColumnWidth = 136`). `AppTabStrip` may scroll horizontally if tabs overflow. Primary action button may wrap below tabs if space is insufficient.
- **Mobile (<600px):** `AppListTable` automatically switches to list layout via `mobileItemBuilder` using `_BiomedicalAssetListTile`. `AppTabStrip` scrolls horizontally. Primary action button wraps below tabs.

The `AppListTable` component handles responsive layout switching automatically via `AppBreakpoints.fromConstraints()` in `_usesListLayout()` and `_usesCompactTableLayout()`. No custom breakpoint logic is needed — the shared component manages it.

## Verification Steps

After implementation, the agent MUST run these commands and confirm they pass:

```bash
# Format
dart format .

# Analyze
dart analyze --fatal-infos

# Run tests related to this screen
flutter test test/features/biomedical/

# Run shared component tests to ensure no regressions
flutter test test/shared/
```

## Testing Requirements

Write or update these tests:

- [ ] Tab navigation: switching tabs calls `controller.applyPanel()` with the correct panel value
- [ ] Deep linking: constructing `BiomedicalRouteQuery(panel: 'work-orders')` and passing as `initialQuery` sets the correct tab
- [ ] URL update: switching tabs updates the URL query parameter `panel`
- [ ] Table columns: each tab displays the correct column set from `_columnsForPanel()`
- [ ] Search: typing in the search bar filters table rows (existing behavior preserved)
- [ ] Filter dialog: filter button opens the filter UI with panel filter removed, only status/priority/facility/date filters present
- [ ] Primary action: button label and behavior change per tab (Registry shows "Register Asset", Work Orders shows "Create Work Order", Support/Analytics show no button)
- [ ] No regressions: existing asset detail dialog, mutation actions, and print functionality still work
- [ ] Column visibility storage: each tab has its own storage key (`biomedical_registry`, `biomedical_work-orders`, etc.)

## Acceptance Criteria

The refactor is complete when ALL of the following are true:

- [ ] The screen uses `AppTabStrip` with 7 tabs matching the `BiomedicalPanels.values` list
- [ ] Each tab has its own URL via the `panel` query parameter that supports deep linking
- [ ] The primary action button is contextual per tab and positioned next to the tab strip
- [ ] Each tab displays a tab-specific set of columns appropriate to that panel's data
- [ ] The panel filter dropdown is removed from the advanced filter dialog — panel selection is via tabs only
- [ ] The `AppWorkspace` toolbar retains summary notifications and refresh button
- [ ] No shared component is re-implemented — only imported and used
- [ ] The layout is fully responsive across mobile, tablet, and desktop (handled by `AppListTable` and `AppTabStrip`)
- [ ] All old/duplicate layout code is removed — `_BiomedicalWorklistPanel`, `_panelFilterKey`, `_panelChoices()` are gone
- [ ] Domain-specific business logic and data are preserved — all mutation actions, detail panel, print report functionality untouched
- [ ] No database migrations required — schema unchanged
- [ ] `dart analyze` reports no new issues — zero unused imports, zero unreferenced declarations
- [ ] All tests pass (no stale test references to removed code)
