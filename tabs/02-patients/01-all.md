# Patients tab — All

## 1. Tab strip

- Label: `patientsTabAll`
- Icon: `Icons.people_outlined`
- Count source: `state.overview.totalPatients` (sibling overview total); when this tab is active and search/user advanced filters narrow, `page.totalItemCount`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: omitted / empty (default All)
- Tab gate: `PatientAllAtomPermissions.tab` = ∩ `patient:read`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Register patient**

- Search hint: `patientsSearchHint`
- Clear: `opdClearFiltersAction` (`Clear filters`)
- Filters: `commonFiltersActionLabel` → `commonAdvancedFiltersTitle`
- Settings: `commonTableSettings*` (+ Close `commonCloseActionLabel`)
- Export: `canExport` via `PatientAllAtomPermissions.export` = ∩ `evidence:export` (omitted when denied)
- Print (toolbar): `commonPrintActionLabel` → `printPatientRegistryList` preview-first (same export gate)
- Context: Register (`patientsRegisterPatientAction`) — omitted without ∩ `patient:write`
- Strip secondary: Duplicate review when duplicates exist — omitted without write
- Date filter on search-bar chrome: **not** the shared date-range strip; dates live inside Advanced filters

## 3. Table

- Row model: `Patient` page from registry controller
- Row select → `showPatientDetailDialog` (`registrySection: all`)
- Default columns (5):
  1. Patient (`patientsPatientColumnLabel`, alwaysVisible) — name only (identifier via optional Patient number)
  2. Contact (`patientsPhoneIdentifierColumnLabel`)
  3. Alerts (`patientsAlertColumnLabel`)
  4. Status (`patientsStatusColumnLabel`, alwaysVisible)
  5. Next action (`patientsNextActionColumnLabel`, alwaysVisible)
- Column choices (Settings): Visit, Patient number, Age, Gender
- Mobile: title name, caption identifier, status meta

## 4. Advanced filters / search fields

Patients-owned `_PatientAdvancedFiltersDialog` (same model as table query):

- Identity: Patient ID, Contact, Facility (if >1), Gender
- Visit: Visit date, Visit from/to, Appointment status
- Record: Status (active/inactive), Consent, Active admission, Outstanding balance, DOB from/to, Created from/to
- Footer: Clear filters → Apply filters → Close

## 5. Primary / secondary / row actions

- Strip: Register; Duplicate review (when present)
- Next action: incomplete → Complete record (`patientsCompleteRecordAction`) opens edit; complete → label-only `patientsOpenRecordAction`
- Row select → Patient detail

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Patient detail | Patients-owned |
| Register new patient | Patients / shared register form |
| Duplicate review | Patients-owned |
| Edit / Complete record | Patients-owned |
| Advanced filters | Patients-owned |
| Table Print preview | Shared `PrintDocumentTemplates.registry` |

## 7. Nested / follow-on

From detail Quick Actions / Active Work (see shared chrome): appointment, OPD encounter, admission, discharge, clinical orders, insurance enroll, report print preview (`PrintDocumentTemplates.patientChart`), billing/pharmacy workbench panels.

## 8. Forms (summary)

- Register / edit patient: identity, contacts, demographics, consents, related records
- Admission quick: admission request fields
- Discharge planning: discharge plan fields
- Appointment quick: schedule fields (**reused**)
- Report preview: period mode + section checkboxes

## 9. Print / labels / preview

- Table Print: `Print` → `printPatientRegistryList` → `PrintDocumentTemplates.registry` (gate ∩ `evidence:export`)
- Detail Report Quick Action → `_PatientReportPrintPreviewDialog` → `PrintDocumentTemplates.patientChart` (gate ∩ `reports:read`)

## 10. Loading / empty / error / success

- Loading: `patientsLoadingTitle` / `patientsLoadingBody`
- Empty: `patientsEmptyTitle` / `patientsEmptyBody`
- Error: scaffold retry; snackbars
- Success: `patientsSavedMessage`
- After mutations: refresh list + overview counts

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list chrome / search / filters / settings / empty / loading / retry | ∩ `patient:read` |
| Export / Print | ∩ `evidence:export` |
| Register / Duplicate review / Complete record / Edit | ∩ `patient:write` |
| Delete in detail | ∩ `patient:delete` |
| Quick Actions / Active Work continues | section nested atoms (see access map) |
| Report print | ∩ `reports:read` |
| Route entry | ∩ `patient:read` + `patient-registry` |
