# Standardize HR Screen

## Objective

Refactor the HR workspace (`HrWorkspacePage`) to match the standardized tab-and-table layout used by the Reception workspace (`ReceptionWorkspacePage`). Currently the HR screen uses `AppWorkspace` with a toolbar-action-bar pattern and displays a single staff directory table, while work queues and staff detail are pushed into secondary dialogs. This refactor restructures the page to use routable `AppTabStrip` tabs — each tab with its own URL segment, contextual primary action button, and `AppListTable` body — mirroring the Reception workspace's `ResponsivePage` + `AppTabStrip` + per-tab `AppListTable` architecture. All existing domain logic, data entities, controllers, and repository code must be preserved; only the UI/layout layer changes.

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification — all information needed is in this prompt. Run tests and formatting after implementation.

## Current State (from audit)

### Files

| File | Purpose |
|------|---------|
| `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart` | Main HR page (~2455 lines): `HrWorkspacePage`, `_HrWorkspaceContent`, `_HrStaffDirectory`, `_HrStaffDetailPanel`, `_HrStaffDetailBody`, `_HrWorkQueuePanel`, `_HrWorkQueueTable`, `_HrActivityPanel`, inline field widgets, helper functions |
| `frontend/lib/features/hr/presentation/pages/hr_workspace_dialog_actions.dart` | `part` file of `hr_workspace_page.dart` — dialog-launching helper functions |
| `frontend/lib/features/hr/presentation/controllers/hr_workspace_controller.dart` | `HrWorkspaceController` — Riverpod `AsyncNotifier`, manages `HrWorkspaceState`, data loading, mutations, realtime sync |
| `frontend/lib/features/hr/domain/entities/hr_entities.dart` | Domain entities: `HrWorkspaceState`, `HrStaffProfile`, `HrStaffDetail`, `HrWorkItem`, `HrQueue`, `HrWorkspaceQuery`, `HrReferenceData`, etc. |
| `frontend/lib/features/hr/domain/repositories/hr_repository.dart` | `HrRepository` interface |
| `frontend/lib/features/hr/data/repositories/hr_repository_impl.dart` | `HrRepositoryImpl` — API calls for HR module |
| `frontend/lib/features/hr/data/dtos/hr_dtos.dart` | DTO mappers |
| `frontend/lib/features/hr/presentation/hr_presentation_helpers.dart` | Shared presentation helper functions |
| `frontend/lib/features/hr/presentation/hr_reference_localizations.dart` | Localized label helpers |
| `frontend/lib/features/hr/presentation/widgets/hr_queue_switcher.dart` | `HrQueueSwitcher` — queue tab selector widget |
| `frontend/lib/features/hr/presentation/widgets/hr_staff_detail_actions.dart` | `HrStaffDetailActions` widget |
| `frontend/lib/features/hr/presentation/widgets/hr_staff_detail_helpers.dart` | Staff detail helper functions |
| `frontend/lib/features/hr/presentation/widgets/hr_staff_detail_overview.dart` | Staff detail overview widget |
| `frontend/lib/features/hr/presentation/widgets/hr_workspace_dialogs.dart` | Work queue and roster/payroll preview dialogs |
| `frontend/lib/features/hr/presentation/widgets/hr_enhanced_dialogs.dart` | Enhanced staff detail dialog |
| `frontend/lib/features/hr/presentation/widgets/hr_staff_onboarding_dialog.dart` | Onboarding dialog |
| `frontend/lib/features/hr/presentation/widgets/hr_staff_offboarding_dialog.dart` | Offboarding dialog |
| `frontend/lib/features/hr/presentation/widgets/hr_assign_department_dialog.dart` | Assign department dialog |
| `frontend/lib/features/hr/presentation/widgets/hr_assign_position_dialog.dart` | Assign position dialog |
| `frontend/lib/features/hr/presentation/widgets/hr_assignment_detail_dialog.dart` | Assignment detail dialog |
| `frontend/lib/features/hr/presentation/widgets/hr_availability_calendar.dart` | Availability calendar widget |
| `frontend/lib/features/hr/presentation/widgets/hr_record_availability_dialog.dart` | Record availability dialog |
| `frontend/lib/features/hr/presentation/widgets/hr_request_leave_dialog.dart` | Request leave dialog |
| `frontend/lib/features/hr/presentation/widgets/hr_leave_detail_dialog.dart` | Leave detail dialog |
| `frontend/lib/features/hr/presentation/widgets/hr_shift_detail_dialog.dart` | Shift detail dialog |
| `frontend/lib/features/hr/presentation/widgets/hr_compensation_dialog.dart` | Compensation dialog |
| `frontend/lib/features/hr/presentation/widgets/hr_compensation_line_editor.dart` | Compensation line editor |
| `frontend/lib/features/hr/presentation/widgets/hr_payroll_wizard_dialog.dart` | Payroll wizard dialog |
| `frontend/lib/features/hr/presentation/widgets/hr_payroll_preview_breakdown.dart` | Payroll preview breakdown |
| `frontend/lib/features/hr/presentation/widgets/hr_weekly_schedule_editor.dart` | Weekly schedule editor |
| `frontend/lib/features/hr/presentation/widgets/hr_access_dialogs.dart` | Access management dialogs |

### Current Layout/Structure

- Uses `AsyncStateScaffold` wrapping an `AppWorkspace` widget (not `ResponsivePage` + `AppTabStrip`).
- The `AppWorkspace` toolbar contains 8 action buttons inline: Add Staff, Work Queues, Manage Access, Schedule Templates, Activity, Refresh, Housekeeping, Fault Report.
- The main body shows a **single** `_HrStaffDirectory` — an `AppListTable<HrStaffProfile>` with search, filters, column visibility, and pagination.
- Work queues (`_HrWorkQueuePanel` / `_HrWorkQueueTable`) are opened as **modal dialogs** — not inline tabs.
- Staff detail (`_HrStaffDetailPanel` / `_HrStaffDetailBody`) is shown in a **dialog** via `showHrStaffDetailDialog`.
- No tab navigation — the URL is always `/hr` with optional query parameters (`?id=`, `?queue=`, `?search=`).
- Summary notifications (leave requests, roster drafts, unassigned shifts, payroll drafts) display as toolbar badge counts.

### Problems/Inconsistencies vs. Reference

1. **No routable tabs** — Reception uses `AppTabStrip` with `ReceptionDeskSection` enum; HR has no equivalent tab strip or URL-segment tabs.
2. **Work queues hidden in dialogs** — In Reception, all data views (appointments, queue, active visits, payment gate) are inline tabs with full tables. HR pushes work queues into a dialog, reducing discoverability.
3. **No `ResponsivePage` wrapper** — Reception uses `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)` around its content; HR uses `AppWorkspace` which has different responsive behavior.
4. **Primary action button not contextual per tab** — Reception places a "Register Patient" primary button next to the tab strip. HR has no per-tab primary action button; all actions are toolbar overflow items.
5. **URL does not reflect active tab** — Reception calls `GoRouter.of(context).replace<void>(location)` when switching tabs, enabling deep-link to specific sections. HR only supports `?queue=` as a query param but doesn't update the URL on tab switch.
6. **Inline field widgets clutter the page file** — `_ShiftAssignmentFields`, `_ShiftSwapFields`, `_ReasonFields`, `_RosterPublishFields`, `_OverrideShiftFields`, `_ProcessPayrollFields` are defined inline in the main page file rather than extracted.

## Reference Implementation

Read these files to understand the target patterns (do NOT modify them):

| File | Key Patterns |
|------|-------------|
| `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` | `ResponsivePage` + `AppTabStrip` + per-tab `AppListTable<_ReceptionDeskRow>`, section enum `ReceptionDeskSection`, `_updateUrlForSection()` for URL sync, contextual primary action button beside tab strip, `_columnsForSection()` per-tab columns, `_buildRows()` per-tab data filtering, `_searchMatcher` for client-side search, `_mobileItemBuilder` for responsive mobile layout |
| `frontend/lib/shared/components/app_tab_strip.dart` | `AppTabStrip` widget — takes `List<AppTabItem>`, `selectedId`, `onTabTapped` |
| `frontend/lib/shared/components/app_list_table.dart` | `AppListTable<T>` widget — `items`/`page`, `columns`, `search`, `columnVisibilityController`, `mobileItemBuilder`, `emptyBuilder`, `onRowSelected`, `shrinkWrap`, `physics` |
| `frontend/lib/shared/layout/responsive_page.dart` | `ResponsivePage` — wraps content with `maxWidth` constraint |
| `frontend/lib/shared/layout/app_workspace.dart` | `AppWorkspace` — current HR wrapper (to be replaced with `ResponsivePage` + `AppTabStrip`) |
| `frontend/lib/shared/layout/app_workspace_toolbar.dart` | `appWorkspaceToolbarWithLabels` — toolbar builder (HR currently uses this) |

## Target Architecture

### Tab Configuration

| Tab Name | Route Query Value | Description | Primary Action Button |
|----------|-------------------|-------------|----------------------|
| Staff Directory | `staff` | Paginated list of all staff profiles with search, filters, department/position/practitioner-type filtering | "Add Staff" → opens `showHrStaffOnboardingDialog` |
| Leave Requests | `leave-requests` | Work items filtered by `HrQueue.leaveRequests` — pending leave approvals | "Request Leave" → opens `showHrRequestLeaveDialog` (requires a selected staff; otherwise just opens the queue view) |
| Shift Roster | `shift-roster` | Combined view: `HrQueue.rosterDrafts`, `HrQueue.unassignedShifts`, `HrQueue.overdueShifts` with `HrQueueSwitcher` to toggle sub-queues | "Schedule Templates" → opens `showHrManageScheduleTemplatesDialog` |
| Payroll | `payroll` | Work items filtered by `HrQueue.payrollDrafts` — draft payroll runs to review and process | "Run Payroll" → opens `showHrPayrollWizardDialog` |
| Access & Roles | `access` | Access management panel — users, roles, permissions | "Manage Access" → opens `showHrAccessWorkspaceDialog` |

### Routing

**Router file:** `frontend/lib/app/router/app_router.dart`

The HR route is currently defined as:

```dart
GoRoute(
  path: AppRoutes.hr.path,     // '/hr'
  name: AppRoutes.hr.name,     // 'hr'
  builder: (_, GoRouterState state) {
    return HrWorkspacePage(
      initialQuery: HrWorkspaceQuery.fromUri(state.uri),
    );
  },
),
```

**No change needed to the router file.** Tab navigation is handled via query parameter `?section=staff|leave-requests|shift-roster|payroll|access`, following the Reception pattern where `_updateUrlForSection()` calls `GoRouter.of(context).replace<void>(location)` to update the URL without a full navigation. The `HrWorkspaceQuery` entity must be extended to parse the `section` query parameter.

**Route definition file:** `frontend/lib/app/router/app_routes.dart` — the `hr` route data at line 468 remains unchanged.

### Page Layout

The refactored `HrWorkspacePage` must follow this widget tree:

```
AsyncStateScaffold<HrWorkspaceState>
  └─ _HrWorkspaceContent (ConsumerStatefulWidget)
       └─ ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)
            └─ Column(crossAxisAlignment: stretch)
                 ├─ Row
                 │   ├─ Expanded → AppTabStrip(tabs: [...], selectedId: ..., onTabTapped: ...)
                 │   ├─ SizedBox(width: theme.spacing.sm)
                 │   └─ _PrimaryActionButton (changes label/icon/onPressed per active tab)
                 ├─ SizedBox(height: theme.spacing.md)
                 ├─ if (lastFailure != null) AppFailureStateView(...)
                 └─ _buildTabBody() → AppListTable<T> specific to the active tab
```

### Tab Enum

Create an `HrDeskSection` enum (analogous to `ReceptionDeskSection`):

```dart
enum HrDeskSection {
  staffDirectory,
  leaveRequests,
  shiftRoster,
  payroll,
  access,
}
```

### Data & State Management

- **Keep `HrWorkspaceController` and `hrWorkspaceControllerProvider` unchanged.** The controller already manages `HrWorkspaceState` with both `staff` (`AppPage<HrStaffProfile>`) and `workItems` (`AppPage<HrWorkItem>`).
- Each tab filters data from the existing state:
  - **Staff Directory:** uses `state.staff` directly (already paginated server-side).
  - **Leave Requests:** uses `state.workItems` filtered by `queue == HrQueue.leaveRequests`.
  - **Shift Roster:** uses `state.workItems` filtered by `queue ∈ {rosterDrafts, unassignedShifts, overdueShifts}`, with `HrQueueSwitcher` for sub-queue toggle.
  - **Payroll:** uses `state.workItems` filtered by `queue == HrQueue.payrollDrafts`.
  - **Access:** triggers on-demand data loading from the controller's access methods (`loadAccessUsers`, `loadAccessRoles`, `loadAccessPermissions`).
- The controller's `applyQueue()` method already supports switching the work-items query to a different `HrQueue`. Use it when the active tab changes to a queue-based tab.
- Summary notification counts remain available from `state.overview.summary`.

## Implementation Steps

### 1. Extend `HrWorkspaceQuery` — File: `frontend/lib/features/hr/domain/entities/hr_entities.dart`

Add a `section` field to `HrWorkspaceQuery` to support the `?section=` query parameter:

```dart
@immutable
final class HrWorkspaceQuery {
  const HrWorkspaceQuery({
    this.focusStaffId,
    this.queue,
    this.search = '',
    this.section = '',
  });

  final String? focusStaffId;
  final HrQueue? queue;
  final String search;
  final String section;

  factory HrWorkspaceQuery.fromUri(Uri uri) {
    final Map<String, String> params = uri.queryParameters;
    // ... existing parsing logic ...
    return HrWorkspaceQuery(
      focusStaffId: staffId,
      queue: HrQueue.fromValue(pick(<String>['queue'])),
      search: staffId ?? pick(<String>['search', 'q']) ?? '',
      section: pick(<String>['section', 'tab']) ?? '',
    );
  }

  bool get hasRouteTargeting {
    return focusStaffId != null ||
        queue != null ||
        search.trim().isNotEmpty ||
        section.trim().isNotEmpty;
  }
}
```

### 2. Create the `HrDeskSection` enum — File: `frontend/lib/features/hr/domain/entities/hr_entities.dart`

Add above/below the existing `HrQueue` enum:

```dart
enum HrDeskSection {
  staffDirectory,
  leaveRequests,
  shiftRoster,
  payroll,
  access,
}
```

### 3. Refactor `HrWorkspacePage` — File: `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart`

**Major changes:**

a. **Replace `AppWorkspace` with `ResponsivePage` + `AppTabStrip`.**

b. **Add `HrDeskSection` state** to `_HrWorkspaceContentState`:
   - `late HrDeskSection _section;`
   - Initialize from `widget.initialQuery?.section` (parse using a `_sectionFromQuery` helper, defaulting to `HrDeskSection.staffDirectory`).

c. **Build the tab strip** using `AppTabStrip`:
   ```dart
   AppTabStrip(
     tabs: <AppTabItem>[
       for (final HrDeskSection section in HrDeskSection.values)
         AppTabItem(
           id: section.name,
           icon: _sectionIcon(section),
           label: '${_sectionLabel(l10n, section)} (${_sectionCount(state, section)})',
         ),
     ],
     selectedId: _section.name,
     onTabTapped: (String tabId) {
       for (final HrDeskSection section in HrDeskSection.values) {
         if (section.name == tabId) {
           setState(() => _section = section);
           _updateUrlForSection(section);
           break;
         }
       }
     },
   )
   ```

d. **Add `_updateUrlForSection`** following Reception's pattern:
   ```dart
   void _updateUrlForSection(HrDeskSection section) {
     if (!mounted) return;
     final String tab = _sectionToQueryValue(section);
     final String location = AppRoutes.hr.location(
       queryParameters: <String, String>{
         if (tab.isNotEmpty) 'section': tab,
       },
     );
     GoRouter.of(context).replace<void>(location);
   }
   ```

e. **Add a contextual primary action button** next to the tab strip:
   ```dart
   Widget _primaryActionButton(AppLocalizations l10n, HrWorkspaceState state) {
     return switch (_section) {
       HrDeskSection.staffDirectory => AppButton.primary(
         label: l10n.hrAddStaffAction,
         leadingIcon: Icons.person_add_outlined,
         onPressed: state.isRefreshing ? null : () => showHrStaffOnboardingDialog(context, ref),
       ),
       HrDeskSection.leaveRequests => AppButton.primary(
         label: l10n.hrWorkQueuesTitle,
         leadingIcon: Icons.pending_actions_outlined,
         onPressed: state.isRefreshing ? null : () => applyHrQueueAndShow(context, ref, HrQueue.leaveRequests),
       ),
       HrDeskSection.shiftRoster => AppButton.primary(
         label: l10n.hrShiftTemplateAction,
         leadingIcon: Icons.view_week_outlined,
         onPressed: state.isRefreshing ? null : () => showHrManageScheduleTemplatesDialog(context, ref),
       ),
       HrDeskSection.payroll => AppButton.primary(
         label: l10n.hrPayrollDraftTitle,
         leadingIcon: Icons.payments_outlined,
         onPressed: null,
       ),
       HrDeskSection.access => AppButton.primary(
         label: l10n.hrManageAccessAction,
         leadingIcon: Icons.manage_accounts_outlined,
         onPressed: state.isRefreshing ? null : () => showHrAccessWorkspaceDialog(context),
       ),
     };
   }
   ```

f. **Build per-tab body** using a `_buildTabBody()` method that returns the appropriate `AppListTable` for the active section:
   - `HrDeskSection.staffDirectory` → existing `_HrStaffDirectory` widget (already built as an `AppListTable<HrStaffProfile>`).
   - `HrDeskSection.leaveRequests` → `AppListTable<HrWorkItem>` filtered to `HrQueue.leaveRequests`.
   - `HrDeskSection.shiftRoster` → `Column` containing `HrQueueSwitcher` + `AppListTable<HrWorkItem>` filtered to roster/shift queues.
   - `HrDeskSection.payroll` → `AppListTable<HrWorkItem>` filtered to `HrQueue.payrollDrafts`.
   - `HrDeskSection.access` → inline access panel (extracted from current dialog-only workflow).

g. **Trigger queue changes on tab switch:** When switching to a queue-based tab (leave requests, shift roster, payroll), call `controller.applyQueue(targetQueue)` to refresh the work items for that queue.

h. **Remove the old `AppWorkspace` wrapper and toolbar action buttons.** The toolbar actions (Refresh, Housekeeping, Fault Report) should be moved to a simple overflow menu or action row below the tab strip. The summary notifications can be displayed as badge counts on the tab labels (as shown in the tab strip label pattern above).

i. **Add imports:**
   ```dart
   import 'package:go_router/go_router.dart';
   import 'package:hosspi_hms/app/router/app_routes.dart';
   import 'package:hosspi_hms/shared/layout/layout.dart'; // for ResponsivePage, PageMaxWidth
   ```

j. **Extract inline field widgets** (`_ShiftAssignmentFields`, `_ShiftSwapFields`, `_ReasonFields`, `_RosterPublishFields`, `_OverrideShiftFields`, `_ProcessPayrollFields`) into a separate file `frontend/lib/features/hr/presentation/widgets/hr_workspace_form_fields.dart` to reduce the page file size. They still need access to `HrReferenceData` and localizations.

### 4. Add section helper functions — File: `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart`

Add these helpers following the Reception reference:

```dart
String _sectionLabel(AppLocalizations l10n, HrDeskSection section) {
  return switch (section) {
    HrDeskSection.staffDirectory => l10n.hrTitle,
    HrDeskSection.leaveRequests => l10n.hrLeaveRequestsSummaryLabel,
    HrDeskSection.shiftRoster => l10n.hrShiftsSectionTitle,
    HrDeskSection.payroll => l10n.hrPayrollDraftsSummaryLabel,
    HrDeskSection.access => l10n.hrManageAccessAction,
  };
}

IconData _sectionIcon(HrDeskSection section) {
  return switch (section) {
    HrDeskSection.staffDirectory => Icons.people_outlined,
    HrDeskSection.leaveRequests => Icons.event_busy_outlined,
    HrDeskSection.shiftRoster => Icons.calendar_view_week_outlined,
    HrDeskSection.payroll => Icons.payments_outlined,
    HrDeskSection.access => Icons.manage_accounts_outlined,
  };
}

int _sectionCount(HrWorkspaceState state, HrDeskSection section) {
  final HrWorkspaceSummary summary = state.overview.summary;
  return switch (section) {
    HrDeskSection.staffDirectory => state.staff.totalItemCount ?? state.staff.items.length,
    HrDeskSection.leaveRequests => summary.leaveRequests,
    HrDeskSection.shiftRoster => summary.draftRosters + summary.unassignedShifts + summary.overdueShifts,
    HrDeskSection.payroll => summary.payrollDraftRuns,
    HrDeskSection.access => 0,
  };
}

static String _sectionToQueryValue(HrDeskSection section) {
  return switch (section) {
    HrDeskSection.staffDirectory => 'staff',
    HrDeskSection.leaveRequests => 'leave-requests',
    HrDeskSection.shiftRoster => 'shift-roster',
    HrDeskSection.payroll => 'payroll',
    HrDeskSection.access => 'access',
  };
}

HrDeskSection? _sectionFromQuery(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'staff':
    case 'staff-directory':
    case 'directory':
      return HrDeskSection.staffDirectory;
    case 'leave':
    case 'leave-requests':
    case 'leaves':
      return HrDeskSection.leaveRequests;
    case 'shift':
    case 'shift-roster':
    case 'roster':
    case 'shifts':
      return HrDeskSection.shiftRoster;
    case 'payroll':
    case 'payroll-drafts':
      return HrDeskSection.payroll;
    case 'access':
    case 'roles':
    case 'permissions':
      return HrDeskSection.access;
    default:
      return null;
  }
}
```

### 5. Add `_mobileItemBuilder` for work items — File: `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart`

The existing `_HrWorkItemTile` and `_HrStaffListTile` already serve as mobile item builders. Reuse them in the `mobileItemBuilder` parameter of each tab's `AppListTable`.

### 6. Keep deep-link handling — File: `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart`

The existing `_handleDeepLink()` logic must be preserved. Extend it to also handle the `section` field:
- If `query.section` is non-empty, resolve it to an `HrDeskSection` and set `_section` accordingly.
- If `query.queue` is provided, map it to the appropriate tab section (e.g., `HrQueue.leaveRequests` → `HrDeskSection.leaveRequests`).

### 7. Verify toolbar actions are still accessible

The following actions from the old toolbar must remain accessible, either as tab-contextual primary buttons or via an overflow/secondary action row:
- Add Staff → primary action on Staff Directory tab
- Work Queues → now inline as tabs (Leave Requests, Shift Roster, Payroll)
- Manage Access → primary action on Access & Roles tab
- Schedule Templates → primary action on Shift Roster tab
- Activity → secondary action (overflow menu or icon button)
- Refresh → secondary action (overflow menu or icon button)
- Housekeeping → secondary action (overflow menu or icon button)
- Fault Report → secondary action (overflow menu or icon button)

## Shared Components — MUST Reuse

Do NOT create new implementations of these. Import and use them directly:

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` / `AppTabItem` | `package:hosspi_hms/shared/components/components.dart` | Tab navigation across HR sections |
| `AppListTable<T>` | `package:hosspi_hms/shared/components/components.dart` | Data table for each tab's content |
| `AppListTableColumn<T>` | `package:hosspi_hms/shared/components/components.dart` | Column definitions per tab |
| `AppListTableSearch<T>` | `package:hosspi_hms/shared/components/components.dart` | Integrated search bar in table |
| `AppListTableColumnVisibilityController<T>` | `package:hosspi_hms/shared/components/components.dart` | Column visibility settings |
| `ResponsivePage` | `package:hosspi_hms/shared/layout/layout.dart` | Page-level responsive wrapper |
| `PageMaxWidth` | `package:hosspi_hms/shared/layout/layout.dart` | Max width enum (`dataHeavy`) |
| `AppButton` | `package:hosspi_hms/shared/components/components.dart` | Primary/secondary action buttons |
| `AppWorkspaceStatusBadge` / `AppWorkspaceStatus` | `package:hosspi_hms/shared/components/components.dart` | Status badge rendering |
| `AppStateView` | `package:hosspi_hms/shared/components/components.dart` | Empty/error state display |
| `AppCopyableIdentifierCell` | `package:hosspi_hms/shared/components/components.dart` | ID cell with copy action |
| `AppListItemText` | `package:hosspi_hms/shared/components/components.dart` | Title/subtitle text in rows |
| `AppFailureStateView` | `package:hosspi_hms/shared/components/components.dart` | Error state with retry |
| `AsyncStateScaffold` | `package:hosspi_hms/shared/layout/layout.dart` | Async loading scaffold |
| `AppPatientDetails` | `package:hosspi_hms/shared/components/components.dart` | Mobile detail card layout |
| `AppWorkspaceRefreshAction` | `package:hosspi_hms/shared/actions/actions.dart` | Refresh button |
| `AppGlobalHousekeepingRequestAction` | `package:hosspi_hms/shared/actions/actions.dart` | Housekeeping request action |
| `AppGlobalFaultReportAction` | `package:hosspi_hms/shared/actions/actions.dart` | Fault report action |
| `HrQueueSwitcher` | `package:hosspi_hms/features/hr/presentation/widgets/hr_queue_switcher.dart` | Sub-queue toggle for shift roster tab |

## Files to Create

| File Path | Purpose |
|-----------|---------|
| `frontend/lib/features/hr/presentation/widgets/hr_workspace_form_fields.dart` | Extracted form field widgets: `HrShiftAssignmentFields`, `HrShiftSwapFields`, `HrReasonFields`, `HrRosterPublishFields`, `HrOverrideShiftFields`, `HrProcessPayrollFields` — previously inline in the page file |

## Files to Modify

| File Path | Changes |
|-----------|---------|
| `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart` | Major refactor: replace `AppWorkspace` with `ResponsivePage` + `AppTabStrip`, add `HrDeskSection` state, per-tab body rendering, URL sync, contextual primary action, extract inline form widgets |
| `frontend/lib/features/hr/domain/entities/hr_entities.dart` | Add `HrDeskSection` enum, add `section` field to `HrWorkspaceQuery` |

## Files to Delete (if any)

No files should be deleted. All widget files in `hr/presentation/widgets/` are still used by dialogs triggered from the page.

## Cleanup: Remove Stale Code

After the refactor, the agent MUST remove all dead/stale code left behind:

- [ ] Remove the old `AppWorkspace` wrapper code and its toolbar/overflow-section definitions from the page file.
- [ ] Remove the `_summaryNotifications()` method if summary counts are now shown as tab badge counts instead of `AppWorkspaceSummaryNotification` objects.
- [ ] Remove unused imports across all modified files (e.g., `AppWorkspace`, `appWorkspaceToolbarWithLabels`, `AppToolbarOverflowSection` imports if no longer used).
- [ ] Remove the extracted inline field widgets from the page file after they've been moved to `hr_workspace_form_fields.dart`.
- [ ] Remove any dead helper functions or private widgets that were only used by the old toolbar layout.
- [ ] Run `dart analyze` to catch any remaining unreferenced declarations and remove them.
- [ ] Verify no test files reference deleted code — update or remove stale tests.

List every file and symbol removed in a "Cleanup Summary" section at the end of the implementation.

## Database Migrations

No database migrations required — schema unchanged. This refactor only restructures the frontend UI layer. The HR domain entities, API contracts, repository implementations, and data models remain identical.

## Responsive Design Requirements

- **Desktop (≥1024px):** Full `AppListTable` with all columns visible. Tab strip displays all tab labels with counts. Primary action button is visible beside the tab strip.
- **Tablet (600–1023px):** `AppListTable` with condensed columns (some columns hidden via `AppListTableColumnVisibilityController`). Tab strip may scroll horizontally. Primary action button remains visible.
- **Mobile (<600px):** `AppListTable` switches to `mobileItemBuilder` rendering — card-based rows using `_HrStaffListTile` (staff tab) and `_HrWorkItemTile` (queue tabs). Tab strip becomes scrollable. Primary action button may be moved to a FAB or compact icon button.

Use `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)` as the outer wrapper — this is the same responsive utility used by the Reception workspace. The `AppListTable` widget already handles the desktop/mobile switch via its `mobileItemBuilder` parameter.

## Verification Steps

After implementation, the agent MUST run these commands and confirm they pass:

```bash
# Format
dart format frontend/lib/features/hr/

# Analyze
cd frontend && dart analyze --fatal-infos

# Run tests related to HR screen (if they exist)
cd frontend && flutter test test/features/hr/ 2>/dev/null || echo "No HR tests found"

# Run shared component tests to ensure no regressions
cd frontend && flutter test test/shared/ 2>/dev/null || echo "No shared tests found"
```

## Testing Requirements

Write or update these tests (if a test directory exists for HR):

- [ ] Tab navigation: switching tabs updates the URL query parameter `section`
- [ ] Deep linking: navigating directly to `/hr?section=leave-requests` renders the Leave Requests tab
- [ ] Deep linking: navigating to `/hr?queue=LEAVE_REQUESTS` maps to the Leave Requests tab
- [ ] Table data: Staff Directory tab displays `state.staff` items
- [ ] Table data: Leave Requests tab displays work items filtered to `HrQueue.leaveRequests`
- [ ] Search: typing in the search bar filters table rows (staff tab uses server-side search, queue tabs use client-side)
- [ ] Primary action: button label changes per tab (Add Staff / Request Leave / Schedule Templates / etc.)
- [ ] Responsive layout: mobile view uses `mobileItemBuilder` for card-based rows
- [ ] No regressions: staff detail dialog still opens when clicking a staff row
- [ ] No regressions: all queue action dialogs (approve/reject leave, publish roster, process payroll) still function

## Acceptance Criteria

The refactor is complete when ALL of the following are true:

- [ ] The HR screen uses routable tabs matching the Reception workspace pattern (`AppTabStrip` with `HrDeskSection` enum)
- [ ] Each tab has its own URL query parameter (`?section=staff|leave-requests|shift-roster|payroll|access`) that supports deep linking
- [ ] The primary action button is contextual per tab and positioned beside the tab strip
- [ ] Each tab body uses `AppListTable` with integrated search, column visibility, and pagination
- [ ] Work queues are displayed inline as tab content instead of modal dialogs
- [ ] No shared component is re-implemented — only imported and used
- [ ] The layout is fully responsive across mobile, tablet, and desktop (using `ResponsivePage` + `mobileItemBuilder`)
- [ ] All old toolbar/overflow-section layout code is removed — no stale symbols remain
- [ ] Domain-specific business logic and data are preserved (controller, repository, entities unchanged except `HrWorkspaceQuery` extension)
- [ ] No database migrations required — schema unchanged
- [ ] `dart analyze` reports no new issues — zero unused imports, zero unreferenced declarations
- [ ] All tests pass (no stale test references to removed code)
- [ ] Staff detail dialog, onboarding, offboarding, and all mutation dialogs continue to work correctly
- [ ] Summary notification counts are visible as tab badge counts
- [ ] The `HrQueueSwitcher` widget is reused on the Shift Roster tab for sub-queue toggling
