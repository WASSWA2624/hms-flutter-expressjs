# Lab tab — All patients (worklist)

## 1. Tab strip

- Label: `labScopeAll` (All patients)
- Icon: `Icons.assignment_outlined`
- Count source: `summary.totalForView(LabWorkbenchView.patients)`
- Sibling tabs: patient-view summary totals (shared chrome)
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `worklist` (alias `all`)
- Tab gate: `LabAllAtomPermissions.tab`
- Scope: `LabQueueScope.all`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Create Lab Order**

- Identical worklist chrome to Pending
- Create: `LabAllAtomPermissions.create`
- Clearing advanced filters resets section to **All patients**
- Print (toolbar): **not mounted**
- Date filter: **enabled**

## 3. Table

- Same patient-view default/optional columns as Pending
- Storage: `lab_worklist` / `lab_cw_worklist`
- Row select → result entry

## 4. Advanced filters / search fields

Same queue / payment / status / result-flag + text filters; queue `all` is native for this tab.

## 5. Primary / secondary / row actions

- Strip: Create
- Next-action Enter result / status text variants
- Orders↔Patients toggle / Lab Configurations / Collect / Open billing — **not mounted**

## 6. Dialogs from this tab

Same Lab-owned / shared / reused set as Pending.

## 7. Nested / follow-on

Same result-entry preview / save / reopen / print chain; create order + optional register patient.

## 8. Forms (summary)

Same create + result entry forms.

## 9. Print / labels / preview

- Table Print: **absent**
- Report: `PrintDocumentTemplates.clinicalResult`

## 10. Loading / empty / error / success

Shared Lab patterns (`labNoPatientsTitle` / `labNoPatientsBody`).

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome / rowSelect | `LabAllAtomPermissions.*` → ∩ `lab:read` |
| Create / result mutations | ∩ `lab:write` |
| previewReport | ∪ `lab:read` \| `lab:write` |
| viewToggle / configure / deleteOrder | documented — **not mounted** |
| Export | ungated |
| Table Print | n/a |
