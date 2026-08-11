# Patients tab — Admitted

## 1. Tab strip

- Label: `patientsTabAdmitted`
- Icon: `Icons.local_hospital_outlined`
- Count source: `state.overview.activeAdmissions`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `admitted`
- Tab gate: `PatientAdmittedAtomPermissions.tab` = ∩ `patient:read`
- **Omitted when unauthorized**
- Scope: `hasActiveAdmission: true`

## 2. Search / Filters / Settings / Export / Print / context

Same toolbar order as All. Table Print **absent**.

## 3. Table

- Row model: admitted-scope `Patient`
- Row select → detail (`registrySection: admitted`)
- Default columns: Patient, Contact, Visit, Status, Next action
  - Visit column **omitted when unauthorized** (`PatientAdmittedAtomPermissions.visitColumn` = ∪ `clinical:read` \| `billing:read`)
- Column choices: Alerts, Patient number, Age, Gender (Visit omitted from choices under same nested-read gate)
- Status badge: when nested admission status allowed, shows visit admission status; else active/inactive / incomplete

## 4. Advanced filters / search fields

Same dialog; on Admitted:

- Active admission filter shown only if nested read allowed
- Outstanding balance filter shown only if `PatientAdmittedAtomPermissions.financialStatus` (∩ `billing:read`)

## 5. Primary / secondary / row actions

Same Register / Duplicate / Complete-Open / row detail as All.

## 6. Dialogs from this tab

Same as All plus admission/discharge-heavy Quick Actions when authorized.

## 7. Nested / follow-on

- Active Work clinical bodies filtered via `filterPatientActiveWorkForAdmittedNestedRead` without ∪ clinical|billing read (appointments remain)
- Billing / pharmacy panels and clinical continues use admitted nested atoms

## 8. Forms (summary)

Same as All; discharge / admission handoff emphasized for admitted patients.

## 9. Print / labels / preview

- Table Print: **absent**
- Detail Report → `PrintDocumentTemplates.patientChart` (∩ `reports:read`)

## 10. Loading / empty / error / success

Shared registry feedback.

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome | ∩ `patient:read` |
| Visit / admission status columns | ∪ `clinical:read` \| `billing:read` |
| Outstanding balance filter / financial status | ∩ `billing:read` |
| Register / write atoms | ∩ `patient:write` |
| Admit / Discharge Quick Actions | clinical write + IPD module |
| Nested clinical Active Work body | nested read ∪ |
