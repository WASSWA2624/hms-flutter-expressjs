# Standardize Radiology Screen

## Objective

Refactor the Radiology workspace to match the standardized tab-and-table layout used by the Reception workspace. The current implementation uses `AppWorkspace` with a toolbar-based summary notification pattern and a view toggle (patients/orders). This refactor replaces that structure with the `ResponsivePage` → `AppTabStrip` → `AppListTable` pattern, converting the existing radiology workflow stages into routable tabs with URL-synced navigation, per-tab row counts, and a contextual primary action button — while fully preserving all domain-specific business logic (order creation, detail dialog, workflow progress, imaging studies, reporting, configurations, PACS sync, and printing).

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification — all information needed is in this prompt. Run tests and formatting after implementation.

## Current State (from audit)

### Radiology screen files

| File | Purpose |
|------|---------|
| `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart` | Main page (~4200 lines with 3 part files). Uses `AsyncStateScaffold` → `AppWorkspace` with `appWorkspaceToolbarWithLabels`. Contains `_RadiologyOrderBoard`, `_RadiologyOrderDetail`, `_RadiologyDetailBody`, and many detail/action widgets. |
| `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.configurations.dart` | `part` file: `_RadiologyConfigurationsDialog` for catalog/equipment management (~900 lines). |
| `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.detail_cells.dart` | `part` file: `_DetailLine`, `_ModalityLabel`, and helper widgets for the detail dialog (~520 lines). |
| `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.print.dart` | `part` file: Print/report generation logic. |
| `frontend/lib/features/radiology/presentation/controllers/radiology_workspace_controller.dart` | `RadiologyWorkspaceController` — Riverpod `AsyncNotifier` managing `RadiologyWorkspaceState`. Handles search, stage/status/modality/priority/billing-gate filters, pagination, order CRUD, study CRUD, result CRUD, catalog management, realtime sync, and adaptive polling. |
| `frontend/lib/features/radiology/domain/entities/radiology_entities.dart` | Domain entities: `RadiologyWorkspaceQuery`, `RadiologyWorkspaceState`, `RadiologyOrder`, `RadiologyResult`, `ImagingStudy`, `RadiologyWorkflow`, `RadiologySummary`, `RadiologyCatalogTest`, `RadiologyEquipmentRecord`, `RadiologyReferenceData`, etc. |
| `frontend/lib/features/radiology/domain/repositories/radiology_repository.dart` | Repository interface + `RadiologyWorkbench`, `StudyAssetUploadSession` classes. |
| `frontend/lib/features/radiology/data/repositories/radiology_repository_impl.dart` | Repository implementation. |
| `frontend/lib/features/radiology/data/dtos/radiology_dtos.dart` | DTO serialization. |
| `frontend/lib/features/radiology/presentation/widgets/radiology_workflow_progress_section.dart` | `RadiologyWorkflowProgressSection` — maps order status to the shared `AppWorkflowStepper`. |

### Current layout problems

- **No tab-based navigation**: Reception uses `AppTabStrip` with an enum (`ReceptionDeskSection`) for tab-routable sections; Radiology uses `AppWorkspace` toolbar with `AppWorkspaceSummaryNotification` chips and a view toggle button (patients vs orders). Stages are filters inside `AppSearchBarFilterGroup`, not tabs.
- **Different component hierarchy**: Reception uses `ResponsivePage` → `Column` → `Row[AppTabStrip + primary button]` → `AppListTable`; Radiology uses `AppWorkspace` → toolbar + body with `_RadiologyOrderBoard` widget.
- **No URL routing for sections**: Reception updates the URL with `?section=appointments` on tab switch via `GoRouter.replace`. Radiology only has `?encounterId=`, `?orderId=`, `?search=` query parameters — no section routing.
- **Primary action placement differs**: Reception places the primary button ("Register Patient") in a `Row` next to the `AppTabStrip`. Radiology places "Request Imaging" inside the `appWorkspaceToolbarWithLabels` toolbar.
- **View toggle instead of tabs**: The patients/orders toggle in Radiology serves a similar purpose to tabs but is a secondary button in the toolbar, not a routable tab strip.

### What already works correctly (PRESERVE these)

- `AppListTable<RadiologyOrder>` with server-side pagination (`page` parameter), `AppListTableSearch`, `AppSearchBarFilterGroup` for advanced filters, `AppListTableColumnVisibilityController`, column choices, and mobile item builder.
- `RadiologyWorkspaceController` with all its methods: `applySearch`, `applyStage`, `applyView`, `applyStatus`, `applyModality`, `applyPriority`, `applyBillingGate`, `applyOrderedDate`, `clearFilters`, `changePage`, `selectOrder`, `createOrder`, `updateOrderRequestDetails`, `assignOrder`, `startOrder`, `completeOrder`, `cancelOrder`, `createStudy`, `draftResult`, `finalizeResult`, `requestFinalization`, `attestFinalization`, `addendumResult`, `syncStudyToPacs`, `uploadStudyAssets`, `deleteStudyAsset`, `searchReferences`, `refreshConfigurations`, `loadFacilityCatalogConfig`, `searchPlatformRadiologyCatalogForOffering`, `upsertRadiologyTestOffering`, `disableRadiologyTestOffering`, `disableRadiologyTestOfferings`.
- Detail dialog (`_openRadiologyDetailDialog`) with all its sections: patient context, workflow progress stepper, request section, studies section, report section, doctor review panel, timeline.
- Configurations dialog for catalog/equipment management.
- Print/report generation.
- Deep-link routing via `RadiologyWorkspaceQuery.fromUri`.
- Realtime sync and adaptive polling.

## Reference Implementation

Read these files to understand the target patterns (do NOT modify them):

| File | Extract |
|------|---------|
| `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` | **Tab structure**: `ReceptionDeskSection` enum → `AppTabStrip` with `AppTabItem` for each section, `selectedId` synced to state, `onTabTapped` calling `setState` + `_updateUrlForSection`. **Layout**: `ResponsivePage` → `Column` → `Row[AppTabStrip (expanded) + primary button]` → `SizedBox` → `AppListTable`. **URL routing**: `_updateUrlForSection` builds `AppRoutes.reception.location(queryParameters:)` and calls `GoRouter.of(context).replace<void>(location)`. **Tab counts**: Label format `'${_sectionLabel(l10n, section)} (${_sectionCount(state, section)})'`. **Primary button**: `AppAccessActionGate` wrapping `AppButton.primary` with `leadingIcon` and `onPressed`. **Search**: `AppListTableSearch` with `controller`, `matcher`, `hintText`. **Mobile**: `mobileItemBuilder` returning `AppPatientDetails`. **Deep-link**: `_applyDeepLink` method reading `ReceptionWorkspaceQuery`. |
| `frontend/lib/features/reception/domain/entities/reception_entities.dart` | **Query model**: `ReceptionWorkspaceQuery` with `section`, `search`, `patientId`, `flowId` fields, `fromUri` factory, `hasRouteTargeting`, `signature`. **Section enum**: `ReceptionDeskSection { appointments, queue, activeVisits, paymentGate }`. |
| `frontend/lib/shared/components/app_tab_strip.dart` | `AppTabStrip` widget: `tabs` (list of `AppTabItem`), `selectedId`, `onTabTapped`. `AppTabItem`: `id`, `icon`, `label`. |
| `frontend/lib/shared/components/app_list_table.dart` | `AppListTable<T>` widget with `items`/`page`, `columns`, `search`, `columnVisibilityController`, `mobileItemBuilder`, `emptyBuilder`, `onRowSelected`, etc. |
| `frontend/lib/shared/layout/responsive_page.dart` | `ResponsivePage` with `maxWidth`, `child`. |
| `frontend/lib/shared/layout/app_workspace.dart` | `AppWorkspace` — the current wrapper used by Radiology. Understand its structure to know what to replace. |
| `frontend/lib/shared/layout/app_workspace_toolbar.dart` | `appWorkspaceToolbarWithLabels` — the toolbar builder currently used by Radiology. |

## Target Architecture

### Tab Configuration

The existing `radiologyStageFilters` (`ALL`, `ORDERED`, `PROCESSING`, `REPORTING`, `COMPLETED`, `CANCELLED`) and `RadiologySummary` counts map naturally to tabs:

| Tab Name | Route Value (`?section=`) | Description | Count Source | Primary Action Button |
|----------|--------------------------|-------------|--------------|----------------------|
| Worklist | `worklist` | Active orders: ORDERED + PROCESSING stages (default tab) | `summary.workloadCount` | "Request Imaging" → `_showCreateOrderDialog` |
| Reporting | `reporting` | Draft reports awaiting finalization | `summary.reportingCount` | "Request Imaging" → `_showCreateOrderDialog` |
| Released | `released` | Finalized / amended results | `summary.releasedCount` | "Request Imaging" → `_showCreateOrderDialog` |
| All Orders | `all` | All orders across all stages | `summary.totalForView(view)` | "Request Imaging" → `_showCreateOrderDialog` |

Create a new enum `RadiologyDeskSection` in `radiology_entities.dart`:

```dart
enum RadiologyDeskSection {
  worklist,
  reporting,
  released,
  allOrders,
}
```

### Routing

- **Router file**: `frontend/lib/app/router/app_router.dart`
- The route at `AppRoutes.radiology` already passes `RadiologyWorkspaceQuery.fromUri(state.uri)` to the page — no router changes needed.
- **URL updates**: Add a `_updateUrlForSection` method (like Reception) that calls `GoRouter.of(context).replace<void>(location)` with `?section=worklist` (or `reporting`, `released`, `all`).
- **Deep-link**: Extend `RadiologyWorkspaceQuery.fromUri` to parse the `section` query parameter. Add a `section` field to `RadiologyWorkspaceQuery`.

### Page Layout

Replace the current `AppWorkspace` wrapper with this widget tree:

```
AsyncStateScaffold<RadiologyWorkspaceState>
  └─ ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)
      └─ Column(crossAxisAlignment: stretch)
          ├─ Row
          │   ├─ Expanded(child: AppTabStrip(tabs: [...], selectedId, onTabTapped))
          │   ├─ SizedBox(width: theme.spacing.sm)
          │   ├─ [Secondary buttons: View Toggle (patients/orders), Configurations]
          │   ├─ SizedBox(width: theme.spacing.sm)
          │   └─ AppButton.primary("Request Imaging", ...)  // permission-gated
          ├─ SizedBox(height: theme.spacing.md)
          ├─ [Optional: AppFailureStateView if lastFailure != null]
          └─ AppListTable<RadiologyOrder>(...)  // keep existing _RadiologyOrderBoard internals
```

### Data & State Management

- **Keep `RadiologyWorkspaceController` as-is** — it already supports stage filtering via `applyStage()`. Tab switches will call `applyStage()` with the appropriate stage value:
  - Worklist → `applyStage('ALL')` with the controller internally filtering to ORDERED + PROCESSING (or send a combined filter if the backend supports it). Alternatively, keep the existing `ALL` stage and filter client-side in `_buildRows`.
  - Reporting → `applyStage('REPORTING')`
  - Released → `applyStage('COMPLETED')`
  - All Orders → `applyStage('ALL')`
- **Tab-to-stage mapping**: Create a `_stageForSection(RadiologyDeskSection)` helper.
- **Count mapping**: Create a `_sectionCount(RadiologySummary, RadiologyWorkbenchView, RadiologyDeskSection)` helper using existing `RadiologySummary` fields.

## Implementation Steps

### 1. Add `RadiologyDeskSection` enum and extend `RadiologyWorkspaceQuery` — File: `frontend/lib/features/radiology/domain/entities/radiology_entities.dart`

- Add the `RadiologyDeskSection` enum after the existing `RadiologyWorkbenchView` enum:
  ```dart
  enum RadiologyDeskSection {
    worklist,
    reporting,
    released,
    allOrders,
  }
  ```
- Add a `section` field to `RadiologyWorkspaceQuery`:
  ```dart
  final String section; // default ''
  ```
- Update `RadiologyWorkspaceQuery.fromUri` to parse `section`:
  ```dart
  final String section = pick(<String>['section', 'panel', 'tab']);
  ```
- Update `copyWith` and constructor to include `section`.
- Update `hasRouteTargeting` to include `section.isNotEmpty`.
- Update `signature` to include `section`.

### 2. Refactor `RadiologyWorkspacePage` layout — File: `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart`

- **In `RadiologyWorkspacePage.build`**: Remove `appBarTitle` from `AsyncStateScaffold` (tabs replace the title). Keep `maxWidth: PageMaxWidth.dataHeavy`, `centerVertically: false`, `onRetry`, `deferLoadingToShell: false`, `keepPreviousDataDuringRefresh: true`.

- **In `_RadiologyWorkspaceContentState`**:
  - Add a `RadiologyDeskSection _section` field, initialized from `widget.initialQuery?.section` (parse to enum, default to `RadiologyDeskSection.worklist`).
  - Add `_updateUrlForSection(RadiologyDeskSection section)` method following the Reception pattern:
    ```dart
    void _updateUrlForSection(RadiologyDeskSection section) {
      if (!mounted) return;
      final String tab = _sectionToQueryValue(section);
      final String location = AppRoutes.radiology.location(
        queryParameters: <String, String>{
          if (tab.isNotEmpty) 'section': tab,
        },
      );
      GoRouter.of(context).replace<void>(location);
    }
    ```
  - Add `_sectionToQueryValue(RadiologyDeskSection)` and `_sectionFromQuery(String)` methods.
  - Add `_sectionIcon(RadiologyDeskSection)` method returning appropriate `IconData`.
  - Add `_sectionLabel(AppLocalizations, RadiologyDeskSection)` method.
  - Add `_sectionCount(RadiologyWorkspaceState, RadiologyDeskSection)` method using `RadiologySummary` fields.

  - **Replace the `build` method body**: Remove the `AppWorkspace(...)` wrapper. Replace with:
    ```dart
    ResponsivePage(
      maxWidth: PageMaxWidth.dataHeavy,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: AppTabStrip(
                    tabs: <AppTabItem>[
                      for (final RadiologyDeskSection section
                          in RadiologyDeskSection.values)
                        AppTabItem(
                          id: section.name,
                          icon: _sectionIcon(section),
                          label: '${_sectionLabel(l10n, section)} (${_sectionCount(state, section)})',
                        ),
                    ],
                    selectedId: _section.name,
                    onTabTapped: (String tabId) {
                      for (final RadiologyDeskSection section
                          in RadiologyDeskSection.values) {
                        if (section.name == tabId) {
                          setState(() => _section = section);
                          _updateUrlForSection(section);
                          _applyStageForSection(section);
                          break;
                        }
                      }
                    },
                  ),
                ),
                SizedBox(width: theme.spacing.sm),
                // View toggle button (patients/orders) — keep existing
                AppButton.secondary(
                  label: state.query.view == RadiologyWorkbenchView.patients
                      ? l10n.radiologyOrdersViewAction
                      : l10n.radiologyPatientsViewAction,
                  leadingIcon: Icons.swap_horiz_outlined,
                  onPressed: state.isMutating ? null : () => controller.applyView(...),
                ),
                if (canWork) ...<Widget>[
                  SizedBox(width: theme.spacing.sm),
                  // Configurations button — keep existing
                  AppButton.secondary(
                    label: l10n.radiologyConfigurationsAction,
                    leadingIcon: Icons.tune_outlined,
                    enabled: !state.isMutating,
                    onPressed: state.isMutating ? null : () => _showRadiologyConfigurationsDialog(...),
                  ),
                ],
                SizedBox(width: theme.spacing.sm),
                if (canRequest)
                  AppButton.primary(
                    label: l10n.radiologyRequestImagingAction,
                    leadingIcon: Icons.add,
                    enabled: !state.isMutating,
                    onPressed: () => _showCreateOrderDialog(context, ref),
                  ),
              ],
            ),
            SizedBox(height: theme.spacing.md),
            if (lastFailure != null) ...<Widget>[
              AppFailureStateView(failure: lastFailure, onRetry: controller.refresh),
              SizedBox(height: theme.spacing.md),
            ],
            _RadiologyOrderBoard(...),  // keep existing
          ],
        ),
      ),
    );
    ```

  - Add `_applyStageForSection(RadiologyDeskSection section)` method that calls the controller:
    ```dart
    void _applyStageForSection(RadiologyDeskSection section) {
      final controller = ref.read(radiologyWorkspaceControllerProvider.notifier);
      switch (section) {
        case RadiologyDeskSection.worklist:
          unawaited(controller.applyStage('ALL')); // worklist shows ordered+processing; filtered by summary
        case RadiologyDeskSection.reporting:
          unawaited(controller.applyStage('REPORTING'));
        case RadiologyDeskSection.released:
          unawaited(controller.applyStage('COMPLETED'));
        case RadiologyDeskSection.allOrders:
          unawaited(controller.applyStage('ALL'));
      }
    }
    ```

  - Update `_scheduleRouteQuery` / `_applyRouteQuery` to also parse and apply the `section` from `initialQuery`.

  - Add `import 'package:go_router/go_router.dart';` if not already present.
  - Add `import 'package:hosspi_hms/app/router/app_routes.dart';` if not already present.

### 3. Remove `AppWorkspace` dependency — File: `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart`

- Remove the import of `app_route_icons.dart` if it was only used for the `AppWorkspace` leading icon (check if still needed for the detail dialog or other uses — keep if needed).
- Remove the `AppWorkspace(...)` widget usage.
- Remove the `appWorkspaceToolbarWithLabels(...)` call and its associated `AppWorkspaceSummaryNotification` list.
- Keep all toolbar actions (view toggle, configurations button, primary action button) — they move into the `Row` next to `AppTabStrip`.

### 4. Handle deep-link for section — File: `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart`

- In `_RadiologyWorkspaceContentState.initState`, initialize `_section` from the initial query:
  ```dart
  _section = _sectionFromQuery(widget.initialQuery?.section ?? '') ?? RadiologyDeskSection.worklist;
  ```
- In `_applyRouteQuery`, parse and apply the section:
  ```dart
  final RadiologyDeskSection? section = _sectionFromQuery(query.section);
  if (section != null) {
    setState(() => _section = section);
    _applyStageForSection(section);
  }
  ```

### 5. Keep `_RadiologyOrderBoard` internals intact — File: `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart`

- `_RadiologyOrderBoard` already uses `AppListTable<RadiologyOrder>` with all the correct patterns (search, filters, pagination, columns, mobile builder). **Do NOT change its internals** — only change how it's embedded in the parent layout.
- The existing `AppSearchBarFilterGroup` filters (stage, status, modality, priority, billing gate) remain as advanced filters within the search bar — they provide finer control beyond what the tabs offer.

### 6. Ensure import consistency — File: `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart`

After refactoring, ensure these imports are present:
```dart
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/shared/layout/layout.dart'; // for ResponsivePage, PageMaxWidth
import 'package:hosspi_hms/shared/components/components.dart'; // for AppTabStrip, AppListTable, etc.
```

Remove any imports that become unused after removing `AppWorkspace`:
- Check if `app_route_icons.dart` is still needed (likely yes, for the detail dialog).
- Check if `app_workspace_toolbar.dart` exports are still needed via `layout.dart` barrel (likely no direct import needed if removed from usage).

## Shared Components — MUST Reuse

Do NOT create new implementations of these. Import and use them directly:

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` | `package:hosspi_hms/shared/components/components.dart` | Tab bar with `AppTabItem` list, `selectedId`, `onTabTapped` |
| `AppTabItem` | `package:hosspi_hms/shared/components/components.dart` | Tab definition: `id`, `icon`, `label` |
| `AppListTable<T>` | `package:hosspi_hms/shared/components/components.dart` | Data table with pagination, search, filters, column visibility |
| `AppListTableSearch<T>` | `package:hosspi_hms/shared/components/components.dart` | Search configuration for `AppListTable` |
| `AppSearchBarFilterGroup` | `package:hosspi_hms/shared/components/components.dart` | Advanced filter group for search bar |
| `AppListTableColumnVisibilityController<T>` | `package:hosspi_hms/shared/components/components.dart` | Column visibility persistence |
| `AppButton` | `package:hosspi_hms/shared/components/components.dart` | `.primary()` and `.secondary()` constructors |
| `AppWorkspaceStatusBadge` | `package:hosspi_hms/shared/components/components.dart` | Status badge in table cells |
| `AppPatientDetails` | `package:hosspi_hms/shared/components/components.dart` | Mobile item builder + detail header |
| `AppWorkspaceStatePanel` | `package:hosspi_hms/shared/components/components.dart` | Empty/loading state panels |
| `AppDialog` / `showAppDialog` | `package:hosspi_hms/shared/components/components.dart` | Dialog infrastructure |
| `ResponsivePage` | `package:hosspi_hms/shared/layout/layout.dart` | Responsive page wrapper with `maxWidth` |
| `PageMaxWidth` | `package:hosspi_hms/shared/layout/layout.dart` | Max width enum (use `PageMaxWidth.dataHeavy`) |
| `AsyncStateScaffold` | `package:hosspi_hms/shared/layout/layout.dart` | Async state loading scaffold |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Permission-gated action wrapper |
| `RadiologyWorkflowProgressSection` | `package:hosspi_hms/features/radiology/presentation/widgets/radiology_workflow_progress_section.dart` | Workflow stepper in detail dialog |

## Files to Create

| File Path | Purpose |
|-----------|---------|
| None | No new files needed. All changes are modifications to existing files. |

## Files to Modify

| File Path | Changes |
|-----------|---------|
| `frontend/lib/features/radiology/domain/entities/radiology_entities.dart` | Add `RadiologyDeskSection` enum. Add `section` field to `RadiologyWorkspaceQuery` + update `fromUri`, `copyWith`, `hasRouteTargeting`, `signature`. |
| `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart` | Replace `AppWorkspace` + toolbar with `ResponsivePage` + `AppTabStrip` + `Row` layout. Add `_section` state, URL routing, stage-to-tab mapping, tab labels/icons/counts. Keep `_RadiologyOrderBoard`, detail dialog, and all part files unchanged. |

## Files to Delete (if any)

| File Path | Reason |
|-----------|--------|
| None | No files to delete. The part files (`*.configurations.dart`, `*.detail_cells.dart`, `*.print.dart`) remain as-is since they contain domain logic that must be preserved. |

## Cleanup: Remove Stale Code

After the refactor, the agent MUST remove all dead/stale code left behind:

- [ ] Remove the `AppWorkspace(...)` widget call and `appWorkspaceToolbarWithLabels(...)` invocation from the build method.
- [ ] Remove the `AppWorkspaceSummaryNotification` list construction (the summary counts move into tab labels).
- [ ] Remove unused imports: check if `app_workspace_toolbar.dart`, `app_workspace_summary_notification.dart`, or `app_route_icons.dart` imports are still needed after removal. Only remove truly unused ones.
- [ ] Remove any dead helper methods that only served the old toolbar layout.
- [ ] Run `dart analyze` to catch any remaining unreferenced declarations and remove them.
- [ ] Verify no test files reference deleted code — update or remove stale tests.

List every file and symbol removed in a "Cleanup Summary" section at the end of the implementation.

## Database Migrations

No database migrations required — schema unchanged. This refactor only restructures the UI layer (page layout and navigation). All data models, API contracts, repository interfaces, controllers, and backend communication remain identical.

## Responsive Design Requirements

- **Desktop (≥1024px):** Full tab strip with all tabs visible in a horizontal row. View toggle and configurations buttons visible inline. Primary action button visible. `AppListTable` renders full columns based on column visibility settings.
- **Tablet (600–1023px):** `AppTabStrip` wraps or scrolls horizontally if needed (it handles this internally). Secondary buttons may stack or overflow. `AppListTable` hides optional columns per visibility settings.
- **Mobile (<600px):** `AppTabStrip` scrolls horizontally. Secondary toolbar buttons collapse into an overflow menu or stack vertically. `AppListTable` switches to `mobileItemBuilder` rendering (already implemented via `_RadiologyOrderListTile`). Primary action button remains visible.

The `ResponsivePage` widget from `frontend/lib/shared/layout/responsive_page.dart` handles max-width constraints. The `AppTabStrip` from `frontend/lib/shared/components/app_tab_strip.dart` handles its own responsive behavior. No additional breakpoint utilities are needed beyond what these shared components provide.

## Verification Steps

After implementation, the agent MUST run these commands and confirm they pass:

```bash
# Format
dart format .

# Analyze
dart analyze --fatal-infos

# Run tests related to radiology
flutter test test/features/radiology/

# Run shared component tests to ensure no regressions
flutter test test/shared/
```

## Testing Requirements

Write or update these tests:

- [ ] Tab navigation: switching tabs updates the `_section` state and triggers the correct `applyStage` call on the controller
- [ ] Deep linking: navigating with `?section=reporting` in the URL renders the Reporting tab as selected and applies the REPORTING stage filter
- [ ] Tab counts: each tab label displays the correct count from `RadiologySummary`
- [ ] Table data: each tab displays the correct filtered dataset via the controller
- [ ] Search: typing in the search bar filters table rows (preserved from current implementation)
- [ ] Advanced filters: filter dialog opens and applies filters correctly (preserved)
- [ ] Primary action: "Request Imaging" button is visible and functional across all tabs
- [ ] View toggle: patients/orders toggle still works correctly within each tab
- [ ] Detail dialog: clicking a row still opens the radiology detail dialog with full workflow
- [ ] Configurations: configurations button still opens the catalog management dialog
- [ ] No regressions: all existing radiology functionality still works (order CRUD, studies, results, PACS, printing)

## Acceptance Criteria

The refactor is complete when ALL of the following are true:

- [ ] The screen uses routable tabs via `AppTabStrip` matching the Reception workspace pattern
- [ ] Each tab has its own URL query parameter (`?section=worklist`, `?section=reporting`, `?section=released`, `?section=all`) that supports deep linking
- [ ] Tab labels show per-tab row counts from `RadiologySummary`
- [ ] The primary action button ("Request Imaging") is positioned in a `Row` next to the `AppTabStrip`, not in a toolbar
- [ ] The view toggle (patients/orders) and configurations button are positioned as secondary actions in the same `Row`
- [ ] The page body uses `AppListTable<RadiologyOrder>` with integrated search, advanced filters, and column settings (preserved from current implementation)
- [ ] No shared component is re-implemented — only imported and used
- [ ] The layout is fully responsive across mobile, tablet, and desktop (handled by `ResponsivePage` and `AppTabStrip`)
- [ ] All domain-specific business logic is preserved: order CRUD, study management, result reporting, PACS sync, printing, workflow progress, detail dialog, configurations dialog
- [ ] All old `AppWorkspace` / toolbar layout code is removed — no stale widgets or dead methods remain
- [ ] No database migrations required — schema unchanged
- [ ] `dart analyze` reports no new issues — zero unused imports, zero unreferenced declarations
- [ ] All tests pass (no stale test references to removed code)
