# Patients — shared / cross-tab chrome

## Shell entry

- Route: `AppRoutes.patients` under app `ShellRoute`
- Workspace gate: `patientRegistryReadRequirement` — ∩ `patient:read` (+ module via `patientRegistryEntryRequirement` / `patient-registry`)
- Catalog entry: `RouteAccessCatalog.patientsEntry` (`patients:read` — note catalog vs matrix key)
- Page wraps `AppAccessGate` → forbidden `AppStateScaffold` when denied
- If no registry tabs are allowed: empty allowed list; gate already blocks page chrome

## Page chrome

- `AsyncStateScaffold<PatientRegistryState>` over `patientRegistryControllerProvider`
  - Loading: `patientsLoadingTitle` / `patientsLoadingBody`
  - Retry: controller `refresh()`
- Body: `ResponsivePage` + `AppTabStrip` + `AppListTable<Patient>`
- In-desk URL: `syncWorkspaceLocation` with `?section=<query>` (omitted for All)
- Deep-link query (`PatientListQuery.fromUri`): `section`/`tab`, `search`/`q`, `patientId`, `contact`/`phone`, outstanding-balance / active-admission flags

## Tab strip (all visible sections)

- Component: `AppTabStrip` / `AppTabItem` (standard variant)
- Tabs omitted when unauthorized (`patientRegistrySectionTabRequirement`) — not disabled
- Counts from overview (sibling model — dedicated unfiltered scope totals):
  - All → `overview.totalPatients`
  - Active → `overview.activePatients`
  - Admitted → `overview.activeAdmissions`
  - Balance due → `overview.unpaidInvoices`
- Count tones: `warning` for Balance due; `info` for All / Active / Admitted
- Icons: people / how_to_reg / local_hospital / payments
- Strip secondary: Duplicate review (`patientsDuplicateSummaryLabel`) when `overview.duplicates` non-empty — **omitted when unauthorized** (`patientRegistryDuplicateReviewAtom` ∩ `patient:write`)

## Table toolbar (shared pattern)

Order on search bar: **Filters → Settings → Export → Register patient** (no table Print)

| Control | Label / key | Notes |
| --- | --- | --- |
| Search | `patientsSearchHint` / `patientsSearchLabel` | mic via `AppSearchBar` default |
| Clear | `patientsClearFiltersAction` | |
| Filters | `patientsAdvancedFiltersAction` → title `patientsAdvancedFiltersTitle` | Patients-owned `_PatientAdvancedFiltersDialog` |
| Settings | `commonTableSettingsActionLabel` → `commonTableSettingsTitle` | |
| Export | `commonTableExportActionLabel` | Excel via `AppListTable` export; `enableDateFilter: false` in export config |
| Print (table) | **absent** | |
| Register | `patientsRegisterPatientAction` | omitted without ∩ `patient:write` |

Column visibility storage: `patients_${section.name}` / widths `patients_cw_${section.name}`.  
Default visible columns prefer **5** data columns (Patient alwaysVisible; Status + Next action alwaysVisible).

## Shared strip / register → dialogs

### Register patient — Patients-owned + **reused** forms

- Entry: `_openRegisterPatientDialog` → `showRegisterNewPatientDialog`
- On create success: snackbar `patientsSavedMessage` → `showPatientDetailDialog`
- Gate: `patientRegistryRegisterAtom(section)` ∩ `patient:write`

### Duplicate review — Patients-owned

- `PatientDuplicateReviewDialog` when overview duplicates present
- Gate: `patientRegistryDuplicateReviewAtom` ∩ `patient:write`

## Shared row hub — Patient detail

| Surface | Owner | File |
| --- | --- | --- |
| Patient detail | Patients-owned | `patient_detail_dialog.dart` / `patient_detail_dialog_body.dart` |
| Edit / Complete record | Patients-owned | `showPatientEditDialog` |
| Schedule appointment | **reused** | `showPatientAppointmentQuickDialog` / `PatientAppointmentQuickDialog` |
| Start OPD | **reused** | `openPatientOpdEncounterFlow` / OPD encounter |
| Request admission | Patients-owned | `showPatientAdmissionQuickDialog` |
| Discharge planning | Patients-owned (+ discharge shared) | `openPatientDischargePlanningDialog` / `patient_discharge_planning_dialog.dart` |
| Lab / Radiology / Theater / Physio orders | **reused** clinical | `openPatientLabOrderDialog` etc. |
| Enroll insurance | **reused** claims | claims insurance config dialogs |
| Patient report Print | Patients-owned preview | `_PatientReportPrintPreviewDialog` → `PrintDocumentTemplates.patientChart` |
| Billing context panel | Patients-owned | `patient_billing_context_panel.dart` |
| Pharmacy context panel | Patients-owned | `patient_pharmacy_context_panel.dart` |

## Detail Quick Actions (all tabs; gates section-aware)

Mounted via `PatientDetailQuickActions` — each atom **omitted when unauthorized**:

- Schedule appointment — ∩ `patient:write`
- Start OPD / View active OPD — encounter / ∪ clinical|billing read
- Request admission / Discharge — clinical write + `inpatient-bed-management`
- Lab / Radiology / Theater / Physio — clinical write + module
- Enroll insurance — ∪ patient|billing|clinical write + `insurance-claims`
- Report — ∩ `reports:read`

## Feedback patterns (cross-tab)

- Success: `patientsSavedMessage` snackbar
- Failures: `_showFailureIfNeeded` / form banners
- Empty: `patientsEmptyTitle` / `patientsEmptyBody`
- Loading / retry: scaffold titles above
