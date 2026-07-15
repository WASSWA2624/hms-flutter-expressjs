# Standardize Theater Screen

## Objective

Refactor the Theater workspace to adopt the standardized tab-and-table layout matching the Reception workspace pattern. The current Theater workspace already uses `AppWorkspace`, `AppListTable`, and `AppWorkspaceSummaryNotification` — but it lacks explicit tab-based navigation with `AppTabStrip`. This refactoring adds routable tabs to the Theater workspace, enabling URL-driven section switching (Scheduled, In Theater, Recovery, Completed), while preserving the existing advanced filter panel, server-side pagination, and all domain-specific clinical workflows (checklist, anesthesia, post-op, handover, etc.).

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification — all information needed is in this prompt. Run tests and formatting after implementation.

## Current State (from audit)

- **Main page:** `frontend/lib/features/theater/presentation/pages/theater_workspace_page.dart` (2404 lines)
- **Controller:** `frontend/lib/features/theater/presentation/controllers/theater_workspace_controller.dart`
- **Entities:** `frontend/lib/features/theater/domain/entities/theater_entities.dart`
- **DTOs:** `frontend/lib/features/theater/data/dtos/theater_dtos.dart`
- **Repository:** `frontend/lib/features/theater/data/repositories/theater_repository_impl.dart`
- **Repository interface:** `frontend/lib/features/theater/domain/repositories/theater_repository.dart`
- **Schedule case form:** `frontend/lib/features/theater/presentation/widgets/theater_schedule_case_form.dart`
- **Route definition:** `AppRoutes.theater` at `/theater` in `frontend/lib/app/router/app_routes.dart`
- **Deep-link model:** `TheaterBoardQuery` parsed from URI query parameters

### Current Layout Structure
- Uses `AsyncStateScaffold<TheaterWorkspaceState>` → `_TheaterWorkspaceContent`
- `_TheaterWorkspaceContent` uses `AppWorkspace` with `appWorkspaceToolbarWithLabels` (toolbar with summary notifications + primary action button)
- `AppWorkspaceSummaryNotification` chips serve as pseudo-tabs: All Cases, Scheduled, In Theater, Ready, Completed
- Single `AppListTable<TheaterCase>` with advanced search/filter panel (status, stage, date, room, surgeon, anesthetist)
- Server-side pagination via `AppPageRequest`
- Row selection opens `_TheaterCaseDetail` in a dialog via `_openTheaterCaseDialog`
- Mobile view via `_TheaterCaseListTile` in `mobileItemBuilder`

### Problems/Inconsistencies
1. No explicit tab-based navigation — summary notifications act as quick-filters but are not true tabs
2. No URL-based section switching — filtering by status updates query parameters but no `section` query param
3. The Reception workspace uses `AppTabStrip` for clear visual tab navigation with URL sync; Theater does not
4. Inconsistent workspace patterns across the app: IPD, Emergency, Nursing, Subscriptions have their own patterns; standardization requires tabs

## Reference Implementation

Read these files to understand the target patterns (do NOT modify them):

| File | Key Patterns to Extract |
|------|------------------------|
| `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` | `AppTabStrip` usage, `ReceptionDeskSection` enum, URL sync via `_updateUrlForSection`, tab-to-data mapping in `_buildRows`, per-tab column definitions in `_columnsForSection` |
| `frontend/lib/shared/components/app_tab_strip.dart` | `AppTabItem` data class (`id`, `icon`, `label`), `AppTabStrip` widget API (`tabs`, `selectedId`, `onTabTapped`) |
| `frontend/lib/shared/layout/app_workspace.dart` | `AppWorkspace` widget API, `AppWorkspaceToolbarConfig`, header/body/toolbar composition |
| `frontend/lib/shared/layout/app_workspace_toolbar.dart` | `appWorkspaceToolbarWithLabels` helper, `AppWorkspaceSummaryNotification` integration |
| `frontend/lib/shared/layout/app_workspace_summary_notification.dart` | `AppWorkspaceSummaryNotification` data class |
| `frontend/lib/shared/components/app_list_table.dart` | `AppListTable<T>` full constructor: `page`, `columns`, `search`, `columnVisibilityController`, `mobileItemBuilder`, pagination params |

## Target Architecture

### Tab Configuration

| Tab Name | Section Enum Value | Query Filter | Description | Primary Action Button |
|----------|-------------------|--------------|-------------|----------------------|
| Scheduled | `scheduled` | `status=SCHEDULED` | Cases awaiting their scheduled time | Schedule Case → opens schedule dialog |
| In Theater | `inTheater` | `status=IN_PROGRESS` | Cases currently undergoing surgery | Schedule Case → opens schedule dialog |
| Recovery | `recovery` | `stage=POST_OP` OR `stage=PACU_HANDOFF` | Cases in post-op recovery/handoff | Schedule Case → opens schedule dialog |
| All Cases | `all` | No status/stage filter | Full list with existing advanced filters | Schedule Case → opens schedule dialog |

### Routing

- **Router file:** `frontend/lib/app/router/app_routes.dart`
- The Theater route remains a single route at `/theater` — tab state is encoded as a query parameter `section` (matching the Reception pattern).
- Deep-link example: `/theater?section=in-theater&search=...`
- The existing `TheaterBoardQuery` already supports `focusCaseId`, `search`, and filter params. Add a `section` parameter for tab persistence.
- No sub-routes needed — tabs switch the filter applied to the same `TheaterCaseQuery`.

### Page Layout

```
AsyncStateScaffold<TheaterWorkspaceState>
  └── _TheaterWorkspaceContent
       └── AppWorkspace(
             title: l10n.theaterTitle,
             leadingIcon: AppRouteIcons.theater,
             toolbar: appWorkspaceToolbarWithLabels(
               summaryNotifications: [...],  // Keep existing summary stats
               primary: Schedule Case button,
               onRefresh: controller.refresh,
               isRefreshing: state.isRefreshing,
             ),
             body: Column(
               children: [
                 Row(
                   children: [
                     Expanded(child: AppTabStrip(tabs: [...], selectedId: ..., onTabTapped: ...)),
                   ],
                 ),
                 SizedBox(height: theme.spacing.md),
                 _TheaterCaseBoard(...)  // existing table widget
               ],
             ),
           )
```

The `AppTabStrip` is placed at the **top of the body** (inside `AppWorkspace.body`), with the `AppListTable` below it. The primary action button stays in the toolbar. Summary notifications remain in the toolbar for at-a-glance counts.

### Data & State Management

- **Existing controller:** `theaterWorkspaceControllerProvider` (keep unchanged)
- **New section state:** Add a `TheaterSection` field to `_TheaterWorkspaceContentState` (local UI state, not in controller — matching Reception pattern)
- **Tab switching:** When a tab is tapped, update `_section`, call the appropriate controller filter method (`applyStatus` / `applyStage` / `clearFilters`), and update the URL via `GoRouter.of(context).replace(...)`.
- **Deep-link restoration:** Parse the `section` query parameter from `TheaterBoardQuery` to set the initial tab.

## Implementation Steps

1. **Add `TheaterSection` enum** — File: `frontend/lib/features/theater/domain/entities/theater_entities.dart`
   - Add a new enum after the existing `TheaterDetailPanel` enum:
     ```dart
     enum TheaterSection { scheduled, inTheater, recovery, all }
     ```
   - Add a `serverValue` getter or static parsing method for URL serialization:
     ```dart
     extension TheaterSectionX on TheaterSection {
       String get queryValue => switch (this) {
         TheaterSection.scheduled => 'scheduled',
         TheaterSection.inTheater => 'in-theater',
         TheaterSection.recovery => 'recovery',
         TheaterSection.all => 'all',
       };

       static TheaterSection? fromQuery(String? value) {
         return switch ((value ?? '').trim().toLowerCase()) {
           'scheduled' => TheaterSection.scheduled,
           'in-theater' || 'in_theater' || 'intheater' => TheaterSection.inTheater,
           'recovery' || 'post-op' || 'post_op' || 'pacu' => TheaterSection.recovery,
           'all' || '' => TheaterSection.all,
           _ => null,
         };
       }
     }
     ```

2. **Add `section` parameter to `TheaterBoardQuery`** — File: `frontend/lib/features/theater/domain/entities/theater_entities.dart`
   - Add `this.section` field to `TheaterBoardQuery` constructor (default `'all'`).
   - Parse it in `TheaterBoardQuery.fromUri` from `params['section']`.
   - Include it in `copyWith`.
   - Update `hasRouteTargeting` to consider `section`.

3. **Add `AppTabStrip` to `_TheaterWorkspaceContentState`** — File: `frontend/lib/features/theater/presentation/pages/theater_workspace_page.dart`
   - Import `AppTabStrip` and `AppTabItem` (from `package:hosspi_hms/shared/components/components.dart` — already imported).
   - Add a `TheaterSection _section` field initialized from `widget.initialQuery?.section` or `TheaterSection.all`.
   - Add a `_updateUrlForSection(TheaterSection section)` method (copy the pattern from Reception):
     ```dart
     void _updateUrlForSection(TheaterSection section) {
       if (!mounted) return;
       final String tab = section.queryValue;
       final String location = AppRoutes.theater.location(
         queryParameters: <String, String>{
           if (tab != 'all') 'section': tab,
         },
       );
       GoRouter.of(context).replace<void>(location);
     }
     ```
   - In the `build` method, insert an `AppTabStrip` at the top of the `AppWorkspace.body` column (before `_TheaterCaseBoard`):
     ```dart
     AppTabStrip(
       tabs: <AppTabItem>[
         for (final TheaterSection section in TheaterSection.values)
           AppTabItem(
             id: section.name,
             icon: _sectionIcon(section),
             label: '${_sectionLabel(l10n, section)} (${_sectionCount(state, section)})',
           ),
       ],
       selectedId: _section.name,
       onTabTapped: (String tabId) {
         for (final TheaterSection section in TheaterSection.values) {
           if (section.name == tabId) {
             setState(() => _section = section);
             _applyTabFilter(section);
             _updateUrlForSection(section);
             break;
           }
         }
       },
     ),
     ```

4. **Implement `_applyTabFilter`** — File: `frontend/lib/features/theater/presentation/pages/theater_workspace_page.dart`
   - When a tab is selected, call the appropriate controller method:
     ```dart
     void _applyTabFilter(TheaterSection section) {
       final TheaterWorkspaceController controller = ref.read(
         theaterWorkspaceControllerProvider.notifier,
       );
       switch (section) {
         case TheaterSection.scheduled:
           controller.applyStatus('SCHEDULED');
         case TheaterSection.inTheater:
           controller.applyStatus('IN_PROGRESS');
         case TheaterSection.recovery:
           controller.applyStage('POST_OP');
         case TheaterSection.all:
           controller.clearFilters();
       }
     }
     ```

5. **Add helper methods** — File: `frontend/lib/features/theater/presentation/pages/theater_workspace_page.dart`
   - Add `_sectionIcon`, `_sectionLabel`, `_sectionCount` methods (mirror Reception's pattern):
     ```dart
     static IconData _sectionIcon(TheaterSection section) {
       return switch (section) {
         TheaterSection.scheduled => Icons.event_available_outlined,
         TheaterSection.inTheater => Icons.meeting_room_outlined,
         TheaterSection.recovery => Icons.monitor_heart_outlined,
         TheaterSection.all => Icons.inventory_2_outlined,
       };
     }

     String _sectionLabel(AppLocalizations l10n, TheaterSection section) {
       return switch (section) {
         TheaterSection.scheduled => l10n.theaterScheduledSummaryLabel,
         TheaterSection.inTheater => l10n.theaterInTheaterSummaryLabel,
         TheaterSection.recovery => l10n.theaterRecoverySectionLabel,
         TheaterSection.all => l10n.theaterAllCasesSummaryLabel,
       };
     }

     int _sectionCount(TheaterWorkspaceState state, TheaterSection section) {
       return switch (section) {
         TheaterSection.scheduled => state.scheduledCount,
         TheaterSection.inTheater => state.inTheaterCount,
         TheaterSection.recovery => _recoveryCount(state),
         TheaterSection.all => _pageTotal(state.cases),
       };
     }

     int _recoveryCount(TheaterWorkspaceState state) {
       return state.cases.items.where((TheaterCase item) {
         final String stage = item.normalizedStage;
         return stage == 'POST_OP' || stage == 'PACU_HANDOFF';
       }).length;
     }
     ```

6. **Add `recoveryCount` to `TheaterWorkspaceState`** — File: `frontend/lib/features/theater/domain/entities/theater_entities.dart`
   - Add a computed getter for recovery-stage cases:
     ```dart
     int get recoveryCount {
       return cases.items.where((TheaterCase item) {
         final String stage = item.normalizedStage;
         return stage == 'POST_OP' || stage == 'PACU_HANDOFF';
       }).length;
     }
     ```

7. **Add localization key for Recovery tab** — File: `frontend/lib/l10n/app_en.arb`
   - Add: `"theaterRecoverySectionLabel": "Recovery"`

8. **Restore initial section from deep link** — File: `frontend/lib/features/theater/presentation/pages/theater_workspace_page.dart`
   - In `_TheaterWorkspaceContentState.initState()`, parse the section from `widget.initialQuery`:
     ```dart
     _section = TheaterSectionX.fromQuery(widget.initialQuery?.section) ?? TheaterSection.all;
     ```
   - On `initState`, after setting `_section`, apply the initial filter if section is not `all`:
     ```dart
     if (_section != TheaterSection.all) {
       WidgetsBinding.instance.addPostFrameCallback((_) {
         if (mounted) _applyTabFilter(_section);
       });
     }
     ```

9. **Keep the existing `_TheaterCaseBoard` and filter panel unchanged** — the advanced filters (status, stage, date, room, surgeon, anesthetist) remain functional within each tab. The tab provides a coarse pre-filter; advanced filters refine within the tab.

10. **Update the route factory in the app router** — File where `TheaterBoardQuery.fromUri` is called:
    - Ensure the `section` query parameter is parsed and passed to `TheaterWorkspacePage(initialQuery: ...)`.

## Shared Components — MUST Reuse

Do NOT create new implementations of these. Import and use them directly:

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` | `package:hosspi_hms/shared/components/components.dart` | Tab bar at top of workspace body |
| `AppTabItem` | `package:hosspi_hms/shared/components/components.dart` | Data class for each tab definition |
| `AppListTable<TheaterCase>` | `package:hosspi_hms/shared/components/components.dart` | Already used — keep as-is |
| `AppWorkspace` | `package:hosspi_hms/shared/layout/layout.dart` | Already used — keep as-is |
| `appWorkspaceToolbarWithLabels` | `package:hosspi_hms/shared/layout/layout.dart` | Already used — keep as-is |
| `AppWorkspaceSummaryNotification` | `package:hosspi_hms/shared/layout/layout.dart` | Already used in toolbar — keep for summary counts |
| `AppButton.primary` | `package:hosspi_hms/shared/components/components.dart` | Primary action button in toolbar |
| `AppPatientDetails` | `package:hosspi_hms/shared/components/components.dart` | Already used in detail view |
| `AppWorkspaceStatusBadge` | `package:hosspi_hms/shared/layout/layout.dart` | Already used for status display |
| `ResponsivePage` | `package:hosspi_hms/shared/layout/layout.dart` | Already used via AppWorkspace |

## Files to Create

| File Path | Purpose |
|-----------|---------|
| None | No new files needed — all changes fit within existing files |

## Files to Modify

| File Path | Changes |
|-----------|---------|
| `frontend/lib/features/theater/domain/entities/theater_entities.dart` | Add `TheaterSection` enum with `TheaterSectionX` extension; add `section` field to `TheaterBoardQuery`; add `recoveryCount` getter to `TheaterWorkspaceState` |
| `frontend/lib/features/theater/presentation/pages/theater_workspace_page.dart` | Add `AppTabStrip` to `_TheaterWorkspaceContentState` build; add `_section` state field; add `_updateUrlForSection`, `_applyTabFilter`, `_sectionIcon`, `_sectionLabel`, `_sectionCount`, `_recoveryCount` methods; parse initial section from query |
| `frontend/lib/l10n/app_en.arb` | Add `theaterRecoverySectionLabel` key |

## Files to Delete (if any)

| File Path | Reason |
|-----------|--------|
| None | This is an additive refactor — existing code is enhanced, not replaced |

## Cleanup: Remove Stale Code

After the refactor, the agent MUST remove all dead/stale code left behind:

- [ ] Remove unused imports across all modified files.
- [ ] If any summary notification was redundant with the new tabs, evaluate whether to keep both (they serve different UX purposes: tabs for navigation, notifications for at-a-glance counts in overflow menu).
- [ ] Run `dart analyze` to catch any remaining unreferenced declarations and remove them.
- [ ] Verify no test files reference deleted code — update or remove stale tests.

List every file and symbol removed in a "Cleanup Summary" section at the end of the implementation.

## Database Migrations

No database migrations required — schema unchanged. This refactoring only adds tab-based UI navigation over existing data. The `TheaterCaseQuery` filters (`status`, `stage`) already work server-side and are unchanged.

## Responsive Design Requirements

- **Desktop (≥1024px):** Full `AppTabStrip` displayed horizontally above the table. All table columns visible. Tab labels include counts.
- **Tablet (600–1023px):** `AppTabStrip` wraps using its built-in `Wrap` layout. Some table columns may be hidden via column visibility. Tab labels include counts.
- **Mobile (<600px):** `AppTabStrip` wraps to multiple rows. Table switches to `mobileItemBuilder` (card-based `_TheaterCaseListTile`). Tabs remain functional with icon + label.

The `AppTabStrip` widget already uses a `Wrap` layout internally, so it handles responsive wrapping automatically. The `AppListTable` already switches to `mobileItemBuilder` at mobile breakpoints. No additional responsive code needed.

## Verification Steps

After implementation, the agent MUST run these commands and confirm they pass:

```bash
# Format
dart format .

# Analyze
dart analyze --fatal-infos

# Run tests related to this screen
flutter test test/features/theater/

# Run shared component tests to ensure no regressions
flutter test test/shared/
```

## Testing Requirements

Write or update these tests:

- [ ] Tab navigation: switching tabs calls the correct controller filter method (`applyStatus('SCHEDULED')`, `applyStatus('IN_PROGRESS')`, `applyStage('POST_OP')`, `clearFilters()`)
- [ ] Deep linking: constructing a `TheaterBoardQuery` with `section=in-theater` initializes the correct tab
- [ ] `TheaterSection` enum: `TheaterSectionX.fromQuery` correctly parses all variants (`'scheduled'`, `'in-theater'`, `'recovery'`, `'all'`, `null`)
- [ ] URL update: tapping a tab updates the URL with the `section` query parameter
- [ ] Table data: each tab displays cases filtered by the correct status/stage
- [ ] Primary action: "Schedule Case" button remains functional across all tabs
- [ ] Summary notifications: counts still display correctly in toolbar regardless of active tab
- [ ] Mobile layout: `AppTabStrip` renders correctly on narrow viewports
- [ ] No regressions: existing deep-link (`focusCaseId`, `panel`) functionality still works

## Acceptance Criteria

The refactor is complete when ALL of the following are true:

- [ ] The Theater screen uses `AppTabStrip` with 4 tabs: Scheduled, In Theater, Recovery, All Cases
- [ ] Each tab has its own URL (via `section` query parameter) that supports deep linking
- [ ] The primary action button ("Schedule Case") remains in the toolbar and works across all tabs
- [ ] The page body continues to use `AppListTable<TheaterCase>` with integrated search, filter, and column settings
- [ ] The advanced filter panel (status, stage, date, room, surgeon, anesthetist) continues to work within each tab
- [ ] No shared component is re-implemented — only imported and used
- [ ] The layout is fully responsive across mobile, tablet, and desktop (AppTabStrip wraps, table switches to mobile builder)
- [ ] Summary notification counts in the toolbar are preserved for at-a-glance status overview
- [ ] All existing domain-specific behavior is preserved (case detail dialog, schedule, reschedule, stage update, checklist, anesthesia, post-op, handover, finalize, cancel)
- [ ] `dart analyze` reports no new issues — zero unused imports, zero unreferenced declarations
- [ ] All tests pass (no stale test references to removed code)
