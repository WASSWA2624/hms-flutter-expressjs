# Standardize OPD Workspace Screen

## Objective

Refactor the OPD (OutPatient Department) workspace screen (`/opd`) to match the standardized tab-and-table layout used by the Reception workspace. The screen currently renders a flat, single-worklist view with all data sources (appointments, queue entries, triage flows, active OPD flows) merged into one `AppWorkspace`-wrapped table with toolbar summary notification cards. After this refactor it will use routable `AppTabStrip` tabs (All Worklist, Arrivals, Queue, Triage, Active Encounters) with URL-synced section state via `?section=` query parameter, per-tab column configurations, per-tab column visibility persistence keys, and the canonical `ResponsivePage` → `Column` → `Row(AppTabStrip, AppButton.primary)` → `AppListTable` widget tree — exactly mirroring the Reception workspace pattern. All existing business logic (client-side filtering, advanced search with field-specific search, summary notification cards as tab badge counts, flow/appointment/queue actions, deep-linking via `?panel=` and `?id=`, realtime sync, urgency-based sorting, category-based row coloring, encounter dialog, walk-in start flow) must be preserved.

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification — all information needed is in this prompt. Run formatting and analysis after implementation.

## Current State (from audit)

### Files

- **Main page file:** `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart` — ~3103 lines. Contains `OpdWorkspacePage`, `_OpdWorkspaceContent`, `_OpdWorkspaceBody`, `_OpdMainTable`, `_OpdTableFilter`, `_OpdTableItem`, `_OpdTableMobileRow`, `_OpdPatientActionsDialog`, `QueueActionsDialog`, `_ProviderSelectField`, `_NextStepCell`, `_QueueStatusCell`, `_ProviderCell`, `_OpdEncounterCell`, plus ~30 private helper functions and 10+ table column/filter/sort definitions.
- **Controller:** `frontend/lib/features/opd/presentation/controllers/opd_workspace_controller.dart` — `OpdWorkspaceController` (`AsyncNotifier<Result<OpdWorkspaceState>>`), provider: `opdWorkspaceControllerProvider`. ~1694 lines. Methods: `refresh`, `applySearch`, `applyAppointmentStatus`, `applyQueueStatus`, `applyFlowStage`, `startOpdEncounter`, `checkInAppointment`, `assignDoctor`, `payConsultation`, `recordVitals`, `doctorReview`, `disposeFlow`, `completeDisposition`, `selectFlow`, `resolveFlowById`, `submitOpdEncounter`, plus page/queue/flow CRUD.
- **Realtime delta applier:** `frontend/lib/features/opd/presentation/controllers/opd_realtime_delta_applier.dart` — `OpdRealtimeDeltaApplier` (abstract final class with static methods).
- **Entities:** `frontend/lib/features/opd/domain/entities/opd_entities.dart` — `OpdAppointmentQuery`, `OpdQueueQuery`, `OpdFlowQuery`, `OpdTriageQueueQuery`, `OpdWorkspaceQuery`, `OpdAppointment`, `OpdQueueEntry`, `OpdFlowSummary`, `OpdFlowDetail`, `OpdWorkspaceState`, `OpdFlowAggregateCounts`, `OpdProviderOption`, `OpdProviderSchedule`, `OpdAvailabilitySlot`, `OpdClinicalAlertThreshold`, `OpdVitalSign`, `OpdClinicalAlert`, `OpdBillingDefaults`, `OpdDrugOption`, `OpdTimelineItem`, `OpdRelatedRecord`. ~1144 lines.
- **Repository interface:** `frontend/lib/features/opd/domain/repositories/opd_repository.dart` — `OpdRepository` (abstract interface).
- **Repository impl:** `frontend/lib/features/opd/data/repositories/opd_repository_impl.dart` — `OpdRepositoryImpl`, provider: `opdRepositoryProvider`. ~666 lines.
- **DTOs:** `frontend/lib/features/opd/data/dtos/opd_dtos.dart` — ~754 lines.
- **Shared OPD actions:**
  - `frontend/lib/shared/opd_actions/opd_actions.dart` — barrel export
  - `frontend/lib/shared/opd_actions/opd_flow_actions_dialog.dart` — `FlowActionsDialog`
  - `frontend/lib/shared/opd_actions/opd_encounter_flow.dart` — `openOpdWorkspaceEncounterFlow`, `buildOpdWorkspaceEncounterDialog`, `showOpdEncounterDialog`
  - `frontend/lib/shared/opd_actions/opd_action_context.dart` — `OpdActionContext`
  - `frontend/lib/shared/opd_actions/opd_provider_options.dart` — `dedupeOpdProviderOptions`, `opdProviderSelectOptions`
  - `frontend/lib/shared/opd_actions/opd_billing_state.dart` — `opdFlowBillingState`, `opdQueueBillingState`, `opdBillingStateFilterValue`, `opdBillingStateFromFilterValue`, `opdBillingTone`, `opdBillingStateLabel`, `opdFlowBillingDisplay`, `opdQueueBillingDisplay`
  - `frontend/lib/shared/opd_actions/opd_status_display.dart` — `opdStageDisplayLabel`, `opdStatusDisplayLabel`, `opdNextStepDisplayLabel`, `opdArrivalModeDisplayLabel`, `opdResponsibleRoleForStage`, `opdSummaryCountLabel`, `triageLevelDisplayLabel`, `opdUnknownProviderLabel`, `opdEncounterIcon`, `opdEncounterPermissionRequirement`, `opdFrontDeskActionRequirement`, `isOpdTerminalStatus` (re-export)
  - `frontend/lib/shared/opd_actions/opd_consultation_billing_breakdown.dart`
  - `frontend/lib/shared/opd_actions/opd_coverage_verification_panel.dart`
  - `frontend/lib/shared/opd_actions/opd_encounter_clinical_services.dart`
  - `frontend/lib/shared/components/opd_encounter_dialog.dart` — `OpdEncounterDialogResult`, `OpdRescheduleAppointmentDialog`, `OpdCancelAppointmentDialog`
- **Route definition:** `frontend/lib/app/router/app_routes.dart` line ~305: `AppRoutes.opd`, path `/opd`.
- **GoRoute registration:** `frontend/lib/app/router/app_router.dart` line ~173: builder passes `OpdWorkspaceQuery.fromUri(state.uri)`.
- **Tests:**
  - `frontend/test/features/opd/presentation/start_walk_in_dialog_test.dart`
  - `frontend/test/features/opd/presentation/opd_workspace_controller_test.dart`
  - `frontend/test/features/opd/opd_workspace_refresh_plan_test.dart`
  - `frontend/test/features/opd/domain/opd_workspace_query_test.dart`
  - `frontend/test/features/opd/domain/opd_consultation_billing_breakdown_test.dart`
  - `frontend/test/features/opd/data/dtos/opd_dtos_test.dart`
  - `frontend/test/shared/opd_actions/opd_provider_options_test.dart`
  - `frontend/test/shared/opd_actions/opd_action_context_test.dart`

### Current layout / structure

```
OpdWorkspacePage (ConsumerWidget)
 └─ AsyncStateScaffold<OpdWorkspaceState>
     └─ _OpdWorkspaceContent (ConsumerStatefulWidget)
         └─ AppWorkspace(title: l10n.opdTitle, leadingIcon: AppRouteIcons.opd)
             ├─ toolbar: appWorkspaceToolbarWithLabels(
             │   summaryNotifications: _opdBackendSummaryNotifications(counts),
             │   primary: AppAccessActionGate → AppButton.primary("Start walk-in"),
             │   onRefresh: ...,
             │   isRefreshing: ...,
             │ )
             └─ body: ValueListenableBuilder<_OpdTableFilter>
                 └─ ValueListenableBuilder<AppPageRequest>
                     └─ _OpdWorkspaceBody (StatefulWidget)
                         └─ _OpdMainTable (ConsumerWidget)
                             └─ SizedBox(width: double.infinity)
                                 └─ AppListTable<_OpdTableItem>(
                                     page: _tablePage(items, request),
                                     columns: [5 default columns from _OpdTableColumnId],
                                     columnChoices: [10 available columns],
                                     columnVisibilityStorageKey: 'opd.worklist',
                                     search: AppListTableSearch with field-specific search + advanced filters,
                                     mobileItemBuilder: _OpdTableMobileRow,
                                     rowColorBuilder: _opdTableRowColor,
                                     emptyBuilder: AppWorkspaceStatePanel.empty,
                                     ...)
```

### Data model

The OPD workspace merges four data sources into a single unified `_OpdTableItem` list:
1. **Triage queue** (`state.triageQueue.items`) — `OpdFlowSummary` items with category `_opdCategoryTriage`
2. **Active flows** (`state.flows.items`) — `OpdFlowSummary` items with category `_opdCategoryActiveFlow`
3. **Queue entries** (`state.queueEntries.items`) — `OpdQueueEntry` items with category `_opdCategoryQueue`
4. **Appointments** (`state.appointments.items`) — `OpdAppointment` items with category `_opdCategoryArrival`

Items are deduplicated (flows take priority over queue entries/appointments they link to) and sorted by urgency rank then time.

### Problems / inconsistencies vs. Reception reference

1. **No tab navigation** — flat single-worklist; no `AppTabStrip`. The data already has natural category-based segmentation (`_opdCategoryArrival`, `_opdCategoryQueue`, `_opdCategoryTriage`, `_opdCategoryActiveFlow`) but these are only used as filter values, not tabs.
2. **No URL-synced section state** — `OpdWorkspaceQuery.fromUri` parses `panel`, `search`, `flowId` but has no `section` parameter for tab routing. The `panel` parameter applies a filter, not a tab switch.
3. **No per-tab column customization** — all rows share the same 5 default columns + 10 available column choices regardless of category.
4. **Uses `AppWorkspace` wrapper** instead of direct `ResponsivePage` — the Reception workspace uses `ResponsivePage` → `Column` → `Row(AppTabStrip, AppButton)` → `AppListTable`. The OPD page wraps in `AppWorkspace` which adds its own header/toolbar chrome with summary notification cards.
5. **Column visibility key not per-section** — uses a single storage key `opd.worklist`, should be per-section like Reception's `reception_${_section.name}`.
6. **Summary notification cards unsurfaced as tab counts** — `OpdFlowAggregateCounts` has `allPatients`, `allOpdPatients`, `activeOpd`, `vitalsNeeded`, `doctorNeeded`, `withDoctor`, `labPending`, `imagingPending`, `pharmacyPending`, `decisionNeeded`, `admissionPending`, `dischargedToday` — some of these should appear as tab badge counts.
7. **Client-side pagination** — OPD does client-side pagination via `_tablePage()` after client-side filtering, unlike Reception which uses `items` directly. This should be preserved as-is since the tab filter is also client-side.

## Reference Implementation

Read these files to understand the target patterns (do NOT modify them):

| File | Key Pattern to Extract |
|------|----------------------|
| `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` | Full tabbed-workspace widget tree: `AsyncStateScaffold` → `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)` → `SizedBox(width: double.infinity)` → `Column(crossAxisAlignment: CrossAxisAlignment.stretch)` → `Row(Expanded(AppTabStrip), SizedBox(width: theme.spacing.sm), AppAccessActionGate(AppButton.primary))` → `SizedBox(height: theme.spacing.md)` → `AppListTable`. Tab enum iteration, `_sectionIcon()`, `_sectionLabel()`, `_sectionCount()`, `_columnsForSection()`, `_updateUrlForSection()`, search matcher, mobile item builder. |
| `frontend/lib/features/reception/domain/entities/reception_entities.dart` | `ReceptionDeskSection` enum + `ReceptionWorkspaceQuery` with `section` field and `fromUri` factory using multi-alias `pick()`. |
| `frontend/lib/shared/components/app_tab_strip.dart` | `AppTabStrip` constructor: `tabs` (`List<AppTabItem>`), `selectedId`, `onTabTapped`. `AppTabItem`: `id`, `icon`, `label`. |
| `frontend/lib/shared/components/app_list_table.dart` | `AppListTable<T>` constructor params: `page`/`items`, `columns`, `search`, `columnVisibilityController`, `columnVisibilityStorageKey`, `columnWidthStorageKey`, `columnVisibilityLabel`, `isLoading`, `shrinkWrap`, `physics`, `onRowSelected`, `itemKeyBuilder`, `mobileItemBuilder`, `emptyBuilder`, `pageLabelBuilder`, `onPageChanged`. |
| `frontend/lib/shared/layout/responsive_page.dart` | `ResponsivePage` with `maxWidth: PageMaxWidth.dataHeavy` (1440px). |
| `frontend/lib/core/responsive/app_breakpoints.dart` | `AppBreakpoints`, `AppBreakpoint` enum: xs (<360), sm (360-599), md (600-839), lg (840-1199), xl (1200-1599), xxl (1600+). `isMobile` = xs/sm. |

## Target Architecture

### Tab Configuration

| Tab Name | Section Enum Value | Route Query `?section=` | Description | Icon | Primary Action Button |
|----------|-------------------|------------------------|-------------|------|----------------------|
| All Worklist | `all` | (default — omitted from URL) | All OPD items combined: appointments, queue, triage, active flows — current flat worklist behavior | `Icons.dashboard_outlined` | Start Walk-in → `openOpdWorkspaceEncounterFlow` |
| Arrivals | `arrivals` | `arrivals` | Today's appointments (`_opdCategoryArrival`) | `Icons.event_outlined` | Start Walk-in → `openOpdWorkspaceEncounterFlow` |
| Queue | `queue` | `queue` | Visit queue entries (`_opdCategoryQueue`) | `Icons.queue_outlined` | Start Walk-in → `openOpdWorkspaceEncounterFlow` |
| Triage | `triage` | `triage` | Triage-stage flows (`_opdCategoryTriage`) | `Icons.monitor_heart_outlined` | Start Walk-in → `openOpdWorkspaceEncounterFlow` |
| Active Encounters | `active` | `active` | Active OPD flows (`_opdCategoryActiveFlow`) | `Icons.medical_services_outlined` | Start Walk-in → `openOpdWorkspaceEncounterFlow` |

Tab badge counts (from `OpdWorkspaceState` computed properties and `OpdFlowAggregateCounts`):

| Tab | Count Source |
|-----|-------------|
| All Worklist | total items in merged worklist (computed from `_tableItems()`) |
| Arrivals | `state.arrivalCount` |
| Queue | `state.queueCount` |
| Triage | `state.triageQueueCount` |
| Active Encounters | `state.activeFlowCount` (or `state.summaryCounts.activeOpd` when available) |

### Routing

**No changes to `app_routes.dart` or `app_router.dart` route definitions are needed.** The `/opd` GoRoute already passes `OpdWorkspaceQuery.fromUri(state.uri)` to the page. The only changes are:

1. **Add a `section` field to `OpdWorkspaceQuery`** — parse `?section=` from the URI in `fromUri`, adding `'section'` to the `pick` keys alongside existing `panel`/`stage`/`filter`/`queue`.
2. **Add an `OpdWorkspaceSection` enum** to `opd_entities.dart` — values: `all`, `arrivals`, `queue`, `triage`, `active`.
3. **URL update on tab change** — use `GoRouter.of(context).replace<void>(location)` with `AppRoutes.opd.location(queryParameters: {'section': sectionQueryValue})`, exactly like Reception's `_updateUrlForSection`.

### Page Layout

Target widget tree (mirrors Reception exactly):

```
OpdWorkspacePage (ConsumerWidget)
 └─ AsyncStateScaffold<OpdWorkspaceState>
     └─ _OpdWorkspaceContent (ConsumerStatefulWidget)
         └─ ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)
             └─ SizedBox(width: double.infinity)
                 └─ Column(crossAxisAlignment: CrossAxisAlignment.stretch)
                     ├─ Row
                     │   ├─ Expanded → AppTabStrip(tabs: [...], selectedId: _section.name, onTabTapped: ...)
                     │   ├─ SizedBox(width: theme.spacing.sm)
                     │   └─ AppAccessActionGate → AppButton.primary("Start walk-in")
                     ├─ SizedBox(height: theme.spacing.md)
                     └─ _OpdWorkspaceBody(
                            state: ...,
                            section: _section,
                            filter: _filterNotifier.value,
                            searchController: ...,
                            columnVisibilityController: ...,
                            pageRequest: ...,
                            onPageChanged: ...,
                            onFilterChanged: ...,
                        )
```

**Key differences from current layout:**
- Replace `AppWorkspace` wrapper with direct `ResponsivePage` → `Column` → `Row`.
- Add `AppTabStrip` inside the `Row`, before the primary action button (with `SizedBox(width: theme.spacing.sm)` between them, matching Reception).
- Spacing between tab row and table via `SizedBox(height: theme.spacing.md)` — matching Reception line 284.
- The summary notification cards from `_opdBackendSummaryNotifications` are removed from the toolbar — their count values become tab badge counts instead. The detailed summary cards (vitals needed, doctor needed, lab pending, etc.) are preserved by allowing the "Active Encounters" tab's advanced filter to further drill into these sub-stages.
- Per-tab column visibility persistence keys: `opd_${section.name}`.
- Per-tab column width persistence keys: `opd_cw_${section.name}`.
- The `onRefresh` callback moves to a refresh button integrated into the search bar or a standalone refresh icon button in the tab row, OR the existing pull-to-refresh / realtime sync continues to handle refresh without a visible button (since the Reception workspace does not have an explicit refresh button in its tab row — rely on realtime sync).

### Per-Tab Column Definitions

**All Worklist tab** — current 5 default columns:
`Patient Number`, `Patient Name`, `Queue/Status`, `Next Step`, `Provider`

**Arrivals tab** — appointment-focused columns (5):
`Patient Number`, `Patient Name`, `Visit Type`, `Arrival Time`, `Next Step`

**Queue tab** — queue-focused columns (5):
`Patient Number`, `Patient Name`, `Queue/Status`, `Provider`, `Next Step`

**Triage tab** — triage-focused columns (6):
`Patient Number`, `Patient Name`, `Queue/Status`, `Waiting Time`, `Provider`, `Next Step`

**Active Encounters tab** — flow-focused columns (6):
`Patient Number`, `Patient Name`, `Queue/Status`, `Next Step`, `Provider`, `Encounter`

All tabs use the same `_availableOpdTableColumns` for column visibility choices — users can toggle any column on any tab via the table settings button.

### Data & State Management

**No changes to the controller or repository are required.** The existing `OpdWorkspaceController` and its methods (`refresh`, `applySearch`, `startOpdEncounter`, etc.) already fetch all needed data. The `OpdWorkspaceState` stays as-is with its four data source pages.

The tab-switching logic should:
1. Map `OpdWorkspaceSection` to a client-side category filter on `_OpdTableItem.category`:
   - `all` → no category filter (show all items from the merged worklist)
   - `arrivals` → `item.category == _opdCategoryArrival`
   - `queue` → `item.category == _opdCategoryQueue`
   - `triage` → `item.category == _opdCategoryTriage`
   - `active` → `item.category == _opdCategoryActiveFlow`
2. Apply the category filter **before** the existing `_OpdTableFilter.matches()` — so advanced filters and search operate within the selected tab's data subset.
3. Reset pagination to first page on tab change.
4. Preserve the existing `_OpdTableFilter` (advanced search, field-specific search, date range, status, category, triage scope, visit type, queue, provider, billing, next action) — all these filters continue to work within the active tab.

The merged `_tableItems()` function continues to produce the full worklist. The tab simply filters by category before passing to `_OpdWorkspaceBody`.

## Implementation Steps

### 1. Add `OpdWorkspaceSection` enum — File: `frontend/lib/features/opd/domain/entities/opd_entities.dart`

Add the following enum **before** the `OpdWorkspaceQuery` class (before line 90):

```dart
enum OpdWorkspaceSection {
  all,
  arrivals,
  queue,
  triage,
  active,
}
```

### 2. Add `section` field to `OpdWorkspaceQuery` — File: `frontend/lib/features/opd/domain/entities/opd_entities.dart`

- Add `this.section = OpdWorkspaceSection.all` to the `OpdWorkspaceQuery` constructor parameter list.
- Add `final OpdWorkspaceSection section;` field.
- In `OpdWorkspaceQuery.fromUri`, add a section parser. Update the `return` statement to include:

```dart
section: _parseOpdSection(pick(<String>['section', 'tab'])),
```

Add a top-level helper function (before `OpdWorkspaceQuery`):

```dart
OpdWorkspaceSection _parseOpdSection(String raw) {
  return switch (raw.trim().toLowerCase()) {
    'arrivals' || 'appointments' => OpdWorkspaceSection.arrivals,
    'queue' || 'desk-queue' || 'desk_queue' => OpdWorkspaceSection.queue,
    'triage' => OpdWorkspaceSection.triage,
    'active' || 'active_flow' || 'encounters' || 'flows' => OpdWorkspaceSection.active,
    _ => OpdWorkspaceSection.all,
  };
}
```

- Update `hasRouteTargeting` to include non-default section:
```dart
bool get hasRouteTargeting =>
    section != OpdWorkspaceSection.all ||
    flowId.isNotEmpty ||
    panel.isNotEmpty ||
    search.isNotEmpty;
```

- Update `signature` to include section:
```dart
String get signature => '${section.name}|$flowId|$panel|$search';
```

### 3. Add section-to-category mapping — File: `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart`

Add these helper functions (as top-level functions or methods, matching the existing code style):

```dart
String? _opdSectionCategory(OpdWorkspaceSection section) {
  return switch (section) {
    OpdWorkspaceSection.all => null,
    OpdWorkspaceSection.arrivals => _opdCategoryArrival,
    OpdWorkspaceSection.queue => _opdCategoryQueue,
    OpdWorkspaceSection.triage => _opdCategoryTriage,
    OpdWorkspaceSection.active => _opdCategoryActiveFlow,
  };
}

IconData _opdSectionIcon(OpdWorkspaceSection section) {
  return switch (section) {
    OpdWorkspaceSection.all => Icons.dashboard_outlined,
    OpdWorkspaceSection.arrivals => Icons.event_outlined,
    OpdWorkspaceSection.queue => Icons.queue_outlined,
    OpdWorkspaceSection.triage => Icons.monitor_heart_outlined,
    OpdWorkspaceSection.active => Icons.medical_services_outlined,
  };
}

String _opdSectionLabel(AppLocalizations l10n, OpdWorkspaceSection section) {
  return switch (section) {
    OpdWorkspaceSection.all => l10n.opdSectionAllLabel,
    OpdWorkspaceSection.arrivals => l10n.opdSectionArrivalsLabel,
    OpdWorkspaceSection.queue => l10n.opdSectionQueueLabel,
    OpdWorkspaceSection.triage => l10n.opdSectionTriageLabel,
    OpdWorkspaceSection.active => l10n.opdSectionActiveLabel,
  };
}

int _opdSectionCount(OpdWorkspaceState state, OpdWorkspaceSection section, List<_OpdTableItem> allItems) {
  return switch (section) {
    OpdWorkspaceSection.all => allItems.length,
    OpdWorkspaceSection.arrivals => state.arrivalCount,
    OpdWorkspaceSection.queue => state.queueCount,
    OpdWorkspaceSection.triage => state.triageQueueCount,
    OpdWorkspaceSection.active => state.summaryCounts.activeOpd > 0
        ? state.summaryCounts.activeOpd
        : state.activeFlowCount,
  };
}

String _opdSectionQueryValue(OpdWorkspaceSection section) {
  return switch (section) {
    OpdWorkspaceSection.all => '',
    OpdWorkspaceSection.arrivals => 'arrivals',
    OpdWorkspaceSection.queue => 'queue',
    OpdWorkspaceSection.triage => 'triage',
    OpdWorkspaceSection.active => 'active',
  };
}

List<_OpdTableColumnId> _opdDefaultColumnsForSection(OpdWorkspaceSection section) {
  return switch (section) {
    OpdWorkspaceSection.all => _defaultOpdTableColumns,
    OpdWorkspaceSection.arrivals => const <_OpdTableColumnId>[
      _OpdTableColumnId.patientNumber,
      _OpdTableColumnId.patientName,
      _OpdTableColumnId.visitType,
      _OpdTableColumnId.arrivalTime,
      _OpdTableColumnId.nextStep,
    ],
    OpdWorkspaceSection.queue => const <_OpdTableColumnId>[
      _OpdTableColumnId.patientNumber,
      _OpdTableColumnId.patientName,
      _OpdTableColumnId.queueStatus,
      _OpdTableColumnId.provider,
      _OpdTableColumnId.nextStep,
    ],
    OpdWorkspaceSection.triage => const <_OpdTableColumnId>[
      _OpdTableColumnId.patientNumber,
      _OpdTableColumnId.patientName,
      _OpdTableColumnId.queueStatus,
      _OpdTableColumnId.waitingTime,
      _OpdTableColumnId.provider,
      _OpdTableColumnId.nextStep,
    ],
    OpdWorkspaceSection.active => const <_OpdTableColumnId>[
      _OpdTableColumnId.patientNumber,
      _OpdTableColumnId.patientName,
      _OpdTableColumnId.queueStatus,
      _OpdTableColumnId.nextStep,
      _OpdTableColumnId.provider,
      _OpdTableColumnId.encounter,
    ],
  };
}
```

### 4. Update imports in `opd_workspace_page.dart` — File: `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart`

Add these imports (if not already present):
```dart
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
```

The `AppTabStrip` and `AppTabItem` are already exported via `package:hosspi_hms/shared/components/components.dart` which is already imported. `ResponsivePage` and `PageMaxWidth` are already exported via `package:hosspi_hms/shared/layout/layout.dart` which is already imported.

### 5. Add section state and URL helpers to `_OpdWorkspaceContentState` — File: `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart`

#### 5a. Add state field

Add to `_OpdWorkspaceContentState`:
```dart
late OpdWorkspaceSection _section;
```

#### 5b. Initialize in `initState`

After the existing `_tableColumnController` initialization, add:
```dart
_section = widget.initialQuery?.section ?? OpdWorkspaceSection.all;
```

#### 5c. Add URL update method (follows Reception pattern exactly)

```dart
void _updateUrlForSection(OpdWorkspaceSection section) {
  if (!mounted) {
    return;
  }
  final String tab = _opdSectionQueryValue(section);
  final String location = AppRoutes.opd.location(
    queryParameters: <String, String>{
      if (tab.isNotEmpty) 'section': tab,
    },
  );
  GoRouter.of(context).replace<void>(location);
}
```

#### 5d. Update `_applyRouteQuery` to handle section from deep-link

In the existing `_applyRouteQuery` method, add section handling at the beginning:

```dart
Future<void> _applyRouteQuery(OpdWorkspaceQuery query) async {
  if (query.section != OpdWorkspaceSection.all && query.section != _section) {
    setState(() => _section = query.section);
  }
  if (query.search.isNotEmpty) {
    _searchController.text = query.search;
  }
  if (query.search.isNotEmpty || query.panel.isNotEmpty) {
    final _OpdTableFilter panelFilter = _opdFilterForPanel(query.panel);
    _setFilter(panelFilter.copyWith(search: query.search));
  }
  if (query.flowId.isNotEmpty) {
    await _openFlowById(query.flowId);
  }
}
```

#### 5e. Add tab change handler

```dart
void _handleTabChanged(OpdWorkspaceSection section) {
  if (section == _section) {
    return;
  }
  setState(() => _section = section);
  _updateUrlForSection(section);
  _setFilter(const _OpdTableFilter());
  _searchController.clear();
}
```

### 6. Replace the `build` method of `_OpdWorkspaceContentState` — File: `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart`

Replace the current `build` method (lines ~109-175) with:

```dart
@override
Widget build(BuildContext context) {
  final l10n = context.l10n;
  final ThemeData theme = Theme.of(context);
  final OpdWorkspaceState state = widget.state;
  final OpdWorkspaceController controller = ref.read(
    opdWorkspaceControllerProvider.notifier,
  );

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
                child: ValueListenableBuilder<_OpdTableFilter>(
                  valueListenable: _filterNotifier,
                  builder: (BuildContext context, _OpdTableFilter filter, _) {
                    return AppTabStrip(
                      tabs: <AppTabItem>[
                        for (final OpdWorkspaceSection section
                            in OpdWorkspaceSection.values)
                          AppTabItem(
                            id: section.name,
                            icon: _opdSectionIcon(section),
                            label:
                                '${_opdSectionLabel(l10n, section)} (${_opdSectionCount(state, section, _cachedAllItems(context))})',
                          ),
                      ],
                      selectedId: _section.name,
                      onTabTapped: (String tabId) {
                        for (final OpdWorkspaceSection section
                            in OpdWorkspaceSection.values) {
                          if (section.name == tabId) {
                            _handleTabChanged(section);
                            break;
                          }
                        }
                      },
                    );
                  },
                ),
              ),
              SizedBox(width: theme.spacing.sm),
              AppAccessActionGate(
                requirement: opdEncounterPermissionRequirement,
                builder: (BuildContext context, bool isAllowed) {
                  return AppButton.primary(
                    label: l10n.opdStartWalkInAction,
                    leadingIcon: opdEncounterIcon,
                    semanticLabel: l10n.opdStartWalkInAction,
                    tooltip: l10n.opdStartEncounterTooltip,
                    enabled: isAllowed,
                    onPressed: () {
                      unawaited(
                        openOpdWorkspaceEncounterFlow(context, ref, widget.state),
                      );
                    },
                  );
                },
              ),
            ],
          ),
          SizedBox(height: theme.spacing.md),
          ValueListenableBuilder<_OpdTableFilter>(
            valueListenable: _filterNotifier,
            builder: (BuildContext context, _OpdTableFilter filter, _) {
              return ValueListenableBuilder<AppPageRequest>(
                valueListenable: _tablePageNotifier,
                builder:
                    (BuildContext context, AppPageRequest tablePageRequest, _) {
                      return _OpdWorkspaceBody(
                        state: state,
                        section: _section,
                        filter: filter,
                        searchController: _searchController,
                        columnVisibilityController: _tableColumnController,
                        pageRequest: tablePageRequest,
                        onPageChanged: _setTablePage,
                        onFilterChanged: _setFilter,
                      );
                    },
              );
            },
          ),
        ],
      ),
    ),
  );
}
```

Add a helper method to `_OpdWorkspaceContentState` for computing the full item list for tab counts:

```dart
List<_OpdTableItem> _cachedAllItems(BuildContext context) {
  return _tableItems(context, widget.state);
}
```

**Important notes:**
- The `AppWorkspace` wrapper, `appWorkspaceToolbarWithLabels`, `_opdBackendSummaryNotifications`, `onRefresh` callback, and `AppRouteIcons.opd` reference are all removed from the `build` method.
- `theme.spacing.sm` and `theme.spacing.md` are the same accessors used in `reception_workspace_page.dart` lines 268 and 284.
- The refresh is now handled purely by realtime sync (already wired in the controller). Users can pull-to-refresh in the parent shell scaffold.

### 7. Update `_OpdWorkspaceBody` widget — File: `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart`

#### 7a. Add `section` parameter

Update the constructor and field:

```dart
class _OpdWorkspaceBody extends StatefulWidget {
  const _OpdWorkspaceBody({
    required this.state,
    required this.section,
    required this.filter,
    required this.searchController,
    required this.columnVisibilityController,
    required this.pageRequest,
    required this.onPageChanged,
    required this.onFilterChanged,
  });

  final OpdWorkspaceState state;
  final OpdWorkspaceSection section;
  final _OpdTableFilter filter;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<_OpdTableItem>
  columnVisibilityController;
  final AppPageRequest pageRequest;
  final ValueChanged<AppPageRequest> onPageChanged;
  final ValueChanged<_OpdTableFilter> onFilterChanged;
```

#### 7b. Update `_OpdWorkspaceBodyState.build` to filter by section

In the `build` method, apply the section filter **before** the existing `_OpdTableFilter.matches()`:

```dart
@override
Widget build(BuildContext context) {
  final List<_OpdTableItem> allItems = _getAllItems(context);
  final String? sectionCategory = _opdSectionCategory(widget.section);
  final List<_OpdTableItem> sectionItems = sectionCategory == null
      ? allItems
      : allItems
          .where((_OpdTableItem item) => item.category == sectionCategory)
          .toList(growable: false);
  final List<_OpdTableItem> items = sectionItems
      .where((_OpdTableItem item) => widget.filter.matches(item))
      .toList(growable: false);

  return _OpdMainTable(
    state: widget.state,
    section: widget.section,
    page: _tablePage(items, widget.pageRequest),
    searchController: widget.searchController,
    columnVisibilityController: widget.columnVisibilityController,
    filter: widget.filter,
    filterItems: sectionItems,
    statuses: _tableStatuses(sectionItems),
    onPageChanged: widget.onPageChanged,
    onFilterChanged: widget.onFilterChanged,
    isLoading:
        widget.state.isRefreshingAppointments ||
        widget.state.isRefreshingQueue ||
        widget.state.isRefreshingFlows ||
        widget.state.isRefreshingTriageQueue,
  );
}
```

Note: `filterItems` and `statuses` now derive from `sectionItems` (filtered by tab) rather than `allItems`, so the filter dropdowns only show choices relevant to the current tab.

### 8. Update `_OpdMainTable` widget — File: `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart`

#### 8a. Add `section` parameter

Add `required this.section` to `_OpdMainTable` constructor and `final OpdWorkspaceSection section;` field.

#### 8b. Update `build` to use per-section columns and keys

In the `build` method:

Replace the hardcoded `columns` with per-section defaults:

```dart
columns: <AppListTableColumn<_OpdTableItem>>[
  for (final _OpdTableColumnId column in _opdDefaultColumnsForSection(section))
    _opdDataColumn(context, column),
],
```

Replace the `columnVisibilityStorageKey` with per-section key:

```dart
columnVisibilityStorageKey: 'opd_${section.name}',
columnWidthStorageKey: 'opd_cw_${section.name}',
```

Keep the existing `columnChoices` list as-is (all 10 available columns for all tabs).

### 9. Add localization strings — File: `frontend/lib/l10n/app_en.arb`

Find the OPD section of `app_en.arb` (near where `"opdTitle"` is defined) and add these entries:

```json
"opdSectionAllLabel": "All worklist",
"@opdSectionAllLabel": {
  "description": "Tab label for showing all OPD worklist items"
},
"opdSectionArrivalsLabel": "Arrivals",
"@opdSectionArrivalsLabel": {
  "description": "Tab label for showing appointment arrivals"
},
"opdSectionQueueLabel": "Queue",
"@opdSectionQueueLabel": {
  "description": "Tab label for showing visit queue entries"
},
"opdSectionTriageLabel": "Triage",
"@opdSectionTriageLabel": {
  "description": "Tab label for showing triage queue flows"
},
"opdSectionActiveLabel": "Active",
"@opdSectionActiveLabel": {
  "description": "Tab label for showing active OPD encounters"
},
```

After adding the ARB entries, regenerate localizations:

```bash
cd frontend && flutter gen-l10n
```

If the project uses a different localization generation command, check the project's `l10n.yaml` or `pubspec.yaml` for the correct command and run that instead.

### 10. Update `_OpdWorkspaceContentState.initState` to initialize `_tableColumnController` with per-section key

The current `_tableColumnController` is initialized once with `storageKey: 'opd.worklist'`. Since per-section keys are now passed via `columnVisibilityStorageKey` on the `AppListTable`, the controller initialization can use a generic key. However, check if `AppListTableColumnVisibilityController` uses its `storageKey` constructor arg or the table's `columnVisibilityStorageKey`. If the controller's `storageKey` is used for persistence, update it to not conflict. The simplest approach: keep the controller initialized without a storage key (or with a generic `'opd'` key), and rely on the table's `columnVisibilityStorageKey` for per-section persistence.

## Shared Components — MUST Reuse

Do NOT create new implementations of these. Import and use them directly:

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` | `package:hosspi_hms/shared/components/components.dart` (via barrel) | Tab bar above the table. Constructor: `AppTabStrip(tabs: [...], selectedId: ..., onTabTapped: ...)` |
| `AppTabItem` | `package:hosspi_hms/shared/components/components.dart` (via barrel) | Tab definition: `AppTabItem(id: ..., icon: ..., label: ...)` |
| `AppListTable<_OpdTableItem>` | `package:hosspi_hms/shared/components/components.dart` (via barrel) | Data table — already in use, keep using it with per-section columns |
| `AppListTableSearch<_OpdTableItem>` | `package:hosspi_hms/shared/components/components.dart` (via barrel) | Search bar config — already in use, preserve all existing search behavior including field-specific search and advanced filters |
| `AppListTableColumnVisibilityController<_OpdTableItem>` | `package:hosspi_hms/shared/components/components.dart` (via barrel) | Column visibility — already in use, update storage keys to be per-section |
| `AppButton.primary` | `package:hosspi_hms/shared/components/components.dart` (via barrel) | Primary action button — already in use |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Permission gate — already in use |
| `AsyncStateScaffold<OpdWorkspaceState>` | `package:hosspi_hms/shared/components/components.dart` (via barrel) | Async state wrapper — already in use |
| `ResponsivePage` | `package:hosspi_hms/shared/layout/layout.dart` (via barrel) | Page layout with `maxWidth: PageMaxWidth.dataHeavy` |
| `AppWorkspaceStatePanel.empty` | `package:hosspi_hms/shared/layout/layout.dart` (via barrel) | Empty state — already in use in table `emptyBuilder` |
| `WorkflowActionButton` | `package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart` | Workflow action button in Next Step column — already in use |
| `FlowActionsDialog` | `package:hosspi_hms/shared/opd_actions/opd_actions.dart` | Flow actions dialog — already in use |
| `openOpdWorkspaceEncounterFlow` | `package:hosspi_hms/shared/opd_actions/opd_actions.dart` | Walk-in encounter flow — already in use |
| `GoRouter` | `package:go_router/go_router.dart` | URL replacement for tab sync — new import |
| `AppRoutes` | `package:hosspi_hms/app/router/app_routes.dart` | Route constants for URL generation — new import |

## Files to Create

No new files need to be created. All changes are modifications to existing files.

## Files to Modify

| File Path | Changes |
|-----------|---------|
| `frontend/lib/features/opd/domain/entities/opd_entities.dart` | Add `OpdWorkspaceSection` enum, `_parseOpdSection` helper, `section` field to `OpdWorkspaceQuery`, update `fromUri`, `hasRouteTargeting`, `signature` |
| `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart` | Replace `AppWorkspace` with `ResponsivePage` → `Column` → `Row(AppTabStrip, AppButton.primary)` → body. Add `_section` state, `_handleTabChanged`, `_updateUrlForSection`, `_opdSectionIcon`, `_opdSectionLabel`, `_opdSectionCount`, `_opdSectionCategory`, `_opdSectionQueryValue`, `_opdDefaultColumnsForSection`. Update `_OpdWorkspaceBody` to accept `section` param and filter items by section category. Update `_OpdMainTable` to accept `section` with per-section columns and storage keys. Update `_applyRouteQuery` to handle section deep-link. Remove `AppWorkspace` wrapper, `appWorkspaceToolbarWithLabels`, `_opdBackendSummaryNotifications`. Add `go_router` and `app_routes` imports. |
| `frontend/lib/l10n/app_en.arb` | Add `opdSectionAllLabel`, `opdSectionArrivalsLabel`, `opdSectionQueueLabel`, `opdSectionTriageLabel`, `opdSectionActiveLabel` localization strings with `@` metadata |

## Files to Delete (if any)

No files need to be deleted. The refactor restructures the UI within existing files.

## Cleanup: Remove Stale Code

After the refactor, the agent MUST remove all dead/stale code left behind:

- [ ] Remove the `AppWorkspace` wrapper usage from `_OpdWorkspaceContentState.build` — replaced by `ResponsivePage` → `Column` → `Row`.
- [ ] Remove `appWorkspaceToolbarWithLabels` call — it was used to wrap the primary action button + summary cards in `AppWorkspace.toolbar`.
- [ ] Remove `_opdBackendSummaryNotifications` method — the summary notification cards are superseded by tab badge counts. (Keep the `OpdFlowAggregateCounts` data — it powers the tab counts.)
- [ ] Remove `_applySummaryFilter` method — it was used by summary notification card `onSelected` callbacks, which are removed.
- [ ] Remove `AppRouteIcons.opd` reference — it was used as `AppWorkspace.leadingIcon`. If this is the only reference in the file, also remove `import 'package:hosspi_hms/app/router/app_route_icons.dart';`. (Check `AppRouteIcons.opd` is not used elsewhere in the file first.)
- [ ] Remove unused imports across all modified files.
- [ ] Run `dart analyze` to catch any remaining unreferenced declarations and remove them.
- [ ] Verify no test files reference deleted code — update or remove stale tests.

List every file and symbol removed in a "Cleanup Summary" section at the end of the implementation.

## Database Migrations

No database migrations required — schema unchanged. The refactor only restructures the Flutter UI layer. The `OpdWorkspaceController` already fetches all needed data (appointments, queue entries, flows, triage queue, summary counts) via the existing API endpoints. No new columns, tables, or indexes are needed.

## Responsive Design Requirements

- **Desktop (≥840px / `lg`+):** Full data table with all per-tab columns visible, `AppTabStrip` and primary action button ("Start walk-in") in a horizontal `Row`, column resize handles enabled, column visibility settings button in search bar, row coloring by category preserved.
- **Tablet (600–839px / `md`):** Same table layout — `AppListTable` renders as table at this breakpoint. Tab labels may truncate. Action button may collapse to icon-only via `AppActionLabelScope` (inherited from the shell scaffold).
- **Mobile (<600px / `xs`/`sm`):** `AppListTable` automatically switches to `mobileItemBuilder` rendering each row via `_OpdTableMobileRow` → `AppListItemRow`. `AppTabStrip` wraps to multiple lines. Primary action button remains accessible.

Use `AppBreakpoints` from `package:hosspi_hms/core/responsive/app_breakpoints.dart` for any breakpoint-dependent logic. The existing `AppListTable` already handles the table/list switch — no manual breakpoint logic needed for the table itself.

## Verification Steps

After implementation, the agent MUST run these commands and confirm they pass:

```bash
# Regenerate localizations
cd frontend && flutter gen-l10n

# Format
dart format frontend/lib/features/opd/ frontend/lib/app/router/ frontend/lib/l10n/

# Analyze
dart analyze frontend/ --fatal-infos

# Run tests related to this screen
flutter test test/features/opd/

# Run shared component tests to ensure no regressions
flutter test test/shared/
```

## Testing Requirements

Write or update these tests:

- [ ] Tab navigation: switching tabs filters the worklist to the correct category (`_opdCategoryArrival`, `_opdCategoryQueue`, `_opdCategoryTriage`, `_opdCategoryActiveFlow`, or all)
- [ ] Tab navigation: switching tabs updates the URL query parameter `?section=` via `GoRouter.replace`
- [ ] Deep linking: constructing an `OpdWorkspaceQuery.fromUri` with `?section=triage` produces `OpdWorkspaceSection.triage`
- [ ] Deep linking: constructing an `OpdWorkspaceQuery.fromUri` with `?section=active` produces `OpdWorkspaceSection.active`
- [ ] Tab counts: badge counts on tabs match `arrivalCount`, `queueCount`, `triageQueueCount`, `activeFlowCount` from `OpdWorkspaceState`
- [ ] Per-tab columns: verify default column set differs per section (5 for all/arrivals/queue, 6 for triage/active)
- [ ] Advanced filters preserved: typing in the search bar filters within the active tab's data subset
- [ ] Advanced filter dialog: filter button opens the filter UI with choices scoped to the current tab's items
- [ ] Field-specific search: selecting a search field and searching works within the tab
- [ ] Primary action: "Start walk-in" button is present on all tabs and opens `openOpdWorkspaceEncounterFlow`
- [ ] Row coloring: `_opdTableRowColor` continues to color rows by category
- [ ] Row click: clicking a row opens `_OpdPatientActionsDialog` (or `FlowActionsDialog` for flows)
- [ ] Mobile layout: widget tests verify `mobileItemBuilder` renders `_OpdTableMobileRow` at mobile breakpoint
- [ ] Existing deep-link: `?panel=vitals` still applies the correct filter within the active tab
- [ ] Existing deep-link: `?id=<flowId>` still opens the flow actions dialog
- [ ] No regressions: all existing OPD workspace tests pass

## Acceptance Criteria

The refactor is complete when ALL of the following are true:

- [ ] The screen uses routable `AppTabStrip` tabs matching the Reception workspace pattern, with 5 tabs: All Worklist, Arrivals, Queue, Triage, Active Encounters
- [ ] Each tab has its own URL via `?section=` that supports deep linking
- [ ] Tab badge counts display the correct count for each data source (arrival, queue, triage, active flow counts)
- [ ] The primary action button ("Start walk-in") is positioned correctly beside the tab strip in a `Row`, wrapped in `AppAccessActionGate`
- [ ] The page body uses `AppListTable<_OpdTableItem>` with per-section default columns, all 10 column choices available via settings, integrated field-specific search, advanced filter, and column visibility settings (per-section persistence keys `opd_${section.name}`)
- [ ] The layout uses `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)` directly instead of `AppWorkspace`
- [ ] Spacing between elements matches Reception: `theme.spacing.sm` between tab strip and button, `theme.spacing.md` between tab row and table
- [ ] Tab switching filters the merged worklist by category (arrivals, queue, triage, active flow) client-side without additional API calls
- [ ] No shared component is re-implemented — only imported and used
- [ ] The layout is fully responsive across mobile, tablet, and desktop
- [ ] All old/duplicate layout code is removed — no stale `AppWorkspace` wrapper, no `appWorkspaceToolbarWithLabels` call, no `_opdBackendSummaryNotifications` method remains
- [ ] Domain-specific business logic is preserved: client-side filtering, advanced search with field-specific search, category-based row coloring, urgency-based sorting, deduplication logic, encounter/queue/appointment actions, deep-linking via `?panel=` and `?id=`, realtime sync, adaptive polling
- [ ] No database migrations required — schema unchanged (explicitly confirmed)
- [ ] `dart analyze` reports no new issues — zero unused imports, zero unreferenced declarations
- [ ] All tests pass (no stale test references to removed code)
- [ ] New localization strings are added for tab labels and localizations are regenerated
