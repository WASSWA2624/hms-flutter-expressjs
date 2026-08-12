# Lab tab — Critical

## 1. Tab strip

- Label: `labScopeCritical`
- Icon: `Icons.priority_high_outlined`
- Count source: `labSectionTabCount` → `summary.criticalForView(LabWorkbenchView.patients)`; active + narrowed → filtered total
- Sibling tabs: patient-view summary totals (shared chrome sibling model)
- Count tone: `AppTabCountTone.danger` (`labSectionCountTone`)
- Deep-link `section`: `critical`
- Tab gate: `LabCriticalAtomPermissions.tab`
- Scope: `LabQueueScope.critical` (`hasCriticalResult`)
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Create Lab Order**

- Same worklist chrome as Pending (Export/Print ∩ `evidence:export`)
- Create: `LabCriticalAtomPermissions.create`
- Print (toolbar): preview-first `printLabWorkspaceList`
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

- Table Print: preview-first worklist print when ∩ `evidence:export`
- Report preview → `PrintDocumentTemplates.clinicalResult`

## 10. Loading / empty / error / success

Shared Lab patterns.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome / rowSelect | `LabCriticalAtomPermissions.*` → ∩ `lab:read` |
| Create / result mutations | ∩ `lab:write` |
| criticalNotify | ∩ `lab:write` + `clinical:read` — **no chrome** |
| Export | ∩ `evidence:export` (`canExportLabWorkspace`) |
| Table Print | ∩ `evidence:export` (`canPrintLabWorkspace`) |
