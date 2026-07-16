# Standardize Clinical Tables

## Objective

Refactor every `AppListTable` on the Clinical workspace (`/clinical`, `ClinicalWorkspacePage`) so each table fully complies with `prompt.md` (search chrome, ≤5 columns, status/action columns when applicable, row detail dialog, responsiveness, realtime).

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

**Scope boundary:** Restructure **table chrome, columns, and row interactions only**. Do not rewrite domain APIs, permissions, tab-strip toolbar actions (Refresh, OPD/Lab/Discharge shortcuts), advanced-filter field definitions, or `_ClinicalEncounterDialog` / `_ClinicalDetailPanel` internals unless required for compilation.

## Current State (from audit)

### Screen wiring

| Field | Value |
|-------|-------|
| Route | `/clinical` (`AppRoutes.clinical`) |
| Page | `ClinicalWorkspacePage` → `_ClinicalWorkspaceContent` → `_ClinicalWorklistPanel` |
| Primary file | `frontend/lib/features/clinical/presentation/pages/clinical_workspace_page.dart` |
| Controller | `clinicalWorkspaceControllerProvider` (`ClinicalWorkspaceController`) |
| Entity | `ClinicalWorklistEntry` (`clinical_entities.dart`) |
| Realtime | `listenForRealtimeRefresh` + `_syncFromRealtime` / `_syncVisibleData` (8s polling fallback) |
| Detail dialog | `_openClinicalEntryDialog` → `_ClinicalEncounterDialog` → `_ClinicalDetailPanel` + `_ClinicalActionBar` |
| Permissions | `AppPermissions.clinicalRead` / `clinicalWrite`; write gate `_writeRequirement` (`encounters-vitals` module) |
| Deep link | `ClinicalWorkspaceQuery.fromUri`: `?section=` or `?tab=`, `?encounterId=` (aliases `encounter`, `id`), `?panel=`, `?search=` or `?q=` |

### Tabs (validate against code — not generator placeholder)

| `ClinicalWorkspaceSection` | UI label (l10n) | `ClinicalQueueScope` | URL `section` value |
|----------------------------|-----------------|----------------------|---------------------|
| `all` | `clinicalSectionAllLabel` → **All** | `all` | *(empty)* |
| `waitingReview` | `clinicalSectionWaitingReviewLabel` → **Waiting review** | `waitingReview` | `waiting-review` |
| `urgent` | `clinicalSectionUrgentLabel` → **Urgent** | `urgent` | `urgent` |
| `resultsReady` | `clinicalSectionResultsReadyLabel` → **Results ready** | `resultsReady` | `results-ready` |
| `inConsultation` | `clinicalSectionInConsultationLabel` → **In consultation** | `inConsultation` | `in-consultation` |
| `completed` | `clinicalSectionCompletedLabel` → **Completed** | `completed` | `completed` |

There is **no** “My patients” tab in code.

### Table inventory (one widget, six tab column profiles)

| # | Table widget | File | Entity | Tab binding | Declared columns today | Detail on row select |
|---|--------------|------|--------|-------------|------------------------|----------------------|
| 1 | `_ClinicalWorklistPanel` | `clinical_workspace_page.dart` | `ClinicalWorklistEntry` | `ClinicalWorkspaceSection` via `_clinicalDefaultColumnsForSection` | **5 or 6** (see matrix) | `onRowSelected` → `_openClinicalEntryDialog` ✓ |

`AppListTable` key: `ValueKey('clinical_table_${section.name}')`.

### Per-tab column matrix (current)

Enum: `_ClinicalTableColumnId` — `patient`, `patientId`, `phone`, `ageSex`, `queue`, `statusStep`, `provider`, `lastUpdated`, `encounter`, `admission`, `encounterType`, `location`.

| Column id | Label (l10n) | Source field | All | Waiting review | Urgent | Results ready | In consultation | Completed |
|-----------|--------------|--------------|:---:|:--------------:|:------:|:-------------:|:---------------:|:---------:|
| `patient` | `opdPatientColumnLabel` | `displayTitle` + `worklistPatientSecondaryLine` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `queue` | `clinicalSourceQueueLabel` | `sourceQueue` (badge via `_ClinicalQueueCell`) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `statusStep` | `clinicalStepColumnLabel` → **Current step** | `stage` / `status` / `nextStep` + urgent + results-ready chips | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `provider` | `opdProviderColumnLabel` | `providerDisplayName` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `lastUpdated` | `clinicalLastUpdatedLabel` | `updatedAt` / `startedAt` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `encounterType` | `clinicalEncounterTypeLabel` | `encounterType` | — | — | — | ✓ | — | ✓ |
| `location` | `clinicalLocationLabel` | `currentLocation` | — | — | — | — | ✓ | — |

**`columnChoices` today:** all 12 enum values are listed in `_availableClinicalTableColumns` and passed to `columnChoices`, but defaults for three tabs exceed five columns.

**Automatic row-number column:** Not declared ✓.

### Search chrome (current)

`_worklistSearch` → `AppListTableSearch<ClinicalWorklistEntry>`:

| Control | Current wiring | `prompt.md` requirement |
|---------|----------------|-------------------------|
| Filters button | `showAdvancedFilterButton: true`, `advancedFilterButtonLabel: l10n.clinicalFiltersLabel` → **Filters** ✓ | **Filters** ✓ |
| Filters modal title | `advancedFilterTitle: l10n.clinicalFiltersLabel` → **Filters** ✗ | **Advanced filters** |
| Settings button | `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` → **Settings** ✓ | **Settings** ✓ |
| Settings modal title | **Missing** `columnVisibilityTitle` on `AppListTable` ✗ | **Table Settings** |
| Extra chrome actions | None in search bar ✓ | None ✓ |

Refresh lives in `AppTabStrip.primaryAction` (correct — not in table search chrome).

### Session persistence (current)

- `AppListTableColumnVisibilityController<ClinicalWorklistEntry>` in `_ClinicalWorkspaceContentState` ✓
- `columnVisibilityStorageKey: 'clinical_${section.name}'` ✓
- `columnWidthStorageKey: 'clinical_cw_${section.name}'` ✓
- Backed by `AppListTableColumnVisibilityMemory` (session scope) ✓

### Row interaction (current)

- `onRowSelected` → `_openClinicalEntryDialog(context, ref, entry)` ✓
- Dialog loads bundle via `controller.selectEntry`, shows `_ClinicalEncounterDialog` with `_ClinicalActionBar` follow-up actions ✓
- **No** dedicated next-action column; workflow actions only inside dialog ✗

### Responsiveness (current)

- `displayMode` not set → defaults to `AppListTableDisplayMode.adaptive` ✓
- `mobileItemBuilder: _clinicalWorklistMobileItemBuilder` exists ✓
- **Gaps:** mobile row shows queue + status chips + provider text but **no next-action control**; uses `_ClinicalStatusText` instead of `AppWorkspaceStatusBadge` parity ✗

### Search matcher (current)

`matcher` delegates to `ClinicalWorklistEntry.matchesSearch(query, filters: filters)`:

- Default haystack (`_searchValuesForField` `null` case) covers raw entity fields including hidden-column sources (`encounterType`, `admissionId`, etc.) ✓
- **Gaps:** does not index formatted display strings used in cells — `_apiLabel(sourceQueue)`, `_clinicalWorklistAgeSexLabel`, `_clinicalProviderLabel` (“Not assigned”), `_dateTimeLabel`, `clinicalUrgentSummaryLabel`, `clinicalResultsReadySummaryLabel`, or resolved `WorkflowActionButton` labels. Expand after column refactor.

### Gap list vs `prompt.md`

| Gap | Severity |
|-----|----------|
| **6 declared columns** on `resultsReady`, `inConsultation`, `completed` tabs | **Blocker** |
| `statusStep` merges workflow status + urgent + results-ready into one column; no separate `status` + `next_action` | **Blocker** |
| Status uses `_ClinicalStatusText`, not `AppWorkspaceStatusBadge` | High |
| No `WorkflowActionButton` / explicit next-action column | **Blocker** |
| `advancedFilterTitle` is “Filters”, not “Advanced filters” | Medium |
| Missing `columnVisibilityTitle` (“Table Settings”) | Medium |
| `_ClinicalPatientCell` is hand-rolled `Column`; should use `AppListItemText` | Medium |
| `ageSex` column merges age + gender (two fields) — keep in `columnChoices` only, hidden by default | Medium |
| Mobile row missing next-action control | High |
| Tests assert `Current step` column header and old layout | Must update |

### Workflow / next-action semantics

`ClinicalWorklistEntry` has workflow fields: `status`, `stage`, `nextStep`, `sourceQueue`, `isUrgent`, `resultsReady`, `isTerminal`.

Registered clinical actions (`workflow_action_registry.dart` → `_clinicalActions`):

| Code / aliases | Label (l10n) | Typical trigger |
|----------------|--------------|-----------------|
| `DOCTOR_REVIEW`, `WAITING_DOCTOR_REVIEW`, … | `opdDoctorReviewAction` | Doctor review stages |
| `REVIEW_RESULTS`, `RESULTS_READY`, … | `opdReviewResultsAction` | Lab results ready |
| `REVIEW_REPORT`, `REPORT_READY`, … | `opdReviewReportAction` | Imaging report ready |
| `MEDICINES_DISPENSED`, … | `opdMedicinesDispensedAction` | Pharmacy complete |

**Primary next-action column pattern** (copy OPD `_NextStepCell`):

```dart
WorkflowActionButton(
  encounterId: item.apiEncounterId,
  patientId: item.apiPatientId,
  admissionId: item.apiAdmissionId,
  stage: item.stage ?? item.status,
  nextStep: item.nextStep,
  sourceModule: _clinicalWorkflowSourceModule(item.sourceQueue),
  compact: true,
  onBeforeNavigate: () => /* optional: close dialog if open */,
)
```

Add helper `_clinicalWorkflowSourceModule(String sourceQueue)` mapping `OPD` → `'opd'`, `TRIAGE` → `'triage'`, `IPD` / `ADMISSION` → `'ipd'`, default `null`.

**Fallback when `WorkflowActionRegistry` returns no action** (terminal rows, unmapped steps):

- Render compact `AppButton.tertiary` (or `TextButton`) with explicit label **`clinicalOpenEncounterAction`** (new l10n: “Review encounter”) that calls `_openClinicalEntryDialog` — same destination as row tap.
- When `isClinicalDispositionActionAvailable(...)` and not terminal, prefer label from `clinicalDispositionActionLabel(...)` and open `_openCompleteDispositionDialog` (same as `_ClinicalActionBar` disposition item). Gate with `AppAccessActionGate` / `_writeRequirement`.

**Status column** (position 4): `AppWorkspaceStatusBadge` with `_entryStatus(item)` only. Move urgent/results-ready indicators:
- Keep row background tints via existing `_clinicalRowColor` ✓
- Optionally add secondary badges inside status `Wrap` (Mortuary pattern) using `clinicalUrgentSummaryLabel` / `clinicalResultsReadySummaryLabel` — these are alert flags, not separate columns.

**Disposition / detail parity:** Next-action column handlers must deep-link or open the **same** dialogs as `_ClinicalActionBar` where applicable; default fallback is always `_openClinicalEntryDialog`.

## Reference Implementation

- `frontend/lib/shared/components/app_list_table.dart` — `columnChoices`, visibility memory, `displayMode`
- `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` — `_MortuaryWorklist` (Filters + Settings chrome, `AppWorkspaceStatusBadge`, `_TwoLineCell`)
- `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` — `emergencyNextActionColumn`, `WorkflowActionButton`
- `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart` — `_RadiologyOrderBoard`, `_patientViewWorklistColumns` (3 data + `next_action` + `status`), `_RadiologyOrderListTile` mobile parity
- `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart` — `_NextStepCell` with `WorkflowActionButton`
- `prompt.md`

Copy patterns:

```dart
// Search chrome (standardize titles)
search: AppListTableSearch<ClinicalWorklistEntry>(
  showAdvancedFilterButton: true,
  advancedFilterButtonLabel: l10n.clinicalFiltersLabel, // "Filters"
  advancedFilterTitle: l10n.clinicalAdvancedFiltersTitle, // "Advanced filters"
  // ...
),
columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
columnVisibilityTitle: l10n.commonTableSettingsTitle, // "Table Settings"
displayMode: AppListTableDisplayMode.adaptive,
```

```dart
// Status column (replace _ClinicalStatusCell in table)
AppWorkspaceStatusBadge(status: _entryStatus(item))
```

```dart
// Patient column (replace _ClinicalPatientCell)
AppListItemText(
  title: item.displayTitle,
  subtitle: item.worklistPatientSecondaryLine,
)
```

## Target Architecture

### Table inventory

| Table widget | Tab / panel | Entity | Default visible columns (max 5) | columnVisibilityStorageKey |
|--------------|-------------|--------|----------------------------------|----------------------------|
| `_ClinicalWorklistPanel` | All | `ClinicalWorklistEntry` | patient, queue, provider, status, next_action | `clinical_all` |
| `_ClinicalWorklistPanel` | Waiting review | `ClinicalWorklistEntry` | patient, queue, provider, status, next_action | `clinical_waitingReview` |
| `_ClinicalWorklistPanel` | Urgent | `ClinicalWorklistEntry` | patient, queue, provider, status, next_action | `clinical_urgent` |
| `_ClinicalWorklistPanel` | Results ready | `ClinicalWorklistEntry` | patient, encounterType, queue, status, next_action | `clinical_resultsReady` |
| `_ClinicalWorklistPanel` | In consultation | `ClinicalWorklistEntry` | patient, location, provider, status, next_action | `clinical_inConsultation` |
| `_ClinicalWorklistPanel` | Completed | `ClinicalWorklistEntry` | patient, queue, encounterType, status, next_action | `clinical_completed` |

`columnWidthStorageKey` pattern unchanged: `clinical_cw_${section.name}`.

### Column plan (shared definitions)

Refactor `_clinicalDataColumn` / `_clinicalDefaultColumnsForSection` into factories with stable `id` strings. Replace `_ClinicalTableColumnId.statusStep` with separate `status` and `next_action`.

| id | Label (l10n) | Source field | Default tabs | Notes |
|----|--------------|--------------|--------------|-------|
| `patient` | `opdPatientColumnLabel` | `displayTitle` + `worklistPatientSecondaryLine` | All | `AppListItemText`; sort by `displayTitle` |
| `queue` | `clinicalSourceQueueLabel` | `sourceQueue` | All except Results ready / In consultation defaults | `_ClinicalQueueCell` or `AppWorkspaceStatusBadge` with `_sourceQueueTone` |
| `provider` | `opdProviderColumnLabel` | `providerDisplayName` | Most tabs | `_clinicalProviderLabel` |
| `status` | `opdStatusColumnLabel` | `stage` / `status` (via `_entryStatus`) | All | `AppWorkspaceStatusBadge`; optional urgent/results chips in `Wrap` |
| `next_action` | `clinicalNextActionColumnLabel` (new) | `nextStep` + workflow registry | All | `WorkflowActionButton` + fallbacks; `alwaysVisible: true` |
| `lastUpdated` | `clinicalLastUpdatedLabel` | `updatedAt` / `startedAt` | **columnChoices** | Hidden by default |
| `encounterType` | `clinicalEncounterTypeLabel` | `encounterType` | Results ready, Completed defaults | |
| `location` | `clinicalLocationLabel` | `currentLocation` | In consultation default | |
| `patientId` | `opdPatientIdLabel` | `apiPatientId` | **columnChoices** | |
| `phone` | `patientsPhoneLabel` | `patientPhone` | **columnChoices** | |
| `ageSex` | `patientsAgeSexColumnLabel` | `patientAgeSex` or computed age+gender | **columnChoices** | Single computed display only |
| `encounter` | `clinicalEncounterNumberLabel` | `apiEncounterId` | **columnChoices** | |
| `admission` | `clinicalAdmissionNumberLabel` | `apiAdmissionId` | **columnChoices** | |

Remove `statusStep` id; migrate any column-visibility session keys are per-section so no migration needed.

### Search chrome (per table)

- Add `advancedFilterTitle: l10n.clinicalAdvancedFiltersTitle` on `AppListTableSearch`.
- Add `columnVisibilityTitle: l10n.commonTableSettingsTitle` on `AppListTable`.
- Keep `advancedFilterButtonLabel: l10n.clinicalFiltersLabel` (**Filters**).
- Do **not** add export, refresh, or overflow to search chrome.

Expand search haystack: add a package-private helper e.g. `clinicalWorklistSearchHaystack(ClinicalWorklistEntry item, AppLocalizations l10n)` used by both `matchesSearch` (or wrapper matcher in `_worklistSearch`) and tests, indexing every column id’s rendered text including hidden `columnChoices` fields and resolved next-action labels.

### Row interaction

- Keep `onRowSelected` → `_openClinicalEntryDialog`.
- Next-action column: `WorkflowActionButton` routes / dialogs per registry; fallbacks call `_openClinicalEntryDialog` or `_openCompleteDispositionDialog` with explicit labels.
- Preserve `controller.selectEntry` + `clearSelection` lifecycle in `_openClinicalEntryDialog`.

### Mobile (`_clinicalWorklistMobileItemBuilder`)

Rebuild following `_RadiologyOrderListTile` / OPD mobile pattern:

- Title: `displayTitle`; subtitle: `worklistPatientSecondaryLine`
- Row header: patient + `AppWorkspaceStatusBadge` (`_entryStatus`)
- Body: tab-priority fields (queue, provider, location, or encounterType depending on `section`)
- Next-action: compact `WorkflowActionButton` or fallback button (extract shared `_ClinicalWorklistNextActionCell` widget used by desktop column + mobile)
- Preserve `_clinicalRowColor` via `AppListTable.rowColorBuilder`
- Row tap still via `onRowSelected`

## Implementation Steps

1. **`frontend/lib/l10n/app_en.arb`**
   - Add `commonTableSettingsTitle`: **"Table Settings"**
   - Add `clinicalAdvancedFiltersTitle`: **"Advanced filters"**
   - Add `clinicalNextActionColumnLabel`: **"Next action"**
   - Add `clinicalOpenEncounterAction`: **"Review encounter"**
   - Run `flutter gen-l10n` during verification.

2. **`clinical_workspace_page.dart` — column enum refactor**
   - Replace `_ClinicalTableColumnId.statusStep` with `status` and `nextAction`.
   - Update `_clinicalTableColumnLabel`, `_clinicalSortComparator`, `_clinicalDataColumn`.
   - Implement `_clinicalStatusColumn` using `AppWorkspaceStatusBadge`.
   - Implement `_clinicalNextActionColumn` (extract `_ClinicalWorklistNextActionCell` as `ConsumerWidget`).
   - Update `_clinicalDefaultColumnsForSection` to return **exactly 5** ids per tab per target matrix.
   - Ensure `columnChoices` lists all optional columns; defaults must not include `lastUpdated` unless user toggles via Settings.

3. **`clinical_workspace_page.dart` — patient cell**
   - Replace `_ClinicalPatientCell` body with `AppListItemText`.

4. **`clinical_workspace_page.dart` — search chrome**
   - Wire `advancedFilterTitle: l10n.clinicalAdvancedFiltersTitle`.
   - Wire `columnVisibilityTitle: l10n.commonTableSettingsTitle`.
   - Set `displayMode: AppListTableDisplayMode.adaptive` explicitly.

5. **`clinical_workspace_page.dart` — search matcher**
   - Add `clinicalWorklistSearchHaystack` (or extend `ClinicalWorklistEntry.matchesSearch`) to include formatted column display strings for all ids in `_availableClinicalTableColumns`.

6. **`clinical_workspace_page.dart` — mobile builder**
   - Rebuild `_clinicalWorklistMobileItemBuilder` with status badge + next-action parity.

7. **Tests** — `frontend/test/features/clinical/presentation/clinical_workspace_page_test.dart`
   - Replace assertions on **Current step** header with **Status** / **Next action** (per new l10n).
   - Assert ≤5 `DataColumn` labels excluding automatic row-number column.
   - Keep Filters + Settings chrome tests; add assertion that advanced filter dialog title is **Advanced filters** if dialog title is visible in test harness.
   - Verify tab column profile changes (e.g. Results ready shows encounter type default, not six columns).

8. **Domain tests** (if matcher moves to entity file)
   - Update `clinical_entities_test.dart` only if `matchesSearch` signature or haystack changes.

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppListTable` / `AppListTableColumn` / `AppListTableSearch` | `package:hosspi_hms/shared/components/components.dart` | Table shell |
| `AppListTableColumnVisibilityController` | `app_list_table.dart` (via components.dart) | Session column visibility |
| `AppListTableColumnVisibilityMemory` | `app_list_table.dart` | Session persistence backing store |
| `AppListItemText` | `components.dart` | Two-line patient cell |
| `AppWorkspaceStatusBadge` | `components.dart` | Status column |
| `WorkflowActionButton` | `package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart` | Next-action column |
| `AppAccessActionGate` | `package:hosspi_hms/core/permissions/access_gate.dart` | Permission-gated disposition fallback |
| `clinicalDispositionActionLabel` / `isClinicalDispositionActionAvailable` | `package:hosspi_hms/shared/clinical_actions/clinical_disposition_actions.dart` | Disposition next-action labels |
| `_ClinicalEncounterDialog` / `_ClinicalActionBar` | same file | Existing detail + follow-up actions (do not duplicate) |
| `clinical_encounter_detail_panels.dart` | `package:hosspi_hms/features/clinical/presentation/widgets/clinical_encounter_detail_panels.dart` | Lab/radiology panels in dialog |

## Files to Create / Modify / Delete

| Action | Path |
|--------|------|
| Modify | `frontend/lib/features/clinical/presentation/pages/clinical_workspace_page.dart` |
| Modify | `frontend/lib/l10n/app_en.arb` |
| Modify | `frontend/test/features/clinical/presentation/clinical_workspace_page_test.dart` |
| Modify (if needed) | `frontend/lib/features/clinical/domain/entities/clinical_entities.dart` |
| Delete | Nothing |

## l10n

Add/update keys in `frontend/lib/l10n/app_en.arb` only:

| Key | English value |
|-----|---------------|
| `commonTableSettingsTitle` | Table Settings |
| `clinicalAdvancedFiltersTitle` | Advanced filters |
| `clinicalNextActionColumnLabel` | Next action |
| `clinicalOpenEncounterAction` | Review encounter |

Prefer existing shared keys where present:

- `commonTableSettingsActionLabel` → Settings (already wired)
- `clinicalFiltersLabel` → Filters (keep for button label)

## Database Migrations

No database migrations required — schema unchanged.

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/clinical/
```

## Testing Requirements

- [ ] Each table: search, Filters, Settings only in chrome
- [ ] Advanced filters modal title is **Advanced filters**; Settings modal title is **Table Settings**
- [ ] Column visibility persists for session per `clinical_${section.name}` key
- [ ] ≤5 default columns per tab; row number automatic
- [ ] Workflow tables: `AppWorkspaceStatusBadge` status + explicit `WorkflowActionButton` / fallback next-action labels
- [ ] Row tap opens `_ClinicalEncounterDialog` with `_ClinicalActionBar` actions
- [ ] Mobile list shows status badge + next-action control + tab-priority fields
- [ ] Realtime refresh still updates rows after mutations/events (`clinicalWorkspaceControllerProvider`)
- [ ] Permissions still gate write actions (`_writeRequirement`, `AppAccessActionGate`)

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md` for `_ClinicalWorklistPanel` on all six tabs
- [ ] Domain logic preserved (scopes, filters, pagination, deep links, dialog actions, row colors)
- [ ] `dart analyze --fatal-infos` clean; `flutter test test/features/clinical/` passes
