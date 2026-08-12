# Lab tab — Completed

## 1. Tab strip

- Label: `labScopeCompleted`
- Icon: `Icons.task_alt_outlined`
- Count source: `labSectionTabCount` → `summary.completedForView(LabWorkbenchView.patients)`; active + narrowed → filtered total
- Sibling tabs: patient-view summary totals (shared chrome sibling model)
- Count tone: `AppTabCountTone.info` (`labSectionCountTone`)
- Deep-link `section`: `completed-today` (aliases `verified`, `completed`, `completed_today`, `done`)
- Tab gate: `LabVerifiedAtomPermissions.tab`
- Scope: `LabQueueScope.completed`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Create Lab Order**

- Same worklist chrome as Pending (Export/Print ∩ `evidence:export`)
- Create: `LabVerifiedAtomPermissions.create`
- Print (toolbar): preview-first `printLabWorkspaceList`
- Date filter: **enabled**

## 3. Table

- Same patient-view columns as Pending
- Storage: `lab_completed` / `lab_cw_completed`
- Row select still opens result entry (read / reopen path)

## 4. Advanced filters / search fields

Same advanced filter model as Pending.

## 5. Primary / secondary / row actions

- Next-action for `COMPLETED`: `labNextActionCompleted` (**text-only**, not activatable)
- Row select → result entry for review / reopen when write ∩

## 6. Dialogs from this tab

Result entry + reopen + report preview/settings + create path (shared catalog).

## 7. Nested / follow-on

Edit verified (`labEditVerifiedResultAction`) → `_ReopenSavedResultDialog` → save; preview/print clinicalResult.

## 8. Forms (summary)

Result reopen notes + draft fields; create forms if Create used.

## 9. Print / labels / preview

- Table Print: preview-first worklist print when ∩ `evidence:export`
- Report: `PrintDocumentTemplates.clinicalResult`

## 10. Loading / empty / error / success

Shared Lab patterns; reopen success `labVerifiedResultReopenedMessage`.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome / rowSelect | `LabVerifiedAtomPermissions.*` → ∩ `lab:read` |
| Create / editVerifiedResult / reopenVerifiedResult | ∩ `lab:write` |
| openBilling | documented — **not mounted** |
| Export | ∩ `evidence:export` (`canExportLabWorkspace`) |
| Table Print | ∩ `evidence:export` (`canPrintLabWorkspace`) |
