# Patients tab — Active

## 1. Tab strip

- Label: `patientsTabActive`
- Icon: `Icons.how_to_reg_outlined`
- Count source: `state.overview.activePatients`; when this tab is active and search/user advanced filters narrow (ignoring section-imposed `isActive: true`), `page.totalItemCount`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `active`
- Tab gate: `PatientActiveAtomPermissions.tab` = ∩ `patient:read`
- **Omitted when unauthorized**
- Scope: `applyToQuery` sets `isActive: true`

## 2. Search / Filters / Settings / Export / Print / context

Same shared order as All: **Filters → Settings → Export → Print → Register**

- Labels / gates identical to All (`PatientActiveAtomPermissions.*`)
- Export / Print: ∩ `evidence:export` (omitted when denied)

## 3. Table

- Row model: `Patient` with active filter applied
- Row select → detail (`registrySection: active`)
- Default columns (5): Patient, Contact, Visit (`patientsVisitColumnLabel`), Status, Next action
- Column choices: Alerts, Patient number, Age, Gender

## 4. Advanced filters / search fields

Same `_PatientAdvancedFiltersDialog` as All (identity / visit / record groups). Footer: Clear filters → Apply filters → Close.

## 5. Primary / secondary / row actions

Same as All: Register, Duplicate review, Complete/Open next-action, row → detail.

## 6. Dialogs from this tab

Same hub set as All (detail, register, duplicate, edit, filters, table Print preview).

## 7. Nested / follow-on

Same Quick Actions / Active Work / billing / pharmacy / report chain as All (`PatientActiveAtomPermissions` nested atoms).

## 8. Forms (summary)

Same as All (register/edit, appointment, admission, discharge, clinical orders, report).

## 9. Print / labels / preview

- Table Print: `Print` → preview-first registry template (∩ `evidence:export`)
- Detail Report: patient chart preview (∩ `reports:read`)

## 10. Loading / empty / error / success

Same as All.

## 11. RBAC / ABAC (omitted when unauthorized)

Same pattern as All with `PatientActiveAtomPermissions` atoms; Export/Print ∩ `evidence:export`.
