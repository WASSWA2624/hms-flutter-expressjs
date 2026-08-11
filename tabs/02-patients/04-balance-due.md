# Patients tab — Balance due

## 1. Tab strip

- Label: `patientsTabBalanceDue`
- Icon: `Icons.payments_outlined`
- Count source: `state.overview.unpaidInvoices`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `balance-due` (aliases `balance_due`, `balancedue`)
- Tab gate: `PatientBalanceDueAtomPermissions.tab` = ∩ `patient:read` + `billing:read`
- **Omitted when unauthorized**
- Scope: `hasOutstandingBalance: true`

## 2. Search / Filters / Settings / Export / Print / context

Same order: **Filters → Settings → Export → Register**

- List chrome / search / filters / settings / empty / retry use Balance due tab read ∩
- Register still ∩ `patient:write` (omitted when denied)
- Table Print: **absent**

## 3. Table

- Row model: balance-due-scope `Patient`
- Row select → detail (`registrySection: balanceDue`)
- Default columns: Patient, Contact, Visit, Status, Next action
- Status: prefers visit status with warning tone when visit present
- Column choices: Alerts, Patient number, Age, Gender

## 4. Advanced filters / search fields

Same advanced filter dialog as All (identity / visit / record).

## 5. Primary / secondary / row actions

Register / Duplicate / Complete-Open / row detail — same pattern; gates from `PatientBalanceDueAtomPermissions`.

## 6. Dialogs from this tab

Same detail hub; billing context panel is primary nested read surface for this tab.

## 7. Nested / follow-on

- Billing context panel mounted for Balance due viewers (`nestedRead` = tab read ∩)
- Open billing workbench → ∩ `billing:write` + `billing-payments` (`PatientBalanceDueAtomPermissions.billingWorkbench`)
- Enroll insurance keeps source ∪ (not matrix ∩ alone)
- Other Quick Actions / Active Work keep source clinical+module gates

## 8. Forms (summary)

Same as All; billing workbench navigation emphasized.

## 9. Print / labels / preview

- Table Print: **absent**
- Detail Report → `PrintDocumentTemplates.patientChart` (∩ `reports:read`)

## 10. Loading / empty / error / success

Shared registry feedback; success snackbars still write-gated entry paths.

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / list chrome / row select / Open record label | ∩ `patient:read` + `billing:read` |
| Register / Duplicate / Complete / Edit | ∩ `patient:write` |
| Billing workbench / nested write | ∩ `billing:write` + `billing-payments` |
| Enroll insurance | source ∪ + claims module |
| Report | ∩ `reports:read` |
| Delete | ∩ `patient:delete` |
