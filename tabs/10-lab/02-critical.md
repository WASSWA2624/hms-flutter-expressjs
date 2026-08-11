# Lab tab — Critical

## 1. Tab strip

- Label: `labScopeCritical`
- Icon: `Icons.priority_high_outlined`
- Count source: `summary.criticalForView(LabWorkbenchView.patients)`
- Sibling tabs: patient-view summary totals (shared chrome)
- Count tone: `AppTabCountTone.danger`
- Deep-link `section`: `critical`
- Tab gate: `LabCriticalAtomPermissions.tab`
- Scope: `LabQueueScope.critical` (`hasCriticalResult`)
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Create Lab Order**

- Same worklist chrome as Pending
- Create: `LabCriticalAtomPermissions.create`
- Print (toolbar): **not mounted**
- Date filter: **enabled**

## 3. Table

- Same patient-view columns as Pending
- Storage: `lab_critical` / `lab_cw_critical`
- Row select → result entry

## 4. Advanced filters / search fields

Same queue / payment / status / result-flag groups and text filters as Pending.

## 5. Primary / secondary / row actions

- Strip: Create
- Next-action often `labNextActionReviewCritical` when no enterable items; Enter result when activatable
- Collect / Open billing / critical notify UI: **not mounted**

## 6. Dialogs from this tab

Same Lab-owned / shared / reused set as Pending.

## 7. Nested / follow-on

Same result-entry preview / save / reopen / print chain. `LabCriticalAtomPermissions.criticalNotify` / `acknowledge` documented — **no dedicated notify chrome**.

## 8. Forms (summary)

Same create + result entry forms as Pending.

## 9. Print / labels / preview

- Table Print: **absent**
- Report preview → `PrintDocumentTemplates.clinicalResult`

## 10. Loading / empty / error / success

Shared Lab patterns.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome / rowSelect | `LabCriticalAtomPermissions.*` → ∩ `lab:read` |
| Create / result mutations | ∩ `lab:write` |
| criticalNotify | ∩ `lab:write` + `clinical:read` — **no chrome** |
| Export | ungated |
| Table Print | n/a |
