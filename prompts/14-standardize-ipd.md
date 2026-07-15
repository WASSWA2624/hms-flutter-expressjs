# Standardize IPD (Inpatient Department) Screen

## Objective

Refactor the IPD workspace page to match the standardized tab-and-table layout used by the Reception workspace. Replace the current `AppWorkspace` toolbar-driven layout (summary notification badges + board mode toggle) with a `ResponsivePage` + `AppTabStrip` pattern where each IPD workflow stage is a dedicated tab with URL-based deep linking. Preserve all existing domain logic, clinical actions, detail dialogs, and the Bed Board view — only restructure the top-level layout shell to conform to the Reception reference pattern.

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification — all information needed is in this prompt. Run tests and formatting after implementation.

## Current State (from audit)

### Files

- **Page:** `frontend/lib/features/ipd/presentation/pages/ipd_workspace_page.dart` (~3065 lines)
- **Controller:** `frontend/lib/features/ipd/presentation/controllers/ipd_workspace_controller.dart` (1019 lines)
- **Widgets:**
  - `frontend/lib/features/ipd/presentation/widgets/ipd_bed_board_panel.dart` (579 lines)
  - `frontend/lib/features/ipd/presentation/widgets/ipd_clinical_order_actions.dart` (146 lines)
  - `frontend/lib/features/ipd/presentation/widgets/ipd_start_admission_dialog.dart` (372 lines)
- **Entities:** `frontend/lib/features/ipd/domain/entities/ipd_entities.dart` (863 lines)
- **Repository:** `frontend/lib/features/ipd/domain/repositories/ipd_repository.dart` (110 lines)
- **Repository impl:** `frontend/lib/features/ipd/data/repositories/ipd_repository_impl.dart` (335 lines)
- **DTOs:** `frontend/lib/features/ipd/data/dtos/ipd_dtos.dart` (710 lines)
- **Tests:**
  - `frontend/test/features/ipd/data/ipd_dtos_test.dart`
  - `frontend/test/features/ipd/domain/ipd_entities_test.dart`
  - `frontend/test/features/ipd/presentation/ipd_workspace_controller_test.dart`
- **Route:** `frontend/lib/app/router/app_routes.dart` (lines 332–343) and `frontend/lib/app/router/app_router.dart` (lines 190–198)

### Current layout and structure

The page uses **`AppWorkspace`** as its layout shell. The toolbar contains:

1. **Summary notification badges** (`AppWorkspaceSummaryNotification`) — one for each scope count (Total, Admission Queue, Active Patients, Transfers, Discharge Planned, Critical Alerts). Clicking a badge calls `controller.applyScope(...)` to change the `IpdQueueScope`.
2. **Board mode toggle** (`AppWorkspaceBoardToggle<IpdBoardMode>`) — switches between `IpdBoardMode.patientBoard` (an `AppListTable<IpdAdmissionSummary>`) and `IpdBoardMode.bedBoard` (`IpdBedBoardPanel`).
3. **Primary action button** (`AppButton.primary`) — "Start Admission" in the toolbar's `primary` slot.
4. **Refresh button** — built into the `appWorkspaceToolbarWithLabels` helper.

The body switches between `_IpdBoardPanel` (patient list table) and `IpdBedBoardPanel` (bed board grid) based on `_boardMode`. Scope filtering is done through the search bar's `filterGroups` with `_ipdScopeFilterKey` and `_ipdWardFilterKey`.

### Problems / inconsistencies with the Reception reference

1. **No tab strip:** Scope switching uses toolbar summary badges + advanced filter, not `AppTabStrip` tabs.
2. **No tab-to-URL routing:** The current `?section=` pattern from the Reception reference is absent. Scope is ephemeral state — deep-linking to a specific scope is not supported.
3. **Different layout shell:** Uses `AppWorkspace` (which adds header/toolbar overhead) instead of `ResponsivePage` with manual composition like Reception.
4. **Board mode toggle instead of tab:** Patient Board vs Bed Board is a segmented button in the toolbar, not a tab.
5. **Primary action in toolbar:** "Start Admission" is in the `AppWorkspace` toolbar, not next to the tab strip as in Reception.
6. **Tab counts missing from labels:** Reception shows counts in tab labels like `"Appointments (12)"`. IPD shows them only as summary badges.

### Components currently in use

- `AppWorkspace`, `AppWorkspaceSummaryNotification`, `AppWorkspaceBoardToggle`, `AppWorkspaceDetailPanel`, `AppWorkspaceStatePanel`, `AppWorkspaceStatusBadge`, `AppWorkspaceActivityList`, `AppWorkspacePatientContextField`
- `AppListTable`, `AppListTableColumn`, `AppListTableSearch`, `AppSearchBarFilterGroup`, `AppListTableColumnVisibilityController`
- `AppDialog`, `AppButton`, `AppTextField`, `AppSelectField`, `AppFormSection`, `AppFormInformationBanner`, `AppConfirmActionDialog`
- `AppPatientDetails`, `AppActionList`, `AppActionItem`
- `WorkflowActionButton`
- `InsuranceAuthorizationPanel`
- `ClinicalAdmissionActionDialog`, `ClinicalFreeTextActionDialog`, `ClinicalRequestBillingPanel`
- `AsyncStateScaffold`

## Reference Implementation

Read these files to understand the target patterns (do NOT modify them):

| File | Key patterns to extract |
|------|------------------------|
| `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` | Tab strip + table layout, `_sectionToQueryValue()` URL mapping, `_updateUrlForSection()`, primary action placement, `_ReceptionDeskRow` row model, `_columnsForSection()`, `mobileItemBuilder`, `_sectionFromQuery()` |
| `frontend/lib/features/reception/domain/entities/reception_entities.dart` | `ReceptionDeskSection` enum as tab definition, `ReceptionWorkspaceQuery.fromUri()` |
| `frontend/lib/shared/components/app_tab_strip.dart` | `AppTabStrip` API: `tabs`, `selectedId`, `onTabTapped`, `AppTabItem` |
| `frontend/lib/shared/layout/responsive_page.dart` | `ResponsivePage` with `maxWidth: PageMaxWidth.dataHeavy` |
| `frontend/lib/shared/components/app_list_table.dart` | `AppListTable` constructor, `AppListTableSearch`, column visibility, pagination |
| `frontend/lib/shared/components/app_button.dart` | `AppButton.primary()` placement pattern |
| `frontend/lib/core/responsive/app_breakpoints.dart` | `AppBreakpoints.of(context)`, `isMobile`, breakpoint values |
| `frontend/lib/shared/layout/responsive_spacing.dart` | `ResponsiveSpacing.pagePaddingFor()` |

## Target Architecture

### Tab Configuration

| Tab Name | Section ID | Route Value | Description | Primary Action Button |
|----------|-----------|-------------|-------------|-----------------------|
| Admission Queue | `admissionQueue` | `admission-queue` | Patients awaiting admission or pending bed assignment | "Start Admission" → opens `IpdStartAdmissionDialog` |
| Active Patients | `activePatients` | `active` | Currently admitted patients with active beds | "Start Admission" → opens `IpdStartAdmissionDialog` |
| Transfers | `transferPending` | `transfers` | Patients with pending or in-progress transfer requests | "Start Admission" → opens `IpdStartAdmissionDialog` |
| Discharge | `dischargePlanned` | `discharge` | Patients with planned discharge or awaiting clearance | "Start Admission" → opens `IpdStartAdmissionDialog` |
| Bed Board | `bedBoard` | `bed-board` | Live ward bed occupancy grid with bed operations | "Start Admission" → opens `IpdStartAdmissionDialog` |

The primary action remains "Start Admission" across all tabs (consistent, always-visible, like Reception's "Register Patient").

### Routing

**Router file:** `frontend/lib/app/router/app_router.dart` (lines 190–198)

The existing `GoRoute` for `/ipd` does **not** need sub-routes. Follow the Reception pattern: keep a single `/ipd` route and add `?section=` query parameter for tab state.

**Entities file:** `frontend/lib/features/ipd/domain/entities/ipd_entities.dart`

Add a `section` field to `IpdAdmissionQuery` and parse it from `?section=` in `fromUri()`. Add `_sectionToQueryValue()` and `_sectionFromQuery()` mappings to the page (following Reception's exact pattern).

The `IpdQueueScope` enum already exists and maps to patient board tabs. Add a new enum value or use a separate mechanism to represent the Bed Board tab (since it's not a queue scope but a display mode).

### Page Layout

Replace the current `AppWorkspace`-based widget tree with this Reception-style tree:

```
IpdWorkspacePage (ConsumerStatefulWidget — as now)
  └─ AsyncStateScaffold<IpdWorkspaceState>
      ├─ [loading] → loading indicator
      ├─ [error] → failure view with retry
      └─ [data] → _IpdWorkspaceContent (ConsumerStatefulWidget)
            └─ ResponsivePage (maxWidth: PageMaxWidth.dataHeavy)
                  └─ SizedBox (width: double.infinity)
                        └─ Column (crossAxisAlignment: CrossAxisAlignment.stretch)
                              ├─ Row
                              │   ├─ Expanded
                              │   │   └─ AppTabStrip
                              │   │       └─ tabs: [one AppTabItem per IpdWorkspaceSection]
                              │   ├─ SizedBox (width: spacing)
                              │   └─ AppAccessActionGate (_ipdOperationalWriteRequirement)
                              │       └─ AppButton.primary ("Start Admission")
                              ├─ SizedBox (height: spacing)
                              └─ [BODY: switches on _section]
                                    ├─ [bedBoard] → IpdBedBoardPanel (as today)
                                    └─ [any queue scope] → AppListTable<IpdAdmissionSummary> (as today, with per-tab columns)
```

### Data & State Management

**Keep the existing `IpdWorkspaceController` and `ipdWorkspaceControllerProvider` unchanged.** The controller already supports:
- `applyScope(IpdQueueScope)` — drives the tab's data filter server-side
- `applySearch(String)` — search bar
- `applyWard(String?)` — ward filter
- `loadBedBoard()` — bed board data loading
- `changePage(AppPageRequest)` — pagination
- All clinical action methods

The only change needed in the controller: **none**. The existing `applyScope` method is already the mechanism for tab switching. The page layer will call it when a tab is selected.

**State tracking for the active tab:** Add a private `_section` field (type `IpdWorkspaceSection`) to `_IpdWorkspaceContentState`, initialized from the URL query parameter. When a tab is tapped, update `_section`, call `controller.applyScope(scope)` for patient board tabs, or `controller.loadBedBoard()` for the Bed Board tab, and update the URL.

## Implementation Steps

### 1. Define the `IpdWorkspaceSection` enum — File: `frontend/lib/features/ipd/domain/entities/ipd_entities.dart`

Add a new enum representing the tab sections:

```dart
enum IpdWorkspaceSection {
  admissionQueue,
  activePatients,
  transferPending,
  dischargePlanned,
  bedBoard,
}
```

This enum is distinct from `IpdQueueScope` because it includes `bedBoard` (which is a display mode, not a queue scope). Add a helper extension:

```dart
extension IpdWorkspaceSectionX on IpdWorkspaceSection {
  IpdQueueScope? get queueScope => switch (this) {
    IpdWorkspaceSection.admissionQueue => IpdQueueScope.admissionQueue,
    IpdWorkspaceSection.activePatients => IpdQueueScope.activePatients,
    IpdWorkspaceSection.transferPending => IpdQueueScope.transferPending,
    IpdWorkspaceSection.dischargePlanned => IpdQueueScope.dischargePlanned,
    IpdWorkspaceSection.bedBoard => null,
  };

  bool get isBedBoard => this == IpdWorkspaceSection.bedBoard;
}
```

### 2. Add `section` to `IpdAdmissionQuery` — File: `frontend/lib/features/ipd/domain/entities/ipd_entities.dart`

Add a `section` field to `IpdAdmissionQuery`:

```dart
final IpdWorkspaceSection section;
```

Default it to `IpdWorkspaceSection.admissionQueue` in the constructor.

Update `fromUri()` to parse `?section=` from the URI (accept multiple aliases like Reception does — e.g. `'admission-queue'`, `'admission_queue'`, `'admissionQueue'` all map to `IpdWorkspaceSection.admissionQueue`).

Update `copyWith()` to include `section`.

### 3. Refactor `IpdWorkspacePage` — File: `frontend/lib/features/ipd/presentation/pages/ipd_workspace_page.dart`

This is the main change. The page is ~3065 lines; the shell restructure only touches the top-level widget (`_IpdWorkspaceContentState.build()`). All other widgets (`_IpdDetailPanel`, `_IpdDetailActions`, `_IpdBoardPanel`, `_IpdPatientCell`, `_IpdMobileAdmissionRow`, `_IpdSection`, `_IpdKeyValueGrid`, `_IpdRecordSection`, `_IpdDischargeSection`, `_IpdSourceContextSection`, `_IpdTheatreHandoverSection`, `_IpdTimelineSection`, `_IpdBedSection`, `ReleaseBedDialog`, `TransferRequestDialog`, `TransferUpdateDialog`, `MedicationAdministrationDialog`, `RequestTherapyDialog`, `_WardRoundActionDialog`) and all helper functions remain unchanged.

#### 3a. Replace imports

Remove the `AppWorkspaceBoardToggle` usage (if it was imported from layout). Ensure `AppTabStrip` and `ResponsivePage` are imported. These are likely already available via the barrel exports:

```dart
import 'package:hosspi_hms/shared/components/components.dart'; // includes AppTabStrip
import 'package:hosspi_hms/shared/layout/layout.dart'; // includes ResponsivePage
```

Both are already imported in the current file. No new imports needed.

#### 3b. Modify `_IpdWorkspaceContentState`

Replace the `_boardMode` field:

```dart
// REMOVE:
IpdBoardMode _boardMode = IpdBoardMode.patientBoard;

// ADD:
IpdWorkspaceSection _section = IpdWorkspaceSection.admissionQueue;
```

Initialize `_section` from the route query in `initState`:

```dart
@override
void initState() {
  super.initState();
  _searchController = TextEditingController(text: widget.state.query.search);
  _tableColumnController =
      AppListTableColumnVisibilityController<IpdAdmissionSummary>();
  _section = widget.state.query.section;
}
```

Remove the `_selectBoardMode` method. Add tab selection and URL update methods following the Reception pattern:

```dart
void _selectSection(IpdWorkspaceSection section) {
  if (_section == section) return;
  setState(() => _section = section);

  final IpdWorkspaceController controller =
      ref.read(ipdWorkspaceControllerProvider.notifier);

  final IpdQueueScope? scope = section.queueScope;
  if (scope != null) {
    unawaited(controller.applyScope(scope));
  } else if (section.isBedBoard) {
    unawaited(controller.loadBedBoard());
  }

  _updateUrlForSection(section);
}

void _updateUrlForSection(IpdWorkspaceSection section) {
  final String sectionValue = _sectionToQueryValue(section);
  final Uri currentUri = GoRouter.of(context).routeInformationProvider.value.uri;
  final Map<String, String> params = Map<String, String>.of(currentUri.queryParameters);
  params['section'] = sectionValue;
  final String location = AppRoutes.ipd.location(queryParameters: params);
  GoRouter.of(context).replace<void>(location);
}

static String _sectionToQueryValue(IpdWorkspaceSection section) {
  return switch (section) {
    IpdWorkspaceSection.admissionQueue => 'admission-queue',
    IpdWorkspaceSection.activePatients => 'active',
    IpdWorkspaceSection.transferPending => 'transfers',
    IpdWorkspaceSection.dischargePlanned => 'discharge',
    IpdWorkspaceSection.bedBoard => 'bed-board',
  };
}

static IpdWorkspaceSection _sectionFromQuery(String? value) {
  return switch ((value ?? '').trim().toLowerCase()) {
    'admission-queue' || 'admission_queue' || 'admissionqueue' || 'queue' => IpdWorkspaceSection.admissionQueue,
    'active' || 'active-patients' || 'active_patients' || 'activepatients' => IpdWorkspaceSection.activePatients,
    'transfers' || 'transfer-pending' || 'transfer_pending' || 'transferpending' => IpdWorkspaceSection.transferPending,
    'discharge' || 'discharge-planned' || 'discharge_planned' || 'dischargeplanned' => IpdWorkspaceSection.dischargePlanned,
    'bed-board' || 'bed_board' || 'bedboard' || 'beds' => IpdWorkspaceSection.bedBoard,
    _ => IpdWorkspaceSection.admissionQueue,
  };
}
```

#### 3c. Replace the `build()` method of `_IpdWorkspaceContentState`

Replace the entire `AppWorkspace(...)` invocation with the Reception-style layout:

```dart
@override
Widget build(BuildContext context) {
  final AppLocalizations l10n = context.l10n;
  final IpdWorkspaceState state = widget.state;
  final IpdWorkspaceController controller = ref.read(
    ipdWorkspaceControllerProvider.notifier,
  );
  final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
  final bool canOperate = _ipdOperationalWriteRequirement.isAllowed(policy);

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
                    AppTabItem(
                      id: IpdWorkspaceSection.admissionQueue.name,
                      icon: Icons.bed_outlined,
                      label: _tabLabel(l10n.ipdAdmissionQueueTabLabel, state.admissionQueueCount),
                    ),
                    AppTabItem(
                      id: IpdWorkspaceSection.activePatients.name,
                      icon: Icons.local_hospital_outlined,
                      label: _tabLabel(l10n.ipdActivePatientsTabLabel, state.activePatientCount),
                    ),
                    AppTabItem(
                      id: IpdWorkspaceSection.transferPending.name,
                      icon: Icons.swap_horiz,
                      label: _tabLabel(l10n.ipdTransfersTabLabel, state.transferPendingCount),
                    ),
                    AppTabItem(
                      id: IpdWorkspaceSection.dischargePlanned.name,
                      icon: Icons.fact_check_outlined,
                      label: _tabLabel(l10n.ipdDischargeTabLabel, state.dischargePlannedCount),
                    ),
                    AppTabItem(
                      id: IpdWorkspaceSection.bedBoard.name,
                      icon: Icons.grid_view_outlined,
                      label: l10n.ipdBedBoardTab,
                    ),
                  ],
                  selectedId: _section.name,
                  onTabTapped: (String id) {
                    final IpdWorkspaceSection section = IpdWorkspaceSection.values.firstWhere(
                      (IpdWorkspaceSection s) => s.name == id,
                      orElse: () => IpdWorkspaceSection.admissionQueue,
                    );
                    _selectSection(section);
                  },
                ),
              ),
              SizedBox(width: Theme.of(context).spacing.md),
              AppAccessActionGate(
                requirement: _ipdOperationalWriteRequirement,
                builder: (BuildContext context, bool isAllowed) {
                  return AppButton.primary(
                    label: l10n.ipdStartAdmissionAction,
                    leadingIcon: Icons.person_add_alt_1_outlined,
                    enabled: isAllowed && !state.isSaving,
                    onPressed: isAllowed
                        ? () => unawaited(_openStartAdmissionDialog(context))
                        : null,
                  );
                },
              ),
            ],
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          if (_section.isBedBoard)
            IpdBedBoardPanel(
              state: state,
              canManageBeds: _ipdBedManageRequirement.isAllowed(policy),
              onManageBeds: () => context.go(AppRoutes.roomsBeds.path),
              onOpenAdmission: (IpdBedBoardEntry bed) {
                final String? admissionId =
                    bed.occupantAdmissionId ?? bed.occupantAdmissionDisplayId;
                if (admissionId != null) {
                  unawaited(
                    _openIpdDetailDialogById(context, ref, admissionId),
                  );
                }
              },
            )
          else
            _IpdBoardPanel(
              state: state,
              searchController: _searchController,
              columnVisibilityController: _tableColumnController,
            ),
        ],
      ),
    ),
  );
}

static String _tabLabel(String label, int count) {
  return count > 0 ? '$label ($count)' : label;
}
```

#### 3d. Remove `_selectBoardMode` method

Delete the `_selectBoardMode(IpdBoardMode mode)` method entirely — it is replaced by `_selectSection`.

#### 3e. Remove unused `IpdBoardMode` references in the page

The `_boardMode` field and its references in `build()` are replaced by `_section`. The `IpdBoardMode` enum itself (in entities) should be kept for now since `IpdBedBoardPanel` may reference it; mark it `@Deprecated` if no longer referenced outside the page.

### 4. Add localization strings — File: `frontend/lib/l10n/app_en.arb`

Add these new tab label strings (check for existing keys first — some may already exist):

```json
"ipdAdmissionQueueTabLabel": "Admission Queue",
"ipdActivePatientsTabLabel": "Active Patients",
"ipdTransfersTabLabel": "Transfers",
"ipdDischargeTabLabel": "Discharge"
```

The `ipdBedBoardTab` key already exists.

### 5. Update `IpdAdmissionQuery.fromUri()` — File: `frontend/lib/features/ipd/domain/entities/ipd_entities.dart`

Extend the factory to parse `?section=`:

```dart
factory IpdAdmissionQuery.fromUri(Uri uri) {
  final Map<String, String> params = uri.queryParameters;
  final String? admissionId = _nonEmpty(
    params['id'] ??
        params['admission'] ??
        params['admissionId'] ??
        params['admission_id'],
  );
  return IpdAdmissionQuery(
    search: admissionId ?? params['search'] ?? '',
    wardId: _nonEmpty(params['wardId'] ?? params['ward']),
    focusAdmissionId: admissionId,
    focusPanel: IpdDetailPanelX.fromToken(params['panel']),
    section: _sectionFromParam(params['section']),
  );
}
```

Add `_sectionFromParam` as a static/top-level helper that maps query values to `IpdWorkspaceSection` (matching the `_sectionFromQuery` logic in the page, or centralizing it here in the entity file — prefer centralizing here to keep the entity self-contained).

### 6. Update `IpdAdmissionQuery.copyWith()` — File: `frontend/lib/features/ipd/domain/entities/ipd_entities.dart`

Add the `section` parameter:

```dart
IpdAdmissionQuery copyWith({
  String? search,
  IpdQueueScope? scope,
  String? wardId,
  AppPageRequest? pageRequest,
  String? focusAdmissionId,
  IpdDetailPanel? focusPanel,
  IpdWorkspaceSection? section,
  bool clearWard = false,
  bool clearFocus = false,
}) {
  return IpdAdmissionQuery(
    search: search ?? this.search,
    scope: scope ?? this.scope,
    wardId: clearWard ? null : wardId ?? this.wardId,
    pageRequest: pageRequest ?? this.pageRequest,
    focusAdmissionId: clearFocus
        ? null
        : focusAdmissionId ?? this.focusAdmissionId,
    focusPanel: clearFocus ? null : focusPanel ?? this.focusPanel,
    section: section ?? this.section,
  );
}
```

### 7. Simplify the scope filter in `_IpdBoardPanel` — File: `frontend/lib/features/ipd/presentation/pages/ipd_workspace_page.dart`

Since the scope is now driven by tab selection (not by the search bar's advanced filter), **remove the `_ipdScopeFilterKey` filter group** from the `AppListTableSearch.filterGroups`. Keep only the `_ipdWardFilterKey` filter group for ward filtering within a tab.

Update the `hasActiveFilters` check:

```dart
hasActiveFilters: state.query.wardId != null,
```

Update `onFilterChanged` to only handle ward changes:

```dart
onFilterChanged: (AppSearchBarFilterValue value) async {
  final String? nextWardId = value.option(_ipdWardFilterKey);
  if (nextWardId != state.query.wardId) {
    final AppFailure? failure = await controller.applyWard(nextWardId);
    if (context.mounted) {
      _showFailureIfNeeded(context, failure);
    }
  }
},
```

Update `filterValue` to only include the ward filter:

```dart
filterValue: AppSearchBarFilterValue(
  options: <String, String?>{
    _ipdWardFilterKey: state.query.wardId,
  },
),
```

Remove the `_ipdScopeFilterKey` constant, `_ipdScopeFilterChoices()` function, `_ipdScopeFromFilter()` function, and `_ipdScopeLabel()` function if they become unused.

### 8. Update column visibility storage keys — File: `frontend/lib/features/ipd/presentation/pages/ipd_workspace_page.dart`

In `_IpdBoardPanel`, update the column visibility storage keys to be section-aware (following Reception's `'reception_${_section.name}'` pattern). Since `_IpdBoardPanel` currently doesn't know the section, either:

- Pass the section as a parameter to `_IpdBoardPanel`, or
- Use a fixed key like `'ipd_patients'` (since all patient board tabs share the same columns)

Preferred approach: Keep the current fixed key since all patient board tabs share identical columns (unlike Reception where columns differ per tab).

### 9. No changes to the router — File: `frontend/lib/app/router/app_router.dart`

The existing `GoRoute` at lines 190–198 already passes `IpdAdmissionQuery.fromUri(state.uri)` as `initialQuery`. Since we added `section` parsing to `fromUri()`, tab deep-linking works automatically. No router changes needed.

### 10. Remove unused code

After the refactor:
- Remove the `_selectBoardMode` method from `_IpdWorkspaceContentState`
- Remove the `_boardMode` field
- Remove `AppWorkspaceBoardToggle` usage (the segmented button widget)
- Remove `appWorkspaceToolbarWithLabels` call and the `AppWorkspaceSummaryNotification` list
- Remove the `_ipdScopeFilterKey` constant and related scope filter helpers (`_ipdScopeFilterChoices`, `_ipdScopeFromFilter`, `_ipdScopeLabel`) if now unused
- Check if `IpdBoardMode` enum in entities is still referenced anywhere. If not, mark as `@Deprecated` or remove.

## Shared Components — MUST Reuse

Do NOT create new implementations of these. Import and use them directly:

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` | `package:hosspi_hms/shared/components/components.dart` | Tab bar with `AppTabItem` list, one per `IpdWorkspaceSection` |
| `AppListTable` | `package:hosspi_hms/shared/components/components.dart` | Already used — keep as-is for patient board tabs |
| `AppListTableSearch` | `package:hosspi_hms/shared/components/components.dart` | Already used — keep for search + ward filter |
| `AppButton.primary` | `package:hosspi_hms/shared/components/components.dart` | "Start Admission" button next to tab strip |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_policy.dart` | Gate the primary action button |
| `ResponsivePage` | `package:hosspi_hms/shared/layout/layout.dart` | Replace `AppWorkspace` as outer layout shell |
| `AsyncStateScaffold` | `package:hosspi_hms/shared/components/components.dart` | Already used — keep for loading/error states |
| `WorkflowActionButton` | `package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart` | Already used in table column — keep as-is |
| `AppWorkspaceStatusBadge` | `package:hosspi_hms/shared/layout/layout.dart` | Already used in table cells — keep as-is |
| `IpdBedBoardPanel` | `package:hosspi_hms/features/ipd/presentation/widgets/ipd_bed_board_panel.dart` | Already used — keep as the Bed Board tab body |

## Files to Create

| File Path | Purpose |
|-----------|---------|
| None | No new files needed — all changes are modifications to existing files |

## Files to Modify

| File Path | Changes |
|-----------|---------|
| `frontend/lib/features/ipd/domain/entities/ipd_entities.dart` | Add `IpdWorkspaceSection` enum, `IpdWorkspaceSectionX` extension, add `section` field to `IpdAdmissionQuery`, update `fromUri()` and `copyWith()` |
| `frontend/lib/features/ipd/presentation/pages/ipd_workspace_page.dart` | Replace `AppWorkspace` shell with `ResponsivePage` + `AppTabStrip`, replace `_boardMode` with `_section`, add tab-to-URL routing, remove toolbar summary notifications, move primary action next to tabs, simplify scope filter in `_IpdBoardPanel` |
| `frontend/lib/l10n/app_en.arb` | Add tab label localization strings: `ipdAdmissionQueueTabLabel`, `ipdActivePatientsTabLabel`, `ipdTransfersTabLabel`, `ipdDischargeTabLabel` |

## Files to Delete (if any)

| File Path | Reason |
|-----------|--------|
| None | No files need to be deleted — the Bed Board panel and all supporting widgets are preserved |

## Cleanup: Remove Stale Code

After the refactor, the agent MUST remove all dead/stale code left behind:

- [ ] Remove the `_selectBoardMode` method from `_IpdWorkspaceContentState`.
- [ ] Remove the `_boardMode` field from `_IpdWorkspaceContentState`.
- [ ] Remove the entire `AppWorkspace(...)` widget construction including the `toolbar:` parameter with `appWorkspaceToolbarWithLabels(...)`, `summaryNotifications:`, `secondary:` (containing `AppWorkspaceBoardToggle`), and `primary:`.
- [ ] Remove `_ipdScopeFilterKey`, `_ipdScopeFilterChoices()`, `_ipdScopeFromFilter()`, and `_ipdScopeLabel()` if they are no longer referenced after removing the scope filter group.
- [ ] Remove unused imports (e.g., `AppWorkspaceBoardToggle` if it was explicitly imported).
- [ ] Check if `IpdBoardMode` enum in `ipd_entities.dart` is still referenced outside the page. If `IpdBedBoardPanel` does not use it, deprecate or remove it.
- [ ] Run `dart analyze` to catch any remaining unreferenced declarations and remove them.
- [ ] Verify no test files reference deleted code — update or remove stale tests.

List every file and symbol removed in a "Cleanup Summary" section at the end of the implementation.

## Database Migrations

No database migrations required — schema unchanged. This refactoring is a pure frontend UI restructure. The underlying data models, API contracts, and query patterns remain identical. The `IpdQueueScope` enum values, API endpoints, and server-side filtering are all preserved.

## Responsive Design Requirements

- **Desktop (≥840px):** Full tab strip with all 5 tabs visible, "Start Admission" button to the right of tabs with label + icon. `AppListTable` displays all 7 columns. Bed Board tab shows the grid layout.
- **Tablet (600–839px):** Tab strip wraps if needed (using `AppTabStrip`'s internal `Wrap`). "Start Admission" button may show icon-only if space is constrained. Table shows all columns but relies on column visibility settings for user customization.
- **Mobile (<600px):** Tab strip wraps to multiple rows. "Start Admission" button below tabs or icon-only. `AppListTable` switches to `mobileItemBuilder` — renders `_IpdMobileAdmissionRow` cards. Bed Board panel's internal responsive behavior handles mobile layout.

Use `AppBreakpoints.of(context)` from `frontend/lib/core/responsive/app_breakpoints.dart` for breakpoint detection. Use `ResponsiveSpacing.pagePaddingFor(breakpoint)` for consistent padding (handled automatically by `ResponsivePage`).

## Verification Steps

After implementation, the agent MUST run these commands and confirm they pass:

```bash
cd frontend

# Format
dart format .

# Analyze
dart analyze --fatal-infos

# Run tests related to this screen
flutter test test/features/ipd/

# Run shared component tests to ensure no regressions
flutter test test/shared/
```

## Testing Requirements

Write or update these tests:

- [ ] Tab navigation: switching tabs updates the URL `?section=` parameter
- [ ] Deep linking: navigating directly to `/ipd?section=active` renders the Active Patients tab
- [ ] Deep linking: navigating to `/ipd?section=bed-board` renders the Bed Board tab
- [ ] Table data: each patient board tab calls `controller.applyScope()` with the correct `IpdQueueScope`
- [ ] Bed Board tab: selecting the Bed Board tab calls `controller.loadBedBoard()`
- [ ] Search: typing in the search bar filters table rows via `controller.applySearch()`
- [ ] Ward filter: ward filter in advanced filter dialog applies via `controller.applyWard()`
- [ ] Primary action: "Start Admission" button is visible on all tabs and opens `IpdStartAdmissionDialog`
- [ ] Tab labels: tab labels include count in parentheses when count > 0
- [ ] Responsive layout: widget tests verify `AppTabStrip` renders on desktop and `mobileItemBuilder` is used on mobile
- [ ] No regressions: existing detail dialog, clinical actions, and bed board functionality still work

## Acceptance Criteria

The refactor is complete when ALL of the following are true:

- [ ] The screen uses `AppTabStrip` with 5 tabs matching the Reception workspace pattern
- [ ] Each tab has its own URL via `?section=` that supports deep linking
- [ ] The primary action button ("Start Admission") is positioned next to the tab strip (not in a toolbar)
- [ ] Patient board tabs use `AppListTable` with integrated search and ward filter
- [ ] The scope filter is driven by tab selection, not by a search bar filter group
- [ ] The Bed Board is the last tab and renders `IpdBedBoardPanel` unchanged
- [ ] No shared component is re-implemented — only imported and used
- [ ] The layout uses `ResponsivePage` (not `AppWorkspace`) as the outer shell
- [ ] The layout is fully responsive across mobile, tablet, and desktop
- [ ] All old toolbar code (summary notifications, board toggle) is removed — no stale code remains
- [ ] Domain-specific business logic, clinical actions, and data are preserved
- [ ] No database migrations required — schema unchanged
- [ ] `dart analyze` reports no new issues — zero unused imports, zero unreferenced declarations
- [ ] All tests pass (no stale test references to removed code)
