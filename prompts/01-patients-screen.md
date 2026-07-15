# Standardize Patients Screen

## Objective

Refactor the Patient Registry screen (`/patients`) to match the standardized tab-and-table layout used by the Reception workspace. The screen currently renders a flat, single-list view with no tab navigation and a monolithic ~6000-line page file wrapped in `AppWorkspace`. After this refactor it will use routable `AppTabStrip` tabs (All Patients, Active, Admitted, Balance Due) with URL-synced section state via `?section=` query parameter, per-tab column configurations, and the canonical `ResponsivePage` → `Column` → `Row(AppTabStrip, AppButton.primary)` → `AppListTable` widget tree — exactly mirroring the Reception workspace pattern. All existing business logic (server-side pagination, advanced filters, patient detail dialog, registration, duplicate management, realtime sync, pharmacist/billing reader views) must be preserved.

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification — all information needed is in this prompt. Run formatting and analysis after implementation.

## Current State (from audit)

### Files

- **Main page file:** `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart` — ~6000 lines, uses `part` directive to include `patient_detail_dialog_body.dart`. Contains `PatientRegistryPage`, `_PatientRegistryContent`, `_PatientList`, `_PatientAdvancedFiltersDialog`, `_PatientFilterDraft`, `_PatientMobileRow`, plus ~20 private cell/helper widgets and top-level functions.
- **Controller:** `frontend/lib/features/patients/presentation/controllers/patient_registry_controller.dart` — `PatientRegistryController` (`AsyncNotifier<Result<PatientRegistryState>>`), provider: `patientRegistryControllerProvider`. ~950 lines. Methods: `applyQuery`, `refresh`, `selectPatient`, `createPatient`, `updatePatient`, `deletePatient`, plus related-record CRUD, duplicate merge, document upload.
- **Entities:** `frontend/lib/features/patients/domain/entities/patient_entities.dart` — `Patient`, `PatientListQuery`, `PatientRegistryState`, `PatientRegistryOverview`, `PatientReferenceData`, `PatientDetail`, `PatientDuplicateQuery`, and ~20 more entity classes. ~933 lines.
- **Repository interface:** `frontend/lib/features/patients/domain/repositories/patient_repository.dart` — `PatientRepository` (abstract).
- **Repository impl:** `frontend/lib/features/patients/data/repositories/patient_repository_impl.dart` — `PatientRepositoryImpl`, provider: `patientRepositoryProvider`. ~529 lines.
- **DTOs:** `frontend/lib/features/patients/data/dtos/patient_dtos.dart` — ~715 lines.
- **Access helpers:** `frontend/lib/features/patients/presentation/patient_registry_access.dart` — `isPharmacyRegistryReader()`, `isBillingRegistryReader()`.
- **Widgets:**
  - `frontend/lib/features/patients/presentation/widgets/patient_detail_dialog_body.dart` — `part of` page file
  - `frontend/lib/features/patients/presentation/widgets/patient_detail_header.dart` — `PatientDetailHeader`
  - `frontend/lib/features/patients/presentation/widgets/patient_detail_quick_actions.dart` — `PatientDetailQuickActions`
  - `frontend/lib/features/patients/presentation/widgets/patient_detail_active_work.dart` — `PatientDetailActiveWorkPanel`
  - `frontend/lib/features/patients/presentation/widgets/patient_active_work_helpers.dart` — `PatientActiveWorkKind`, `collectPatientActiveWorkItems()`
  - `frontend/lib/features/patients/presentation/widgets/patient_panels.dart` — `PatientTimelineList`
  - `frontend/lib/features/patients/presentation/widgets/patient_billing_context_panel.dart` — `PatientBillingContextPanel`
  - `frontend/lib/features/patients/presentation/widgets/patient_pharmacy_context_panel.dart` — `PatientPharmacyContextPanel`
  - `frontend/lib/features/patients/presentation/widgets/patient_form_fields.dart` — form field wrappers
  - `frontend/lib/features/patients/presentation/widgets/patient_widgets.dart` — barrel export
  - `frontend/lib/features/patients/presentation/widgets/patient_detail_dialog.dart` — re-exports `showPatientDetailDialog`
  - `frontend/lib/features/patients/presentation/widgets/patient_discharge_planning_dialog.dart`
- **Route definition:** `frontend/lib/app/router/app_routes.dart` line ~257: `AppRoutes.patients`, path `/patients`.
- **GoRoute registration:** `frontend/lib/app/router/app_router.dart` line ~132: builder passes `PatientListQuery.fromUri(state.uri)`.
- **Tests:**
  - `frontend/test/features/patients/presentation/patient_registry_page_test.dart` — ~1355 lines
  - `frontend/test/features/patients/presentation/patient_registry_access_test.dart`
  - `frontend/test/features/patients/presentation/patient_active_work_helpers_test.dart`
  - `frontend/test/features/patients/data/patient_repository_impl_test.dart`

### Current layout / structure

```
PatientRegistryPage (ConsumerWidget)
 └─ AppAccessGate (patientRead)
     └─ AsyncStateScaffold<PatientRegistryState>
         └─ _PatientRegistryContent (ConsumerStatefulWidget)
             └─ AppWorkspace(title: l10n.patientsTitle, leadingIcon: AppRouteIcons.patients)
                 ├─ toolbar: appWorkspaceToolbarWithLabels(primary: AppAccessActionGate → AppButton.primary("Register patient"))
                 └─ body: _PatientList → AppListTable<Patient>
                     ├─ page: state.page (server-side pagination)
                     ├─ 8 columns: Patient Number, Patient Name, Age/Sex, Phone/Identifier, Alert, Visit, Status, Next Action
                     ├─ search: AppListTableSearch with client-side matcher + advanced filter dialog
                     ├─ columnVisibilityController (no per-section key)
                     ├─ onPageChanged → applyQuery
                     ├─ mobileItemBuilder: _PatientMobileRow → AppListItemRow
                     └─ emptyBuilder: AppWorkspaceStatePanel.empty
```

### Problems / inconsistencies vs. Reception reference

1. **No tab navigation** — flat single-list; no `AppTabStrip`.
2. **No URL-synced section state** — `PatientListQuery.fromUri` parses `search`, `patientId`, `contact`, `has_outstanding_balance`, `has_active_admission` but has no `section` parameter for tab routing.
3. **No per-tab column customization** — all 8 columns are shown regardless of context.
4. **Uses `AppWorkspace` wrapper** instead of direct `ResponsivePage` — the Reception workspace uses `ResponsivePage` → `Column` → `Row(AppTabStrip, AppButton)` → `AppListTable`. The patients page wraps in `AppWorkspace` which adds its own header/toolbar chrome; the tabbed pattern puts tabs + primary action in a `Row` directly.
5. **Monolithic file** — page + filter dialog + table columns + cell widgets + helpers all in one ~6000-line file (plus a `part` file for the detail dialog body).
6. **Tab counts unsurfaced** — `PatientRegistryOverview` has `totalPatients`, `activePatients`, `activeAdmissions`, `unpaidInvoices` counts that should appear as tab badge counts but are only shown in dashboard summary cards.
7. **Column visibility keys not per-section** — uses a single storage key, should be per-section like Reception's `reception_${_section.name}`.

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
| All Patients | `all` | `all` (default — omitted from URL when selected) | Full patient registry, no section filter applied | `Icons.people_outlined` | Register Patient → `RegisterNewPatientDialog` |
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

**No changes to `app_routes.dart` or `app_router.dart` route definitions are needed.** The `/patients` GoRoute already passes `PatientListQuery.fromUri(state.uri)` to the page. The only changes are:

1. **Add a `section` field to `PatientListQuery`** — parse `?section=` from the URI in `fromUri`.
2. **Add a `PatientRegistrySection` enum** to `patient_entities.dart` — values: `all`, `active`, `admitted`, `balanceDue`.
3. **URL update on tab change** — use `GoRouter.of(context).replace<void>(location)` with `AppRoutes.patients.location(queryParameters: {'section': sectionQueryValue})`, exactly like Reception's `_updateUrlForSection`.

### Page Layout

Target widget tree (mirrors Reception exactly):

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
                         │   ├─ SizedBox(width: theme.spacing.sm)
                         │   └─ AppAccessActionGate → AppButton.primary("Register patient")
                         ├─ SizedBox(height: theme.spacing.md)
                         └─ _PatientList(
                                state: ...,
                                section: _section,
                                searchController: ...,
                                columnVisibilityController: ...,
                            )
```

**Key differences from current layout:**
- Replace `AppWorkspace` wrapper with direct `ResponsivePage` → `Column` → `Row`.
- Add `AppTabStrip` inside the `Row`, before the primary action button (with `SizedBox(width: theme.spacing.sm)` between them, matching Reception).
- Spacing between tab row and table via `SizedBox(height: theme.spacing.md)` — matching Reception line 284.
- Per-tab columns via `_columnsForSection(PatientRegistrySection section)`.
- Per-tab column visibility persistence keys: `patients_${section.name}`.
- Per-tab column width persistence keys: `patients_cw_${section.name}`.

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

**No changes to the controller or repository are required.** The existing `PatientRegistryController` and its methods (`applyQuery`, `refresh`, `selectPatient`, `createPatient`, etc.) already support all needed query parameters via `PatientListQuery`. The `PatientRegistryState` stays as-is.

The tab-switching logic should:
1. Map `PatientRegistrySection` to `PatientListQuery` filter fields:
   - `all` → no section filter applied (clear `isActive`, `hasActiveAdmission`, `hasOutstandingBalance`)
   - `active` → `isActive: true`
   - `admitted` → `hasActiveAdmission: true`
   - `balanceDue` → `hasOutstandingBalance: true`
2. Call `ref.read(patientRegistryControllerProvider.notifier).applyQuery(filteredQuery)` on tab change.
3. Reset pagination to first page on tab change.

The `PatientRegistryOverview` (fetched at load time and refreshed on sync) already provides the count values needed for tab badges:
- `overview.totalPatients`, `overview.activePatients`, `overview.activeAdmissions`, `overview.unpaidInvoices`

## Implementation Steps

### 1. Add `PatientRegistrySection` enum — File: `frontend/lib/features/patients/domain/entities/patient_entities.dart`

Add the following enum **before** the `PatientListQuery` class (before line 5):

```dart
enum PatientRegistrySection {
  all,
  active,
  admitted,
  balanceDue,
}
```

### 2. Add `section` field to `PatientListQuery` — File: `frontend/lib/features/patients/domain/entities/patient_entities.dart`

- Add `this.section = PatientRegistrySection.all` to the `PatientListQuery` constructor parameter list.
- Add `final PatientRegistrySection section;` field (with the other fields, after `final AppPageRequest pageRequest;`).
- In `PatientListQuery.fromUri`, add a section parser:

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

In the `return PatientListQuery(...)` call within `fromUri`, add:
```dart
section: parseSection(pick(<String>['section', 'tab'])),
```

- Add `section` to `copyWith`:
  - Parameter: `PatientRegistrySection? section,`
  - Body: `section: section ?? this.section,`
- Update `signature` getter to include section:
  ```dart
  String get signature =>
      '${section.name}|$search|$patientId|$contact|$hasOutstandingBalance|$hasActiveAdmission';
  ```
- Update `hasRouteTargeting` to include non-default section:
  ```dart
  bool get hasRouteTargeting {
    return section != PatientRegistrySection.all ||
        search.trim().isNotEmpty ||
        patientId.trim().isNotEmpty ||
        contact.trim().isNotEmpty ||
        hasOutstandingBalance != null ||
        hasActiveAdmission != null;
  }
  ```

### 3. Add section-to-query filter helper — File: `frontend/lib/features/patients/domain/entities/patient_entities.dart`

Add an extension on `PatientRegistrySection` (after the enum):

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

  String get queryValue {
    switch (this) {
      case PatientRegistrySection.all:
        return '';
      case PatientRegistrySection.active:
        return 'active';
      case PatientRegistrySection.admitted:
        return 'admitted';
      case PatientRegistrySection.balanceDue:
        return 'balance-due';
    }
  }
}
```

Note: `all` returns `''` so it is omitted from the URL (matching the Reception pattern where the default section produces no query parameter).

### 4. Update imports in `patient_registry_page.dart` — File: `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart`

Add these imports (if not already present):
```dart
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
```

The `app_tab_strip.dart` import is not needed explicitly because `AppTabStrip` and `AppTabItem` are already exported via `package:hosspi_hms/shared/components/components.dart` which is already imported. Verify this by checking that `components.dart` barrel exports `app_tab_strip.dart`. Similarly, `ResponsivePage` and `PageMaxWidth` are already exported via `package:hosspi_hms/shared/layout/layout.dart` which is already imported.

### 5. Add section state and URL helpers to `_PatientRegistryContentState` — File: `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart`

#### 5a. Add state field

Add to `_PatientRegistryContentState`:
```dart
late PatientRegistrySection _section;
```

#### 5b. Initialize in `initState`

After the existing `_tableColumnController` initialization, add:
```dart
_section = widget.initialQuery?.section ?? PatientRegistrySection.all;
```

#### 5c. Add URL update method (follows Reception pattern exactly)

```dart
void _updateUrlForSection(PatientRegistrySection section) {
  if (!mounted) {
    return;
  }
  final String tab = section.queryValue;
  final String location = AppRoutes.patients.location(
    queryParameters: <String, String>{
      if (tab.isNotEmpty) 'section': tab,
    },
  );
  GoRouter.of(context).replace<void>(location);
}
```

#### 5d. Add tab change handler

```dart
Future<void> _handleTabChanged(PatientRegistrySection section) async {
  if (section == _section) {
    return;
  }
  setState(() => _section = section);
  _updateUrlForSection(section);
  _tableSearchController.clear();
  final PatientListQuery baseQuery = const PatientListQuery(
  ).copyWith(section: section);
  final PatientListQuery filteredQuery = section.applyToQuery(baseQuery);
  final AppFailure? failure = await ref
      .read(patientRegistryControllerProvider.notifier)
      .applyQuery(filteredQuery);
  if (mounted) {
    await _showFailureIfNeeded(context, failure);
  }
}
```

#### 5e. Add tab display helpers

Add these private methods to `_PatientRegistryContentState` (or as top-level functions, matching the existing code style in the file):

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

### 6. Replace the `build` method of `_PatientRegistryContentState` — File: `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart`

Replace the current `build` method (lines ~164-196) with:

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
                        label:
                            '${_sectionLabel(l10n, section)} (${_sectionCount(widget.state, section)})',
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
              SizedBox(width: theme.spacing.sm),
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
          SizedBox(height: theme.spacing.md),
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

**Important:** Verify that `theme.spacing.sm` and `theme.spacing.md` work — this is the same accessor used in `reception_workspace_page.dart` lines 268 and 284. If the IDE reports an error, check how `AppThemeExtensions` defines the spacing getter and use the exact same call. The Reception page imports `package:hosspi_hms/app/theme/app_theme_extensions.dart` which is already imported in the patients page.

### 7. Update `_PatientList` widget — File: `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart`

#### 7a. Add `section` parameter

Update the constructor and field:

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
  final AppListTableColumnVisibilityController<Patient>
  columnVisibilityController;
```

#### 7b. Add per-section column definitions

Add a method to `_PatientList` or as a top-level function:

```dart
List<AppListTableColumn<Patient>> _columnsForSection(
  BuildContext context,
  WidgetRef ref,
  PatientRegistrySection section,
  AppLocalizations l10n,
) {
  final AppListTableColumn<Patient> numberCol = AppListTableColumn<Patient>(
    label: l10n.patientsPatientNumberColumnLabel,
    sortComparator: (Patient left, Patient right) =>
        appListTableCompareText(
          left.effectiveIdentifier ?? left.publicId,
          right.effectiveIdentifier ?? right.publicId,
        ),
    cellBuilder: (_, Patient patient) =>
        _PatientNumberCell(patient: patient),
  );
  final AppListTableColumn<Patient> nameCol = AppListTableColumn<Patient>(
    label: l10n.patientsPatientColumnLabel,
    sortComparator: (Patient left, Patient right) =>
        appListTableCompareText(
          left.effectiveDisplayName,
          right.effectiveDisplayName,
        ),
    cellBuilder: (_, Patient patient) =>
        _PatientNameCell(patient: patient),
  );
  final AppListTableColumn<Patient> ageSexCol = AppListTableColumn<Patient>(
    label: l10n.patientsAgeSexColumnLabel,
    sortComparator: (Patient left, Patient right) =>
        appListTableCompareDateTime(left.dateOfBirth, right.dateOfBirth),
    cellBuilder: (_, Patient patient) => _AgeSexText(patient: patient),
  );
  final AppListTableColumn<Patient> phoneCol = AppListTableColumn<Patient>(
    label: l10n.patientsPhoneIdentifierColumnLabel,
    sortComparator: (Patient left, Patient right) =>
        appListTableCompareText(
          left.primaryPhone ?? left.primaryEmail,
          right.primaryPhone ?? right.primaryEmail,
        ),
    cellBuilder: (_, Patient patient) =>
        _PatientContactIdentifierCell(patient: patient),
  );
  final AppListTableColumn<Patient> alertCol = AppListTableColumn<Patient>(
    label: l10n.patientsAlertColumnLabel,
    sortComparator: (Patient left, Patient right) =>
        appListTableCompareText(
          _patientAlertSortValue(left),
          _patientAlertSortValue(right),
        ),
    cellBuilder: (_, Patient patient) =>
        _PatientAlertCell(patient: patient),
  );
  final AppListTableColumn<Patient> visitCol = AppListTableColumn<Patient>(
    label: l10n.patientsVisitColumnLabel,
    sortComparator: (Patient left, Patient right) =>
        appListTableCompareDateTime(
          left.currentVisit?.occurredAt,
          right.currentVisit?.occurredAt,
        ),
    cellBuilder: (_, Patient patient) =>
        _VisitContextCell(patient: patient),
  );
  final AppListTableColumn<Patient> statusCol = AppListTableColumn<Patient>(
    label: l10n.patientsStatusColumnLabel,
    sortComparator: (Patient left, Patient right) =>
        appListTableCompareText(
          left.isActive ? 'active' : 'inactive',
          right.isActive ? 'active' : 'inactive',
        ),
    cellBuilder: (BuildContext context, Patient patient) =>
        _patientActiveStatusText(context, patient.isActive),
  );
  final AppListTableColumn<Patient> nextActionCol = AppListTableColumn<Patient>(
    label: l10n.patientsNextActionColumnLabel,
    cellBuilder: (_, Patient patient) => _NextActionCell(
      patient: patient,
      onPressed: () {
        unawaited(showPatientDetailDialog(context, ref, patient.id));
      },
    ),
  );

  switch (section) {
    case PatientRegistrySection.all:
      return <AppListTableColumn<Patient>>[
        numberCol, nameCol, ageSexCol, phoneCol, alertCol, visitCol, statusCol, nextActionCol,
      ];
    case PatientRegistrySection.active:
      return <AppListTableColumn<Patient>>[
        numberCol, nameCol, ageSexCol, phoneCol, alertCol, visitCol, nextActionCol,
      ];
    case PatientRegistrySection.admitted:
      return <AppListTableColumn<Patient>>[
        numberCol, nameCol, ageSexCol, phoneCol, alertCol, visitCol, nextActionCol,
      ];
    case PatientRegistrySection.balanceDue:
      return <AppListTableColumn<Patient>>[
        numberCol, nameCol, ageSexCol, phoneCol, visitCol, statusCol, nextActionCol,
      ];
  }
}
```

#### 7c. Update `_PatientList.build` to use per-section columns and keys

In the `build` method, replace the hardcoded `columns: <AppListTableColumn<Patient>>[...]` with:

```dart
columns: _columnsForSection(context, ref, section, l10n),
```

Add per-section storage keys (replacing any existing keys):

```dart
columnVisibilityStorageKey: 'patients_${section.name}',
columnWidthStorageKey: 'patients_cw_${section.name}',
```

#### 7d. Update `onPageChanged` to preserve section filter

Replace the current `onPageChanged` callback:

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

### 8. Update search and filter to preserve section context — File: `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart`

#### 8a. Update `_applyTableSearch`

The `_applyTableSearch` method must preserve the current section when searching. Update it to include section:

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

#### 8b. Update `_applyPatientFilterDraft`

The top-level `_applyPatientFilterDraft` function takes a `PatientRegistryState` and builds the query from the filter draft. Since this function doesn't have access to the current section directly, the `section` must be available on `state.query.section` (which it will be, since all query mutations now carry the section). The existing code in `_applyPatientFilterDraft` already delegates to `state.query.copyWith(...)`, so the section will be preserved automatically since `copyWith` defaults to `this.section`. **No change needed** to `_applyPatientFilterDraft` itself.

However, verify that the `_PatientAdvancedFiltersDialog` does not clear the section when building its next query. If it calls `state.query.copyWith(...)`, the section is automatically preserved. Confirm this is the case.

### 9. Add localization strings — File: `frontend/lib/l10n/app_en.arb`

Find the patients section of `app_en.arb` (near line ~4488 where `"patientsTitle"` is defined) and add these entries:

```json
"patientsTabAll": "All patients",
"@patientsTabAll": {
  "description": "Tab label for showing all patients"
},
"patientsTabActive": "Active",
"@patientsTabActive": {
  "description": "Tab label for showing active patients"
},
"patientsTabAdmitted": "Admitted",
"@patientsTabAdmitted": {
  "description": "Tab label for showing currently admitted patients"
},
"patientsTabBalanceDue": "Balance due",
"@patientsTabBalanceDue": {
  "description": "Tab label for showing patients with outstanding balance"
},
```

After adding the ARB entries, regenerate localizations:

```bash
cd frontend && flutter gen-l10n
```

If the project uses a different localization generation command, check the project's `l10n.yaml` or `pubspec.yaml` for the correct command and run that instead.

### 10. Preserve the `part` file relationship

The `patient_detail_dialog_body.dart` uses `part of` pointing to `patient_registry_page.dart`. This `part` relationship must be preserved. The detail dialog code inside the `part` file does not need changes — it continues to work as-is since it accesses the controller via `ref.read(patientRegistryControllerProvider.notifier)`.

## Shared Components — MUST Reuse

Do NOT create new implementations of these. Import and use them directly:

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` | `package:hosspi_hms/shared/components/components.dart` (via barrel) | Tab bar above the table. Constructor: `AppTabStrip(tabs: [...], selectedId: ..., onTabTapped: ...)` |
| `AppTabItem` | `package:hosspi_hms/shared/components/components.dart` (via barrel) | Tab definition: `AppTabItem(id: ..., icon: ..., label: ...)` |
| `AppListTable<Patient>` | `package:hosspi_hms/shared/components/components.dart` (via barrel) | Data table — already in use, keep using it with per-section columns |
| `AppListTableSearch<Patient>` | `package:hosspi_hms/shared/components/components.dart` (via barrel) | Search bar config — already in use, preserve all existing search behavior |
| `AppListTableColumnVisibilityController<Patient>` | `package:hosspi_hms/shared/components/components.dart` (via barrel) | Column visibility — already in use, update storage keys to be per-section |
| `AppButton.primary` | `package:hosspi_hms/shared/components/components.dart` (via barrel) | Primary action button — already in use |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Permission gate — already in use |
| `AsyncStateScaffold<PatientRegistryState>` | `package:hosspi_hms/shared/components/components.dart` (via barrel) | Async state wrapper — already in use |
| `ResponsivePage` | `package:hosspi_hms/shared/layout/layout.dart` (via barrel) | Page layout with `maxWidth: PageMaxWidth.dataHeavy` |
| `AppWorkspaceStatePanel.empty` | `package:hosspi_hms/shared/layout/layout.dart` (via barrel) | Empty state — already in use in table `emptyBuilder` |
| `RegisterNewPatientDialog` | `package:hosspi_hms/shared/patient_actions/register_new_patient_dialog.dart` | Registration dialog — already used via `_openRegisterPatientDialog` |
| `showPatientDetailDialog` | `package:hosspi_hms/shared/patient_actions/patient_detail_dialog.dart` | Detail dialog — already in use |
| `GoRouter` | `package:go_router/go_router.dart` | URL replacement for tab sync — new import |
| `AppRoutes` | `package:hosspi_hms/app/router/app_routes.dart` | Route constants for URL generation — new import |

## Files to Create

No new files need to be created. All changes are modifications to existing files.

## Files to Modify

| File Path | Changes |
|-----------|---------|
| `frontend/lib/features/patients/domain/entities/patient_entities.dart` | Add `PatientRegistrySection` enum, `PatientRegistrySectionFilter` extension (with `applyToQuery` and `queryValue`), `section` field to `PatientListQuery`, update `fromUri`, `copyWith`, `signature`, `hasRouteTargeting` |
| `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart` | Replace `AppWorkspace` with `ResponsivePage` → `Column` → `Row(AppTabStrip, AppButton.primary)` → `_PatientList` tabbed layout. Add `_section` state, `_handleTabChanged`, `_updateUrlForSection`, `_sectionIcon`, `_sectionLabel`, `_sectionCount`. Extract `_columnsForSection` from hardcoded column list. Update `_PatientList` to accept `section` param with per-section columns and storage keys. Update `_applyTableSearch` to preserve section context. Add `go_router` and `app_routes` imports. |
| `frontend/lib/l10n/app_en.arb` | Add `patientsTabAll`, `patientsTabActive`, `patientsTabAdmitted`, `patientsTabBalanceDue` localization strings with `@` metadata |

## Files to Delete (if any)

No files need to be deleted. The refactor restructures the UI within existing files.

## Cleanup: Remove Stale Code

After the refactor, the agent MUST remove all dead/stale code left behind:

- [ ] Remove the `AppWorkspace` wrapper usage from `_PatientRegistryContentState.build` — replaced by `ResponsivePage` → `Column` → `Row`.
- [ ] Remove `appWorkspaceToolbarWithLabels` call — it was used to wrap the primary action button in `AppWorkspace.toolbar`. The primary action is now placed directly in the `Row` next to `AppTabStrip`.
- [ ] Remove `AppRouteIcons.patients` reference — it was used as `AppWorkspace.leadingIcon`. If this is the only reference in the file, also remove `import 'package:hosspi_hms/app/router/app_route_icons.dart';`.
- [ ] Remove the hardcoded inline column list from the old `_PatientList.build` — replaced by `_columnsForSection`.
- [ ] Remove unused imports across all modified files.
- [ ] Run `dart analyze` to catch any remaining unreferenced declarations and remove them.
- [ ] Verify no test files reference deleted code — update or remove stale tests.

List every file and symbol removed in a "Cleanup Summary" section at the end of the implementation.

## Database Migrations

No database migrations required — schema unchanged. The refactor only restructures the Flutter UI layer. The `PatientListQuery` already supports `isActive`, `hasActiveAdmission`, and `hasOutstandingBalance` filter fields, and the backend API already handles these query parameters. No new columns, tables, or indexes are needed.

## Responsive Design Requirements

- **Desktop (≥840px / `lg`+):** Full data table with all per-tab columns visible, `AppTabStrip` and primary action button ("Register patient") in a horizontal `Row`, column resize handles enabled, column visibility settings button in search bar.
- **Tablet (600–839px / `md`):** Same table layout — `AppListTable` with `displayMode: AppListTableDisplayMode.adaptive` automatically renders as table at this breakpoint. Tab labels may truncate. Action button may collapse to icon-only via `AppActionLabelScope` (inherited from the shell scaffold).
- **Mobile (<600px / `xs`/`sm`):** `AppListTable` automatically switches to `mobileItemBuilder` rendering each row via `_PatientMobileRow` → `AppListItemRow`. `AppTabStrip` wraps to multiple lines. Primary action button remains accessible.

Use `AppBreakpoints` from `package:hosspi_hms/core/responsive/app_breakpoints.dart` for any breakpoint-dependent logic. The existing `AppListTable.displayMode: AppListTableDisplayMode.adaptive` already handles the table/list switch — no manual breakpoint logic needed for the table itself.

## Verification Steps

After implementation, the agent MUST run these commands and confirm they pass:

```bash
# Regenerate localizations
cd frontend && flutter gen-l10n

# Format
dart format frontend/lib/features/patients/ frontend/lib/app/router/ frontend/lib/l10n/

# Analyze
dart analyze frontend/ --fatal-infos

# Run tests related to this screen
flutter test test/features/patients/

# Run shared component tests to ensure no regressions
flutter test test/shared/
```

## Testing Requirements

Write or update these tests in `frontend/test/features/patients/presentation/patient_registry_page_test.dart`:

- [ ] Tab navigation: switching tabs updates the URL query parameter `?section=` via `GoRouter.replace`
- [ ] Deep linking: constructing a `PatientListQuery.fromUri` with `?section=admitted` produces `PatientRegistrySection.admitted`
- [ ] Tab data: each tab applies the correct filter to `PatientListQuery` — assert `isActive`, `hasActiveAdmission`, `hasOutstandingBalance` fields via `PatientRegistrySectionFilter.applyToQuery`
- [ ] Tab counts: badge counts on tabs match `PatientRegistryOverview` values (`totalPatients`, `activePatients`, `activeAdmissions`, `unpaidInvoices`)
- [ ] Per-tab columns: verify column count differs per section (8 for All, 7 for Active/Admitted/Balance Due)
- [ ] Search preservation: typing in the search bar filters table rows and preserves the active section filter
- [ ] Advanced filter dialog: filter button opens the filter UI and applies filters while preserving the section
- [ ] Primary action: "Register patient" button is present on all tabs and opens `RegisterNewPatientDialog`
- [ ] Mobile layout: widget tests verify `mobileItemBuilder` renders `_PatientMobileRow` at mobile breakpoint
- [ ] No regressions: existing page test expectations still pass — patient detail dialog opens on row click, registration dialog opens on primary action, pharmacist/billing reader views work

## Acceptance Criteria

The refactor is complete when ALL of the following are true:

- [ ] The screen uses routable `AppTabStrip` tabs matching the Reception workspace pattern, with 4 tabs: All Patients, Active, Admitted, Balance Due
- [ ] Each tab has its own URL via `?section=` that supports deep linking
- [ ] Tab badge counts display `totalPatients`, `activePatients`, `activeAdmissions`, `unpaidInvoices` from the overview
- [ ] The primary action button ("Register patient") is positioned correctly beside the tab strip in a `Row`, wrapped in `AppAccessActionGate`
- [ ] The page body uses `AppListTable<Patient>` with per-section columns, integrated search, advanced filter, and column visibility settings (per-section persistence keys)
- [ ] The layout uses `ResponsivePage(maxWidth: PageMaxWidth.dataHeavy)` directly instead of `AppWorkspace`
- [ ] Spacing between elements matches Reception: `theme.spacing.sm` between tab strip and button, `theme.spacing.md` between tab row and table
- [ ] No shared component is re-implemented — only imported and used
- [ ] The layout is fully responsive across mobile, tablet, and desktop (automatic via `AppListTable.adaptive` + `ResponsivePage`)
- [ ] All old/duplicate layout code is removed — no stale `AppWorkspace` wrapper, no `appWorkspaceToolbarWithLabels` call, no `AppRouteIcons.patients` reference remains
- [ ] Domain-specific business logic is preserved: server-side pagination, advanced filters, patient detail dialog, registration, realtime sync, duplicate management, all patient actions, pharmacist/billing reader views
- [ ] No database migrations required — schema unchanged (explicitly confirmed)
- [ ] The `part` file relationship with `patient_detail_dialog_body.dart` is preserved and functional
- [ ] `dart analyze` reports no new issues — zero unused imports, zero unreferenced declarations
- [ ] All tests pass (no stale test references to removed code)
- [ ] New localization strings are added for tab labels and localizations are regenerated
