# Standardize Clinical Workspace Screen

## Objective

Refactor the Clinical workspace screen (`/clinical`) to match the standardized tab-and-table layout used by the Reception workspace. The screen currently renders a flat, single-worklist view inside an `AppWorkspace` wrapper with toolbar summary notification cards (All active work, Waiting review, Urgent, Results ready, In consultation) and secondary toolbar action buttons (Add note, Request lab, Prescribe, Request radiology). After this refactor it will use routable `AppTabStrip` tabs (All, Waiting Review, Urgent, Results Ready, In Consultation, Completed) with URL-synced section state via `?section=` query parameter, per-tab column configurations, per-tab column visibility persistence keys, and the canonical `ResponsivePage` → `Column` → `Row(AppTabStrip, AppButton.primary)` → `AppListTable` widget tree — exactly mirroring the Reception workspace pattern. All existing business logic (server-side pagination, field-specific search, advanced filters with scope/source/status/provider/encounter-type/location, encounter detail dialog, clinical action dialogs, triage handoff panel, results preview, consultation summary printing, realtime sync, urgency-based row coloring, deep-linking via `?encounterId=` and `?panel=` and `?search=`, `ClinicalQueueScope` filtering) must be preserved.

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification — all information needed is in this prompt. Run formatting and analysis after implementation.

## Current State (from audit)

### Files

- **Main page file:** `frontend/lib/features/clinical/presentation/pages/clinical_workspace_page.dart` — ~3178 lines. Contains `ClinicalWorkspacePage`, `_ClinicalWorkspaceContent`, `_ClinicalWorkspaceContentState`, `_ClinicalWorklistPanel`, `_ClinicalEncounterDialog`, `_ClinicalDetailPanel`, `_ClinicalEncounterContextPanel`, `_ClinicalTriageHandoffPanel`, `_ClinicalActionBar`, `_ClinicalRecordSections`, `_ClinicalQueueCell`, `_ClinicalStatusCell`, `_ClinicalStatusText`, `_ClinicalPatientCell`, `_ClinicalInfoGrid`, `_ClinicalVitalsGrid`, `_ClinicalVitalSummary`, `_ClinicalAlertsWrap`, plus ~50 helper functions for columns, filters, formatting, dialogs, and printing.
- **Controller:** `frontend/lib/features/clinical/presentation/controllers/clinical_workspace_controller.dart` — `ClinicalWorkspaceController` (`AsyncNotifier<Result<ClinicalWorkspaceState>>`), provider: `clinicalWorkspaceControllerProvider`. ~1809 lines. Methods: `refresh`, `applySearch`, `applyScope`, `applyWorklistFilters`, `changePage`, `selectEntry`, `clearSelection`, `clearRealtimeNotice`, `createClinicalNote`, `createDiagnosis`, `createProcedure`, `createCarePlan`, `createLabOrder`, `updateLabOrder`, `cancelLabOrder`, `deleteLabOrder`, `createRadiologyOrder`, `updateRadiologyOrder`, `cancelRadiologyOrder`, `deleteRadiologyOrder`, `createPharmacyOrder`, `updatePharmacyOrder`, `cancelPharmacyOrder`, `deletePharmacyOrder`, `createReferral`, `createFollowUp`, `createAdmission`, `dischargeAdmission`, `completeEncounter`.
- **Encounter detail panels:** `frontend/lib/features/clinical/presentation/widgets/clinical_encounter_detail_panels.dart` — `ClinicalWorkflowProgressStrip`, `ClinicalLabOrdersTablePanel`, `ClinicalRadiologyOrdersTablePanel`, `ClinicalActionsPanel`, `ClinicalActionItem`, `ClinicalActionKind`, `sortClinicalRecordsNewestFirst`, `clinicalEncounterWriteRequirement`. ~1066 lines.
- **Entities:** `frontend/lib/features/clinical/domain/entities/clinical_entities.dart` — `ClinicalWorkspaceQuery`, `ClinicalQueueScope`, `ClinicalWorklistQuery`, `ClinicalWorklistFilters`, `ClinicalWorklistEntry`, `ClinicalRelatedRecord`, `ClinicalLabOrderItem`, `ClinicalRadiologyOrderItem`, `ClinicalPharmacyOrderItem`, `ClinicalVitalSummary`, `ClinicalAlertSummary`, `ClinicalWorkflowTimelineItem`, `ClinicalTriageHandoff`, `ClinicalEncounterBundle`, `ClinicalWorkspaceState`, `clinicalWorklistEntryMatchesScope`, `deduplicateClinicalWorklistEntries`. ~1227 lines.
- **Repository interface:** `frontend/lib/features/clinical/domain/repositories/clinical_repository.dart` — `ClinicalRepository` (abstract interface). ~99 lines.
- **Repository impl:** `frontend/lib/features/clinical/data/repositories/clinical_repository_impl.dart` — `ClinicalRepositoryImpl`, provider: `clinicalRepositoryProvider`.
- **DTOs:** `frontend/lib/features/clinical/data/dtos/clinical_dtos.dart`
- **Shared clinical actions:**
  - `frontend/lib/shared/clinical_actions/clinical_actions.dart` — barrel export
  - `frontend/lib/shared/clinical_actions/clinical_action_models.dart` — `ClinicalActionCatalogOption`, `ClinicalActionRadiologyRequest`, `ClinicalActionReferenceData`, `ClinicalRequestPatientContext`
  - Various dialog files in `frontend/lib/shared/clinical_actions/`
- **Route definition:** `frontend/lib/app/router/app_routes.dart` line ~383: `AppRoutes.clinical`, path `/clinical`.
- **GoRoute registration:** `frontend/lib/app/router/app_router.dart` line ~234: builder passes `ClinicalWorkspaceQuery.fromUri(state.uri)`.
- **Tests:**
  - `frontend/test/features/clinical/presentation/clinical_workspace_page_test.dart`
  - `frontend/test/features/clinical/presentation/clinical_workspace_controller_test.dart`
  - `frontend/test/features/clinical/domain/clinical_entities_test.dart`
  - `frontend/test/features/clinical/data/clinical_dtos_test.dart`

### Current layout / structure

```
ClinicalWorkspacePage (ConsumerWidget)
 └─ AsyncStateScaffold<ClinicalWorkspaceState>
     └─ _ClinicalWorkspaceContent (ConsumerStatefulWidget)
         └─ AppWorkspace(title: l10n.clinicalTitle, leadingIcon: AppRouteIcons.clinical)
             ├─ toolbar: appWorkspaceToolbarWithLabels(
             │   summaryNotifications: [All active work, Waiting review, Urgent, Results ready, In consultation],
             │   secondary: [Add note, Request lab, Prescribe, Request radiology] (context-sensitive toolbar buttons),
             │   onRefresh: ...,
             │   isRefreshing: ...,
             │ )
             └─ body: _ClinicalWorklistPanel (ConsumerWidget)
                 └─ AppListTable<ClinicalWorklistEntry>(
                     page: state.worklist,
                     columns: [5 default columns: patient, queue, statusStep, provider, lastUpdated],
                     columnChoices: [12 available columns],
                     columnVisibilityStorageKey: 'clinical.worklist',
                     search: AppListTableSearch with field-specific search + advanced filters + scope filter,
                     mobileItemBuilder: _clinicalWorklistMobileItemBuilder,
                     rowColorBuilder: _clinicalRowColor,
                     emptyBuilder: AppWorkspaceStatePanel.state(empty),
                     onRowSelected: _openClinicalEntryDialog → encounter detail dialog,
                     ...)
```

### Data model

The Clinical workspace fetches data server-side via `ClinicalWorkspaceController`:
1. **Encounters** from `ClinicalRepository.listEncounters()` — OPD and standalone encounters
2. **Admissions** from `ClinicalRepository.listAdmissions()` — IPD admissions

These are merged via `deduplicateClinicalWorklistEntries()` and stored in `ClinicalWorkspaceState.worklist` as an `AppPage<ClinicalWorklistEntry>`.

The `ClinicalQueueScope` enum (`all`, `today`, `urgent`, `waitingReview`, `inConsultation`, `resultsReady`, `completed`) drives server-side scope filtering via `ClinicalWorkspaceController.applyScope()`.

State counts available from `ClinicalWorkspaceState`:
- `waitingReviewCount` — items matching review state
- `urgentCount` — items marked urgent
- `resultsReadyCount` — items with results ready
- `inConsultationCount` — items in consultation state
- `completedCount` — terminal items
- `workloadCount` — unique items needing clinical action

### Problems / inconsistencies vs. Reception reference

1. **No tab navigation** — flat single-worklist; no `AppTabStrip`. The scope system (`ClinicalQueueScope`) filters the data but only via the advanced filter dialog or summary notification card clicks — not via visual tabs.
2. **No URL-synced section state** — `ClinicalWorkspaceQuery.fromUri` parses `encounterId`, `panel`, `search` but has no `section` parameter for tab routing. The `panel` param maps to scope via `_applyRouteQuery` but doesn't set a tab.
3. **No per-tab column customization** — all rows share the same 5 default columns + 12 available column choices regardless of scope.
4. **Uses `AppWorkspace` wrapper** instead of direct `ResponsivePage` — the Reception workspace uses `ResponsivePage` → `Column` → `Row(AppTabStrip, AppButton)` → `AppListTable`. The Clinical page wraps in `AppWorkspace` which adds its own header/toolbar chrome with summary notification cards and secondary toolbar buttons.
5. **Column visibility key not per-section** — uses a single storage key `clinical.worklist`, should be per-section like Reception's `reception_${_section.name}`.
6. **Summary notification cards unsurfaced as tab counts** — `ClinicalWorkspaceState` has `waitingReviewCount`, `urgentCount`, `resultsReadyCount`, `inConsultationCount`, `completedCount` — these should appear as tab badge counts.
7. **Secondary toolbar buttons are context-sensitive** — Add Note, Request Lab, Prescribe, Request Radiology require a selected encounter. These buttons must move to the encounter detail dialog (they're already duplicated there in `_ClinicalActionBar`), and the primary action in the tab row should be a single "Select Patient" or contextual action.
8. **Server-side scope filtering** — Unlike OPD (client-side), Clinical uses `ClinicalQueueScope` via `controller.applyScope()` which triggers a server-side re-fetch. Tab switching must trigger `applyScope()` rather than client-side filtering.

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

| Tab Name | Section Enum Value | Route Query `?section=` | Description | Icon | Badge Count Source | Primary Action Button |
|----------|-------------------|------------------------|-------------|------|-------------------|----------------------|
| All | `all` | (default — omitted from URL) | All encounters — current flat worklist behavior, scope = `ClinicalQueueScope.all` | `Icons.inventory_2_outlined` | `_pageTotal(state.worklist)` | — (no primary button; clinical actions are encounter-contextual) |
| Waiting Review | `waitingReview` | `waiting-review` | Encounters waiting doctor review, scope = `ClinicalQueueScope.waitingReview` | `Icons.rate_review_outlined` | `state.waitingReviewCount` | — |
| Urgent | `urgent` | `urgent` | Urgent encounters, scope = `ClinicalQueueScope.urgent` | `Icons.priority_high_outlined` | `state.urgentCount` | — |
| Results Ready | `resultsReady` | `results-ready` | Encounters with lab/radiology results ready, scope = `ClinicalQueueScope.resultsReady` | `Icons.science_outlined` | `state.resultsReadyCount` | — |
| In Consultation | `inConsultation` | `in-consultation` | Active consultation encounters, scope = `ClinicalQueueScope.inConsultation` | `Icons.medical_information_outlined` | `state.inConsultationCount` | — |
| Completed | `completed` | `completed` | Completed/closed encounters, scope = `ClinicalQueueScope.completed` | `Icons.task_alt_outlined` | `state.completedCount` | — |

**Note on primary action button:** Unlike Reception (which has "Register patient") and OPD (which has "Start walk-in"), the Clinical workspace's actions (Add note, Request lab, Prescribe, Request radiology) all require a selected encounter. These actions already exist in the encounter detail dialog's `_ClinicalActionBar`. Therefore, the tab row will have the `AppTabStrip` filling the full row width — no primary action button beside the tabs. If the existing "Today" scope filter is desired, add a `ClinicalQueueScope.today` tab between "All" and "Waiting Review".

### Routing

**No changes to `app_routes.dart` or `app_router.dart` route definitions are needed.** The `/clinical` GoRoute already passes `ClinicalWorkspaceQuery.fromUri(state.uri)` to the page. The only changes are:

1. **Add a `section` field to `ClinicalWorkspaceQuery`** — parse `?section=` from the URI in `fromUri`. The existing `panel` key already picks `'panel', 'tab', 'section'` — but currently maps to the string `panel` field. Instead, add a dedicated `ClinicalWorkspaceSection` enum and `section` field separate from `panel`.
2. **Add a `ClinicalWorkspaceSection` enum** to `clinical_entities.dart` — values: `all`, `waitingReview`, `urgent`, `resultsReady`, `inConsultation`, `completed`.
3. **Map `ClinicalWorkspaceSection` to `ClinicalQueueScope`** — each tab maps 1:1 to a scope value. Tab switching calls `controller.applyScope(scope)` to trigger server-side data refresh.
4. **URL update on tab change** — use `GoRouter.of(context).replace<void>(location)` with `AppRoutes.clinical.location(queryParameters: {'section': sectionQueryValue})`, exactly like Reception's `_updateUrlForSection`.

### Page Layout

Target widget tree (mirrors Reception exactly):

```
ClinicalWorkspacePage (ConsumerWidget)
 └─ AsyncStateScaffold<ClinicalWorkspaceState>
     └─ _ClinicalWorkspaceContent (ConsumerStatefulWidget)
         └─ ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)
             └─ SizedBox(width: double.infinity)
                 └─ Column(crossAxisAlignment: CrossAxisAlignment.stretch)
                     ├─ AppTabStrip(tabs: [...], selectedId: _section.name, onTabTapped: ...)
                     ├─ SizedBox(height: theme.spacing.md)
                     └─ _ClinicalWorklistPanel(
                            state: ...,
                            section: _section,
                            searchController: ...,
                            columnVisibilityController: ...,
                            onSearchChanged: ...,
                            onSearchSubmitted: ...,
                        )
```

**Key differences from current layout:**
- Replace `AppWorkspace` wrapper with direct `ResponsivePage` → `Column`.
- Add `AppTabStrip` at the top of the `Column` (no primary action button beside it — the tab strip takes full width via `AppTabStrip` directly, no `Row`/`Expanded` wrapper needed since there's no sibling button).
- Spacing between tab strip and table via `SizedBox(height: theme.spacing.md)` — matching Reception line 284.
- The summary notification cards from `appWorkspaceToolbarWithLabels` are removed — their count values become tab badge counts.
- The secondary toolbar buttons (Add note, Request lab, Prescribe, Request radiology) are removed from the toolbar — they remain only in the encounter detail dialog's `_ClinicalActionBar`.
- Per-tab column visibility persistence keys: `clinical_${section.name}`.
- Per-tab column width persistence keys: `clinical_cw_${section.name}`.
- The `onRefresh` callback is handled by realtime sync (already wired in the controller via `WorkspaceAdaptivePolling` and `listenForRealtimeRefresh`).

### Per-Tab Column Definitions

**All tab** — current 5 default columns:
`Patient`, `Queue`, `Status/Step`, `Provider`, `Last Updated`

**Waiting Review tab** — review-focused columns (5):
`Patient`, `Queue`, `Status/Step`, `Provider`, `Last Updated`

**Urgent tab** — urgency-focused columns (5):
`Patient`, `Queue`, `Status/Step`, `Provider`, `Last Updated`

**Results Ready tab** — results-focused columns (6):
`Patient`, `Queue`, `Status/Step`, `Encounter Type`, `Provider`, `Last Updated`

**In Consultation tab** — consultation-focused columns (6):
`Patient`, `Queue`, `Status/Step`, `Provider`, `Location`, `Last Updated`

**Completed tab** — completed-focused columns (6):
`Patient`, `Queue`, `Status/Step`, `Encounter Type`, `Provider`, `Last Updated`

All tabs use the same `_availableClinicalTableColumns` for column visibility choices — users can toggle any of the 12 available columns on any tab via the table settings button.

### Data & State Management

**The controller and repository remain unchanged.** The existing `ClinicalWorkspaceController` methods (`refresh`, `applySearch`, `applyScope`, `applyWorklistFilters`, `changePage`, `selectEntry`, etc.) already support scope-based filtering via `ClinicalQueueScope`.

The tab-switching logic:
1. Map `ClinicalWorkspaceSection` → `ClinicalQueueScope` 1:1:
   - `all` → `ClinicalQueueScope.all`
   - `waitingReview` → `ClinicalQueueScope.waitingReview`
   - `urgent` → `ClinicalQueueScope.urgent`
   - `resultsReady` → `ClinicalQueueScope.resultsReady`
   - `inConsultation` → `ClinicalQueueScope.inConsultation`
   - `completed` → `ClinicalQueueScope.completed`
2. When a tab is tapped, call `controller.applyScope(mappedScope)` — this triggers a server-side re-fetch with the new scope.
3. Update the URL via `GoRouter.replace` with the new `?section=` value.
4. Reset the search controller text to empty (or keep existing search if the user expects it to persist across tab changes — follow OPD pattern which clears search on tab change).
5. The existing `_ClinicalWorklistPanel` continues to render `AppListTable<ClinicalWorklistEntry>` with `page: state.worklist` — the controller handles the filtering server-side.

**Note:** The current advanced filter dialog includes a "Scope" filter group (`_clinicalFilterScope`). Since scope is now controlled by tabs, the `includeScope: true` parameter in `_clinicalFilterGroups()` should be changed to `includeScope: false` — the scope filter is removed from the advanced filter dialog because the tab strip replaces it.

## Implementation Steps

### 1. Add `ClinicalWorkspaceSection` enum — File: `frontend/lib/features/clinical/domain/entities/clinical_entities.dart`

Add the following enum **after** the existing `ClinicalQueueScope` enum (after line 54):

```dart
enum ClinicalWorkspaceSection {
  all,
  waitingReview,
  urgent,
  resultsReady,
  inConsultation,
  completed,
}
```

### 2. Add `section` field to `ClinicalWorkspaceQuery` — File: `frontend/lib/features/clinical/domain/entities/clinical_entities.dart`

- Add `this.section = ClinicalWorkspaceSection.all` to the `ClinicalWorkspaceQuery` constructor parameter list.
- Add `final ClinicalWorkspaceSection section;` field.
- In `ClinicalWorkspaceQuery.fromUri`, add a section parser. Update the return statement to include:

```dart
section: _parseClinicalSection(pick(<String>['section', 'tab'])),
```

**Important:** The existing `panel` field already uses `pick(<String>['panel', 'tab', 'section'])`. Update the `panel` pick to only use `pick(<String>['panel'])` to avoid conflicts, since `section` now has its own dedicated parser.

Add a top-level helper function (before `ClinicalWorkspaceQuery`):

```dart
ClinicalWorkspaceSection _parseClinicalSection(String raw) {
  return switch (raw.trim().toLowerCase()) {
    'waiting-review' || 'waiting_review' || 'waitingreview' || 'review' =>
      ClinicalWorkspaceSection.waitingReview,
    'urgent' => ClinicalWorkspaceSection.urgent,
    'results-ready' || 'results_ready' || 'resultsready' || 'results' =>
      ClinicalWorkspaceSection.resultsReady,
    'in-consultation' ||
    'in_consultation' ||
    'inconsultation' ||
    'consultation' =>
      ClinicalWorkspaceSection.inConsultation,
    'completed' || 'closed' || 'done' => ClinicalWorkspaceSection.completed,
    _ => ClinicalWorkspaceSection.all,
  };
}
```

- Update `hasRouteTargeting` to include non-default section:
```dart
bool get hasRouteTargeting =>
    section != ClinicalWorkspaceSection.all ||
    encounterId.isNotEmpty ||
    panel.isNotEmpty ||
    search.isNotEmpty;
```

- Update `signature` to include section:
```dart
String get signature => '${section.name}|$encounterId|$panel|$search';
```

### 3. Add section-to-scope mapping — File: `frontend/lib/features/clinical/presentation/pages/clinical_workspace_page.dart`

Add these helper functions (as top-level functions, matching the existing code style):

```dart
ClinicalQueueScope _clinicalSectionScope(ClinicalWorkspaceSection section) {
  return switch (section) {
    ClinicalWorkspaceSection.all => ClinicalQueueScope.all,
    ClinicalWorkspaceSection.waitingReview => ClinicalQueueScope.waitingReview,
    ClinicalWorkspaceSection.urgent => ClinicalQueueScope.urgent,
    ClinicalWorkspaceSection.resultsReady => ClinicalQueueScope.resultsReady,
    ClinicalWorkspaceSection.inConsultation =>
      ClinicalQueueScope.inConsultation,
    ClinicalWorkspaceSection.completed => ClinicalQueueScope.completed,
  };
}

IconData _clinicalSectionIcon(ClinicalWorkspaceSection section) {
  return switch (section) {
    ClinicalWorkspaceSection.all => Icons.inventory_2_outlined,
    ClinicalWorkspaceSection.waitingReview => Icons.rate_review_outlined,
    ClinicalWorkspaceSection.urgent => Icons.priority_high_outlined,
    ClinicalWorkspaceSection.resultsReady => Icons.science_outlined,
    ClinicalWorkspaceSection.inConsultation =>
      Icons.medical_information_outlined,
    ClinicalWorkspaceSection.completed => Icons.task_alt_outlined,
  };
}

String _clinicalSectionLabel(
  AppLocalizations l10n,
  ClinicalWorkspaceSection section,
) {
  return switch (section) {
    ClinicalWorkspaceSection.all => l10n.clinicalSectionAllLabel,
    ClinicalWorkspaceSection.waitingReview =>
      l10n.clinicalSectionWaitingReviewLabel,
    ClinicalWorkspaceSection.urgent => l10n.clinicalSectionUrgentLabel,
    ClinicalWorkspaceSection.resultsReady =>
      l10n.clinicalSectionResultsReadyLabel,
    ClinicalWorkspaceSection.inConsultation =>
      l10n.clinicalSectionInConsultationLabel,
    ClinicalWorkspaceSection.completed => l10n.clinicalSectionCompletedLabel,
  };
}

int _clinicalSectionCount(
  ClinicalWorkspaceState state,
  ClinicalWorkspaceSection section,
) {
  return switch (section) {
    ClinicalWorkspaceSection.all => _pageTotal(state.worklist),
    ClinicalWorkspaceSection.waitingReview => state.waitingReviewCount,
    ClinicalWorkspaceSection.urgent => state.urgentCount,
    ClinicalWorkspaceSection.resultsReady => state.resultsReadyCount,
    ClinicalWorkspaceSection.inConsultation => state.inConsultationCount,
    ClinicalWorkspaceSection.completed => state.completedCount,
  };
}

String _clinicalSectionQueryValue(ClinicalWorkspaceSection section) {
  return switch (section) {
    ClinicalWorkspaceSection.all => '',
    ClinicalWorkspaceSection.waitingReview => 'waiting-review',
    ClinicalWorkspaceSection.urgent => 'urgent',
    ClinicalWorkspaceSection.resultsReady => 'results-ready',
    ClinicalWorkspaceSection.inConsultation => 'in-consultation',
    ClinicalWorkspaceSection.completed => 'completed',
  };
}

List<_ClinicalTableColumnId> _clinicalDefaultColumnsForSection(
  ClinicalWorkspaceSection section,
) {
  return switch (section) {
    ClinicalWorkspaceSection.all => _defaultClinicalTableColumns,
    ClinicalWorkspaceSection.waitingReview => _defaultClinicalTableColumns,
    ClinicalWorkspaceSection.urgent => _defaultClinicalTableColumns,
    ClinicalWorkspaceSection.resultsReady => const <_ClinicalTableColumnId>[
      _ClinicalTableColumnId.patient,
      _ClinicalTableColumnId.queue,
      _ClinicalTableColumnId.statusStep,
      _ClinicalTableColumnId.encounterType,
      _ClinicalTableColumnId.provider,
      _ClinicalTableColumnId.lastUpdated,
    ],
    ClinicalWorkspaceSection.inConsultation => const <_ClinicalTableColumnId>[
      _ClinicalTableColumnId.patient,
      _ClinicalTableColumnId.queue,
      _ClinicalTableColumnId.statusStep,
      _ClinicalTableColumnId.provider,
      _ClinicalTableColumnId.location,
      _ClinicalTableColumnId.lastUpdated,
    ],
    ClinicalWorkspaceSection.completed => const <_ClinicalTableColumnId>[
      _ClinicalTableColumnId.patient,
      _ClinicalTableColumnId.queue,
      _ClinicalTableColumnId.statusStep,
      _ClinicalTableColumnId.encounterType,
      _ClinicalTableColumnId.provider,
      _ClinicalTableColumnId.lastUpdated,
    ],
  };
}
```

### 4. Update imports in `clinical_workspace_page.dart` — File: `frontend/lib/features/clinical/presentation/pages/clinical_workspace_page.dart`

Add these imports (if not already present):
```dart
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
```

The `AppTabStrip` and `AppTabItem` are already exported via `package:hosspi_hms/shared/components/components.dart` which is already imported. `ResponsivePage` and `PageMaxWidth` are already exported via `package:hosspi_hms/shared/layout/layout.dart` which is already imported.

### 5. Add section state and URL helpers to `_ClinicalWorkspaceContentState` — File: `frontend/lib/features/clinical/presentation/pages/clinical_workspace_page.dart`

#### 5a. Add state field

Add to `_ClinicalWorkspaceContentState` field declarations (near `_appliedRouteSignature`):
```dart
late ClinicalWorkspaceSection _section;
```

#### 5b. Initialize in `initState`

After the existing `_tableColumnController` initialization (line ~151), add:
```dart
_section = widget.initialQuery?.section ?? ClinicalWorkspaceSection.all;
```

#### 5c. Add URL update method (follows Reception pattern exactly)

```dart
void _updateUrlForSection(ClinicalWorkspaceSection section) {
  if (!mounted) {
    return;
  }
  final String tab = _clinicalSectionQueryValue(section);
  final String location = AppRoutes.clinical.location(
    queryParameters: <String, String>{
      if (tab.isNotEmpty) 'section': tab,
    },
  );
  GoRouter.of(context).replace<void>(location);
}
```

#### 5d. Update `_applyRouteQuery` to handle section from deep-link

Modify the existing `_applyRouteQuery` method (lines ~177-191) to add section handling at the beginning:

```dart
Future<void> _applyRouteQuery(ClinicalWorkspaceQuery query) async {
  final ClinicalWorkspaceController controller =
      ref.read(clinicalWorkspaceControllerProvider.notifier);
  if (query.section != ClinicalWorkspaceSection.all &&
      query.section != _section) {
    _handleTabChanged(query.section);
  }
  if (query.search.isNotEmpty) {
    _searchController.text = query.search;
    await controller.applySearch(query.search);
  }
  if (query.encounterId.isNotEmpty) {
    final ClinicalWorklistEntry? entry =
        _findEntryByEncounterId(query.encounterId);
    if (entry != null) {
      await controller.selectEntry(entry);
    }
  }
}
```

#### 5e. Add tab change handler

```dart
void _handleTabChanged(ClinicalWorkspaceSection section) {
  if (section == _section) {
    return;
  }
  setState(() => _section = section);
  _updateUrlForSection(section);
  _searchController.clear();
  final ClinicalQueueScope scope = _clinicalSectionScope(section);
  ref.read(clinicalWorkspaceControllerProvider.notifier).applyScope(scope);
}
```

### 6. Replace the `build` method of `_ClinicalWorkspaceContentState` — File: `frontend/lib/features/clinical/presentation/pages/clinical_workspace_page.dart`

Replace the current `build` method (lines ~246-352) with:

```dart
@override
Widget build(BuildContext context) {
  final AppLocalizations l10n = context.l10n;
  final ThemeData theme = Theme.of(context);
  final ClinicalWorkspaceState state = widget.state;

  return ResponsivePage(
    maxWidth: PageMaxWidth.dataHeavy,
    child: SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTabStrip(
            tabs: <AppTabItem>[
              for (final ClinicalWorkspaceSection section
                  in ClinicalWorkspaceSection.values)
                AppTabItem(
                  id: section.name,
                  icon: _clinicalSectionIcon(section),
                  label:
                      '${_clinicalSectionLabel(l10n, section)} (${_clinicalSectionCount(state, section)})',
                ),
            ],
            selectedId: _section.name,
            onTabTapped: (String tabId) {
              for (final ClinicalWorkspaceSection section
                  in ClinicalWorkspaceSection.values) {
                if (section.name == tabId) {
                  _handleTabChanged(section);
                  break;
                }
              }
            },
          ),
          SizedBox(height: theme.spacing.md),
          _ClinicalWorklistPanel(
            state: state,
            section: _section,
            searchController: _searchController,
            columnVisibilityController: _tableColumnController,
            onSearchChanged: _applySearch,
            onSearchSubmitted: _applySearchImmediately,
          ),
        ],
      ),
    ),
  );
}
```

**Important notes:**
- The `AppWorkspace` wrapper, `appWorkspaceToolbarWithLabels`, summary notification cards, secondary toolbar buttons, `onRefresh` callback, and `AppRouteIcons.clinical` reference are all removed from the `build` method.
- `theme.spacing.md` is the same accessor used in `reception_workspace_page.dart` line 284.
- The refresh is now handled purely by realtime sync and adaptive polling (already wired in the controller). Users can pull-to-refresh in the parent shell scaffold.
- The clinical toolbar buttons (Add note, Request lab, Prescribe, Request radiology) that were in the toolbar are NOT lost — they remain in the encounter detail dialog's `_ClinicalActionBar` widget, which is their proper context since they require a selected encounter.

### 7. Update `_ClinicalWorklistPanel` widget — File: `frontend/lib/features/clinical/presentation/pages/clinical_workspace_page.dart`

#### 7a. Add `section` parameter

Update the constructor and field:

```dart
class _ClinicalWorklistPanel extends ConsumerWidget {
  const _ClinicalWorklistPanel({
    required this.state,
    required this.section,
    required this.searchController,
    required this.columnVisibilityController,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
  });

  final ClinicalWorkspaceState state;
  final ClinicalWorkspaceSection section;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<ClinicalWorklistEntry>
  columnVisibilityController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
```

#### 7b. Update `build` to use per-section columns and keys

In the `build` method of `_ClinicalWorklistPanel`:

Replace the hardcoded `columns` with per-section defaults:

```dart
columns: <AppListTableColumn<ClinicalWorklistEntry>>[
  for (final _ClinicalTableColumnId column
      in _clinicalDefaultColumnsForSection(section))
    _clinicalDataColumn(context, column),
],
```

Replace the `columnVisibilityStorageKey` with per-section key:

```dart
columnVisibilityStorageKey: 'clinical_${section.name}',
```

Add a per-section column width key:

```dart
columnWidthStorageKey: 'clinical_cw_${section.name}',
```

#### 7c. Update the filter groups to exclude scope

In the `_worklistSearch()` call inside `_ClinicalWorklistPanel.build`, change `includeScope: true` to `includeScope: false`:

```dart
filterGroups: _clinicalFilterGroups(
  l10n,
  filterEntries,
  includeScope: false,
),
```

Since the scope is now controlled by the tab strip, the scope filter dropdown in the advanced filter dialog is no longer needed.

### 8. Remove `_clinicalToolbarButton` method — File: `frontend/lib/features/clinical/presentation/pages/clinical_workspace_page.dart`

Remove the `_clinicalToolbarButton` method from `_ClinicalWorkspaceContentState` (lines ~213-243). It was used exclusively by the toolbar secondary buttons which are now removed. The clinical action buttons remain in the encounter detail dialog via `_ClinicalActionBar`.

### 9. Add localization strings — File: `frontend/lib/l10n/app_en.arb`

Find the clinical section of `app_en.arb` (near where `"clinicalTitle"` is defined, around line ~8570) and add these entries:

```json
"clinicalSectionAllLabel": "All",
"@clinicalSectionAllLabel": {
  "description": "Tab label for showing all clinical worklist items"
},
"clinicalSectionWaitingReviewLabel": "Waiting review",
"@clinicalSectionWaitingReviewLabel": {
  "description": "Tab label for encounters waiting doctor review"
},
"clinicalSectionUrgentLabel": "Urgent",
"@clinicalSectionUrgentLabel": {
  "description": "Tab label for urgent encounters"
},
"clinicalSectionResultsReadyLabel": "Results ready",
"@clinicalSectionResultsReadyLabel": {
  "description": "Tab label for encounters with results ready"
},
"clinicalSectionInConsultationLabel": "In consultation",
"@clinicalSectionInConsultationLabel": {
  "description": "Tab label for encounters currently in consultation"
},
"clinicalSectionCompletedLabel": "Completed",
"@clinicalSectionCompletedLabel": {
  "description": "Tab label for completed/closed encounters"
},
```

After adding the ARB entries, regenerate localizations:

```bash
cd frontend && flutter gen-l10n
```

If the project uses a different localization generation command, check the project's `l10n.yaml` or `pubspec.yaml` for the correct command and run that instead.

### 10. Update `_ClinicalWorkspaceContentState.initState` — File: `frontend/lib/features/clinical/presentation/pages/clinical_workspace_page.dart`

If the initial query has a section, apply the matching scope on init. In `initState`, after setting `_section`, add:

```dart
if (_section != ClinicalWorkspaceSection.all) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    ref
        .read(clinicalWorkspaceControllerProvider.notifier)
        .applyScope(_clinicalSectionScope(_section));
  });
}
```

This ensures that if the page is deep-linked with `?section=urgent`, the controller fetches urgent-scoped data on init.

## Shared Components — MUST Reuse

Do NOT create new implementations of these. Import and use them directly:

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` | `package:hosspi_hms/shared/components/components.dart` (via barrel) | Tab bar above the table. Constructor: `AppTabStrip(tabs: [...], selectedId: ..., onTabTapped: ...)` |
| `AppTabItem` | `package:hosspi_hms/shared/components/components.dart` (via barrel) | Tab definition: `AppTabItem(id: ..., icon: ..., label: ...)` |
| `AppListTable<ClinicalWorklistEntry>` | `package:hosspi_hms/shared/components/components.dart` (via barrel) | Data table — already in use, keep using it with per-section columns |
| `AppListTableSearch<ClinicalWorklistEntry>` | `package:hosspi_hms/shared/components/components.dart` (via barrel) | Search bar config — already in use, preserve all existing search behavior including field-specific search and advanced filters (minus scope filter) |
| `AppListTableColumnVisibilityController<ClinicalWorklistEntry>` | `package:hosspi_hms/shared/components/components.dart` (via barrel) | Column visibility — already in use, update storage keys to be per-section |
| `AsyncStateScaffold<ClinicalWorkspaceState>` | `package:hosspi_hms/shared/components/components.dart` (via barrel) | Async state wrapper — already in use |
| `ResponsivePage` | `package:hosspi_hms/shared/layout/layout.dart` (via barrel) | Page layout with `maxWidth: PageMaxWidth.dataHeavy` |
| `AppWorkspaceStatePanel` | `package:hosspi_hms/shared/layout/layout.dart` (via barrel) | Empty/loading state — already in use in table `emptyBuilder` |
| `GoRouter` | `package:go_router/go_router.dart` | URL replacement for tab sync — new import |
| `AppRoutes` | `package:hosspi_hms/app/router/app_routes.dart` | Route constants for URL generation — new import |

## Files to Create

No new files need to be created. All changes are modifications to existing files.

## Files to Modify

| File Path | Changes |
|-----------|---------|
| `frontend/lib/features/clinical/domain/entities/clinical_entities.dart` | Add `ClinicalWorkspaceSection` enum, `_parseClinicalSection` helper, `section` field to `ClinicalWorkspaceQuery`, update `fromUri` (separate `panel` and `section` parsing), `hasRouteTargeting`, `signature` |
| `frontend/lib/features/clinical/presentation/pages/clinical_workspace_page.dart` | Replace `AppWorkspace` with `ResponsivePage` → `Column` → `AppTabStrip` → `_ClinicalWorklistPanel`. Add `_section` state, `_handleTabChanged`, `_updateUrlForSection`, `_clinicalSectionIcon`, `_clinicalSectionLabel`, `_clinicalSectionCount`, `_clinicalSectionScope`, `_clinicalSectionQueryValue`, `_clinicalDefaultColumnsForSection`. Update `_ClinicalWorklistPanel` to accept `section` param with per-section columns and storage keys. Update `_applyRouteQuery` to handle section deep-link. Change `includeScope: true` to `includeScope: false` in `_worklistSearch()`. Remove `_clinicalToolbarButton` method. Remove `AppWorkspace` wrapper, `appWorkspaceToolbarWithLabels`, summary notification cards, secondary toolbar buttons. Add `go_router` and `app_routes` imports. |
| `frontend/lib/l10n/app_en.arb` | Add `clinicalSectionAllLabel`, `clinicalSectionWaitingReviewLabel`, `clinicalSectionUrgentLabel`, `clinicalSectionResultsReadyLabel`, `clinicalSectionInConsultationLabel`, `clinicalSectionCompletedLabel` localization strings with `@` metadata |

## Files to Delete (if any)

No files need to be deleted. The refactor restructures the UI within existing files.

## Cleanup: Remove Stale Code

After the refactor, the agent MUST remove all dead/stale code left behind:

- [ ] Remove the `AppWorkspace` wrapper usage from `_ClinicalWorkspaceContentState.build` — replaced by `ResponsivePage` → `Column`.
- [ ] Remove `appWorkspaceToolbarWithLabels` call — it was used to wrap the summary cards + secondary buttons + refresh in `AppWorkspace.toolbar`.
- [ ] Remove the summary notification card definitions from the old `build` method — the summary counts are now displayed as tab badge counts.
- [ ] Remove the secondary toolbar button definitions (Add note, Request lab, Prescribe, Request radiology) from the old `build` method — these remain in the encounter detail dialog's `_ClinicalActionBar`.
- [ ] Remove `_clinicalToolbarButton` method — it was used exclusively by the removed secondary toolbar buttons.
- [ ] Remove `AppRouteIcons.clinical` reference — it was used as `AppWorkspace.leadingIcon`. If this is the only reference in the file, also remove `import 'package:hosspi_hms/app/router/app_route_icons.dart';`. (Check `AppRouteIcons.clinical` is not used elsewhere in the file first.)
- [ ] Remove unused imports across all modified files.
- [ ] Run `dart analyze` to catch any remaining unreferenced declarations and remove them.
- [ ] Verify no test files reference deleted code — update or remove stale tests.

List every file and symbol removed in a "Cleanup Summary" section at the end of the implementation.

## Database Migrations

No database migrations required — schema unchanged. The refactor only restructures the Flutter UI layer. The `ClinicalWorkspaceController` already fetches all needed data via the existing `ClinicalRepository` API endpoints with `ClinicalQueueScope` filtering. No new columns, tables, or indexes are needed.

## Responsive Design Requirements

- **Desktop (≥840px / `lg`+):** Full data table with all per-tab columns visible, `AppTabStrip` at full width above the table, column resize handles enabled, column visibility settings button in search bar, row coloring by urgency/results/review state preserved.
- **Tablet (600–839px / `md`):** Same table layout — `AppListTable` renders as table at this breakpoint. Tab labels may truncate (the `AppTabStrip` uses `Wrap` internally). Action button labels may collapse to icon-only via `AppActionLabelScope` (inherited from the shell scaffold).
- **Mobile (<600px / `xs`/`sm`):** `AppListTable` automatically switches to `mobileItemBuilder` rendering each row via `_clinicalWorklistMobileItemBuilder` → `AppListItemRow`. `AppTabStrip` wraps to multiple lines via its internal `Wrap` widget.

Use `AppBreakpoints` from `package:hosspi_hms/core/responsive/app_breakpoints.dart` for any breakpoint-dependent logic. The existing `AppListTable` already handles the table/list switch — no manual breakpoint logic needed for the table itself.

## Verification Steps

After implementation, the agent MUST run these commands and confirm they pass:

```bash
# Regenerate localizations
cd frontend && flutter gen-l10n

# Format
dart format frontend/lib/features/clinical/ frontend/lib/l10n/

# Analyze
dart analyze frontend/ --fatal-infos

# Run tests related to this screen
flutter test test/features/clinical/

# Run shared component tests to ensure no regressions
flutter test test/shared/
```

## Testing Requirements

Write or update these tests:

- [ ] Tab navigation: switching tabs calls `controller.applyScope()` with the correct `ClinicalQueueScope` value
- [ ] Tab navigation: switching tabs updates the URL query parameter `?section=` via `GoRouter.replace`
- [ ] Deep linking: constructing a `ClinicalWorkspaceQuery.fromUri` with `?section=urgent` produces `ClinicalWorkspaceSection.urgent`
- [ ] Deep linking: constructing a `ClinicalWorkspaceQuery.fromUri` with `?section=waiting-review` produces `ClinicalWorkspaceSection.waitingReview`
- [ ] Deep linking: constructing a `ClinicalWorkspaceQuery.fromUri` with `?section=results-ready` produces `ClinicalWorkspaceSection.resultsReady`
- [ ] Deep linking: constructing a `ClinicalWorkspaceQuery.fromUri` with `?section=in-consultation` produces `ClinicalWorkspaceSection.inConsultation`
- [ ] Deep linking: constructing a `ClinicalWorkspaceQuery.fromUri` with `?section=completed` produces `ClinicalWorkspaceSection.completed`
- [ ] Tab counts: badge counts on tabs match `waitingReviewCount`, `urgentCount`, `resultsReadyCount`, `inConsultationCount`, `completedCount` from `ClinicalWorkspaceState`
- [ ] Per-tab columns: verify default column set uses 5 columns for all/waitingReview/urgent, 6 columns for resultsReady/inConsultation/completed
- [ ] Advanced filters preserved: typing in the search bar filters within the active tab's data subset
- [ ] Advanced filter dialog: filter button opens the filter UI without the "Scope" dropdown (removed since scope = tab)
- [ ] Field-specific search: selecting a search field and searching works within the tab
- [ ] Row coloring: `_clinicalRowColor` continues to color rows by urgency/results/review state
- [ ] Row click: clicking a row opens `_ClinicalEncounterDialog` with full encounter detail and action bar
- [ ] Mobile layout: widget tests verify `mobileItemBuilder` renders `_clinicalWorklistMobileItemBuilder` → `AppListItemRow` at mobile breakpoint
- [ ] Existing deep-link: `?encounterId=<id>` still opens the encounter detail dialog
- [ ] Section persistence on `panel` key: `?panel=` no longer conflicts with `?section=` (separate parsing)
- [ ] No regressions: all existing clinical workspace tests pass
- [ ] `hasRouteTargeting`: verify that `ClinicalWorkspaceQuery` with non-default section returns `true`
- [ ] `signature`: verify that `ClinicalWorkspaceQuery.signature` includes section name

## Acceptance Criteria

The refactor is complete when ALL of the following are true:

- [ ] The screen uses routable `AppTabStrip` tabs matching the Reception workspace pattern, with 6 tabs: All, Waiting Review, Urgent, Results Ready, In Consultation, Completed
- [ ] Each tab has its own URL via `?section=` that supports deep linking
- [ ] Tab badge counts display the correct count for each scope (waiting review, urgent, results ready, in consultation, completed)
- [ ] Tab switching triggers `controller.applyScope()` with the corresponding `ClinicalQueueScope` for server-side data refresh
- [ ] The page body uses `AppListTable<ClinicalWorklistEntry>` with per-section default columns, all 12 column choices available via settings, integrated field-specific search, advanced filter (without scope dropdown), and column visibility settings (per-section persistence keys `clinical_${section.name}`)
- [ ] The layout uses `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)` directly instead of `AppWorkspace`
- [ ] Spacing between tab strip and table matches Reception: `theme.spacing.md`
- [ ] The encounter detail dialog (`_ClinicalEncounterDialog`) continues to show full encounter bundle with `_ClinicalActionBar` containing all clinical actions (Add note, Diagnose, Request lab, Request radiology, Prescribe, Procedure, Refer, Admit, Follow-up, Disposition)
- [ ] No shared component is re-implemented — only imported and used
- [ ] The layout is fully responsive across mobile, tablet, and desktop
- [ ] All old/duplicate layout code is removed — no stale `AppWorkspace` wrapper, no `appWorkspaceToolbarWithLabels` call, no summary notification cards, no `_clinicalToolbarButton` method remains
- [ ] Domain-specific business logic is preserved: server-side scope filtering via `ClinicalQueueScope`, field-specific search, advanced filters (source, status, provider, encounter type, location), encounter detail dialog, clinical action dialogs, triage handoff panel, results preview, consultation summary printing, realtime sync, urgency-based row coloring, deduplication logic, deep-linking via `?encounterId=` and `?search=`
- [ ] No database migrations required — schema unchanged (explicitly confirmed)
- [ ] `dart analyze` reports no new issues — zero unused imports, zero unreferenced declarations
- [ ] All tests pass (no stale test references to removed code)
- [ ] New localization strings are added for tab labels and localizations are regenerated
