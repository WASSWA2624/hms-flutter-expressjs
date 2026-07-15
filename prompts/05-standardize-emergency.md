# Standardize Emergency Screen

## Objective

Refactor the Emergency workspace to match the standardized tab-and-table layout used by the Reception workspace. The current emergency screen uses `AppWorkspace` with `appWorkspaceToolbarWithLabels` and summary-notification chips for scope filtering. The refactored screen must adopt the Reception pattern: an `AppTabStrip` with clearly labelled sections, a per-tab `AppListTable` with client-side search, per-section columns, and a tab-aware primary action button — while preserving all existing domain logic (triage, response, dispatch, ambulance trips, handoff, theater scheduling, and "care before billing" workflows).

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification — all information needed is in this prompt. Run tests and formatting after implementation.

The workspace root is `d:\coding\apps\flutter\hms`. The frontend code is in `frontend/`. Use `flutter test` and `dart format` from the `frontend/` directory.

## Current State (from audit)

### Emergency module files

| File | Purpose |
|------|---------|
| `frontend/lib/features/emergency/presentation/pages/emergency_workspace_page.dart` | Main page: ~2 150 lines. Contains the full workspace, detail panel, dialogs, helper functions, and `_EmergencyText` string constants. Uses `AppWorkspace` + `appWorkspaceToolbarWithLabels`. |
| `frontend/lib/features/emergency/presentation/controllers/emergency_workspace_controller.dart` | `EmergencyWorkspaceController` — Riverpod `AsyncNotifier` managing board state, pagination, search, scope, detail selection, mutations, realtime sync, and adaptive polling. |
| `frontend/lib/features/emergency/domain/entities/emergency_entities.dart` | Domain classes: `EmergencyBoardScope`, `EmergencyDetailPanelFocus`, `EmergencyWorkspaceQuery`, `EmergencyHandoffOutcome`, `EmergencyBoardQuery`, `EmergencyCaseSummary`, `EmergencyCaseDetail`, `EmergencyQuickArrivalInput`, `EmergencyWorkspaceState`, plus reference data and sub-entities for triage, response, dispatch, and trips. |
| `frontend/lib/features/emergency/domain/repositories/emergency_repository.dart` | `EmergencyRepository` interface — 12 methods covering board listing, detail loading, CRUD mutations, handoff, ambulance lifecycle. |
| `frontend/lib/features/emergency/data/repositories/emergency_repository_impl.dart` | `EmergencyRepositoryImpl` — full REST implementation using `ApiClient` against `HmsApiResource.emergencyCases`, `triageAssessments`, `emergencyResponses`, `ambulanceDispatches`, `ambulanceTrips`, and `ambulances`. |
| `frontend/lib/features/emergency/data/dtos/emergency_dtos.dart` | DTOs: `EmergencyCasePageDto`, `EmergencyCaseDto`, `EmergencyTriageAssessmentDto`, `EmergencyResponseRecordDto`, `EmergencyAmbulanceDto`, `EmergencyAmbulanceDispatchDto`, `EmergencyAmbulanceTripDto`, plus decoder functions. |
| `frontend/test/features/emergency/emergency_handoff_test.dart` | Tests for `EmergencyWorkspaceQuery.fromUri`, `EmergencyHandoffOutcome` deep links, `EmergencyCaseDto` handoff mapping. |

### Current layout problems

- **No tabs.** The emergency board uses `AppWorkspaceSummaryNotification` chips in the toolbar to switch `EmergencyBoardScope`. This makes all scopes live in a single flat table.
- **Monolith page file.** All dialogs (`_QuickArrivalDialog`, `_DispatchDialog`, `_HandoffDialog`), helper widgets (`_EmergencyCaseCell`, `_EmergencyDetailPanel`, `_EmergencyHandoffOutcomePanel`, `_EmergencyTimelinePanel`, `_AmbulancePanel`, `_EmergencyActionPanel`), option lists, and text constants live in a single 2 150-line file.
- **No section-specific columns.** The same 6 columns are used for every scope, whereas Reception adapts columns per tab.
- **No tab-aware URL sync.** Reception updates the browser URL when the user switches tabs (`?section=...`); Emergency does not.
- **Missing `AppTabStrip`.** Reception uses the shared `AppTabStrip` component for tab navigation; Emergency relies on summary-notification chips.
- **Column-visibility storage keys are absent.** Reception passes `columnVisibilityStorageKey` and `columnWidthStorageKey` per tab; Emergency does not.

### Route configuration

- **Path:** `/emergency`
- **Route data:** `AppRoutes.emergency` defined in `frontend/lib/app/router/app_routes.dart` (line 319).
- **GoRouter entry:** `frontend/lib/app/router/app_router.dart` — a simple `GoRoute` that passes `EmergencyWorkspaceQuery.fromUri(state.uri)` as `initialQuery`.
- **Query model:** `EmergencyWorkspaceQuery` supports `?id=`, `?panel=`, `?search=` deep links.

## Reference Implementation

Read these files to understand the target patterns (do NOT modify them):

| File | What to learn |
|------|---------------|
| `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` | Tab-based workspace with `AppTabStrip`, per-section table columns, `AppListTable` with `columnVisibilityStorageKey`/`columnWidthStorageKey`, search with `AppListTableSearch`, tab-aware URL sync via `GoRouter.of(context).replace`, mobile item builder, section counts in tab labels. |
| `frontend/lib/features/reception/domain/entities/reception_entities.dart` | `ReceptionWorkspaceQuery` with `.fromUri()`, `.hasRouteTargeting`, `.signature`, `ReceptionDeskSection` enum. |
| `frontend/lib/features/reception/presentation/reception_access.dart` | Access requirements pattern. |
| `frontend/lib/shared/components/app_tab_strip.dart` | `AppTabStrip` and `AppTabItem` widget API. |
| `frontend/lib/shared/components/app_list_table.dart` | `AppListTable<T>` API — `items`, `columns`, `search`, `columnVisibilityController`, `columnVisibilityStorageKey`, `columnWidthStorageKey`, `onRowSelected`, `emptyBuilder`, `mobileItemBuilder`, `isLoading`. |
| `frontend/lib/shared/components/app_search_bar.dart` | `AppListTableSearch<T>`, `AppSearchBarFilterGroup`, `AppSearchBarFilterValue`. |
| `frontend/lib/shared/layout/app_workspace.dart` | `AppWorkspace` widget and `AppWorkspaceToolbarConfig`. |
| `frontend/lib/shared/layout/app_workspace_toolbar.dart` | `appWorkspaceToolbarWithLabels` helper. |
| `frontend/lib/shared/layout/responsive_page.dart` | `ResponsivePage` and `PageMaxWidth`. |
| `frontend/lib/shared/workflow_actions/workflow_action_button.dart` | `WorkflowActionButton` for the "Next action" column. |

## Target Architecture

### Tab Configuration

| Tab Name | Route Query Value | Description | Icon | Primary Action Button |
|----------|------------------|-------------|------|----------------------|
| Active cases | `active` | Open emergency cases (default scope) | `Icons.emergency_outlined` | "Quick arrival" — opens `_QuickArrivalDialog` |
| Critical | `critical` | Open + Critical/High severity | `Icons.priority_high_outlined` | "Quick arrival" |
| Ambulance | `ambulance` | Cases with dispatch/trip activity | `Icons.airport_shuttle_outlined` | "Quick arrival" |
| Handoff ready | `handoff` | Triaged + responded + open → ready to hand off | `Icons.output_outlined` | "Quick arrival" |
| Closed | `closed` | Completed/cancelled cases | `Icons.check_circle_outlined` | None |
| All | `all` | Every emergency record | `Icons.inventory_2_outlined` | "Quick arrival" |

### Routing

The route stays at `/emergency`. The tab is expressed as a query parameter `?scope=active|critical|ambulance|handoff|closed|all`. When the user switches tabs, call `GoRouter.of(context).replace(...)` to keep the URL in sync, exactly as Reception does with `?section=...`. The existing `EmergencyWorkspaceQuery` already has `caseId`, `panel`, and `search`. Add a `scope` field that maps to the query parameter.

### Page Layout

Replace the current `AppWorkspace`-based layout with a `ResponsivePage`-wrapped column, matching Reception:

```
ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)
└── Column(crossAxisAlignment: CrossAxisAlignment.stretch)
    ├── Row
    │   ├── Expanded → AppTabStrip (6 tabs, counts in labels)
    │   └── SizedBox(width: theme.spacing.sm)
    │   └── AppAccessActionGate → AppButton.primary("Quick arrival")
    ├── SizedBox(height: theme.spacing.md)
    └── AppListTable<EmergencyCaseSummary>(
          items: _buildRows(state, currentTab),
          columns: _columnsForTab(currentTab),
          columnVisibilityController: _columnVisibilityController,
          columnVisibilityStorageKey: 'emergency_${tab.name}',
          columnWidthStorageKey: 'emergency_cw_${tab.name}',
          search: AppListTableSearch(...),
          emptyBuilder: ...,
          mobileItemBuilder: ...,
          onRowSelected: _openEmergencyDetailDialog,
          isLoading: state.isRefreshingBoard,
        )
```

### Data & State Management

- **Keep** `EmergencyWorkspaceController` as-is. The existing `applyScope()`, `applySearch()`, `changePage()`, `selectCase()` methods already manage board filtering. The tab widget simply calls `controller.applyScope(...)` when the user taps a tab.
- **Keep** `emergencyWorkspaceControllerProvider` unchanged.
- **Keep** all repository and DTO layers unchanged.
- **Add** a `scope` field to `EmergencyWorkspaceQuery` so the deep-link `?scope=active` can pre-select a tab on navigation.

## Implementation Steps

### Step 1: Add `scope` to `EmergencyWorkspaceQuery`

**File:** `frontend/lib/features/emergency/domain/entities/emergency_entities.dart`

Add a `scope` string field to `EmergencyWorkspaceQuery` and parse it in `fromUri()`:
- Add `this.scope = ''` to the constructor.
- In `fromUri()`, add `scope: pick(<String>['scope', 'board', 'tab'])`.
- Update `hasRouteTargeting` to include `scope.isNotEmpty`.
- Update `signature` to include `scope`.

### Step 2: Create an `EmergencyBoardTab` enum

**File:** `frontend/lib/features/emergency/domain/entities/emergency_entities.dart`

Add a new enum at the top of the file (near `EmergencyBoardScope`):

```dart
enum EmergencyBoardTab { active, critical, ambulance, handoff, closed, all }
```

This enum maps 1:1 to `EmergencyBoardScope` but is used exclusively by the UI layer to identify tabs.

### Step 3: Extract widgets to a dedicated widgets file

**File to create:** `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart`

Move these private widgets from `emergency_workspace_page.dart` into this file and make them public (remove leading underscore):
- `EmergencyCaseCell` (was `_EmergencyCaseCell`)
- `EmergencyDetailPanel` (was `_EmergencyDetailPanel`)
- `EmergencyHandoffOutcomePanel` (was `_EmergencyHandoffOutcomePanel`)
- `EmergencyTimelinePanel` (was `_EmergencyTimelinePanel`)
- `AmbulancePanel` (was `_AmbulancePanel`)
- `EmergencyActionPanel` (was `_EmergencyActionPanel`)
- `EmergencyText` string constants class (was `_EmergencyText`)
- All helper functions: `_severityStatus`, `_responseStatus`, `_triageStatus`, `_caseStatus`, `_ambulanceTone`, `_severityTone`, `_pageLabel`, `_countLabel`, `_pageTotal`, `_dateTimeLabel`, `_apiLabel`, `_joinDisplay`, `_nonEmpty`, `_firstNonEmpty`, `_normalizedOption`, `_requiredText`, `_requiredSelect`, `_emergencyNextStepCode`, `_hasTheaterHandoff`, `_escapeHtml`, `_emergencySummaryHtml`, `_showFailureIfNeeded`
- Helper functions for filters: `_scopeOptions`, `_emergencyScopeFilterKey`, `_emergencyFilterValue`, `_emergencyScopeFromFilter`, `_emergencyScopeFilterChoices`, `_severityOptions`, `_triageOptions`, `_triageActionOptions`, `_ambulanceStatusOptions`, `_handoffOptions`
- `_rowColor` function

Keep all imports the helpers need. Export from a barrel if desired.

### Step 4: Extract dialogs to a dedicated dialogs file

**File to create:** `frontend/lib/features/emergency/presentation/widgets/emergency_dialogs.dart`

Move these dialog widgets from `emergency_workspace_page.dart`:
- `QuickArrivalDialog` (was `_QuickArrivalDialog`)
- `DispatchDialog` (was `_DispatchDialog`)
- `HandoffDialog` (was `_HandoffDialog`)
- `DispatchInput` (was `_DispatchInput`)
- `HandoffInput` (was `_HandoffInput`)

Make them public (remove leading underscore).

### Step 5: Rewrite `emergency_workspace_page.dart` with tab-based layout

**File:** `frontend/lib/features/emergency/presentation/pages/emergency_workspace_page.dart`

Rewrite `_EmergencyWorkspaceContentState.build()` to follow the Reception pattern:

1. **Replace** the `AppWorkspace(toolbar: appWorkspaceToolbarWithLabels(...), body: _EmergencyBoardPanel(...))` with a `ResponsivePage` → `Column` structure.

2. **Add** an `AppTabStrip` as the first child in the `Row`, with one `AppTabItem` per `EmergencyBoardTab` value. Each tab label should include the count in parentheses (e.g., "Active (3)").

3. **Place** the "Quick arrival" `AppButton.primary` next to the tab strip (same `Row`), gated by `AppAccessActionGate` with `_writeRequirement`.

4. **Below** the tab strip, place the `AppListTable<EmergencyCaseSummary>` directly (no `_EmergencyBoardPanel` wrapper needed anymore).

5. **Add** a `_columnsForTab(EmergencyBoardTab tab)` method that returns tab-specific columns:

   - **Active / Critical / All tabs:** Patient, Priority, Arrival, Response, Location, Next action
   - **Ambulance tab:** Patient, Priority, Dispatch status, Ambulance, Trip status, Arrival
   - **Handoff ready tab:** Patient, Priority, Triage level, Response, Next action (handoff button)
   - **Closed tab:** Patient, Priority, Arrival, Handoff destination, Closed at

6. **Add** `columnVisibilityStorageKey: 'emergency_${_currentTab.name}'` and `columnWidthStorageKey: 'emergency_cw_${_currentTab.name}'` to each `AppListTable`.

7. **Add** URL sync: when the user taps a tab, call `GoRouter.of(context).replace(AppRoutes.emergency.location(queryParameters: {'scope': tab.name}))`.

8. **Maintain** client-side `items` filtering by computing the visible rows from `state.board.items` based on `_currentTab`, exactly as Reception does with `_buildRows(state)`.

9. **Preserve** `onRowSelected` → `_openEmergencyDetailDialog(...)` behavior.

10. **Preserve** the `_applyDeepLink` logic — extend it to handle `?scope=` by mapping to the matching tab on mount.

11. **Remove** `AppWorkspaceSummaryNotification` chips from the toolbar since their role is now served by the tab strip.

### Step 6: Update the search configuration

Move the advanced filter (board scope dropdown) out of the search bar's `advancedFilter*` parameters. The scope is now controlled by the tab strip. Keep the text search in the `AppListTableSearch`. Remove the `showAdvancedFilterButton`, `advancedFilterButtonLabel`, `advancedFilterTitle`, `advancedFilterApplyLabel`, `advancedFilterResetLabel`, `enableDateFilter`, `allFieldsLabel`, `filterGroups`, `filterValue`, `hasActiveFilters`, and `onFilterChanged` properties from the search config.

### Step 7: Wire `EmergencyWorkspaceQuery.scope` in the router

**File:** `frontend/lib/app/router/app_router.dart`

The `GoRoute` for `/emergency` already passes `EmergencyWorkspaceQuery.fromUri(state.uri)`. After Step 1, the `scope` field will be parsed automatically. No router change is needed.

### Step 8: Update tab counts

Expose tab counts from `EmergencyWorkspaceState`. The state object already has `activeCount`, `criticalCount`, `ambulanceCount`, and `handoffCount`. Add:
- `closedCount` — count of items where `!item.isOpen`
- `allCount` — `board.items.length` or `board.totalItemCount`

Use these in the tab labels.

### Step 9: Add mobile item builder

Add a `_mobileItemBuilder(BuildContext context, EmergencyCaseSummary item)` method that returns a compact mobile layout matching Reception's `AppPatientDetails`-based mobile rows. Reuse `EmergencyCaseCell` content with severity and response badges in a `Wrap`.

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` | `package:hosspi_hms/shared/components/app_tab_strip.dart` (via `components.dart`) | Tab navigation across board scopes |
| `AppListTable<T>` | `package:hosspi_hms/shared/components/app_list_table.dart` (via `components.dart`) | Data table for emergency cases |
| `AppListTableColumn<T>` | Same as above | Column definitions per tab |
| `AppListTableSearch<T>` | `package:hosspi_hms/shared/components/app_search_bar.dart` (via `components.dart`) | Search bar integration |
| `AppListTableColumnVisibilityController<T>` | `package:hosspi_hms/shared/components/app_list_table_column_visibility_memory.dart` (via `components.dart`) | Column show/hide state |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Permission-gated primary action button |
| `AppButton` | `package:hosspi_hms/shared/components/app_button.dart` (via `components.dart`) | Primary action button |
| `AppWorkspaceStatusBadge` / `AppWorkspaceStatus` | `package:hosspi_hms/shared/layout/app_workspace.dart` (via `layout.dart`) | Status badges in table cells |
| `WorkflowActionButton` | `package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart` | "Next action" column |
| `ResponsivePage` / `PageMaxWidth` | `package:hosspi_hms/shared/layout/responsive_page.dart` (via `layout.dart`) | Page wrapper with max width |
| `AppPatientDetails` | `package:hosspi_hms/shared/components/app_patient_details.dart` (via `components.dart`) | Mobile row builder and detail panel |
| `AppTimeline` / `AppTimelineItem` | `package:hosspi_hms/shared/components/app_timeline.dart` (via `components.dart`) | Triage/response/ambulance timelines |
| `AppDialog` / `showAppDialog` | `package:hosspi_hms/shared/components/app_dialog.dart` (via `components.dart`) | All dialogs |
| `AppActionPanel` / `AppActionItem` | `package:hosspi_hms/shared/components/components.dart` | Case action panel |
| `AppInfoTileGrid` / `AppInfoTileData` | `package:hosspi_hms/shared/components/app_info_tile.dart` (via `components.dart`) | Handoff outcome details |
| `AppStateView` / `AppWorkspaceStatePanel` | `package:hosspi_hms/shared/components/app_state_view.dart` (via `components.dart`) | Empty/loading states |
| `AsyncStateScaffold` | `package:hosspi_hms/shared/components/app_state_view.dart` (via `components.dart`) | Async state loading wrapper |

**Do NOT** create new table, tab, search, or filter implementations. Reuse the shared components listed above.

## Files to Create

| File Path | Purpose |
|-----------|---------|
| `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` | Extracted cell widgets, detail panel, timeline panel, ambulance panel, action panel, handoff outcome panel, text constants, helper functions |
| `frontend/lib/features/emergency/presentation/widgets/emergency_dialogs.dart` | Extracted dialog widgets: quick arrival, dispatch, handoff |

## Files to Modify

| File Path | Changes |
|-----------|---------|
| `frontend/lib/features/emergency/presentation/pages/emergency_workspace_page.dart` | Rewrite to tab-based layout using `AppTabStrip` + `AppListTable`. Remove extracted widgets/dialogs. Import new widget files. Replace `AppWorkspace` + `appWorkspaceToolbarWithLabels` with `ResponsivePage` + `Column`. |
| `frontend/lib/features/emergency/domain/entities/emergency_entities.dart` | Add `EmergencyBoardTab` enum. Add `scope` field to `EmergencyWorkspaceQuery`. Add `closedCount` and `allCount` getters to `EmergencyWorkspaceState`. |
| `frontend/test/features/emergency/emergency_handoff_test.dart` | Add test case for `EmergencyWorkspaceQuery.fromUri` parsing the new `?scope=` parameter. |

## Files to Delete (if any)

None. No files should be deleted.

## Cleanup: Remove Stale Code

- [ ] Remove `AppWorkspaceSummaryNotification` usage from the emergency page (the toolbar chips that filter by scope are replaced by tabs).
- [ ] Remove `appWorkspaceToolbarWithLabels` call from the emergency page (the toolbar with summary notifications is no longer needed).
- [ ] Remove `AppWorkspace` wrapper from the emergency page (replaced by `ResponsivePage`).
- [ ] Remove `_EmergencyBoardPanel` widget class — its logic is now inline in the page.
- [ ] Remove all now-unused imports from `emergency_workspace_page.dart`.
- [ ] Verify no dead code remains after extraction (run `dart analyze frontend`).

## Database Migrations

No database migrations required. This refactoring only restructures the UI layer. All domain entities, DTOs, repository methods, and API endpoints remain unchanged.

## Responsive Design Requirements

### Desktop (width ≥ 840px)
- Full `AppTabStrip` with all 6 tabs visible.
- "Quick arrival" button visible in the `Row` next to the tab strip.
- `AppListTable` renders as a data table with sortable column headers.
- Detail dialog opens at `maxWidth: 980` (preserve current behavior).

### Tablet (600px ≤ width < 840px)
- `AppTabStrip` wraps naturally (it uses `Wrap` internally).
- "Quick arrival" button stays in the `Row` but may wrap below tabs.
- Table columns use the same desktop columns; `AppListTable` handles horizontal scroll internally.

### Mobile (width < 600px)
- `AppTabStrip` wraps into multiple lines.
- "Quick arrival" button wraps below tabs.
- `AppListTable` switches to `mobileItemBuilder` — render each emergency case as a compact card with patient name, severity badge, response badge, location, and arrival time.
- Detail still opens in a dialog (existing behavior).

The `ResponsivePage` and `AppListTable` already handle these breakpoints internally. No custom breakpoint logic is needed — just provide a `mobileItemBuilder`.

## Verification Steps

Run these commands from the `frontend/` directory:

```bash
# 1. Static analysis
dart analyze .

# 2. Format check
dart format --set-exit-if-changed .

# 3. Run emergency-specific tests
flutter test test/features/emergency/

# 4. Run shared component tests (verify no regressions)
flutter test test/shared/components/app_list_table_test.dart
flutter test test/shared/components/app_search_bar_test.dart

# 5. Run full test suite
flutter test
```

## Testing Requirements

- [ ] **Unit test:** `EmergencyWorkspaceQuery.fromUri` correctly parses `?scope=critical` and maps it to the `scope` field.
- [ ] **Unit test:** `EmergencyWorkspaceQuery.signature` includes the scope value.
- [ ] **Existing tests pass:** All tests in `test/features/emergency/emergency_handoff_test.dart` continue to pass without modification.
- [ ] **Widget smoke test (manual):** Navigate to `/emergency` → verify 6 tabs render with counts → switching tabs filters the table → "Quick arrival" button opens the dialog → clicking a row opens the detail dialog → URL updates with `?scope=...`.
- [ ] **Deep link test (manual):** Navigate to `/emergency?scope=ambulance&search=John` → ambulance tab is pre-selected, search is pre-filled.

## Acceptance Criteria

- [ ] The emergency workspace renders an `AppTabStrip` with 6 tabs: Active, Critical, Ambulance, Handoff ready, Closed, All.
- [ ] Each tab label includes the item count in parentheses (e.g., "Active (3)").
- [ ] Switching tabs filters the emergency board without a full API reload (client-side filtering from the existing board data, matching how `_buildRows` works in Reception).
- [ ] The "Quick arrival" primary action button is visible next to the tab strip, gated by `emergencyWrite` permission.
- [ ] `AppListTable` is used with `columnVisibilityStorageKey` and `columnWidthStorageKey` per tab.
- [ ] Table columns change per tab (e.g., Ambulance tab shows dispatch/trip columns; Closed tab shows handoff destination).
- [ ] The URL updates to reflect the active tab (`?scope=active`).
- [ ] Deep linking with `?scope=...` pre-selects the correct tab.
- [ ] Deep linking with `?id=...` still opens the case detail dialog.
- [ ] Client-side text search works within the active tab's items.
- [ ] Mobile layout uses `mobileItemBuilder` with compact case cards.
- [ ] The page file is under 600 lines (widgets and dialogs extracted to separate files).
- [ ] `dart analyze .` reports no new errors or warnings.
- [ ] `dart format --set-exit-if-changed .` passes.
- [ ] All existing emergency tests pass.
- [ ] No shared component was duplicated — only reused.
- [ ] All domain logic (triage, response, dispatch, ambulance trips, handoff, theater scheduling, printing) is preserved.

---

Rules files used: `prompt-generators/02-prompt-generator.md`
Model used: Claude Opus 4.6
