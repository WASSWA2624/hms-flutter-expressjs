# Standardize Nursing Screen

## Objective

Refactor the Nursing workspace to match the standardized tab-and-table layout used by the Reception workspace. The nursing workspace page is currently a 3,268-line monolithic file with all dialogs defined inline. This refactor will: (1) add an `AppTabStrip` for scope-based tab navigation with URL query sync, (2) introduce per-tab column configurations, (3) add a contextual primary action button next to the tab strip, (4) create a `NursingWorkspaceQuery` deep-link model, (5) extract all dialog widgets into separate files, and (6) wire per-tab column visibility/width storage keys. All existing domain logic, state management, and business behavior will be preserved.

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification — all information needed is in this prompt. Run tests and formatting after implementation.

## Current State (from audit)

- **Main page**: `frontend/lib/features/nursing/presentation/pages/nursing_workspace_page.dart` (~3,268 lines) — monolithic file with all dialogs inline
- **Entities**: `frontend/lib/features/nursing/domain/entities/nursing_entities.dart` (1,173 lines) — `NursingQueueScope`, `NursingDetailPanel`, `NursingNoteTags`, `NursingWorklistQuery`, `NursingPatientSummary`, `NursingPatientDetail`, `NursingWorkspaceState`, etc.
- **Controller**: `frontend/lib/features/nursing/presentation/controllers/nursing_workspace_controller.dart` (1,245 lines) — `NursingWorkspaceController` (Riverpod `AsyncNotifier`)
- **Repository interface**: `frontend/lib/features/nursing/domain/repositories/nursing_repository.dart`
- **Repository impl**: `frontend/lib/features/nursing/data/repositories/nursing_repository_impl.dart`
- **DTOs**: `frontend/lib/features/nursing/data/dtos/nursing_dtos.dart`
- **Shared nursing components**: `frontend/lib/shared/components/app_nursing_components.dart` — `AppMedicationAdministrationForm`, `AppHandoverActionForm`, `AppCareTaskChecklist`, `AppRosterAssignmentList`, `AppWardActivityList`, `AppNursingRecordList`
- **Route**: `/nursing` with inline query param extraction in `frontend/lib/app/router/app_router.dart` (lines 217–232)
- **Route definition**: `frontend/lib/app/router/app_routes.dart` (lines 370–382) — requires `inpatient-bed-management` module
- **Tests**: `frontend/test/features/nursing/domain/nursing_entities_test.dart`, `frontend/test/features/nursing/data/nursing_dtos_test.dart`, `frontend/test/features/nursing/presentation/nursing_workspace_controller_test.dart`

### Current problems / inconsistencies

- **No visual tab navigation**: `NursingQueueScope` values (assignedWard, urgent, medicationDue, handoverPending, transferPending, dischargePending, all) are only accessible via toolbar summary notification chips and the advanced filter panel — no `AppTabStrip` for quick scope switching
- **No URL sync for scope**: The current route supports `?id=...&panel=...` for deep-linking to a patient detail, but the active scope is NOT synced to the URL (no `?scope=...` query parameter)
- **No dedicated query model**: Router uses inline `state.uri.queryParameters` extraction instead of a `NursingWorkspaceQuery.fromUri()` factory
- **Monolithic file**: All 10+ dialog classes (`_MedicationDialog`, `_HandoverDialog`, `_NursingShiftContextDialog`, `_PrintNursingSummaryDialog`, `_NursingPatientDetailDialog`, vitals dialog, note dialog, escalation dialog, transfer dialog, discharge clearance dialog, accept handover dialog, care plan dialog, prescription dialog, lab order dialog, radiology order dialog) are defined in the single 3,268-line page file
- **Single column set**: Only one set of default columns + column choices, unlike reception which swaps columns per tab
- **No per-tab storage keys**: `columnVisibilityStorageKey` and `columnWidthStorageKey` are not passed (reception uses `'reception_${_section.name}'` pattern)
- **No primary action button in tab strip row**: Toolbar secondary actions are all listed as overflow actions, no promoted primary action next to the tab strip
- **Helper functions at file scope**: ~20 top-level private helper functions (`_apiLabel`, `_joinDisplay`, `_summaryStatus`, `_statusTone`, `_taskTypeLabel`, etc.) clutter the file

## Reference Implementation

Read these files to understand the target patterns (do NOT modify them):

| File | Key Patterns to Extract |
|------|------------------------|
| `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` | Tab enum → `_section` local state, `_sectionToQueryValue()` / `_sectionFromQuery()` URL mapping, `_updateUrlForSection()` via `GoRouter.replace`, `AppTabStrip` in `Row` with primary action button, single `AppListTable` with `_columnsForSection()` switch, per-tab `columnVisibilityStorageKey: 'reception_${_section.name}'`, `_searchMatcher` |
| `frontend/lib/features/reception/domain/entities/reception_entities.dart` | `ReceptionWorkspaceQuery.fromUri()` factory, `hasRouteTargeting`, `signature` deduplication |
| `frontend/lib/shared/components/app_list_table.dart` | `AppListTable<T>` constructor: `columns`, `columnChoices`, `columnVisibilityStorageKey`, `columnWidthStorageKey`, `search`, `mobileItemBuilder`, `emptyBuilder`, `page`, `onPageChanged` |
| `frontend/lib/shared/components/app_tab_strip.dart` | `AppTabStrip` with `tabs: List<AppTabItem>`, `selectedId: String?`, `onTabTapped: ValueChanged<String>` |
| `frontend/lib/shared/layout/app_workspace.dart` | `AppWorkspace` with `title`, `leadingIcon`, `toolbar`, `body`, `primaryAction` |
| `frontend/lib/shared/components/app_search_bar.dart` | `AppSearchBarFilterGroup`, `AppSearchBarTextFilter`, `AppSearchBarFieldChoice`, `AppSearchBarFilterValue` |
| `frontend/lib/core/responsive/app_breakpoints.dart` | `AppBreakpoint` enum (xs, sm, md, lg, xl, xxl), `AppBreakpoints.fromConstraints()`, `isMobile` |
| `frontend/lib/shared/layout/responsive_page.dart` | `ResponsivePage`, `PageMaxWidth.dataHeavy` |

## Target Architecture

### Tab Configuration

The existing `NursingQueueScope` enum will be reused as the tab model. Each scope maps to a visual tab:

| Tab Name | Scope Value | Route Query `?scope=` | Icon | Description | Primary Action Button |
|----------|-------------|----------------------|------|-------------|----------------------|
| All | `NursingQueueScope.all` | `all` (default) | `Icons.inventory_2_outlined` | Full nursing worklist | Record Vitals |
| Assigned Ward | `NursingQueueScope.assignedWard` | `assigned-ward` | `Icons.local_hospital_outlined` | Patients in nurse's assigned ward | Record Vitals |
| Urgent | `NursingQueueScope.urgent` | `urgent` | `Icons.priority_high_outlined` | Critical/urgent patients | Record Vitals |
| Medication Due | `NursingQueueScope.medicationDue` | `medication-due` | `Icons.medication_outlined` | Patients with pending medications | Administer Medication |
| Handover Pending | `NursingQueueScope.handoverPending` | `handover-pending` | `Icons.swap_horiz_outlined` | Patients with pending handovers | Create Handover |
| Transfer Pending | `NursingQueueScope.transferPending` | `transfer-pending` | `Icons.transfer_within_a_station_outlined` | Patients awaiting transfer | Acknowledge Transfer |
| Discharge Pending | `NursingQueueScope.dischargePending` | `discharge-pending` | `Icons.logout_outlined` | Patients pending discharge | Discharge Clearance |

### Routing

**Router file**: `frontend/lib/app/router/app_router.dart`

Replace the inline query extraction (lines 217–232) with:

```dart
GoRoute(
  path: AppRoutes.nursing.path,
  name: AppRoutes.nursing.name,
  builder: (_, GoRouterState state) {
    return NursingWorkspacePage(
      initialQuery: NursingWorkspaceQuery.fromUri(state.uri),
    );
  },
),
```

This mirrors reception's pattern at lines 138–146 of the same file.

### Page Layout

The refactored page widget tree:

```
NursingWorkspacePage (ConsumerWidget)
  └── AsyncStateScaffold<NursingWorkspaceState>
      └── _NursingWorkspaceContent (ConsumerStatefulWidget)
          └── AppWorkspace(
                title: l10n.nursingTitle,
                leadingIcon: AppRouteIcons.nursing,
                toolbar: appWorkspaceToolbarWithLabels(l10n, ...),
                body: Column(
                  children: [
                    Row(                              // <-- tab strip + primary action
                      children: [
                        Expanded(
                          child: AppTabStrip(
                            tabs: _nursingTabs(l10n),
                            selectedId: _scopeToQueryValue(_scope),
                            onTabTapped: _onTabTapped,
                          ),
                        ),
                        AppAccessActionGate(
                          requirement: writeRequirement,
                          builder: (_, isAllowed) => AppButton.primary(
                            label: _primaryActionLabel(l10n, _scope),
                            leadingIcon: _primaryActionIcon(_scope),
                            enabled: isAllowed,
                            onPressed: _primaryAction,
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: AppListTable<NursingWorkItem>(
                        page: state.worklist,
                        columns: _columnsForScope(l10n, _scope),
                        columnChoices: _columnChoicesForScope(l10n, _scope),
                        columnVisibilityStorageKey: 'nursing_${_scope.name}',
                        columnWidthStorageKey: 'nursing_cw_${_scope.name}',
                        search: AppListTableSearch<NursingWorkItem>(...),
                        mobileItemBuilder: _mobileItemBuilder,
                        ...
                      ),
                    ),
                  ],
                ),
              )
```

### Data & State Management

- **Controller**: Keep existing `NursingWorkspaceController` at `frontend/lib/features/nursing/presentation/controllers/nursing_workspace_controller.dart` and its provider `nursingWorkspaceControllerProvider` unchanged
- **State**: Keep existing `NursingWorkspaceState` in `frontend/lib/features/nursing/domain/entities/nursing_entities.dart` unchanged
- **Scope application**: Continue using `controller.applyScope(scope)` to change the scope — this triggers server-side filtering and pagination
- **Search/filter**: Keep existing `controller.applySearch()`, `controller.applyAdvancedFilters()`, and `controller.changePage()` — they already handle scope changes through the query
- **Realtime sync**: No changes needed — `NursingWorkspaceController` already uses `listenForRealtimeRefresh` with `RealtimeEventGroups.nursing` and `WorkspaceAdaptivePolling`

## Implementation Steps

### 1. Create `NursingWorkspaceQuery` deep-link model — File: `frontend/lib/features/nursing/domain/entities/nursing_entities.dart`

Add a new class after `NursingDetailPanel` (around line 33), following the pattern from `ReceptionWorkspaceQuery` in `frontend/lib/features/reception/domain/entities/reception_entities.dart`:

```dart
@immutable
final class NursingWorkspaceQuery {
  const NursingWorkspaceQuery({
    this.scope = '',
    this.search = '',
    this.admissionId = '',
    this.panel = '',
  });

  factory NursingWorkspaceQuery.fromUri(Uri uri) {
    final Map<String, String> params = uri.queryParameters;
    String pick(List<String> keys) {
      for (final String key in keys) {
        final String value = (params[key] ?? '').trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
      return '';
    }

    return NursingWorkspaceQuery(
      scope: pick(<String>['scope', 'section', 'filter', 'queue']),
      search: pick(<String>['search', 'q', 'patient']),
      admissionId: pick(<String>['id', 'admissionId', 'admission_id', 'encounterId', 'encounter_id']),
      panel: pick(<String>['panel', 'detail']),
    );
  }

  final String scope;
  final String search;
  final String admissionId;
  final String panel;

  bool get hasRouteTargeting =>
      scope.isNotEmpty ||
      search.isNotEmpty ||
      admissionId.isNotEmpty ||
      panel.isNotEmpty;

  String get signature => '$scope|$search|$admissionId|$panel';
}
```

### 2. Update router to use `NursingWorkspaceQuery` — File: `frontend/lib/app/router/app_router.dart`

Replace lines 217–232 (the nursing `GoRoute`) with:

```dart
GoRoute(
  path: AppRoutes.nursing.path,
  name: AppRoutes.nursing.name,
  builder: (_, GoRouterState state) {
    return NursingWorkspacePage(
      initialQuery: NursingWorkspaceQuery.fromUri(state.uri),
    );
  },
),
```

Update the import at the top of `app_router.dart`: ensure `NursingWorkspaceQuery` is importable from `nursing_entities.dart`. Remove the `NursingDetailPanel` import if it was separate (it's in the same file so likely already imported via `nursing_entities.dart`).

Update `NursingWorkspacePage` constructor to accept `NursingWorkspaceQuery? initialQuery` instead of separate `initialAdmissionId` and `initialPanel` parameters.

### 3. Extract dialog widgets to separate files — File: Create new files in `frontend/lib/features/nursing/presentation/widgets/`

Extract each dialog class from `nursing_workspace_page.dart` into its own file. Move the dialog and any directly supporting private classes/functions it uses:

| New File | Classes/Functions to Extract |
|----------|------------------------------|
| `nursing_patient_detail_dialog.dart` | `_NursingPatientDetailDialog`, `_NursingPatientDetailContent`, `_NursingActionBar`, `_NursingAdmissionChecklistPanel`, `_NursingRecordPanel`, `_NursingHandoverPanel` — make them non-private (remove leading `_`), e.g. `NursingPatientDetailDialog` |
| `nursing_medication_dialog.dart` | `_MedicationDialog`, `_MedicationDialogState` — rename to `NursingMedicationDialog` |
| `nursing_handover_dialog.dart` | `_HandoverDialog`, `_HandoverDialogState` — rename to `NursingHandoverDialog` (keep `escalation` parameter) |
| `nursing_shift_context_dialog.dart` | `_NursingShiftContextDialog`, `_NursingShiftContextPanel` — rename to `NursingShiftContextDialog`, `NursingShiftContextPanel` |
| `nursing_print_summary_dialog.dart` | `_PrintNursingSummaryDialog` — rename to `NursingPrintSummaryDialog` |
| `nursing_vitals_dialog.dart` | Extract the vitals recording dialog (currently invoked via `_openVitalsDialog`) — rename to `NursingVitalsDialog` |
| `nursing_note_dialog.dart` | Extract the note dialog (invoked via `_openNoteDialog`) — rename to `NursingNoteDialog` |
| `nursing_discharge_clearance_dialog.dart` | Extract the discharge clearance dialog (invoked via `_openDischargeClearanceDialog`) — rename to `NursingDischargeClearanceDialog` |
| `nursing_transfer_dialog.dart` | Extract the transfer acknowledgement dialog (invoked via `_openTransferDialog`) — rename to `NursingTransferDialog` |
| `nursing_escalation_dialog.dart` | Extract the escalation dialog (invoked via `_openEscalationDialog`) — rename to `NursingEscalationDialog` |
| `nursing_helpers.dart` | Extract all top-level helper functions that are shared between the page and dialogs: `_apiLabel`, `_joinDisplay`, `_summaryStatus`, `_statusFromValue`, `_statusTone`, `_priorityStatus`, `_taskTypeLabel`, `_dueTimeLabel`, `_admissionLabel`, `_responsibleNurseLabel`, `_lastObservationLabel`, `_pageTotal`, `_pageLabel`, `_showFailureIfNeeded`, `_dialogActions`, `_selectedDetailFromState`, `_medicationRoutes`, `_supportedMedicationRoute`, `_vitalRecords`, `_medicationRecords`, `_noteRecords`, `_carePlanRecords`, `_handoverRecords`, `_activityEntries`, `_admissionChecklistItems`, `_handoverActivityEntries`, `_rosterViews`, `_nursingSummaryText`, `_nursingSummaryHtml`, `_responsibleNurseSortValue`, `_statusOptions`, `_NursingSummaryText` — remove leading `_` and make public (prefix with `nursing` where appropriate, e.g. `nursingApiLabel`, `nursingJoinDisplay`, `nursingSummaryStatus`) |
| `nursing_patient_cell.dart` | `_NursingPatientCell` — rename to `NursingPatientCell` |

Each extracted file must import:
- `package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart`
- `package:hosspi_hms/features/nursing/presentation/controllers/nursing_workspace_controller.dart`
- `package:hosspi_hms/shared/components/components.dart`
- `package:hosspi_hms/shared/layout/layout.dart`
- `package:hosspi_hms/l10n/app_localizations.dart`
- `package:hosspi_hms/l10n/app_localizations_x.dart`
- Any other imports needed by the specific dialog (e.g., `clinical_entities.dart`, `patient_entities.dart`, printing imports)

After extraction, the main `nursing_workspace_page.dart` imports each widget file and calls the public dialog classes.

### 4. Add tab strip with scope navigation — File: `frontend/lib/features/nursing/presentation/pages/nursing_workspace_page.dart`

After extracting dialogs, refactor `_NursingWorkspaceContentState` to add:

**a) Tab state and URL sync** (follow reception's pattern from lines 159–203):

```dart
NursingQueueScope _scope = NursingQueueScope.all;

@override
void initState() {
  super.initState();
  _searchController = TextEditingController(text: widget.state.query.search);
  _filterValue = _filterValueFromQuery(widget.state.query);
  _scope = _scopeFromQuery(widget.initialQuery?.scope) ?? widget.state.query.scope;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    unawaited(_handleDeepLink());
  });
}

static String _scopeToQueryValue(NursingQueueScope scope) {
  return switch (scope) {
    NursingQueueScope.all => 'all',
    NursingQueueScope.assignedWard => 'assigned-ward',
    NursingQueueScope.urgent => 'urgent',
    NursingQueueScope.medicationDue => 'medication-due',
    NursingQueueScope.handoverPending => 'handover-pending',
    NursingQueueScope.transferPending => 'transfer-pending',
    NursingQueueScope.dischargePending => 'discharge-pending',
  };
}

NursingQueueScope? _scopeFromQuery(String? raw) {
  return switch (raw?.trim().toLowerCase()) {
    'all' || '' || null => NursingQueueScope.all,
    'assigned-ward' || 'assigned_ward' || 'ward' => NursingQueueScope.assignedWard,
    'urgent' || 'critical' => NursingQueueScope.urgent,
    'medication-due' || 'medication_due' || 'medication' => NursingQueueScope.medicationDue,
    'handover-pending' || 'handover_pending' || 'handover' => NursingQueueScope.handoverPending,
    'transfer-pending' || 'transfer_pending' || 'transfer' => NursingQueueScope.transferPending,
    'discharge-pending' || 'discharge_pending' || 'discharge' => NursingQueueScope.dischargePending,
    _ => null,
  };
}

void _updateUrlForScope(NursingQueueScope scope) {
  if (!mounted) return;
  final String tab = _scopeToQueryValue(scope);
  final String location = AppRoutes.nursing.location(
    queryParameters: <String, String>{
      if (tab.isNotEmpty && tab != 'all') 'scope': tab,
    },
  );
  GoRouter.of(context).replace<void>(location);
}

void _onTabTapped(String tabId) {
  final NursingQueueScope? scope = _scopeFromQuery(tabId);
  if (scope == null || scope == _scope) return;
  setState(() => _scope = scope);
  _updateUrlForScope(scope);
  ref.read(nursingWorkspaceControllerProvider.notifier).applyScope(scope);
}
```

**b) Tab strip definition** (follow reception's `AppTabStrip` usage):

```dart
List<AppTabItem> _nursingTabs(AppLocalizations l10n) {
  return <AppTabItem>[
    AppTabItem(
      id: _scopeToQueryValue(NursingQueueScope.all),
      icon: Icons.inventory_2_outlined,
      label: l10n.nursingScopeAllLabel,
    ),
    AppTabItem(
      id: _scopeToQueryValue(NursingQueueScope.assignedWard),
      icon: Icons.local_hospital_outlined,
      label: l10n.nursingScopeAssignedWardLabel,
    ),
    AppTabItem(
      id: _scopeToQueryValue(NursingQueueScope.urgent),
      icon: Icons.priority_high_outlined,
      label: l10n.nursingScopeUrgentLabel,
    ),
    AppTabItem(
      id: _scopeToQueryValue(NursingQueueScope.medicationDue),
      icon: Icons.medication_outlined,
      label: l10n.nursingScopeMedicationDueLabel,
    ),
    AppTabItem(
      id: _scopeToQueryValue(NursingQueueScope.handoverPending),
      icon: Icons.swap_horiz_outlined,
      label: l10n.nursingScopeHandoverPendingLabel,
    ),
    AppTabItem(
      id: _scopeToQueryValue(NursingQueueScope.transferPending),
      icon: Icons.transfer_within_a_station_outlined,
      label: l10n.nursingScopeTransferPendingLabel,
    ),
    AppTabItem(
      id: _scopeToQueryValue(NursingQueueScope.dischargePending),
      icon: Icons.logout_outlined,
      label: l10n.nursingScopeDischargePendingLabel,
    ),
  ];
}
```

**c) Primary action button per tab:**

```dart
String _primaryActionLabel(AppLocalizations l10n, NursingQueueScope scope) {
  return switch (scope) {
    NursingQueueScope.medicationDue => l10n.nursingActionAdministerMedication,
    NursingQueueScope.handoverPending => l10n.nursingActionCreateHandover,
    NursingQueueScope.transferPending => l10n.nursingActionAcknowledgeTransfer,
    NursingQueueScope.dischargePending => l10n.nursingActionDischargeClearance,
    _ => l10n.nursingActionRecordVitals,
  };
}

IconData _primaryActionIcon(NursingQueueScope scope) {
  return switch (scope) {
    NursingQueueScope.medicationDue => Icons.medication_outlined,
    NursingQueueScope.handoverPending => Icons.swap_horiz_outlined,
    NursingQueueScope.transferPending => Icons.transfer_within_a_station_outlined,
    NursingQueueScope.dischargePending => Icons.fact_check_outlined,
    _ => Icons.monitor_heart_outlined,
  };
}
```

### 5. Add per-tab column configuration — File: `frontend/lib/features/nursing/presentation/pages/nursing_workspace_page.dart`

Create a `_columnsForScope()` method that returns different column sets per scope (like reception's `_columnsForSection()`). Each scope should highlight the most relevant columns:

| Scope | Default Columns |
|-------|----------------|
| `all` | Patient, Location, Task Type, Priority, Status |
| `assignedWard` | Patient, Location (ward/room/bed), Task Type, Priority, Status |
| `urgent` | Patient, Priority (alwaysVisible), Location, Status, Due Time |
| `medicationDue` | Patient, Medication Due Count, Location, Due Time, Status |
| `handoverPending` | Patient, Responsible Nurse, Location, Status, Observations |
| `transferPending` | Patient, Location, Transfer Status, Admission, Status |
| `dischargePending` | Patient, Location, Discharge Status, Admission, Due Time |

The columns must use:
- `AppListTableColumn<NursingWorkItem>` with `label`, `sortComparator`, `cellBuilder`
- `AppWorkspaceStatusBadge` for status/priority badges
- Existing cell widgets: `NursingPatientCell` (extracted in step 3)
- Existing helper functions from `nursing_helpers.dart` (extracted in step 3)

### 6. Wire per-tab column visibility and width storage keys — File: `frontend/lib/features/nursing/presentation/pages/nursing_workspace_page.dart`

In the `_NursingWorklistPanel` (or wherever `AppListTable` is now rendered), add:

```dart
columnVisibilityStorageKey: 'nursing_${_scope.name}',
columnWidthStorageKey: 'nursing_cw_${_scope.name}',
```

This follows reception's pattern at lines 288–289.

### 7. Update `NursingWorkspacePage` constructor — File: `frontend/lib/features/nursing/presentation/pages/nursing_workspace_page.dart`

Change from:

```dart
class NursingWorkspacePage extends ConsumerWidget {
  const NursingWorkspacePage({
    this.initialAdmissionId,
    this.initialPanel,
    super.key,
  });

  final String? initialAdmissionId;
  final NursingDetailPanel? initialPanel;
```

To:

```dart
class NursingWorkspacePage extends ConsumerWidget {
  const NursingWorkspacePage({
    this.initialQuery,
    super.key,
  });

  final NursingWorkspaceQuery? initialQuery;
```

Update `_NursingWorkspaceContent` similarly. The deep-link handling (`_handleDeepLink`) must derive `initialAdmissionId` from `initialQuery?.admissionId` and `initialPanel` from `NursingDetailPanel.fromValue(initialQuery?.panel)`.

### 8. Update the build method layout — File: `frontend/lib/features/nursing/presentation/pages/nursing_workspace_page.dart`

Refactor the `_NursingWorkspaceContentState.build()` method to place the `AppTabStrip` + primary action button in a `Row` above the `AppListTable`, matching reception's layout pattern (lines 259–312):

```dart
@override
Widget build(BuildContext context) {
  final AppLocalizations l10n = context.l10n;
  final NursingWorkspaceState state = widget.state;
  final NursingWorkspaceController controller = ref.read(
    nursingWorkspaceControllerProvider.notifier,
  );

  return AppWorkspace(
    title: l10n.nursingTitle,
    leadingIcon: AppRouteIcons.nursing,
    toolbar: appWorkspaceToolbarWithLabels(
      l10n,
      summaryNotifications: <AppWorkspaceSummaryNotification>[
        // ... keep existing summary notifications ...
      ],
      secondary: <Widget>[
        // ... keep existing secondary toolbar actions ...
      ],
      onRefresh: () async { ... },
      isRefreshing: state.isRefreshing || state.isRefreshingDetail,
    ),
    body: Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: AppTabStrip(
                tabs: _nursingTabs(l10n),
                selectedId: _scopeToQueryValue(_scope),
                onTabTapped: _onTabTapped,
              ),
            ),
            AppAccessActionGate(
              requirement: writeRequirement,
              builder: (BuildContext context, bool isAllowed) {
                return AppButton.primary(
                  label: _primaryActionLabel(l10n, _scope),
                  leadingIcon: _primaryActionIcon(_scope),
                  enabled: isAllowed && !state.isSaving,
                  onPressed: isAllowed ? () => _executePrimaryAction() : null,
                );
              },
            ),
          ],
        ),
        Expanded(
          child: _NursingWorklistPanel(
            state: state,
            scope: _scope,
            searchController: _searchController,
            filterValue: _filterValue,
            onFilterChanged: _onFilterChanged,
          ),
        ),
      ],
    ),
  );
}
```

### 9. Update `_NursingWorklistPanel` to accept scope — File: `frontend/lib/features/nursing/presentation/pages/nursing_workspace_page.dart`

Add a `scope` parameter and use it for per-tab column configuration:

```dart
class _NursingWorklistPanel extends ConsumerWidget {
  const _NursingWorklistPanel({
    required this.state,
    required this.scope,
    required this.searchController,
    required this.filterValue,
    required this.onFilterChanged,
  });

  final NursingWorkspaceState state;
  final NursingQueueScope scope;
  final TextEditingController searchController;
  final AppSearchBarFilterValue filterValue;
  final ValueChanged<AppSearchBarFilterValue> onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    // ...
    return AppListTable<NursingWorkItem>(
      page: state.worklist,
      columns: _columnsForScope(l10n, scope),
      columnChoices: _columnChoicesForScope(l10n, scope),
      columnVisibilityStorageKey: 'nursing_${scope.name}',
      columnWidthStorageKey: 'nursing_cw_${scope.name}',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      // ... keep remaining configuration ...
    );
  }
}
```

### 10. Update tests — File: `frontend/test/features/nursing/presentation/nursing_workspace_controller_test.dart`

Update any test references to the old `NursingWorkspacePage` constructor to use the new `initialQuery` parameter.

### 11. Add `NursingWorkspaceQuery` tests — File: `frontend/test/features/nursing/domain/nursing_entities_test.dart`

Add tests for:
- `NursingWorkspaceQuery.fromUri()` with various query parameter combinations
- `hasRouteTargeting` returning correct values
- `signature` producing unique strings

## Shared Components — MUST Reuse

Do NOT create new implementations of these. Import and use them directly:

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppListTable<T>` | `package:hosspi_hms/shared/components/components.dart` | Main worklist table with built-in search, pagination, column visibility |
| `AppListTableSearch<T>` | `package:hosspi_hms/shared/components/components.dart` | Search config embedded in `AppListTable.search` parameter |
| `AppListTableColumn<T>` | `package:hosspi_hms/shared/components/components.dart` | Column definition with `label`, `sortComparator`, `cellBuilder` |
| `AppTabStrip` | `package:hosspi_hms/shared/components/components.dart` | Tab bar with `AppTabItem` list, `selectedId`, `onTabTapped` |
| `AppTabItem` | `package:hosspi_hms/shared/components/components.dart` | Tab definition with `id`, `icon`, `label` |
| `AppWorkspace` | `package:hosspi_hms/shared/layout/layout.dart` | Page layout with `title`, `toolbar`, `body` |
| `AppWorkspaceStatusBadge` | `package:hosspi_hms/shared/layout/layout.dart` | Status badge with `AppWorkspaceStatus` model |
| `AppWorkspaceDetailPanel` | `package:hosspi_hms/shared/layout/layout.dart` | Bordered detail section with `title` and `child` |
| `AppWorkspaceStatePanel` | `package:hosspi_hms/shared/layout/layout.dart` | Empty/loading/error state panels |
| `AppButton` | `package:hosspi_hms/shared/components/components.dart` | Primary/secondary/tertiary action buttons |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Permission gating wrapper |
| `AppDialog` | `package:hosspi_hms/shared/components/components.dart` | Dialog wrapper |
| `AppPatientDetailDialog` | `package:hosspi_hms/shared/components/components.dart` | Patient detail dialog shell |
| `AppPatientDetails` | `package:hosspi_hms/shared/components/components.dart` | Patient context header with fields and alerts |
| `AsyncStateScaffold<T>` | `package:hosspi_hms/shared/components/components.dart` | Async loading/error/success scaffold |
| `WorkflowActionButton` | `package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart` | Next-step action button for workflow |
| `AppMedicationAdministrationForm` | `package:hosspi_hms/shared/components/components.dart` | Medication form (from `app_nursing_components.dart`) |
| `AppHandoverActionForm` | `package:hosspi_hms/shared/components/components.dart` | Handover form |
| `AppCareTaskChecklist` | `package:hosspi_hms/shared/components/components.dart` | Admission checklist |
| `AppRosterAssignmentList` | `package:hosspi_hms/shared/components/components.dart` | Roster display |
| `AppWardActivityList` | `package:hosspi_hms/shared/components/components.dart` | Ward activity timeline |
| `AppNursingRecordList` | `package:hosspi_hms/shared/components/components.dart` | Nursing records display |
| `AppSearchBarFilterGroup` | `package:hosspi_hms/shared/components/components.dart` | Dropdown filter group for advanced filters |
| `AppSearchBarTextFilter` | `package:hosspi_hms/shared/components/components.dart` | Text filter field for advanced filters |
| `AppSearchBarFilterValue` | `package:hosspi_hms/shared/components/components.dart` | Composite filter state value |

## Files to Create

| File Path | Purpose |
|-----------|---------|
| `frontend/lib/features/nursing/presentation/widgets/nursing_patient_detail_dialog.dart` | Patient detail dialog with patient context, action bar, checklist, records panels |
| `frontend/lib/features/nursing/presentation/widgets/nursing_medication_dialog.dart` | Medication administration dialog |
| `frontend/lib/features/nursing/presentation/widgets/nursing_handover_dialog.dart` | Handover creation dialog (with escalation mode) |
| `frontend/lib/features/nursing/presentation/widgets/nursing_shift_context_dialog.dart` | Shift context / roster / pending handovers dialog |
| `frontend/lib/features/nursing/presentation/widgets/nursing_print_summary_dialog.dart` | Print nursing summary dialog |
| `frontend/lib/features/nursing/presentation/widgets/nursing_vitals_dialog.dart` | Vitals recording dialog |
| `frontend/lib/features/nursing/presentation/widgets/nursing_note_dialog.dart` | Nursing note dialog |
| `frontend/lib/features/nursing/presentation/widgets/nursing_discharge_clearance_dialog.dart` | Discharge clearance dialog |
| `frontend/lib/features/nursing/presentation/widgets/nursing_transfer_dialog.dart` | Transfer acknowledgement dialog |
| `frontend/lib/features/nursing/presentation/widgets/nursing_escalation_dialog.dart` | Escalation dialog |
| `frontend/lib/features/nursing/presentation/widgets/nursing_helpers.dart` | Shared helper functions (status mapping, label formatting, record builders) |
| `frontend/lib/features/nursing/presentation/widgets/nursing_patient_cell.dart` | `NursingPatientCell` — patient name/ID cell widget for the table |

## Files to Modify

| File Path | Changes |
|-----------|---------|
| `frontend/lib/features/nursing/domain/entities/nursing_entities.dart` | Add `NursingWorkspaceQuery` class with `fromUri()` factory |
| `frontend/lib/features/nursing/presentation/pages/nursing_workspace_page.dart` | (1) Change constructor to accept `NursingWorkspaceQuery?`, (2) Add `_scope` state + URL sync methods, (3) Add `AppTabStrip` in build, (4) Add per-tab columns + primary action, (5) Remove all extracted dialog/helper code, (6) Import new widget files |
| `frontend/lib/app/router/app_router.dart` | Replace nursing GoRoute builder to use `NursingWorkspaceQuery.fromUri()` |
| `frontend/test/features/nursing/domain/nursing_entities_test.dart` | Add tests for `NursingWorkspaceQuery` |
| `frontend/test/features/nursing/presentation/nursing_workspace_controller_test.dart` | Update constructor references if needed |

## Files to Delete (if any)

No files need to be deleted. All changes involve modifying existing files and creating new widget files for extracted dialog code.

## Cleanup: Remove Stale Code

After the refactor, the agent MUST remove all dead/stale code left behind:

- [ ] Delete all dialog class definitions from `nursing_workspace_page.dart` after they have been extracted to separate files in `presentation/widgets/`
- [ ] Delete all top-level helper functions from `nursing_workspace_page.dart` that were moved to `nursing_helpers.dart`
- [ ] Remove unused imports across all modified files
- [ ] Remove the `_NursingPatientCell` class from the main page file (moved to `nursing_patient_cell.dart`)
- [ ] Remove `_NursingSummaryText` abstract class if moved to helpers
- [ ] Remove the old `initialAdmissionId` and `initialPanel` constructor parameters from `NursingWorkspacePage` and `_NursingWorkspaceContent`
- [ ] Verify no references to the old constructor pattern remain in the router or any cross-feature navigation (check `frontend/lib/features/ipd/`, `frontend/lib/features/icu/`, `frontend/lib/features/opd/`, `frontend/lib/features/discharge/`, `frontend/lib/features/theater/`, `frontend/lib/shared/opd_actions/`, `frontend/lib/features/home/presentation/widgets/home_metric_routes.dart`)
- [ ] Run `dart analyze` to catch any remaining unreferenced declarations and remove them
- [ ] Verify no test files reference deleted code — update or remove stale tests

List every file and symbol removed in a "Cleanup Summary" section at the end of the implementation.

## Database Migrations

No database migrations required — schema unchanged. The refactoring only restructures the UI layer (tab navigation, file organization, URL sync). The backend API endpoints, data models, and database schema remain identical. The `NursingWorkspaceController` continues to call the same repository methods with the same query parameters.

## Responsive Design Requirements

- **Desktop (≥840px, `AppBreakpoint.md` and above):** Full `AppListTable` with DataTable rendering, all columns visible (per-tab column visibility settings apply), `AppTabStrip` renders all tabs horizontally, primary action button renders with label + icon
- **Tablet (600–839px, `AppBreakpoint.md`):** Same table layout but with condensed columns (some hidden by default via column visibility), `AppTabStrip` may scroll horizontally, primary action button renders with label
- **Mobile (<600px, `AppBreakpoint.xs` / `AppBreakpoint.sm`):** `AppListTable` switches to `mobileItemBuilder` (list mode — this is automatic via `AppListTableDisplayMode.adaptive`), each item renders as `NursingPatientCell` with status badges and summary text, primary action button renders icon-only via `AppActionLabelScope`

The breakpoint utility to use: `AppBreakpoints` from `package:hosspi_hms/core/responsive/app_breakpoints.dart`. `AppListTable` already handles the adaptive table↔list switch automatically at `xs`/`sm` breakpoints via its internal `_usesListLayout()` method.

The page uses `PageMaxWidth.dataHeavy` (1440px) via `AppWorkspace`'s default — no changes needed.

## Verification Steps

After implementation, the agent MUST run these commands and confirm they pass:

```bash
cd frontend

# Format
dart format .

# Analyze
dart analyze --fatal-infos

# Run tests related to this screen
flutter test test/features/nursing/

# Run shared component tests to ensure no regressions
flutter test test/shared/
```

## Testing Requirements

Write or update these tests:

- [ ] Tab navigation: switching tabs via `_onTabTapped` updates `_scope` and calls `controller.applyScope()`
- [ ] URL sync: `_updateUrlForScope()` generates the correct URL with `?scope=` query parameter
- [ ] `NursingWorkspaceQuery.fromUri()`: parses `?scope=urgent&id=abc&panel=vitals` correctly
- [ ] `NursingWorkspaceQuery.fromUri()`: handles alias parameters (`section`, `admission_id`, `encounterId`)
- [ ] `NursingWorkspaceQuery.hasRouteTargeting`: returns true when any parameter is set
- [ ] `NursingWorkspaceQuery.signature`: produces distinct strings for different queries
- [ ] Per-tab columns: `_columnsForScope()` returns different column sets per scope
- [ ] Primary action: button label and icon change per scope
- [ ] Deep linking: `initialQuery` with `admissionId` + `panel` still opens the correct patient and panel
- [ ] No regressions: existing controller tests still pass
- [ ] Table data: each scope tab displays correctly filtered data

## Acceptance Criteria

The refactor is complete when ALL of the following are true:

- [ ] The nursing workspace uses `AppTabStrip` with 7 scope-based tabs matching the reception pattern
- [ ] Each tab has its own URL query parameter (`?scope=...`) that supports deep linking
- [ ] The primary action button is contextual per tab (Record Vitals / Administer Medication / Create Handover / etc.) and positioned in a `Row` with the tab strip
- [ ] The page body uses `AppListTable` with per-tab column configuration, per-tab `columnVisibilityStorageKey`, and per-tab `columnWidthStorageKey`
- [ ] The router uses `NursingWorkspaceQuery.fromUri()` instead of inline parameter extraction
- [ ] All dialog widgets are extracted to separate files in `frontend/lib/features/nursing/presentation/widgets/`
- [ ] The main page file is reduced from ~3,268 lines to under ~500 lines
- [ ] No shared component is re-implemented — only imported and used
- [ ] The layout is fully responsive across mobile, tablet, and desktop (automatic via `AppListTable` + `AppBreakpoints`)
- [ ] All old/duplicate layout code is removed — no stale private classes or dead symbols remain
- [ ] Domain-specific business logic (controller, state, repository, realtime sync) is preserved unchanged
- [ ] No database migrations required — schema unchanged
- [ ] `dart analyze` reports no new issues — zero unused imports, zero unreferenced declarations
- [ ] All tests pass (no stale test references to removed code)
- [ ] New tests cover `NursingWorkspaceQuery`, tab navigation, URL sync, and per-tab column configuration
