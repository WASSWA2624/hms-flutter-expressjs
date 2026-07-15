# Standardize Patients Screen

## Objective

Refactor the Patient Registry screen (`/patients`) to match the standardized tab-and-table layout used by the Reception workspace. The screen currently renders a flat, single-list view with no tab navigation and a monolithic 6000+ line page file. After this refactor it will use routable `AppTabStrip` tabs (All Patients, Active, Admitted, Balance Due) with URL-synced section state, per-tab column configurations, and the canonical `ResponsivePage` + `AppTabStrip` + `AppListTable` widget tree — exactly mirroring the Reception workspace pattern. All existing business logic (server-side pagination, advanced filters, patient detail dialog, registration, realtime sync) must be preserved.

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification — all information needed is in this prompt. Run formatting and analysis after implementation.

## Current State (from audit)

- **Main page file:** `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart` — 6000+ lines, uses `part` directive to include `patient_detail_dialog_body.dart`.
- **Controller:** `frontend/lib/features/patients/presentation/controllers/patient_registry_controller.dart` — `PatientRegistryController` (`AsyncNotifier<Result<PatientRegistryState>>`), provider: `patientRegistryControllerProvider`.
- **Entities:** `frontend/lib/features/patients/domain/entities/patient_entities.dart` — `Patient`, `PatientListQuery`, `PatientRegistryState`, `PatientRegistryOverview`, `PatientReferenceData`, `PatientDetail`, etc.
- **Repository:** `frontend/lib/features/patients/data/repositories/patient_repository_impl.dart` — `PatientRepositoryImpl`, provider: `patientRepositoryProvider`.
- **DTOs:** `frontend/lib/features/patients/data/dtos/patient_dtos.dart`.
- **Access helpers:** `frontend/lib/features/patients/presentation/patient_registry_access.dart` — `isPharmacyRegistryReader`, `isBillingRegistryReader`.
- **Widgets (part/barrel):**
  - `frontend/lib/features/patients/presentation/widgets/patient_detail_dialog_body.dart` (`part of` page)
  - `frontend/lib/features/patients/presentation/widgets/patient_detail_header.dart`
  - `frontend/lib/features/patients/presentation/widgets/patient_detail_quick_actions.dart`
  - `frontend/lib/features/patients/presentation/widgets/patient_detail_active_work.dart`
  - `frontend/lib/features/patients/presentation/widgets/patient_active_work_helpers.dart`
  - `frontend/lib/features/patients/presentation/widgets/patient_panels.dart`
  - `frontend/lib/features/patients/presentation/widgets/patient_billing_context_panel.dart`
  - `frontend/lib/features/patients/presentation/widgets/patient_pharmacy_context_panel.dart`
  - `frontend/lib/features/patients/presentation/widgets/patient_form_fields.dart`
  - `frontend/lib/features/patients/presentation/widgets/patient_widgets.dart` (barrel)
  - `frontend/lib/features/patients/presentation/widgets/patient_detail_dialog.dart` (re-export)
  - `frontend/lib/features/patients/presentation/widgets/patient_discharge_planning_dialog.dart`
- **Route definition:** `frontend/lib/app/router/app_routes.dart` line ~257 (`AppRoutes.patients`, path `/patients`).
- **GoRoute registration:** `frontend/lib/app/router/app_router.dart` line ~132, builder passes `PatientListQuery.fromUri(state.uri)`.
- **Shell destination:** `frontend/lib/app/router/app_router.dart` line ~517, in the patient-access group.
- **Tests:**
  - `frontend/test/features/patients/presentation/patient_registry_page_test.dart`
  - `frontend/test/features/patients/presentation/patient_registry_access_test.dart`
  - `frontend/test/features/patients/presentation/patient_active_work_helpers_test.dart`
  - `frontend/test/features/patients/data/patient_repository_impl_test.dart`

### Current layout / structure:

```
PatientRegistryPage (ConsumerWidget)
 └─ AppAccessGate (patientRead)
     └─ AsyncStateScaffold<PatientRegistryState>
         └─ _PatientRegistryContent (ConsumerStatefulWidget)
             └─ AppWorkspace
                 ├─ toolbar: AppWorkspaceToolbarConfig with "Register Patient" primary button
                 └─ body: _PatientList → AppListTable<Patient>
                     ├─ 8 columns (Number, Name, Age/Sex, Phone/ID, Alert, Visit, Status, Next Action)
                     ├─ search: AppListTableSearch with advanced filter dialog
                     ├─ server-side pagination via page/onPageChanged
                     └─ mobileItemBuilder: _PatientMobileRow
```

### Problems / inconsistencies vs. Reception reference:

1. **No tab navigation** — flat single-list; no `AppTabStrip`.
2. **No URL-synced section state** — `PatientListQuery.fromUri` parses `search/patientId/contact/has_outstanding_balance/has_active_admission` but has no `section` parameter for tab routing.
3. **No per-tab column customization** — all 8 columns are shown regardless of context.
4. **Uses `AppWorkspace`** instead of `ResponsivePage` directly — the Reception workspace uses `ResponsivePage` + `Column` + `Row(AppTabStrip, AppButton)` + `AppListTable`. The patients page wraps in `AppWorkspace` which adds its own header/toolbar chrome; the tabbed pattern skips that and puts tabs + primary action in a `Row` directly.
5. **Monolithic file** — the page + filter dialog + table columns + cell widgets + helper functions are all in one 6000+ line file (plus a `part` file for the detail dialog body).
6. **Tab counts missing** — the `PatientRegistryOverview` has `totalPatients`, `activePatients`, `activeAdmissions`, `unpaidInvoices` counts that should appear as tab badge counts, but they are not surfaced in the UI.

## Reference Implementation

Read these files to understand the target patterns (do NOT modify them):

| File | Key Pattern to Extract |
|------|----------------------|
| `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` | Full tabbed-workspace widget tree: `AsyncStateScaffold` → `ResponsivePage` → `Column` → `Row(AppTabStrip, AppButton.primary)` → `AppListTable`. Tab enum iteration, `_sectionIcon()`, `_sectionLabel()`, `_sectionCount()`, `_columnsForSection()`, `_updateUrlForSection()`, search matcher, mobile item builder. |
| `frontend/lib/features/reception/domain/entities/reception_entities.dart` | `ReceptionDeskSection` enum + `ReceptionWorkspaceQuery` with `section` field and `fromUri` factory. |
| `frontend/lib/shared/components/app_tab_strip.dart` | `AppTabStrip` constructor: `tabs` (`List<AppTabItem>`), `selectedId`, `onTabTapped`. `AppTabItem`: `id`, `icon`, `label`. |
| `frontend/lib/shared/components/app_list_table.dart` | `AppListTable<T>` constructor params. `AppListTableSearch<T>` config. `AppListTableColumnVisibilityController<T>`. |
| `frontend/lib/shared/layout/responsive_page.dart` | `ResponsivePage` with `maxWidth: PageMaxWidth.dataHeavy`. |
| `frontend/lib/shared/layout/app_workspace.dart` | `AppWorkspace` (current patients page uses this — will be replaced by direct `ResponsivePage`). |
| `frontend/lib/core/responsive/app_breakpoints.dart` | `AppBreakpoints`, `AppBreakpoint`, `ResponsiveBuilder`. Breakpoints: xs (<360), sm (360-599), md (600-839), lg (840-1199), xl (1200-1599), xxl (1600+). `isMobile` = xs/sm. |

## Target Architecture

### Tab Configuration

| Tab Name | Section Enum Value | Route Query `?section=` | Description | Icon | Primary Action Button |
|----------|-------------------|------------------------|-------------|------|----------------------|
| All Patients | `all` | `all` (default) | Full patient registry, no filter | `Icons.people_outlined` | Register Patient → `RegisterNewPatientDialog` |
| Active | `active` | `active` | Active patients only (`isActive=true`) | `Icons.how_to_reg_outlined` | Register Patient → `RegisterNewPatientDialog` |
| Admitted | `admitted` | `admitted` | Currently hospitalized (`hasActiveAdmission=true`) | `Icons.local_hospital_outlined` | Register Patient → `RegisterNewPatientDialog` |
| Balance Due | `balanceDue` | `balance-due` | Outstanding balance (`hasOutstandingBalance=true`) | `Icons.payments_outlined` | Register Patient → `RegisterNewPatientDialog` |

Tab badge counts (from `PatientRegistryOverview`):

| Tab | Count Source |
|-----|-------------|
| All Patients | `overview.totalPatients` |
| Active | `overview.activePatients` |
| Admitted | `overview.activeAdmissions` |
| Balance Due | `overview.unpaidInvoices` |

### Routing

**No changes to `app_routes.dart` or `app_router.dart` route definitions are needed.** The `/patients` GoRoute already passes `PatientListQuery.fromUri(state.uri)` to the page. The only change is:

1. **Add a `section` field to `PatientListQuery`** — parse `?section=` from the URI in `fromUri`.
2. **Add a `PatientRegistrySection` enum** to `patient_entities.dart` — values: `all`, `active`, `admitted`, `balanceDue`.
3. **URL update on tab change** — use `GoRouter.of(context).replace<void>(location)` with `AppRoutes.patients.location(queryParameters: {'section': sectionQueryValue})`, exactly like Reception's `_updateUrlForSection`.

### Page Layout

Target widget tree (mirrors Reception):

```
PatientRegistryPage (ConsumerWidget)
 └─ AppAccessGate (patientRead)
     └─ AsyncStateScaffold<PatientRegistryState>
         └─ _PatientRegistryContent (ConsumerStatefulWidget)
             └─ ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)
                 └─ SizedBox(width: double.infinity)
                     └─ Column(crossAxisAlignment: CrossAxisAlignment.stretch)
                         ├─ Row
                         │   ├─ Expanded → AppTabStrip(tabs: [...], selectedId: _section.name, onTabTapped: ...)
                         │   └─ AppAccessActionGate → AppButton.primary("Register Patient")
                         ├─ SizedBox(height: theme.spacing.md)
                         └─ AppListTable<Patient>(
                                page: state.page,
                                columns: _columnsForSection(_section),
                                search: AppListTableSearch<Patient>(...),
                                columnVisibilityStorageKey: 'patients_${_section.name}',
                                columnWidthStorageKey: 'patients_cw_${_section.name}',
                                mobileItemBuilder: _mobileItemBuilder,
                                onRowSelected: → showPatientDetailDialog,
                                onPageChanged: → applyQuery with section filter,
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                isLoading: state.isRefreshingList,
                            )
```

**Key differences from current layout:**
- Replace `AppWorkspace` wrapper with direct `ResponsivePage` + `Column` + `Row`.
- Add `AppTabStrip` inside the `Row`, before the primary action button.
- Per-tab columns via `_columnsForSection(PatientRegistrySection section)`.
- Per-tab column visibility persistence keys: `patients_${section.name}`.

### Per-Tab Column Definitions

**All Patients tab** — all 8 existing columns:
`Patient Number`, `Patient Name`, `Age/Sex`, `Phone/Identifier`, `Alert`, `Visit`, `Status`, `Next Action`

**Active tab** — 7 columns (drop `Status` since all rows are active):
`Patient Number`, `Patient Name`, `Age/Sex`, `Phone/Identifier`, `Alert`, `Visit`, `Next Action`

**Admitted tab** — 7 columns (drop `Status`, show `Visit` which already contains admission context):
`Patient Number`, `Patient Name`, `Age/Sex`, `Phone/Identifier`, `Alert`, `Visit`, `Next Action`

**Balance Due tab** — 7 columns (drop `Alert`, keep `Status` for outstanding balance context):
`Patient Number`, `Patient Name`, `Age/Sex`, `Phone/Identifier`, `Visit`, `Status`, `Next Action`

### Data & State Management

**No changes to the controller or repository are required.** The existing `PatientRegistryController` and its methods (`applyQuery`, `refresh`, `selectPatient`, `createPatient`, etc.) already support all needed query parameters via `PatientListQuery`.

The tab-switching logic should:
1. Map `PatientRegistrySection` to `PatientListQuery` filter fields:
   - `all` → no filter applied (default query)
   - `active` → `isActive: true`
   - `admitted` → `hasActiveAdmission: true`
   - `balanceDue` → `hasOutstandingBalance: true`
2. Call `ref.read(patientRegistryControllerProvider.notifier).applyQuery(filteredQuery)` on tab change.
3. Reset pagination to first page on tab change.

The `PatientRegistryOverview` (fetched at load time and refreshed on sync) already provides the count values needed for tab badges.

## Implementation Steps

### 1. Add `PatientRegistrySection` enum — File: `frontend/lib/features/patients/domain/entities/patient_entities.dart`

Add the following enum **before** the `PatientListQuery` class:

```dart
enum PatientRegistrySection {
  all,
  active,
  admitted,
  balanceDue,
}
```

### 2. Add `section` field to `PatientListQuery` — File: `frontend/lib/features/patients/domain/entities/patient_entities.dart`

- Add `this.section = PatientRegistrySection.all` to the `PatientListQuery` constructor.
- Add `final PatientRegistrySection section;` field.
- In `PatientListQuery.fromUri`, parse `section` from the URI query parameters:

```dart
PatientRegistrySection parseSection(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'active':
      return PatientRegistrySection.active;
    case 'admitted':
      return PatientRegistrySection.admitted;
    case 'balance-due':
    case 'balance_due':
    case 'balancedue':
      return PatientRegistrySection.balanceDue;
    default:
      return PatientRegistrySection.all;
  }
}
```

Call: `section: parseSection(pick(<String>['section', 'tab']))`.

- Add `section` to `copyWith` (no `clearSection` needed — always has a value).
- Add `section` to `signature` getter.

### 3. Add section-to-query filter helper — File: `frontend/lib/features/patients/domain/entities/patient_entities.dart`

Add a method or extension on `PatientRegistrySection`:

```dart
extension PatientRegistrySectionFilter on PatientRegistrySection {
  PatientListQuery applyToQuery(PatientListQuery query) {
    switch (this) {
      case PatientRegistrySection.all:
        return query.copyWith(
          clearIsActive: true,
          clearHasActiveAdmission: true,
          clearHasOutstandingBalance: true,
        );
      case PatientRegistrySection.active:
        return query.copyWith(
          isActive: true,
          clearHasActiveAdmission: true,
          clearHasOutstandingBalance: true,
        );
      case PatientRegistrySection.admitted:
        return query.copyWith(
          hasActiveAdmission: true,
          clearIsActive: true,
          clearHasOutstandingBalance: true,
        );
      case PatientRegistrySection.balanceDue:
        return query.copyWith(
          hasOutstandingBalance: true,
          clearIsActive: true,
          clearHasActiveAdmission: true,
        );
    }
  }
}
```

### 4. Add section URL query-value mapping — File: `frontend/lib/features/patients/domain/entities/patient_entities.dart`

Add to the `PatientRegistrySectionFilter` extension:

```dart
String get queryValue {
  switch (this) {
    case PatientRegistrySection.all:
      return 'all';
    case PatientRegistrySection.active:
      return 'active';
    case PatientRegistrySection.admitted:
      return 'admitted';
    case PatientRegistrySection.balanceDue:
      return 'balance-due';
  }
}
```

### 5. Refactor `PatientRegistryPage` — File: `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart`

This is the core refactor. Transform the page from `AppWorkspace`-wrapped to `ResponsivePage` + `AppTabStrip` + `AppListTable`.

#### 5a. Update imports

Add:
```dart
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/shared/components/app_tab_strip.dart';
import 'package:hosspi_hms/shared/layout/responsive_page.dart';
```

Remove (if no longer needed after removing `AppWorkspace`):
```dart
import 'package:hosspi_hms/shared/layout/layout.dart'; // only if AppWorkspace was the sole reason for this import — check carefully
```

#### 5b. Modify `_PatientRegistryContent`

Add state fields:

```dart
late PatientRegistrySection _section;
```

In `initState`, initialize `_section` from the initial query:

```dart
_section = widget.initialQuery?.section ?? PatientRegistrySection.all;
```

Add URL update method (follows Reception pattern):

```dart
void _updateUrlForSection(PatientRegistrySection section) {
  final Map<String, String> queryParameters = <String, String>{
    'section': section.queryValue,
  };
  final String location = AppRoutes.patients.location(
    queryParameters: queryParameters,
  );
  GoRouter.of(context).replace<void>(location);
}
```

Add tab change handler:

```dart
Future<void> _handleTabChanged(PatientRegistrySection section) async {
  if (section == _section) return;
  setState(() => _section = section);
  _updateUrlForSection(section);
  _tableSearchController.clear();
  final PatientListQuery baseQuery = const PatientListQuery().copyWith(
    section: section,
  );
  final PatientListQuery filteredQuery = section.applyToQuery(baseQuery);
  final AppFailure? failure = await ref
      .read(patientRegistryControllerProvider.notifier)
      .applyQuery(filteredQuery);
  if (mounted) {
    await _showFailureIfNeeded(context, failure);
  }
}
```

#### 5c. Replace the `build` method of `_PatientRegistryContentState`

Replace the current `AppWorkspace` tree with:

```dart
@override
Widget build(BuildContext context) {
  final l10n = context.l10n;
  final ThemeData theme = Theme.of(context);

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
                    for (final PatientRegistrySection section
                        in PatientRegistrySection.values)
                      AppTabItem(
                        id: section.name,
                        icon: _sectionIcon(section),
                        label: '${_sectionLabel(l10n, section)} (${_sectionCount(widget.state, section)})',
                      ),
                  ],
                  selectedId: _section.name,
                  onTabTapped: (String tabId) {
                    for (final PatientRegistrySection section
                        in PatientRegistrySection.values) {
                      if (section.name == tabId) {
                        unawaited(_handleTabChanged(section));
                        break;
                      }
                    }
                  },
                ),
              ),
              AppAccessActionGate(
                requirement: _PatientRegistryContent._writeRequirement,
                builder: (BuildContext context, bool isAllowed) {
                  return AppButton.primary(
                    leadingIcon: Icons.person_add_alt_1_outlined,
                    label: l10n.patientsRegisterPatientAction,
                    semanticLabel: l10n.patientsRegisterPatientAction,
                    tooltip: l10n.patientsRegisterPatientAction,
                    enabled: isAllowed,
                    onPressed: () {
                      _openRegisterPatientDialog(context, ref);
                    },
                  );
                },
              ),
            ],
          ),
          SizedBox(height: theme.extension<AppSpacingThemeExtension>()?.md ?? 12),
          _PatientList(
            state: widget.state,
            section: _section,
            searchController: _tableSearchController,
            columnVisibilityController: _tableColumnController,
          ),
        ],
      ),
    ),
  );
}
```

**Note:** Check the exact way spacing is accessed in the Reception page (e.g., `theme.spacing.md`). If the codebase uses `theme.extension<AppSpacingThemeExtension>()?.md`, follow that pattern. If it uses a different accessor (like `AppSpacing.md` or a direct theme extension getter), mirror the Reception code exactly.

#### 5d. Add helper functions for tab display

Add these private functions to the file (mirror the Reception pattern):

```dart
IconData _sectionIcon(PatientRegistrySection section) {
  switch (section) {
    case PatientRegistrySection.all:
      return Icons.people_outlined;
    case PatientRegistrySection.active:
      return Icons.how_to_reg_outlined;
    case PatientRegistrySection.admitted:
      return Icons.local_hospital_outlined;
    case PatientRegistrySection.balanceDue:
      return Icons.payments_outlined;
  }
}

String _sectionLabel(AppLocalizations l10n, PatientRegistrySection section) {
  switch (section) {
    case PatientRegistrySection.all:
      return l10n.patientsTabAll;
    case PatientRegistrySection.active:
      return l10n.patientsTabActive;
    case PatientRegistrySection.admitted:
      return l10n.patientsTabAdmitted;
    case PatientRegistrySection.balanceDue:
      return l10n.patientsTabBalanceDue;
  }
}

int _sectionCount(PatientRegistryState state, PatientRegistrySection section) {
  switch (section) {
    case PatientRegistrySection.all:
      return state.overview.totalPatients;
    case PatientRegistrySection.active:
      return state.overview.activePatients;
    case PatientRegistrySection.admitted:
      return state.overview.activeAdmissions;
    case PatientRegistrySection.balanceDue:
      return state.overview.unpaidInvoices;
  }
}
```

#### 5e. Add per-tab column definitions

Modify `_PatientList` to accept a `section` parameter and select columns based on it:

```dart
List<AppListTableColumn<Patient>> _columnsForSection(
  BuildContext context,
  WidgetRef ref,
  PatientRegistrySection section,
  AppLocalizations l10n,
) {
  // Build the full set of available columns
  final AppListTableColumn<Patient> numberCol = /* existing Patient Number column */;
  final AppListTableColumn<Patient> nameCol = /* existing Patient Name column */;
  final AppListTableColumn<Patient> ageSexCol = /* existing Age/Sex column */;
  final AppListTableColumn<Patient> phoneCol = /* existing Phone/Identifier column */;
  final AppListTableColumn<Patient> alertCol = /* existing Alert column */;
  final AppListTableColumn<Patient> visitCol = /* existing Visit column */;
  final AppListTableColumn<Patient> statusCol = /* existing Status column */;
  final AppListTableColumn<Patient> nextActionCol = /* existing Next Action column */;

  switch (section) {
    case PatientRegistrySection.all:
      return [numberCol, nameCol, ageSexCol, phoneCol, alertCol, visitCol, statusCol, nextActionCol];
    case PatientRegistrySection.active:
      return [numberCol, nameCol, ageSexCol, phoneCol, alertCol, visitCol, nextActionCol];
    case PatientRegistrySection.admitted:
      return [numberCol, nameCol, ageSexCol, phoneCol, alertCol, visitCol, nextActionCol];
    case PatientRegistrySection.balanceDue:
      return [numberCol, nameCol, ageSexCol, phoneCol, visitCol, statusCol, nextActionCol];
  }
}
```

Extract the existing column definitions from the current `_PatientList.build` method into this function. Each `AppListTableColumn<Patient>` definition remains identical — just the selection changes per section.

#### 5f. Update `_PatientList` widget

Add `section` to the constructor:

```dart
class _PatientList extends ConsumerWidget {
  const _PatientList({
    required this.state,
    required this.section,
    required this.searchController,
    required this.columnVisibilityController,
  });

  final PatientRegistryState state;
  final PatientRegistrySection section;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<Patient> columnVisibilityController;
```

In `build`, replace the hardcoded `columns` list with:

```dart
columns: _columnsForSection(context, ref, section, l10n),
```

Update column visibility and width storage keys to be per-section:

```dart
columnVisibilityStorageKey: 'patients_${section.name}',
columnWidthStorageKey: 'patients_cw_${section.name}',
```

Update `onPageChanged` to apply the section filter:

```dart
onPageChanged: (AppPageRequest request) async {
  final PatientListQuery baseQuery = state.query.copyWith(
    pageRequest: request,
    section: section,
  );
  final PatientListQuery filteredQuery = section.applyToQuery(baseQuery);
  final AppFailure? failure = await ref
      .read(patientRegistryControllerProvider.notifier)
      .applyQuery(filteredQuery);
  if (context.mounted) {
    await _showFailureIfNeeded(context, failure);
  }
},
```

### 6. Add localization strings — File: appropriate `.arb` files

Add the following localization keys (find the ARB files used by this project — likely `frontend/lib/l10n/app_en.arb` or similar):

```json
"patientsTabAll": "All Patients",
"patientsTabActive": "Active",
"patientsTabAdmitted": "Admitted",
"patientsTabBalanceDue": "Balance Due"
```

If the project uses a different localization approach (code-generated, extension methods, etc.), add the keys following the existing pattern. Search for existing keys like `patientsTitle`, `patientsLoadingTitle` to find the correct file and format.

### 7. Update search and filter to preserve section context

When the search debounce fires in `_handleTableSearchChanged`, ensure the section filter is preserved:

In `_applyTableSearch`, update:

```dart
Future<void> _applyTableSearch(String query) async {
  final String search = query.trim();
  if (search == widget.state.query.search.trim()) {
    return;
  }

  final PatientListQuery baseQuery = widget.state.query.copyWith(
    search: search,
    section: _section,
    pageRequest: widget.state.query.pageRequest.first(),
  );
  final PatientListQuery filteredQuery = _section.applyToQuery(baseQuery);
  final AppFailure? failure = await ref
      .read(patientRegistryControllerProvider.notifier)
      .applyQuery(filteredQuery);
  if (mounted) {
    await _showFailureIfNeeded(context, failure);
  }
}
```

Similarly, update `_applyPatientFilterDraft` to include the section filter when applying advanced filters.

### 8. Preserve the `part` file relationship

The `patient_detail_dialog_body.dart` uses `part of` pointing to `patient_registry_page.dart`. This `part` relationship must be preserved. The detail dialog code inside the `part` file does not need changes — it continues to work as-is since it accesses the controller via `ref.read(patientRegistryControllerProvider.notifier)`.

### 9. Remove unused imports

After replacing `AppWorkspace` with `ResponsivePage` + direct widget composition:
- Remove the `AppWorkspace`-related import if it is no longer used anywhere in the file.
- Keep the `AppWorkspaceToolbarConfig` / `appWorkspaceToolbarWithLabels` import **only if** it is still referenced (check the detail dialog body or other widgets in the file). If unused, remove it.
- Remove `import 'package:hosspi_hms/app/router/app_route_icons.dart';` only if `AppRouteIcons.patients` is no longer used. (It was used as `leadingIcon` in `AppWorkspace` — check if it's still needed.)

## Shared Components — MUST Reuse

Do NOT create new implementations of these. Import and use them directly:

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` | `package:hosspi_hms/shared/components/app_tab_strip.dart` | Tab bar above the table. Constructor: `AppTabStrip(tabs: [...], selectedId: ..., onTabTapped: ...)` |
| `AppTabItem` | `package:hosspi_hms/shared/components/app_tab_strip.dart` | Tab definition: `AppTabItem(id: ..., icon: ..., label: ...)` |
| `AppListTable<Patient>` | `package:hosspi_hms/shared/components/components.dart` | Data table — already in use, keep using it with per-section columns |
| `AppListTableSearch<Patient>` | `package:hosspi_hms/shared/components/components.dart` | Search bar config — already in use, preserve all existing search behavior |
| `AppListTableColumnVisibilityController<Patient>` | `package:hosspi_hms/shared/components/components.dart` | Column visibility — already in use, update storage keys to be per-section |
| `AppButton.primary` | `package:hosspi_hms/shared/components/app_button.dart` | Primary action button — already in use |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Permission gate — already in use |
| `AsyncStateScaffold<PatientRegistryState>` | `package:hosspi_hms/shared/components/components.dart` | Async state wrapper — already in use |
| `ResponsivePage` | `package:hosspi_hms/shared/layout/responsive_page.dart` | Page layout with `maxWidth: PageMaxWidth.dataHeavy` |
| `AppWorkspaceStatePanel.empty` | `package:hosspi_hms/shared/layout/layout.dart` | Empty state — already in use in table `emptyBuilder` |
| `RegisterNewPatientDialog` | `package:hosspi_hms/shared/patient_actions/register_new_patient_dialog.dart` | Registration dialog — already in use |
| `showPatientDetailDialog` | `package:hosspi_hms/shared/patient_actions/patient_detail_dialog.dart` | Detail dialog — already in use |

## Files to Create

No new files need to be created. All changes are modifications to existing files.

## Files to Modify

| File Path | Changes |
|-----------|---------|
| `frontend/lib/features/patients/domain/entities/patient_entities.dart` | Add `PatientRegistrySection` enum, `PatientRegistrySectionFilter` extension, `section` field to `PatientListQuery`, update `fromUri`, `copyWith`, `signature` |
| `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart` | Replace `AppWorkspace` with `ResponsivePage` + `AppTabStrip` + `AppListTable` tabbed layout. Add `_section` state, `_handleTabChanged`, `_updateUrlForSection`, `_sectionIcon`, `_sectionLabel`, `_sectionCount`, `_columnsForSection`. Update `_PatientList` to accept `section` param. Update search/filter to preserve section context. Update imports. |
| `frontend/lib/l10n/app_en.arb` (or equivalent ARB file) | Add `patientsTabAll`, `patientsTabActive`, `patientsTabAdmitted`, `patientsTabBalanceDue` localization strings |

## Files to Delete (if any)

No files need to be deleted. The refactor restructures the UI within existing files.

## Cleanup: Remove Stale Code

After the refactor, the agent MUST remove all dead/stale code left behind:

- [ ] Remove the `AppWorkspace` wrapper usage from `_PatientRegistryContentState.build` — replaced by `ResponsivePage` + `Column` + `Row`.
- [ ] Remove `appWorkspaceToolbarWithLabels` call if no longer used (it was used to wrap the primary action button in `AppWorkspace.toolbar`).
- [ ] Remove the `AppRouteIcons.patients` import/usage if it was only used as `AppWorkspace.leadingIcon`.
- [ ] Remove unused imports across all modified files.
- [ ] Run `dart analyze` to catch any remaining unreferenced declarations and remove them.
- [ ] Verify no test files reference deleted code — update or remove stale tests.

List every file and symbol removed in a "Cleanup Summary" section at the end of the implementation.

## Database Migrations

No database migrations required — schema unchanged. The refactor only restructures the Flutter UI layer. The `PatientListQuery` already supports `isActive`, `hasActiveAdmission`, and `hasOutstandingBalance` filter fields, and the backend API already handles these query parameters. No new columns, tables, or indexes are needed.

## Responsive Design Requirements

- **Desktop (≥840px / `lg`+):** Full data table with all per-tab columns visible, `AppTabStrip` and primary action button in a horizontal `Row`, column resize handles enabled.
- **Tablet (600–839px / `md`):** Same table layout (this is handled automatically by `AppListTable` with `displayMode: AppListTableDisplayMode.adaptive`). Tab labels may truncate. Action button may collapse to icon-only via `AppActionLabelScope`.
- **Mobile (<600px / `xs`/`sm`):** `AppListTable` automatically switches to `mobileItemBuilder` rendering each row via `_PatientMobileRow`. `AppTabStrip` wraps to multiple lines. Primary action button should remain accessible.

Use `AppBreakpoints` from `package:hosspi_hms/core/responsive/app_breakpoints.dart` for any breakpoint-dependent logic. The existing `AppListTable.displayMode: AppListTableDisplayMode.adaptive` already handles the table/list switch — no manual breakpoint logic needed for the table itself.

## Verification Steps

After implementation, the agent MUST run these commands and confirm they pass:

```bash
# Format
dart format frontend/lib/features/patients/ frontend/lib/app/router/

# Analyze
dart analyze frontend/ --fatal-infos

# Run tests related to this screen
flutter test test/features/patients/

# Run shared component tests to ensure no regressions
flutter test test/shared/
```

## Testing Requirements

Write or update these tests:

- [ ] Tab navigation: switching tabs updates the URL query parameter `?section=`
- [ ] Deep linking: navigating to `/patients?section=admitted` renders the Admitted tab as selected
- [ ] Tab data: each tab applies the correct filter to `PatientListQuery` (assert `isActive`, `hasActiveAdmission`, `hasOutstandingBalance` fields)
- [ ] Tab counts: badge counts on tabs match `PatientRegistryOverview` values
- [ ] Per-tab columns: verify column count differs per section (8 for All, 7 for Active/Admitted/Balance Due)
- [ ] Search: typing in the search bar filters table rows and preserves the active section filter
- [ ] Advanced filter dialog: filter button opens the filter UI and applies filters while preserving section
- [ ] Primary action: "Register Patient" button is present on all tabs
- [ ] Mobile layout: widget tests verify `mobileItemBuilder` renders at mobile breakpoint
- [ ] No regressions: existing page test expectations still pass (patient detail dialog opens on row click, registration dialog opens on primary action)

## Acceptance Criteria

The refactor is complete when ALL of the following are true:

- [ ] The screen uses routable `AppTabStrip` tabs matching the Reception workspace pattern, with 4 tabs: All Patients, Active, Admitted, Balance Due
- [ ] Each tab has its own URL via `?section=` that supports deep linking
- [ ] Tab badge counts display `totalPatients`, `activePatients`, `activeAdmissions`, `unpaidInvoices` from the overview
- [ ] The primary action button ("Register Patient") is contextual and positioned correctly beside the tab strip
- [ ] The page body uses `AppListTable<Patient>` with per-section columns, integrated search, advanced filter, and column visibility settings (per-section persistence keys)
- [ ] The layout uses `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)` directly instead of `AppWorkspace`
- [ ] No shared component is re-implemented — only imported and used
- [ ] The layout is fully responsive across mobile, tablet, and desktop (automatic via `AppListTable.adaptive` + `ResponsivePage`)
- [ ] All old/duplicate layout code is removed — no stale `AppWorkspace` wrapper remains
- [ ] Domain-specific business logic is preserved: server-side pagination, advanced filters, patient detail dialog, registration, realtime sync, duplicate management, all patient actions
- [ ] No database migrations required — schema unchanged (explicitly confirmed)
- [ ] The `part` file relationship with `patient_detail_dialog_body.dart` is preserved and functional
- [ ] `dart analyze` reports no new issues — zero unused imports, zero unreferenced declarations
- [ ] All tests pass (no stale test references to removed code)
- [ ] New localization strings are added for tab labels
