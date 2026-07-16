# Standardize Patients Tables

## Objective

Refactor every `AppListTable` on the Patients workspace (`/patients`, `PatientRegistryPage`) so each table fully complies with `prompt.md` (search chrome, ≤5 columns, status/action columns when applicable, row detail dialog, responsiveness, realtime).

## Compliance Checklist (from prompt.md — per table)

- [ ] Global search matches all columns (including hidden)
- [ ] Search chrome has only Filters (Advanced filters modal) and Settings (Table Settings modal)
- [ ] Session-persisted column visibility via `AppListTableColumnVisibilityController`
- [ ] ≤ 5 declared columns; automatic row number only
- [ ] One semantic field per column; two-line display only for primary/secondary of one field
- [ ] Status + explicit next-action columns when entity has workflow
- [ ] Row tap opens reused detail dialog with follow-up actions
- [ ] Adaptive layout + `mobileItemBuilder` parity
- [ ] Real-time refresh via Riverpod providers

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification. Run tests and formatting after implementation. Treat `prompt.md` as the normative table contract.

**Scope boundary:** Restructure **table chrome, columns, and row interactions only**. Do not rewrite domain APIs, permissions, unrelated screen chrome (tab strip, Register patient toolbar, advanced-filter field definitions), or patient detail dialog internals unless required for compilation.

## Current State (from audit)

### Screen wiring

| Field | Value |
|-------|-------|
| Route | `/patients` (`AppRoutes.patients`) |
| Page | `PatientRegistryPage` → `_PatientRegistryContent` |
| Primary file | `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart` |
| Controller | `patientRegistryControllerProvider` (`PatientRegistryController`) |
| Realtime | `listenForRealtimeRefresh` with `RealtimeEventGroups.patientRegistry` + adaptive polling |
| Detail dialog | `showPatientDetailDialog` in `patient_detail_dialog_body.dart` (part of registry page) |
| Tabs | `PatientRegistrySection`: `all`, `active`, `admitted`, `balanceDue` |
| Deep link | `?section=<value>` (`active`, `admitted`, `balance-due`) |

### Table inventory (one widget, four tab column profiles)

| # | Table widget | File | Entity | Tab binding | Declared columns today | Detail on row select |
|---|--------------|------|--------|-------------|------------------------|----------------------|
| 1 | `_PatientList` | `patient_registry_page.dart` | `Patient` | `PatientRegistrySection` via `_columnsForSection` | **7–8** (see matrix below) | `onRowSelected` → `showPatientDetailDialog(context, ref, patient.id)` ✓ |

### Per-tab column matrix (current)

| Column | id (missing today) | Label (l10n) | Source | All | Active | Admitted | Balance due |
|--------|-------------------|--------------|--------|:---:|:------:|:--------:|:-----------:|
| Patient no. | — | `patientsPatientNumberColumnLabel` | `effectiveIdentifier` / `publicId` | ✓ | ✓ | ✓ | ✓ |
| Patient name | — | `patientsPatientColumnLabel` | `effectiveDisplayName` | ✓ | ✓ | ✓ | ✓ |
| Age / sex | — | `patientsAgeSexColumnLabel` | `dateOfBirth` + `gender` (**two fields merged**) | ✓ | ✓ | ✓ | ✓ |
| Phone | — | `patientsPhoneIdentifierColumnLabel` | `primaryPhone` / `primaryEmail` | ✓ | ✓ | ✓ | ✓ |
| Alerts | — | `patientsAlertColumnLabel` | `hasAllergyAlert`, `requiresCompletion` | ✓ | ✓ | ✓ | — |
| Visit | — | `patientsVisitColumnLabel` | `currentVisit` (title+status / date) | ✓ | ✓ | ✓ | ✓ |
| Status | — | `patientsStatusColumnLabel` | `isActive` via `_patientActiveStatusText` | ✓ | — | — | ✓ |
| Next action | — | `patientsNextActionColumnLabel` | `_NextActionCell` (`AppButton`) | ✓ | ✓ | ✓ | ✓ |

**Automatic row-number column:** Not declared (correct — `AppListTable` adds it from pagination).

### Search chrome (current)

`_PatientList` uses `AppListTableSearch<Patient>` with:

- `showAdvancedFilterButton: true`
- `advancedFilterButtonLabel: l10n.patientsAdvancedFiltersAction` → **"Filters"** ✓
- Advanced filter modal (`_PatientAdvancedFiltersDialog`) title: `l10n.patientsAdvancedFiltersTitle` → **"Advanced filters"** ✓
- `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` → **"Settings"** ✓
- **Missing:** `advancedFilterTitle` on `AppListTableSearch` (wire `l10n.patientsAdvancedFiltersTitle` for consistency with Mortuary)
- **Missing:** `columnVisibilityTitle` on `AppListTable` (must be **"Table Settings"**)
- **Missing:** `columnChoices` — all 7–8 columns are in `columns` only
- No export/refresh/overflow in search chrome ✓

### Session persistence (current)

- `AppListTableColumnVisibilityController<Patient>` owned by `_PatientRegistryContentState`
- `columnVisibilityStorageKey: 'patients_${section.name}'` ✓ (per tab)
- `columnWidthStorageKey: 'patients_cw_${section.name}'` ✓
- Backed by `AppListTableColumnVisibilityMemory` (session scope) ✓

### Row interaction (current)

- `onRowSelected` → `showPatientDetailDialog` ✓
- `_NextActionCell` also opens `showPatientDetailDialog` (same destination) ✓
- Labels: `patientsCompleteRecordAction` ("Complete record") when `requiresCompletion`; else `patientsOpenRecordAction` ("Open record") ✓
- Uses `AppButton`, not `WorkflowActionButton` — **correct for this entity** (no encounter-scoped workflow registry; `WorkflowActionButton` requires `encounterId`)

### Responsiveness (current)

- `displayMode` not set → defaults to `AppListTableDisplayMode.adaptive` ✓
- `mobileItemBuilder` → `_PatientMobileRow` — **gaps:** no visit, no next-action control, uses `AppStatusText` instead of badge parity, shows alert OR status not both

### Search matcher (current)

`_matchesPatientTableSearch` indexes many patient fields but **omits** formatted age/sex display, `patientsNoAlertsLabel`, visit formatted title line (`OPD - In Progress`), and fields that will move to `columnChoices`. Must expand when columns are restructured.

### Gap list vs `prompt.md`

| Gap | Severity |
|-----|----------|
| 7–8 declared columns per tab (max 5) | **Blocker** |
| No `columnChoices` for lower-priority fields | **Blocker** |
| Patient no. + Patient name are separate columns; should be one patient field with two-line `AppListItemText` | High |
| Age / sex column merges two semantic fields | High |
| Status uses `AppStatusText` / `_patientActiveStatusText`, not `AppWorkspaceStatusBadge` | High |
| Missing `columnVisibilityTitle` ("Table Settings") | Medium |
| Missing `advancedFilterTitle` on search widget | Low |
| Columns lack stable `id` strings | Medium |
| Mobile row missing visit, status badge, next-action | High |
| Tests in `patient_registry_page_test.dart` assert old 8-column layout | Must update |

### Workflow / next-action semantics

Patient registry workflow (per row, not shared `WorkflowActionRegistry`):

| Condition | Status display | Next-action label | Handler |
|-----------|----------------|-------------------|---------|
| `requiresCompletion == true` | Registration incomplete (`patientsRegistrationIncompleteValue`, warning tone) | `patientsCompleteRecordAction` | `showPatientDetailDialog` |
| `isActive == false` | Inactive (`patientsInactiveFilter`) | `patientsOpenRecordAction` | `showPatientDetailDialog` |
| Default active, complete | Active (`patientsActiveFilter`) | `patientsOpenRecordAction` | `showPatientDetailDialog` |
| `balanceDue` tab context | Prefer billing-oriented status if visit/admission data present; else active/inactive | Same explicit verbs; detail dialog exposes `PatientDetailQuickActions` billing paths | `showPatientDetailDialog` |

Do **not** adopt `WorkflowActionButton` unless you add a registered patient-registry action — keep explicit `AppButton.secondary` / `AppButton.tertiary` with permission gating via `AppAccessActionGate` (existing pattern in `_NextActionCell`).

## Reference Implementation

- `frontend/lib/shared/components/app_list_table.dart` — table contract, `columnChoices`, visibility memory
- `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` — `_MortuaryWorklist` search chrome (Filters + Settings), `_TwoLineCell`, `AppWorkspaceStatusBadge`
- `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` — `emergencyNextActionColumn`, explicit action labels
- `prompt.md`

Copy patterns:

```dart
// Mortuary search chrome (Filters + Settings only)
search: AppListTableSearch<T>(
  showAdvancedFilterButton: true,
  advancedFilterButtonLabel: l10n.patientsAdvancedFiltersAction,
  advancedFilterTitle: l10n.patientsAdvancedFiltersTitle,
  // ...
),
columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
columnVisibilityTitle: l10n.commonTableSettingsTitle,
```

```dart
// Two-line single field (Mortuary _TwoLineCell / AppListItemText)
AppListItemText(
  title: patient.effectiveDisplayName,
  subtitle: patient.effectiveIdentifier ?? l10n.profileUnknownValue,
)
```

```dart
// Status badge (replace _patientActiveStatusText in table cells)
AppWorkspaceStatusBadge(
  status: AppWorkspaceStatus(
    label: /* formatted label */,
    tone: /* AppWorkspaceStatusTone */,
    icon: /* optional */,
  ),
)
```

## Target Architecture

### Table inventory

| Table widget | Tab / panel | Entity | Default visible columns (max 5) | columnVisibilityStorageKey |
|--------------|-------------|--------|----------------------------------|----------------------------|
| `_PatientList` | All patients | `Patient` | patient, contact, alerts, status, next_action | `patients_all` |
| `_PatientList` | Active | `Patient` | patient, contact, visit, status, next_action | `patients_active` |
| `_PatientList` | Admitted | `Patient` | patient, contact, visit, status, next_action | `patients_admitted` |
| `_PatientList` | Balance due | `Patient` | patient, contact, visit, status, next_action | `patients_balanceDue` |

### Column plan — shared column definitions

Refactor `_columnsForSection` into a column builder that returns `(columns, columnChoices)` or builds a master list with per-tab default visibility. Every `AppListTableColumn` **must** have a stable `id`.

| id | Label (l10n) | Source field | Default visible | Notes |
|----|--------------|--------------|-----------------|-------|
| `patient` | `patientsPatientColumnLabel` | `effectiveDisplayName` + `effectiveIdentifier` | All tabs | `AppListItemText` two-line; sort by `effectiveDisplayName` |
| `contact` | `patientsPhoneIdentifierColumnLabel` | `primaryPhone` / `primaryEmail` | All tabs | Single contact field |
| `alerts` | `patientsAlertColumnLabel` | allergy + registration flags | **All** tab only | `_PatientAlertCell` |
| `visit` | `patientsVisitColumnLabel` | `currentVisit` | Active, Admitted, Balance due | `_VisitContextCell` (title+status primary, date subtitle = one visit field) |
| `status` | `patientsStatusColumnLabel` | composite registry status | All tabs | `AppWorkspaceStatusBadge`; see workflow table above |
| `next_action` | `patientsNextActionColumnLabel` | `requiresCompletion` / permissions | All tabs | `_NextActionCell`; `alwaysVisible: true` |
| `patient_number` | `patientsPatientNumberColumnLabel` | `effectiveIdentifier` | **columnChoices** | Hidden by default after patient merge |
| `age` | New key `patientsAgeColumnLabel` ("Age") | `dateOfBirth` | **columnChoices** | `_patientAgeLabel` only |
| `gender` | New key `patientsGenderColumnLabel` ("Gender") | `gender` | **columnChoices** | `_genderLabel` only — splits age/sex violation |

Pass hidden columns via `columnChoices` on `AppListTable<Patient>`:

```dart
AppListTable<Patient>(
  columns: defaultColumnsForSection(section),      // ≤ 5 entries
  columnChoices: optionalColumnsForSection(section), // patient_number, age, gender, alerts (when not default), etc.
  columnVisibilityStorageKey: 'patients_${section.name}',
  columnWidthStorageKey: 'patients_cw_${section.name}',
  columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
  columnVisibilityTitle: l10n.commonTableSettingsTitle,
  displayMode: AppListTableDisplayMode.adaptive,
  // ...
)
```

### Per-tab default `columns` array (exactly 5 each)

**All patients:** `patient`, `contact`, `alerts`, `status`, `next_action`  
**Active:** `patient`, `contact`, `visit`, `status`, `next_action` — status shows registration/active state (not redundant "active" only)  
**Admitted:** `patient`, `contact`, `visit`, `status`, `next_action` — status prefers admission/visit status label when `currentVisit` is admission  
**Balance due:** `patient`, `contact`, `visit`, `status`, `next_action`

Move `alerts` to `columnChoices` on Active/Admitted/Balance due tabs. Move `visit` to `columnChoices` on All tab.

### Search chrome (per table)

- Extend `_matchesPatientTableSearch` haystack to include every column id's display strings (including hidden `columnChoices`): formatted age, gender label, alert labels, visit title line, status labels, next-action labels.
- `AppListTableSearch`: add `advancedFilterTitle: l10n.patientsAdvancedFiltersTitle`.
- Keep `showAdvancedFilterButton: true`, `advancedFilterButtonLabel: l10n.patientsAdvancedFiltersAction`.
- Do not add any trailing control beyond Filters and Settings.

### Row interaction

- Keep `onRowSelected` → `showPatientDetailDialog(context, ref, patient.id)`.
- Keep `_NextActionCell` handlers opening the same dialog.
- Preserve `AppAccessActionGate` on "Complete record".

### Mobile (`_PatientMobileRow`)

Rebuild to mirror desktop priority for the active section:

- Title: `effectiveDisplayName`; subtitle: `effectiveIdentifier`
- Details row: status badge + alert chips when present
- Visit summary on tabs where `visit` is a default column
- Trailing: compact next-action button (reuse `_NextActionCell` logic or extract shared builder)
- Row tap still handled by `AppListTable` `onRowSelected`

## Implementation Steps

1. **`frontend/lib/l10n/app_en.arb`**
   - Add `commonTableSettingsTitle`: **"Table Settings"**
   - Add `patientsAgeColumnLabel`: **"Age"**
   - Add `patientsGenderColumnLabel`: **"Gender"**
   - Run codegen (`flutter gen-l10n`) as part of verification.

2. **`patient_registry_page.dart` — column refactor**
   - Extract column factories with stable `id` values.
   - Implement `patient` column using `AppListItemText` (merge number + name).
   - Split `ageSexCol` into optional `age` and `gender` columns in `columnChoices`.
   - Replace `_patientActiveStatusText` in **table/mobile status positions** with `AppWorkspaceStatusBadge` + `AppWorkspaceStatus` (helper: `_patientRegistryStatus(Patient, AppLocalizations, PatientRegistrySection section)`).
   - Refactor `_columnsForSection` to return ≤5 defaults per tab; wire `columnChoices`.
   - Add `columnVisibilityTitle: l10n.commonTableSettingsTitle`.
   - Add `advancedFilterTitle` on `AppListTableSearch`.
   - Explicitly set `displayMode: AppListTableDisplayMode.adaptive`.

3. **`patient_registry_page.dart` — search**
   - Update `_matchesPatientTableSearch` to index all column display values (use shared formatters already in file: `_patientAgeLabel`, `_genderLabel`, `_VisitContextCell` strings, status labels).

4. **`patient_registry_page.dart` — mobile**
   - Update `_PatientMobileRow` to accept `PatientRegistrySection section` (or column profile) and render parity fields + next action.

5. **`frontend/test/features/patients/presentation/patient_registry_page_test.dart`**
   - Update `patient worklist shows registry contract columns` to expect ≤5 default headers and `columnChoices` behavior (e.g. Visit/Next action visible on wide desktop when in default set; Age/sex hidden unless enabled via Settings).
   - Keep `renders AppTabStrip with tabs, Register patient toolbar, and Filters/Settings` passing.
   - Add/update assertions: Settings opens dialog titled "Table Settings"; default column count ≤5.

6. **Do not modify**
   - `PatientRegistryController` realtime wiring
   - `_PatientAdvancedFiltersDialog` field definitions
   - `patient_repository` / DTOs / API contracts

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppListTable` / `AppListTableColumn` / `AppListTableSearch` | `package:hosspi_hms/shared/components/components.dart` | Table shell |
| `AppListTableColumnVisibilityController` | `app_list_table.dart` (via components) | Session column visibility |
| `AppListTableColumnVisibilityMemory` | `app_list_table_column_visibility_memory.dart` | Persistence backing store |
| `AppListItemText` / `AppListItemRow` | `app_list_item_text.dart` | Two-line patient cell, mobile row |
| `AppWorkspaceStatusBadge` / `AppWorkspaceStatus` | `package:hosspi_hms/shared/layout/app_workspace.dart` | Status column |
| `AppButton` / `AppAccessActionGate` | `components.dart` | Next-action column |
| `showPatientDetailDialog` | `patient_detail_dialog_body.dart` (part) | Row select + next action |
| `appListTableCompareText` / `appListTableCompareDateTime` | `app_list_table.dart` | Sort comparators |

## Files to Create / Modify / Delete

| Action | Path |
|--------|------|
| Modify | `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart` |
| Modify | `frontend/lib/l10n/app_en.arb` |
| Modify | `frontend/test/features/patients/presentation/patient_registry_page_test.dart` |
| Delete | None |

## l10n

- Add/update keys in `frontend/lib/l10n/app_en.arb` only.
- New keys: `commonTableSettingsTitle`, `patientsAgeColumnLabel`, `patientsGenderColumnLabel`.
- Reuse: `commonTableSettingsActionLabel`, `patientsAdvancedFiltersAction`, `patientsAdvancedFiltersTitle`.

## Database Migrations

No database migrations required — schema unchanged.

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/patients/
```

Manual smoke (web or desktop):

1. Open `/patients` — confirm 5 default columns on All tab; Settings shows hidden columns (age, gender, patient number, visit).
2. Switch to Active / Admitted / Balance due — confirm per-tab column set changes; storage keys isolate visibility per tab.
3. Search matches a patient by MRN only visible via Settings.
4. Filters opens "Advanced filters"; Settings opens "Table Settings".
5. Row tap and next-action both open patient detail dialog.
6. Narrow viewport — mobile cards show status + next action.

## Testing Requirements

- [ ] Each table: search, Filters, Settings only in chrome
- [ ] Column visibility persists for session per `patients_<section>` key
- [ ] ≤5 default columns; row number automatic
- [ ] Workflow tables: explicit status + next-action labels (`Complete record` / `Open record`)
- [ ] Row tap opens detail dialog
- [ ] Mobile list shows same priority fields, status, and next action
- [ ] Realtime refresh still updates rows after mutations/events (controller untouched)
- [ ] Permissions still gate write actions on "Complete record"

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md` for every `AppListTable` on `/patients` (the `_PatientList` widget across all four tabs)
- [ ] Domain logic preserved (tab filters, counts, pagination, deep links, dialogs, permissions)
- [ ] `dart analyze --fatal-infos` clean; `flutter test test/features/patients/` passes
