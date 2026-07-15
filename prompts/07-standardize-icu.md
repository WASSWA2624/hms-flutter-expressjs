# Standardize ICU Screen

## Objective

Refactor the ICU (Intensive Care Unit) workspace to match the standardized tab-and-table layout used by the Reception workspace. The ICU screen currently uses `AppWorkspace` with `AppWorkspaceSummaryNotification` badges for scope filtering and an `AppWorkspaceBoardToggle` for switching between patient board and bed board views. This refactor replaces the notification-badge scoping with an `AppTabStrip`-based tab navigation pattern (matching Reception), makes each tab routable via URL query parameters, adds column visibility persistence, and preserves all existing domain logic including the bed board view, detail dialogs, clinical actions, and real-time sync.

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification — all information needed is in this prompt. Run tests and formatting after implementation.

## Current State (from audit)

### ICU Files

- **Page**: `frontend/lib/features/icu/presentation/pages/icu_workspace_page.dart` — ~2600 lines, contains `IcuWorkspacePage`, `_IcuWorkspaceContent`, `_IcuBoardPanel`, `_IcuDetailPanel`, `_IcuActionPanel`, `_IcuAlertPanel`, `_IcuObservationPanel`, `_IcuVitalTrendPanel`, `_IcuCarePanel`, `_IcuTransferPanel`, plus 8 dialog widgets and many helper functions.
- **Controller**: `frontend/lib/features/icu/presentation/controllers/icu_workspace_controller.dart` — `IcuWorkspaceController` (AsyncNotifier), manages board listing, patient selection, vitals, alerts, observations, transfers, and bed board.
- **Entities**: `frontend/lib/features/icu/domain/entities/icu_entities.dart` — `IcuBoardScope`, `IcuBoardView`, `IcuDetailPanel`, `IcuTransferAction`, `IcuBoardQuery`, `IcuPatientSummary`, `IcuPatientDetail`, `IcuWorkspaceState`, and many supporting types.
- **DTOs**: `frontend/lib/features/icu/data/dtos/icu_dtos.dart` — All DTO classes for JSON decoding.
- **Repository**: `frontend/lib/features/icu/domain/repositories/icu_repository.dart` (interface), `frontend/lib/features/icu/data/repositories/icu_repository_impl.dart` (implementation using `ApiClient`).
- **Widgets**: `frontend/lib/features/icu/presentation/widgets/icu_bed_board_panel.dart` (bed board view), `frontend/lib/features/icu/presentation/widgets/icu_format.dart` (display helpers: `apiLabel`, `joinDisplay`, `icuStatus`, `alertStatus`, tone functions).
- **Tests**: `frontend/test/features/icu/data/icu_dtos_test.dart`, `frontend/test/features/icu/presentation/icu_workspace_controller_test.dart`.
- **Route**: `AppRoutes.icu` at `/icu` — simple `GoRoute` with `IcuBoardQuery.fromUri(state.uri)`, no sub-routes.

### Current Layout/Structure

- Uses `AsyncStateScaffold<IcuWorkspaceState>` wrapping `AppWorkspace` layout widget.
- Toolbar has `AppWorkspaceSummaryNotification` badges (All, Active, Critical, Transfers, Discharge Ready) that call `controller.applyScope()`.
- Toolbar has `AppWorkspaceBoardToggle<IcuBoardView>` to switch between `patientBoard` and `bedBoard`.
- Toolbar has 3 `AppAccessActionGate`-wrapped `AppButton.secondary` actions (Start Stay, Record Vitals, Record Observation).
- Body switches between `_IcuBoardPanel` (uses `AppListTable<IcuPatientSummary>` with server-side pagination) and `IcuBedBoardPanel` (card-style list).
- Table has `AppListTableSearch` with `AppSearchBarFilterGroup` for scope filtering.
- No column visibility persistence.
- URL is not updated when scope changes — only deep link on initial load.

### Problems/Inconsistencies

1. Scope filtering uses `AppWorkspaceSummaryNotification` badges instead of `AppTabStrip` tabs — inconsistent with Reception pattern.
2. URL is not updated when the user switches scopes or views — no routable tab support.
3. No `AppListTableColumnVisibilityController` or column visibility/width storage keys.
4. The toolbar has redundant scope filtering (both summary notification badges AND the `AppSearchBarFilterGroup` in the search bar offer scope switching).
5. No `columnVisibilityStorageKey` or `columnWidthStorageKey` for table state persistence.
6. The page file is ~2600 lines — dialog widgets should ideally be extracted, but this refactor focuses on the tab/table standardization.

## Reference Implementation

Read these files to understand the target patterns (do NOT modify them):

- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` — Tab-based navigation with `AppTabStrip`, URL updates on tab switch, `AppListTable` with column visibility controller, search, mobile layout.
- `frontend/lib/shared/components/app_tab_strip.dart` — `AppTabStrip` widget (tab bar component with `AppTabItem` list, `selectedId`, `onTabTapped` callback).
- `frontend/lib/shared/components/app_list_table.dart` — `AppListTable<T>` widget with `AppListTableColumnVisibilityController`, `columnVisibilityStorageKey`, `columnWidthStorageKey`.
- `frontend/lib/shared/layout/responsive_page.dart` — `ResponsivePage` wrapper with `PageMaxWidth`.
- `frontend/lib/shared/layout/app_workspace.dart` — `AppWorkspace`, `AppWorkspaceDetailPanel`, `AppWorkspaceStatePanel`, `AppWorkspaceStatusBadge`, `AppWorkspaceStatus`, `AppWorkspaceStatusTone`.
- `frontend/lib/shared/components/app_search_bar.dart` — `AppListTableSearch`, `AppSearchBarFilterGroup`, `AppSearchBarFilterChoice`, `AppSearchBarFilterValue`.
- `frontend/lib/shared/layout/app_workspace_board_toggle.dart` — `AppWorkspaceBoardToggle<T>`.
- `frontend/lib/shared/layout/app_workspace_summary_notification.dart` — `AppWorkspaceSummaryNotification`.

Key patterns to extract from Reception:
- `AppTabStrip` defines tabs via `List<AppTabItem>` with `id`, `icon`, `label`.
- Tab selection tracked via local state `_section` enum.
- `_updateUrlForSection()` calls `GoRouter.of(context).replace<void>(location)` with query parameters.
- Primary action button placed in a `Row` alongside the `AppTabStrip`.
- `AppListTable` uses `columnVisibilityController`, `columnVisibilityStorageKey`, and `columnWidthStorageKey`.

## Target Architecture

### Tab Configuration

| Tab Name | Query Value | Description | Primary Action Button |
|----------|------------|-------------|----------------------|
| Active | `active` | Currently active ICU patients (default) | Start Stay (contextual on selection) |
| Critical | `critical` | Patients with critical alerts | Start Stay (contextual on selection) |
| Transfers | `transfers` | Patients with pending transfers | Start Stay (contextual on selection) |
| Discharge Ready | `discharge` | Patients with planned discharge | Start Stay (contextual on selection) |
| Ended | `ended` | Patients whose ICU stay has ended | None |
| All | `all` | All ICU patients regardless of status | Start Stay (contextual on selection) |
| Bed Board | `beds` | Visual bed occupancy board | None |

### Routing

**File to modify**: `frontend/lib/features/icu/presentation/pages/icu_workspace_page.dart`

The ICU route remains a single `GoRoute` at `/icu` (no sub-routes needed). Tab state is communicated via the `section` query parameter:
- `/icu` → defaults to Active tab
- `/icu?section=active` → Active tab
- `/icu?section=critical` → Critical tab
- `/icu?section=transfers` → Transfers tab
- `/icu?section=discharge` → Discharge Ready tab
- `/icu?section=ended` → Ended tab
- `/icu?section=all` → All tab
- `/icu?section=beds` → Bed Board tab

When the user switches tabs, call `GoRouter.of(context).replace<void>(location)` to update the URL without pushing a new route (same pattern as Reception's `_updateUrlForSection`).

The existing deep-link parameters (`?id=`, `?panel=`) must continue to work alongside the new `section` parameter.

**Modify `IcuBoardQuery`** in `frontend/lib/features/icu/domain/entities/icu_entities.dart` to add a `section` field parsed from the URI, so the page can initialize to the correct tab on deep link.

### Page Layout

The refactored page widget tree should be:

```
AsyncStateScaffold<IcuWorkspaceState>
  └─ ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)
      └─ Column
          ├─ Row
          │   ├─ Expanded(child: AppTabStrip(tabs: [...], selectedId: ..., onTabTapped: ...))
          │   └─ SizedBox + AppAccessActionGate → AppButton.primary("Start ICU Stay")
          ├─ SizedBox(height: theme.spacing.md)
          └─ (if bed board tab selected)
              │   IcuBedBoardPanel(...)
              (else)
                  AppListTable<IcuPatientSummary>(...)
```

- **Tab bar**: `AppTabStrip` with 7 tabs (Active, Critical, Transfers, Discharge Ready, Ended, All, Bed Board). Each tab shows the count in parentheses: `"Active (3)"`.
- **Primary action button**: `AppButton.primary` with label from `l10n.icuActionStartStay`, gated by `AppAccessActionGate` with `writeRequirement`. Only enabled when a selected patient is eligible to start a stay. Hidden when the Bed Board tab is selected.
- **Body**: When a patient-list tab is selected, render `AppListTable<IcuPatientSummary>` with search, column visibility, and pagination. When the Bed Board tab is selected, render `IcuBedBoardPanel`.
- **Search bar**: Integrated via `AppListTable`'s `search` parameter using `AppListTableSearch<IcuPatientSummary>`.
- **Filter**: The `AppSearchBarFilterGroup` for scope filtering is REMOVED (redundant with tabs). The search bar remains for text search only.

### Data & State Management

**No changes to the controller** (`IcuWorkspaceController`). The controller already supports `applyScope()`, `applySearch()`, `changePage()`, `setView()`, and all mutation methods. The page will simply call `controller.applyScope()` when a tab is tapped, exactly as it does today from the summary notification badges.

**Existing providers to reuse**:
- `icuWorkspaceControllerProvider` — `AsyncNotifierProvider<IcuWorkspaceController, Result<IcuWorkspaceState>>` from `frontend/lib/features/icu/presentation/controllers/icu_workspace_controller.dart`.
- `icuRepositoryProvider` — `Provider<IcuRepository>` from `frontend/lib/features/icu/data/repositories/icu_repository_impl.dart`.

**New state**: Add a local `_section` field (an `IcuWorkspaceSection` enum) to track the active tab in `_IcuWorkspaceContentState`, similar to Reception's `_section` field.

## Implementation Steps

1. **Add `IcuWorkspaceSection` enum** — File: `frontend/lib/features/icu/domain/entities/icu_entities.dart`
   - Add a new enum after `IcuBoardView`:
     ```dart
     enum IcuWorkspaceSection { active, critical, transfers, discharge, ended, all, beds }
     ```
   - Add a mapping helper from `IcuWorkspaceSection` to `IcuBoardScope`:
     ```dart
     extension IcuWorkspaceSectionX on IcuWorkspaceSection {
       IcuBoardScope? toBoardScope() => switch (this) {
         IcuWorkspaceSection.active => IcuBoardScope.active,
         IcuWorkspaceSection.critical => IcuBoardScope.critical,
         IcuWorkspaceSection.transfers => IcuBoardScope.transfer,
         IcuWorkspaceSection.discharge => IcuBoardScope.discharge,
         IcuWorkspaceSection.ended => IcuBoardScope.ended,
         IcuWorkspaceSection.all => IcuBoardScope.all,
         IcuWorkspaceSection.beds => null,
       };
       bool get isBedBoard => this == IcuWorkspaceSection.beds;
     }
     ```

2. **Update `IcuBoardQuery` to parse section from URI** — File: `frontend/lib/features/icu/domain/entities/icu_entities.dart`
   - Add `String section` field (default `''`) to `IcuBoardQuery`.
   - In `IcuBoardQuery.fromUri`, parse `params['section']` and store it.
   - Add `section` to `copyWith`.

3. **Refactor `_IcuWorkspaceContent`** — File: `frontend/lib/features/icu/presentation/pages/icu_workspace_page.dart`
   - Add `late IcuWorkspaceSection _section;` state field.
   - Add `late final AppListTableColumnVisibilityController<IcuPatientSummary> _columnVisibilityController;`.
   - In `initState()`:
     - Initialize `_section` from `widget.initialQuery` (parse `section` query param to `IcuWorkspaceSection`), defaulting to `IcuWorkspaceSection.active`.
     - Create `_columnVisibilityController = AppListTableColumnVisibilityController<IcuPatientSummary>();`.
   - In `dispose()`, dispose the column visibility controller.
   - Add `_updateUrlForSection(IcuWorkspaceSection section)` method following Reception's pattern:
     ```dart
     void _updateUrlForSection(IcuWorkspaceSection section) {
       if (!mounted) return;
       final String tab = section.name;
       final String location = AppRoutes.icu.location(
         queryParameters: <String, String>{
           if (tab != 'active') 'section': tab,
         },
       );
       GoRouter.of(context).replace<void>(location);
     }
     ```
   - Add `_sectionFromQueryValue(String raw)` static method to parse section query values.
   - Add `_sectionLabel(AppLocalizations l10n, IcuWorkspaceSection section)` returning localized tab labels.
   - Add `_sectionIcon(IcuWorkspaceSection section)` returning appropriate icons.
   - Add `_sectionCount(IcuWorkspaceState state, IcuWorkspaceSection section)` returning the count for each tab badge.

4. **Replace the `build()` method of `_IcuWorkspaceContentState`** — File: `frontend/lib/features/icu/presentation/pages/icu_workspace_page.dart`
   - Remove `AppWorkspace(...)` wrapper.
   - Use the new tab-based layout:
     ```dart
     @override
     Widget build(BuildContext context) {
       final AppLocalizations l10n = context.l10n;
       final ThemeData theme = Theme.of(context);
       final IcuWorkspaceState state = widget.state;
       final IcuWorkspaceController controller = ref.read(
         icuWorkspaceControllerProvider.notifier,
       );
       final bool isBedView = _section.isBedBoard;

       return ResponsivePage(
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
                         for (final IcuWorkspaceSection section
                             in IcuWorkspaceSection.values)
                           AppTabItem(
                             id: section.name,
                             icon: _sectionIcon(section),
                             label: '${_sectionLabel(l10n, section)} (${_sectionCount(state, section)})',
                           ),
                       ],
                       selectedId: _section.name,
                       onTabTapped: (String tabId) {
                         for (final IcuWorkspaceSection section
                             in IcuWorkspaceSection.values) {
                           if (section.name == tabId) {
                             setState(() => _section = section);
                             _updateUrlForSection(section);
                             final IcuBoardScope? scope = section.toBoardScope();
                             if (scope != null) {
                               controller.applyScope(scope);
                             }
                             if (section.isBedBoard &&
                                 state.bedBoard.beds.isEmpty) {
                               controller.loadBedBoard();
                             }
                             break;
                           }
                         }
                       },
                     ),
                   ),
                   if (!isBedView) ...<Widget>[
                     SizedBox(width: theme.spacing.sm),
                     AppAccessActionGate(
                       requirement: _IcuWorkspaceContent.writeRequirement,
                       builder: (BuildContext context, bool isAllowed) {
                         final bool canStartStay =
                             state.selectedDetail?.isEligibleToStartStay ?? false;
                         return AppButton.primary(
                           label: l10n.icuActionStartStay,
                           leadingIcon: Icons.play_circle_outline,
                           enabled: isAllowed && canStartStay && !state.isSaving,
                           onPressed: () => _confirmAction(
                             context: context,
                             title: l10n.icuStartStayTitle,
                             body: l10n.icuStartStayBody,
                             actionLabel: l10n.icuStartStayActionLabel,
                             onConfirmed: controller.startIcuStay,
                           ),
                         );
                       },
                     ),
                   ],
                 ],
               ),
               SizedBox(height: theme.spacing.md),
               if (isBedView)
                 IcuBedBoardPanel(
                   state: state,
                   writeRequirement: _IcuWorkspaceContent.writeRequirement,
                 )
               else
                 _IcuBoardPanel(
                   state: state,
                   writeRequirement: _IcuWorkspaceContent.writeRequirement,
                   searchController: _searchController,
                   columnVisibilityController: _columnVisibilityController,
                 ),
             ],
           ),
         ),
       );
     }
     ```

5. **Update `_IcuBoardPanel`** — File: `frontend/lib/features/icu/presentation/pages/icu_workspace_page.dart`
   - Add `columnVisibilityController` parameter to `_IcuBoardPanel`.
   - Pass `columnVisibilityController: columnVisibilityController` to `AppListTable`.
   - Add `columnVisibilityStorageKey: 'icu_board'` to `AppListTable`.
   - Add `columnWidthStorageKey: 'icu_cw_board'` to `AppListTable`.
   - REMOVE the `showAdvancedFilterButton`, `advancedFilterButtonLabel`, `advancedFilterTitle`, `advancedFilterApplyLabel`, `advancedFilterResetLabel`, `enableDateFilter`, `allFieldsLabel`, `filterGroups`, `filterValue`, `hasActiveFilters`, and `onFilterChanged` properties from `AppListTableSearch` — scope filtering is now handled by tabs.
   - Keep the search `controller`, `semanticLabel`, `hintText`, `matcher`, and `onSubmitted` properties.

6. **Add tab helper methods** — File: `frontend/lib/features/icu/presentation/pages/icu_workspace_page.dart`
   - Add `_sectionLabel`:
     ```dart
     String _sectionLabel(AppLocalizations l10n, IcuWorkspaceSection section) {
       return switch (section) {
         IcuWorkspaceSection.active => l10n.icuActiveIcuLabel,
         IcuWorkspaceSection.critical => l10n.icuCriticalAlertsLabel,
         IcuWorkspaceSection.transfers => l10n.icuTransfersLabel,
         IcuWorkspaceSection.discharge => l10n.icuDischargeReadyLabel,
         IcuWorkspaceSection.ended => l10n.icuEndedStaysLabel,
         IcuWorkspaceSection.all => l10n.icuAllIcuLabel,
         IcuWorkspaceSection.beds => l10n.icuViewBedBoard,
       };
     }
     ```
   - Add `_sectionIcon`:
     ```dart
     static IconData _sectionIcon(IcuWorkspaceSection section) {
       return switch (section) {
         IcuWorkspaceSection.active => Icons.bed_outlined,
         IcuWorkspaceSection.critical => Icons.priority_high_outlined,
         IcuWorkspaceSection.transfers => Icons.compare_arrows_outlined,
         IcuWorkspaceSection.discharge => Icons.fact_check_outlined,
         IcuWorkspaceSection.ended => Icons.output_outlined,
         IcuWorkspaceSection.all => Icons.inventory_2_outlined,
         IcuWorkspaceSection.beds => Icons.bed_outlined,
       };
     }
     ```
   - Add `_sectionCount`:
     ```dart
     int _sectionCount(IcuWorkspaceState state, IcuWorkspaceSection section) {
       return switch (section) {
         IcuWorkspaceSection.active => state.activeCount,
         IcuWorkspaceSection.critical => state.criticalCount,
         IcuWorkspaceSection.transfers => state.transferCount,
         IcuWorkspaceSection.discharge => state.dischargeReadyCount,
         IcuWorkspaceSection.ended => state.board.items.where((IcuPatientSummary item) => item.isEndedIcu).length,
         IcuWorkspaceSection.all => _pageTotal(state.board),
         IcuWorkspaceSection.beds => state.bedBoard.beds.length,
       };
     }
     ```

7. **Remove stale toolbar code** — File: `frontend/lib/features/icu/presentation/pages/icu_workspace_page.dart`
   - Remove the `AppWorkspace` widget and its `toolbar: appWorkspaceToolbarWithLabels(...)` block entirely.
   - Remove the `summaryNotifications` list and the `AppWorkspaceBoardToggle` from the toolbar.
   - Remove the secondary action buttons (`Start Stay`, `Record Vitals`, `Record Observation`) from the toolbar — the primary "Start Stay" action moves to the tab strip row. The "Record Vitals" and "Record Observation" actions remain available inside the detail dialog's `_IcuActionPanel`.
   - Remove the `onRefresh` and `isRefreshing` toolbar callbacks — add a refresh button inline or rely on realtime sync.

8. **Remove stale scope filter code** — File: `frontend/lib/features/icu/presentation/pages/icu_workspace_page.dart`
   - Remove the `_scopeOptions` function.
   - Remove the `_icuScopeFilterKey` constant.
   - Remove the `_icuFilterValue` function.
   - Remove the `_icuScopeFromFilter` function.
   - Remove the `_icuScopeFilterChoices` function.

9. **Add required imports** — File: `frontend/lib/features/icu/presentation/pages/icu_workspace_page.dart`
   - Add: `import 'package:hosspi_hms/shared/components/app_tab_strip.dart';` (if not already exported from `components.dart` barrel).
   - Verify `AppTabStrip` and `AppTabItem` are accessible. If exported via `components.dart`, no additional import needed.
   - Add: `import 'package:hosspi_hms/shared/layout/responsive_page.dart';` (if not already exported from `layout.dart` barrel).

10. **Update deep-link handling** — File: `frontend/lib/features/icu/presentation/pages/icu_workspace_page.dart`
    - In `_scheduleDeepLink` and `_handleDeepLink`, after handling the `focusAdmissionId`, also parse the `section` query parameter and set `_section` accordingly.
    - Parse the section from `widget.initialQuery` in `initState`.

## Shared Components — MUST Reuse

Do NOT create new implementations of these. Import and use them directly:

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` | `package:hosspi_hms/shared/components/app_tab_strip.dart` (or via `components.dart` barrel) | Tab navigation with `AppTabItem` list |
| `AppListTable<T>` | `package:hosspi_hms/shared/components/app_list_table.dart` (or via `components.dart` barrel) | Data table with pagination, search, column visibility |
| `AppListTableColumnVisibilityController<T>` | Same as `AppListTable` | Column visibility persistence |
| `AppListTableSearch<T>` | `package:hosspi_hms/shared/components/app_search_bar.dart` (or via `components.dart` barrel) | Search bar integrated in table |
| `ResponsivePage` | `package:hosspi_hms/shared/layout/responsive_page.dart` (or via `layout.dart` barrel) | Page wrapper with max-width constraint |
| `AppWorkspaceStatusBadge` | `package:hosspi_hms/shared/layout/app_workspace.dart` (or via `layout.dart` barrel) | Status badge in table cells |
| `AppWorkspaceDetailPanel` | Same as above | Detail panel sections |
| `AppWorkspaceStatePanel` | Same as above | Empty/loading state panels |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Permission gating on actions |
| `AppButton` | `package:hosspi_hms/shared/components/components.dart` | Primary/secondary/tertiary buttons |
| `AppPatientDetails` | `package:hosspi_hms/shared/components/app_patient_details.dart` (or via `components.dart` barrel) | Patient detail display in mobile/detail views |
| `IcuBedBoardPanel` | `package:hosspi_hms/features/icu/presentation/widgets/icu_bed_board_panel.dart` | Bed board view (keep as-is) |

## Files to Create

No new files need to be created. All changes are modifications to existing files.

## Files to Modify

| File Path | Changes |
|-----------|---------|
| `frontend/lib/features/icu/domain/entities/icu_entities.dart` | Add `IcuWorkspaceSection` enum with `IcuWorkspaceSectionX` extension. Add `section` field to `IcuBoardQuery`. |
| `frontend/lib/features/icu/presentation/pages/icu_workspace_page.dart` | Replace `AppWorkspace` layout with `ResponsivePage` + `AppTabStrip`. Add tab state management, URL updates, column visibility controller. Remove `AppWorkspaceSummaryNotification` toolbar, `AppWorkspaceBoardToggle`, scope filter functions. Update `_IcuBoardPanel` to accept column visibility controller and remove filter props from search. |
| `frontend/lib/features/icu/data/dtos/icu_dtos.dart` | No changes expected — DTO layer is unaffected. |
| `frontend/lib/features/icu/presentation/controllers/icu_workspace_controller.dart` | No changes — controller API is fully compatible. |
| `frontend/lib/features/icu/presentation/widgets/icu_bed_board_panel.dart` | No changes — bed board is preserved as-is. |
| `frontend/lib/features/icu/presentation/widgets/icu_format.dart` | No changes — formatting helpers are preserved. |

## Files to Delete (if any)

No files need to be deleted. The refactor modifies existing files only.

## Cleanup: Remove Stale Code

After the refactor, the agent MUST remove all dead/stale code left behind:

- [ ] Remove the `_scopeOptions()` function from `icu_workspace_page.dart`.
- [ ] Remove the `_icuScopeFilterKey` constant from `icu_workspace_page.dart`.
- [ ] Remove the `_icuFilterValue()` function from `icu_workspace_page.dart`.
- [ ] Remove the `_icuScopeFromFilter()` function from `icu_workspace_page.dart`.
- [ ] Remove the `_icuScopeFilterChoices()` function from `icu_workspace_page.dart`.
- [ ] Remove any unused imports across all modified files (e.g., `AppWorkspaceBoardToggle` import if no longer used, `AppWorkspaceSummaryNotification` import if no longer used).
- [ ] Remove the `_statusOptions()` function if unused after removing filter code (check if it's still used by `_CriticalAlertDialog`).
- [ ] Verify no test files reference removed functions — update stale test references.
- [ ] Run `dart analyze` to catch any remaining unreferenced declarations and remove them.

List every file and symbol removed in a "Cleanup Summary" section at the end of the implementation.

## Database Migrations

No database migrations required — schema unchanged. This refactor only restructures the Flutter UI layer (tab navigation, layout, column visibility). The backend API endpoints, data models, and query parameters remain identical. The controller already supports all scope-based filtering via the `IcuBoardScope` enum and `applyScope()` method.

## Responsive Design Requirements

- **Desktop (≥1024px):** Full `AppListTable` with all 7 columns visible (Patient, Bed, Source, Alert, Status, ICU Start, Transfer). Tab strip scrollable horizontally if needed. Primary action button visible inline.
- **Tablet (600–1023px):** `AppListTable` with column visibility allowing users to hide less critical columns (Source, Transfer). Tab strip may wrap or scroll. Primary action button visible.
- **Mobile (<600px):** `AppListTable` switches to `mobileItemBuilder` rendering `_IcuPatientCell` with status badges in a `Wrap`. Tab strip scrolls horizontally. Primary action button may stack below tabs.

The `ResponsivePage` widget (from `frontend/lib/shared/layout/responsive_page.dart`) handles max-width constraints. The `AppListTable` already handles the mobile breakpoint switch via its `mobileItemBuilder` parameter. The `AppTabStrip` handles horizontal scrolling natively.

## Verification Steps

After implementation, the agent MUST run these commands and confirm they pass:

```bash
# Format
cd frontend && dart format .

# Analyze
dart analyze --fatal-infos

# Run tests related to ICU
flutter test test/features/icu/

# Run shared component tests to ensure no regressions
flutter test test/shared/
```

## Testing Requirements

Write or update these tests:

- [ ] Tab navigation: switching tabs calls `controller.applyScope()` with the correct scope
- [ ] Deep linking: navigating to `/icu?section=critical` initializes the Critical tab
- [ ] Deep linking: navigating to `/icu?section=beds` shows the Bed Board
- [ ] Existing deep links: `/icu?id=ADM-123&panel=vitals` still opens the detail dialog on the vitals panel
- [ ] Table data: the patient board tab displays the `AppListTable` with correct columns
- [ ] Search: typing in the search bar calls `controller.applySearch()`
- [ ] Column visibility: the `columnVisibilityStorageKey` is set to `'icu_board'`
- [ ] Bed board: selecting the Bed Board tab renders `IcuBedBoardPanel`
- [ ] Primary action: the "Start ICU Stay" button is visible on patient tabs and hidden on the Bed Board tab
- [ ] No regressions: all existing controller tests pass unchanged

## Acceptance Criteria

The refactor is complete when ALL of the following are true:

- [ ] The ICU screen uses `AppTabStrip` with 7 tabs (Active, Critical, Transfers, Discharge Ready, Ended, All, Bed Board)
- [ ] Each tab updates the URL query parameter (`?section=`) supporting deep linking
- [ ] The primary action button ("Start ICU Stay") is positioned in the tab strip row and hidden on Bed Board tab
- [ ] The page body uses `AppListTable` with `columnVisibilityController`, `columnVisibilityStorageKey: 'icu_board'`, and `columnWidthStorageKey: 'icu_cw_board'`
- [ ] The `AppSearchBarFilterGroup` scope filter is removed from the search bar (tabs handle scoping)
- [ ] The `AppWorkspaceSummaryNotification` badges and `AppWorkspaceBoardToggle` are removed from the toolbar
- [ ] The `AppWorkspace` wrapper is replaced with `ResponsivePage`
- [ ] No shared component is re-implemented — only imported and used
- [ ] The layout is fully responsive across mobile, tablet, and desktop via `ResponsivePage` and `AppListTable`'s `mobileItemBuilder`
- [ ] All old/duplicate scope filter code is removed — no stale functions or dead symbols remain
- [ ] All ICU domain-specific business logic is preserved (detail dialogs, clinical actions, bed board, vitals, alerts, observations, transfers, discharge)
- [ ] The controller (`IcuWorkspaceController`) is NOT modified — only the page UI layer changes
- [ ] No database migrations required — schema unchanged
- [ ] `dart analyze` reports no new issues — zero unused imports, zero unreferenced declarations
- [ ] All tests pass (no stale test references to removed code)
