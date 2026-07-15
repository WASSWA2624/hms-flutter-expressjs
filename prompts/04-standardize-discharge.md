# Standardize Discharge Screen

## Objective

Refactor the Discharge workspace screen to match the standardized tab-and-table layout used by the Reception workspace. The discharge screen currently uses `AppWorkspace` with `AppWorkspaceSummaryNotification` toolbar badges as pseudo-tabs and a single fixed-height queue panel. This refactor will replace that with a proper `AppTabStrip` tab bar with routable sections, per-tab `AppListTable` columns, a contextual primary action button, `ResponsivePage` wrapping, and URL-driven tab persistence — matching the reception workspace reference pattern.

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification — all information needed is in this prompt. Run tests and formatting after implementation.

## Current State (from audit)

- **Page file:** `frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart` (1611 lines)
- **Controller:** `frontend/lib/features/discharge/presentation/controllers/discharge_workspace_controller.dart`
- **Entities:** `frontend/lib/features/discharge/domain/entities/discharge_entities.dart`
- **Repository:** `frontend/lib/features/discharge/domain/repositories/discharge_repository.dart`
- **Repository impl:** `frontend/lib/features/discharge/data/repositories/discharge_repository_impl.dart`
- **DTOs:** `frontend/lib/features/discharge/data/dtos/discharge_dtos.dart`
- **Widgets:** `frontend/lib/features/discharge/presentation/widgets/discharge_clearance_tile.dart`, `discharge_clearance_dialog.dart`, `discharge_planning_dialog.dart`, `show_discharge_planning_dialog.dart`
- **Test:** `frontend/test/features/discharge/presentation/discharge_workspace_controller_test.dart`, `frontend/test/features/discharge/domain/discharge_entities_test.dart`
- **Route:** `/discharge` defined in `frontend/lib/app/router/app_routes.dart` (line 516) and wired in `frontend/lib/app/router/app_router.dart` (line 317)

### Current layout structure:
- `DischargeWorkspacePage` → `AsyncStateScaffold` → `_DischargeWorkspaceContent`
- `_DischargeWorkspaceContent` uses `AppWorkspace` with `appWorkspaceToolbarWithLabels` toolbar containing `AppWorkspaceSummaryNotification` badges for each status category
- Single `_DischargeQueuePanel` with fixed `SizedBox(height: 520)` wrapping `AppListTable<IpdAdmissionSummary>` using `page:` parameter (server-side pagination)
- No `AppTabStrip` — status filtering is done via toolbar notification badges and `AppSearchBarFilterGroup` in the search bar
- No `ResponsivePage` wrapper
- Missing `columnVisibilityStorageKey` and `columnWidthStorageKey`
- Detail view is a dialog (`_openDischargeDetailDialog`) — this is correct and must be preserved

### Problems/inconsistencies:
1. No routable tabs — status filters use notification badges instead of tab navigation
2. Fixed `SizedBox(height: 520)` instead of shrinkWrap pattern
3. Missing `ResponsivePage` wrapper with `PageMaxWidth.dataHeavy`
4. No `columnVisibilityStorageKey` or `columnWidthStorageKey` on `AppListTable`
5. No primary action button alongside the tab strip
6. URL does not encode current tab/section — only supports deep-link via admission ID

## Reference Implementation

Read these files to understand the target patterns (do NOT modify them):

- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` — canonical tab-and-table workspace pattern:
  - `AppTabStrip` with `ReceptionDeskSection` enum for tabs
  - URL updates via `_updateUrlForSection()` using `GoRouter.of(context).replace<void>(location)`
  - `AppListTable` with `items:` (client-side) + `shrinkWrap: true` + `NeverScrollableScrollPhysics()`
  - Per-tab columns via `_columnsForSection()`
  - Primary action button (`Register Patient`) in `Row` next to `Expanded(child: AppTabStrip(...))`
  - `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy, child: ...)` wrapper
  - `columnVisibilityStorageKey` and `columnWidthStorageKey` per section
  - `WorkflowActionButton` in next_action column
  - Deep-link support via query parameter `section`
- `frontend/lib/shared/components/app_list_table.dart` — `AppListTable`, `AppListTableColumn`, `AppListTableSearch`, `AppListTableColumnVisibilityController`
- `frontend/lib/shared/components/app_tab_strip.dart` — `AppTabStrip`, `AppTabItem`
- `frontend/lib/shared/layout/app_workspace.dart` — `AppWorkspace` (current pattern — will be replaced)
- `frontend/lib/shared/layout/responsive_page.dart` — `ResponsivePage`, `PageMaxWidth`
- `frontend/lib/shared/workflow_actions/workflow_action_button.dart` — `WorkflowActionButton`

## Target Architecture

### Tab Configuration

| Tab Name | Route Query Value | Description | Primary Action Button |
|----------|------------------|-------------|----------------------|
| All Patients | `all` | All discharge queue patients (current full queue) | "Plan Discharge" → opens discharge planning dialog for selected row |
| Planned | `planned` | Patients with discharge planned, awaiting clearance | "Manage Clearance" → opens clearance checklist dialog |
| Pending Clearance | `pending` | Patients with one or more clearance items pending (pharmacy/billing/nursing/documents) | "Manage Clearance" → opens clearance checklist dialog |
| Completed | `completed` | Successfully discharged patients | "Print Summary" → print discharge summary |

### Routing

**File:** `frontend/lib/app/router/app_router.dart`

The route definition at line 317 already passes `DischargeWorklistQuery.fromUri(state.uri)` as `initialQuery`. Extend `DischargeWorklistQuery` to include a `section` field parsed from `state.uri.queryParameters['section']`. The page will read `initialQuery.section` to set the initial tab, and update the URL when tabs change using `GoRouter.of(context).replace<void>(location)` — exactly as `_ReceptionWorkspaceContentState._updateUrlForSection()` does.

**Do NOT add sub-routes.** The tab is encoded as a query parameter `?section=planned` on the existing `/discharge` route. This matches the Reception pattern.

### Page Layout

Replace the current `AppWorkspace` + `AppWorkspaceSummaryNotification` toolbar with:

```
ResponsivePage(
  maxWidth: PageMaxWidth.dataHeavy,
  child: SizedBox(
    width: double.infinity,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: AppTabStrip(
                tabs: [for each DischargeDeskSection],
                selectedId: _section.name,
                onTabTapped: (tabId) { setState → _section; _updateUrlForSection(); },
              ),
            ),
            SizedBox(width: theme.spacing.sm),
            // Primary action button (contextual per tab)
            AppButton.primary(
              label: _primaryActionLabel(l10n, _section),
              leadingIcon: _primaryActionIcon(_section),
              onPressed: () => _handlePrimaryAction(),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        AppListTable<IpdAdmissionSummary>(
          items: _buildRows(state),  // client-side filtered from queue.items
          columns: _columnsForSection(l10n),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          columnVisibilityController: _columnVisibilityController,
          columnVisibilityStorageKey: 'discharge_${_section.name}',
          columnWidthStorageKey: 'discharge_cw_${_section.name}',
          search: AppListTableSearch<IpdAdmissionSummary>(...),
          mobileItemBuilder: _mobileItemBuilder,
          ...
        ),
      ],
    ),
  ),
)
```

**Key changes:**
- Remove `AppWorkspace` wrapper and `appWorkspaceToolbarWithLabels` toolbar
- Remove the fixed `SizedBox(height: 520)` wrapping the table
- Add `ResponsivePage` wrapper
- Add `AppTabStrip` with contextual tab counts in labels
- Add primary action button next to tab strip
- Switch `AppListTable` from `page:` to `items:` with client-side filtering per tab
- Add `columnVisibilityStorageKey` and `columnWidthStorageKey`
- Use `shrinkWrap: true` and `NeverScrollableScrollPhysics()`

### Data & State Management

Keep the existing `DischargeWorkspaceController` (`dischargeWorkspaceControllerProvider`) and its `DischargeWorkspaceState` largely unchanged. The controller already provides:
- `state.queue` — `AppPage<IpdAdmissionSummary>` with all items
- `state.query` — `DischargeWorklistQuery` with search/status/pagination
- Status counts: `plannedCount`, `summaryPendingCount`, `pharmacyPendingCount`, `billingPendingCount`, `nursingPendingCount`, `documentsReadyCount`, `completedCount`
- `applySearch()`, `applyStatus()`, `refresh()`, `selectAdmission()`

The page will filter `state.queue.items` locally per tab using the existing `matchesDischargeStatus()` and `isCompletedDischarge()` / `isPlannedDischarge()` functions from `discharge_entities.dart`.

**No new providers are needed.** The section/tab state is local widget state (same as Reception).

## Implementation Steps

1. **Add `DischargeDeskSection` enum** — File: `frontend/lib/features/discharge/domain/entities/discharge_entities.dart`
   - Add after the `DischargeStatusFilter` enum:
   ```dart
   enum DischargeDeskSection { all, planned, pendingClearance, completed }
   ```

2. **Extend `DischargeWorklistQuery`** — File: `frontend/lib/features/discharge/domain/entities/discharge_entities.dart`
   - Add a `section` field (default `''`) to `DischargeWorklistQuery`
   - In `DischargeWorklistQuery.fromUri()`, parse `params['section']` into the `section` field
   - Add `section` to `copyWith()` and `hasRouteTargeting`

3. **Refactor `_DischargeWorkspaceContent`** — File: `frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart`
   - Remove `AppWorkspace` wrapper and `appWorkspaceToolbarWithLabels` toolbar
   - Remove all `AppWorkspaceSummaryNotification` code
   - Add `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy, child: ...)` wrapper
   - Add local `DischargeDeskSection _section` state variable (initialized from `widget.initialQuery?.section`)
   - Add `AppTabStrip` with 4 tabs (All, Planned, Pending Clearance, Completed)
   - Tab labels include counts: `'${label} (${count})'`
   - Add primary action button in `Row` next to `Expanded(child: AppTabStrip(...))`
   - Add `_updateUrlForSection()` method following the Reception pattern:
     ```dart
     void _updateUrlForSection(DischargeDeskSection section) {
       if (!mounted) return;
       final String tab = _sectionToQueryValue(section);
       final String location = AppRoutes.discharge.location(
         queryParameters: <String, String>{
           if (tab.isNotEmpty) 'section': tab,
         },
       );
       GoRouter.of(context).replace<void>(location);
     }
     ```

4. **Refactor `_DischargeQueuePanel` into inline table** — File: `frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart`
   - Remove `_DischargeQueuePanel` as a separate widget class
   - Inline the `AppListTable` into `_DischargeWorkspaceContentState.build()`
   - Remove the fixed `SizedBox(height: 520)` wrapper
   - Switch from `page:` to `items:` with `_buildRows(state)` that filters locally per tab
   - Add `shrinkWrap: true` and `physics: const NeverScrollableScrollPhysics()`
   - Add `columnVisibilityStorageKey: 'discharge_${_section.name}'`
   - Add `columnWidthStorageKey: 'discharge_cw_${_section.name}'`
   - Keep existing columns but add column `id` values for storage keys

5. **Add per-tab row filtering** — File: `frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart`
   - Add `_buildRows()` method:
     ```dart
     List<IpdAdmissionSummary> _buildRows(DischargeWorkspaceState state) {
       switch (_section) {
         case DischargeDeskSection.all:
           return state.queue.items.toList();
         case DischargeDeskSection.planned:
           return state.queue.items.where(isPlannedDischarge).toList();
         case DischargeDeskSection.pendingClearance:
           return state.queue.items.where((item) =>
             !isCompletedDischarge(item) && !isPlannedDischarge(item)
           ).toList();
         case DischargeDeskSection.completed:
           return state.queue.items.where(isCompletedDischarge).toList();
       }
     }
     ```

6. **Add per-tab column definitions** — File: `frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart`
   - Add `_columnsForSection()` method returning tab-specific columns
   - **All tab:** Patient, Location, Status, Next Action, Target Date (all existing columns, with `id` values)
   - **Planned tab:** Patient, Location, Clearance Phase, Next Action, Target Date
   - **Pending Clearance tab:** Patient, Location, Blocking Item, Next Action
   - **Completed tab:** Patient, Location, Discharged At

7. **Add primary action button logic** — File: `frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart`
   - Add `_primaryActionLabel()` that returns different labels per tab:
     - All: `l10n.dischargeStartPlanAction` ("Plan Discharge")
     - Planned: `l10n.dischargeManageClearanceAction` ("Manage Clearance")
     - Pending Clearance: `l10n.dischargeManageClearanceAction` ("Manage Clearance")
     - Completed: `l10n.dischargePrintSummaryAction` ("Print Summary")
   - The primary action button should be disabled when no row is selected — its behavior opens the detail dialog with the relevant initial tab

8. **Add section helper methods** — File: `frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart`
   - `_sectionToQueryValue()` — converts enum to URL query value
   - `_sectionFromQuery()` — converts query string to enum
   - `_sectionLabel()` — localized tab label
   - `_sectionIcon()` — icon per section
   - `_sectionCount()` — item count per section

9. **Add `id` values to all table columns** — File: `frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart`
   - Every `AppListTableColumn` must have an `id` field for column visibility storage to work. Add `id: 'patient_name'`, `id: 'location'`, `id: 'status'`, `id: 'next_action'`, `id: 'target_date'`, `id: 'clearance_phase'`, `id: 'blocking_item'`, `id: 'discharged_at'`

10. **Update search to use client-side matcher** — File: `frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart`
    - Keep server-side `onSubmitted` for the controller's `applySearch()`
    - Add a real client-side `matcher:` function (currently `(_, _) => true`) that matches patient name, display ID, and location against the query — this enables instant local filtering while server results load

11. **Preserve deep-link handling** — File: `frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart`
    - Keep the existing `_scheduleDeepLink()` and `_handleDeepLink()` logic
    - Extend it to also handle `section` query parameter for tab deep-linking
    - When a section is provided via query params, set `_section` accordingly

12. **Preserve all detail dialog logic** — File: `frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart`
    - Keep `_openDischargeDetailDialog()`, `_DischargeDetailContent`, `_CrossModuleLinksSection`, `_ClearanceChecklist`, `_SummarySection`, `_RelatedRecordsSection`, `_TimelineSection`, `_PendingOrdersSection`, `_BillingDialog`, `_PharmacyDialog`, and all helper functions
    - These are detail-level widgets that appear in dialogs — they are NOT affected by the tab refactor

13. **Keep filter integration** — File: `frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart`
    - Keep the `AppSearchBarFilterGroup` for status filtering within the search bar
    - The tabs provide a quick visual filter; the search bar filter provides granular status control within the "All" tab
    - When a tab other than "All" is selected, the filter dropdown can still be used for sub-filtering

14. **Update the controller test** — File: `frontend/test/features/discharge/presentation/discharge_workspace_controller_test.dart`
    - No changes needed to the controller test since the controller is not being modified
    - Verify the test still passes after changes

## Shared Components — MUST Reuse

Do NOT create new implementations of these. Import and use them directly:

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppListTable` | `package:hosspi_hms/shared/components/components.dart` | Main data table for discharge queue |
| `AppListTableColumn` | `package:hosspi_hms/shared/components/components.dart` | Column definitions with `id`, `label`, `cellBuilder`, `sortComparator` |
| `AppListTableSearch` | `package:hosspi_hms/shared/components/components.dart` | Search bar with filter groups integrated into table |
| `AppListTableColumnVisibilityController` | `package:hosspi_hms/shared/components/components.dart` | Column visibility management |
| `AppTabStrip` / `AppTabItem` | `package:hosspi_hms/shared/components/components.dart` | Tab navigation bar |
| `AppWorkspaceStatusBadge` | `package:hosspi_hms/shared/components/components.dart` | Status badge display |
| `ResponsivePage` / `PageMaxWidth` | `package:hosspi_hms/shared/layout/layout.dart` | Responsive page wrapper |
| `WorkflowActionButton` | `package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart` | Per-row workflow action |
| `AppButton` | `package:hosspi_hms/shared/components/components.dart` | Primary/secondary action buttons |
| `AppPatientDetails` | `package:hosspi_hms/shared/components/components.dart` | Patient details display in detail dialog |
| `AppWorkspaceDetailPanel` | `package:hosspi_hms/shared/components/components.dart` | Section panels in detail dialog |
| `AppTimeline` | `package:hosspi_hms/shared/components/components.dart` | Timeline display |
| `AppWorkflowStepper` | `package:hosspi_hms/shared/components/components.dart` | Clearance progress stepper |
| `appListTableCompareText` | `package:hosspi_hms/shared/components/components.dart` | Text sort comparator |
| `appListTableCompareDateTime` | `package:hosspi_hms/shared/components/components.dart` | DateTime sort comparator |
| `AppSearchBarFilterGroup` / `AppSearchBarFilterChoice` / `AppSearchBarFilterValue` | `package:hosspi_hms/shared/components/components.dart` | Advanced filter in search bar |

## Files to Create

No new files needed. All changes are modifications to existing files.

## Files to Modify

| File Path | Changes |
|-----------|---------|
| `frontend/lib/features/discharge/domain/entities/discharge_entities.dart` | Add `DischargeDeskSection` enum; add `section` field to `DischargeWorklistQuery` |
| `frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart` | Major refactor: replace `AppWorkspace` with `ResponsivePage` + `AppTabStrip` + inline `AppListTable`; remove `_DischargeQueuePanel` class; add tab logic, per-tab columns, primary action button, URL updating, client-side filtering |

## Files to Delete (if any)

None. All discharge widget files (`discharge_clearance_tile.dart`, `discharge_clearance_dialog.dart`, `discharge_planning_dialog.dart`, `show_discharge_planning_dialog.dart`) are still used by the detail dialog and must be preserved.

## Cleanup: Remove Stale Code

After the refactor, the agent MUST remove all dead/stale code left behind:

- [ ] Remove `_DischargeQueuePanel` widget class (its logic is inlined into `_DischargeWorkspaceContentState.build()`)
- [ ] Remove the `AppWorkspace` wrapper and `appWorkspaceToolbarWithLabels` call
- [ ] Remove all `AppWorkspaceSummaryNotification` constructions from the page
- [ ] Remove unused imports (`app_route_icons.dart` if no longer used, `app_workspace_summary_notification.dart` barrel if unused)
- [ ] Remove the fixed `SizedBox(height: 520)` wrapper
- [ ] Remove the `_statusFilterOptions()` function if it's now fully replaced by `AppSearchBarFilterGroup` choices
- [ ] Run `dart analyze` to catch any remaining unreferenced declarations and remove them
- [ ] Verify no test files reference deleted code — update or remove stale tests

List every file and symbol removed in a "Cleanup Summary" section at the end of the implementation.

## Database Migrations

No database migrations required — schema unchanged. The refactor is purely a frontend UI restructuring. The discharge entities, DTOs, repository, and backend API contracts remain identical.

## Responsive Design Requirements

- **Desktop (≥1024px):** Full table with all columns visible (controlled by `AppListTableColumnVisibilityController`), `AppTabStrip` and primary action button on the same row, horizontal scrolling for overflow columns
- **Tablet (600–1023px):** Compact table layout (smaller column widths via `AppListTable` internal compact logic at `AppBreakpoint.md`), tabs may wrap, primary action button may use icon-only mode
- **Mobile (<600px):** Card-based list via `mobileItemBuilder` (existing `_MobileQueueItem`), tabs stack vertically or scroll horizontally (handled by `AppTabStrip` internal responsive behavior)

Use `ResponsivePage` from `package:hosspi_hms/shared/layout/layout.dart` with `maxWidth: PageMaxWidth.dataHeavy`. The `AppListTable` internally uses `AppBreakpoints.fromConstraints()` to switch between desktop table and mobile list layouts.

## Verification Steps

After implementation, the agent MUST run these commands and confirm they pass:

```bash
# Format
dart format .

# Analyze
dart analyze --fatal-infos

# Run tests related to this screen
flutter test test/features/discharge/

# Run shared component tests to ensure no regressions
flutter test test/shared/
```

## Testing Requirements

Write or update these tests:

- [ ] Tab navigation: switching tabs updates `_section` state and the displayed items change
- [ ] Deep linking: navigating to `/discharge?section=planned` renders the Planned tab
- [ ] Deep linking: navigating to `/discharge?id=ADM-001` still opens the detail dialog
- [ ] Table data: each tab displays the correct filtered subset of the queue
- [ ] Search: typing in the search bar filters table rows (client-side matcher)
- [ ] Filter dialog: the status filter in the search bar still works within each tab
- [ ] Primary action: button label changes per tab
- [ ] Responsive layout: widget tests verify the table switches to mobile list at small breakpoints
- [ ] No regressions: existing discharge detail dialog functionality still works
- [ ] Column visibility: changing visible columns persists via storage keys

## Acceptance Criteria

The refactor is complete when ALL of the following are true:

- [ ] The screen uses `AppTabStrip` with 4 tabs: All, Planned, Pending Clearance, Completed
- [ ] Each tab filters the queue items locally and displays the correct subset
- [ ] The URL updates when tabs are switched (e.g., `/discharge?section=planned`)
- [ ] Deep-linking to `/discharge?section=completed` renders the Completed tab
- [ ] Deep-linking to `/discharge?id=ADM-001` still works (detail dialog opens)
- [ ] The primary action button is contextual per tab and positioned next to the tab strip
- [ ] The page body uses `AppListTable` with `shrinkWrap: true` and `NeverScrollableScrollPhysics()`
- [ ] `columnVisibilityStorageKey` and `columnWidthStorageKey` are set per section
- [ ] All columns have `id` values for column visibility storage
- [ ] `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)` wraps the content
- [ ] The `AppWorkspace` wrapper and `AppWorkspaceSummaryNotification` toolbar are removed
- [ ] The fixed `SizedBox(height: 520)` is removed
- [ ] No shared component is re-implemented — only imported and used
- [ ] The layout is fully responsive across mobile, tablet, and desktop
- [ ] All old/duplicate layout code is removed — no stale classes remain
- [ ] Domain-specific business logic (detail dialog, clearance, pharmacy/billing dialogs) is preserved
- [ ] No database migrations required — schema unchanged
- [ ] `dart analyze` reports no new issues — zero unused imports, zero unreferenced declarations
- [ ] All tests pass (no stale test references to removed code)
