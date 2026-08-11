# Patients tab — Admitted

## 1. Tab strip

- Label: `patientsTabAdmitted`
- Icon: `Icons.local_hospital_outlined`
- Count source: `state.overview.activeAdmissions`; when this tab is active and search/user advanced filters narrow (ignoring section-imposed `hasActiveAdmission: true`), `page.totalItemCount`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `admitted`
- Tab gate: `PatientAdmittedAtomPermissions.tab` = ∩ `patient:read`
- **Omitted when unauthorized**
- Scope: `hasActiveAdmission: true`

## 2. Search / Filters / Settings / Export / Print / context

Same toolbar order as All: **Filters → Settings → Export → Print → Register**. Export/Print ∩ `evidence:export`.

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
- Footer: Clear filters → Apply filters → Close

## 5. Primary / secondary / row actions

Same Register / Duplicate / Complete-Open / row detail as All.

## 6. Dialogs from this tab

Same as All plus admission/discharge-heavy Quick Actions when authorized; table Print preview when export allowed.

## 7. Nested / follow-on

- Active Work clinical bodies filtered via `filterPatientActiveWorkForAdmittedNestedRead` without ∪ clinical|billing read (appointments remain)
- Billing / pharmacy panels and clinical continues use admitted nested atoms

## 8. Forms (summary)

Same as All; discharge / admission handoff emphasized for admitted patients.

## 9. Print / labels / preview

- Table Print: preview-first registry template (∩ `evidence:export`)
- Detail Report: patient chart preview (∩ `reports:read`)

## 10. Loading / empty / error / success

Same as All.

## 11. RBAC / ABAC (omitted when unauthorized)

Same pattern as All with `PatientAdmittedAtomPermissions` atoms; Export/Print ∩ `evidence:export`; Visit/status nested read ∪ clinical|billing.
