# Patients tab — Active

## 1. Tab strip

- Label: `patientsTabActive`
- Icon: `Icons.how_to_reg_outlined`
- Count source: `state.overview.activePatients`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `active`
- Tab gate: `PatientActiveAtomPermissions.tab` = ∩ `patient:read`
- **Omitted when unauthorized**
- Scope: `applyToQuery` sets `isActive: true`

## 2. Search / Filters / Settings / Export / Print / context

Same shared order as All: **Filters → Settings → Export → Register**

- Labels / gates identical to All (`PatientActiveAtomPermissions.*`)
- Table Print: **absent**

## 3. Table

- Row model: `Patient` with active filter applied
- Row select → detail (`registrySection: active`)
- Default columns (5): Patient, Contact, Visit (`patientsVisitColumnLabel`), Status, Next action
- Column choices: Alerts, Patient number, Age, Gender

## 4. Advanced filters / search fields

Same `_PatientAdvancedFiltersDialog` as All (identity / visit / record groups).

## 5. Primary / secondary / row actions

Same as All: Register, Duplicate review, Complete/Open next-action, row → detail.

## 6. Dialogs from this tab

Same hub set as All (detail, register, duplicate, edit, filters).

## 7. Nested / follow-on

Same Quick Actions / Active Work / billing / pharmacy / report chain as All (`PatientActiveAtomPermissions` nested atoms).

## 8. Forms (summary)

Same as All (register/edit, appointment, admission, discharge, clinical orders, report).

## 9. Print / labels / preview

- Table Print: **absent**
- Detail Report → `PrintDocumentTemplates.patientChart` when ∩ `reports:read`

## 10. Loading / empty / error / success

Shared registry scaffold / empty / `patientsSavedMessage`.

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome | ∩ `patient:read` (`PatientActiveAtomPermissions.tab`) |
| Register / Duplicate / Complete / Edit | ∩ `patient:write` |
| Delete | ∩ `patient:delete` |
| Nested Quick Actions | `PatientActiveAtomPermissions.*` (same sources as All) |
