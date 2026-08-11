# Patients tab — Balance due

## 1. Tab strip

- Label: `patientsTabBalanceDue`
- Icon: `Icons.payments_outlined`
- Count source: `state.overview.unpaidInvoices`; when this tab is active and search/user advanced filters narrow (ignoring section-imposed `hasOutstandingBalance: true`), `page.totalItemCount`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `balance-due` (aliases `balance_due`, `balancedue`)
- Tab gate: `PatientBalanceDueAtomPermissions.tab` = ∩ `patient:read` + `billing:read`
- **Omitted when unauthorized**
- Scope: `hasOutstandingBalance: true`

## 2. Search / Filters / Settings / Export / Print / context

Same order: **Filters → Settings → Export → Print → Register**

- List chrome / search / filters / settings / empty / retry use Balance due tab read ∩
- Export / Print: ∩ `evidence:export` (omitted when denied)
- Register still ∩ `patient:write` (omitted when denied)

## 3. Table

- Row model: balance-due-scope `Patient`
- Row select → detail (`registrySection: balanceDue`)
- Default columns: Patient, Contact, Visit, Status, Next action
- Status: prefers visit status with warning tone when visit present
- Column choices: Alerts, Patient number, Age, Gender

## 4. Advanced filters / search fields

Same advanced filter dialog as All (identity / visit / record). Footer: Clear filters → Apply filters → Close.

## 5. Primary / secondary / row actions

Register / Duplicate / Complete-Open / row detail — same pattern; gates from `PatientBalanceDueAtomPermissions`.

## 6. Dialogs from this tab

Same detail hub; billing context panel is primary nested read surface for this tab; table Print preview when export allowed.

## 7. Nested / follow-on

- Billing context panel mounted for Balance due viewers (`nestedRead` = tab read ∩)
- Open billing workbench → ∩ `billing:write` + `billing-payments` (`PatientBalanceDueAtomPermissions.billingWorkbench`)
- Enroll insurance keeps source ∪ (not matrix ∩ alone)
- Other Quick Actions / Active Work keep source clinical+module gates

## 8. Forms (summary)

Same as All; billing workbench handoff emphasized.

## 9. Print / labels / preview

- Table Print: preview-first registry template (∩ `evidence:export`)
- Detail Report: patient chart preview (∩ `reports:read`)

## 10. Loading / empty / error / success

Same as All.

## 11. RBAC / ABAC (omitted when unauthorized)

Tab/list chrome ∩ `patient:read` + `billing:read`; Export/Print ∩ `evidence:export`; Register/write ∩ `patient:write`; billing workbench ∩ `billing:write` + module.
