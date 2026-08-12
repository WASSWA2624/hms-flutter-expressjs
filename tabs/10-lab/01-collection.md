# Lab tab — Pending (collection)

## 1. Tab strip

- Label: `labScopeCollection` (Pending)
- Icon: `Icons.biotech_outlined`
- Count source: `labSectionTabCount` → `summary.collectionForView(LabWorkbenchView.patients)`; active + narrowed → filtered total
- Sibling tabs: patient-view summary totals (shared chrome sibling model)
- Count tone: `AppTabCountTone.warning` (`labSectionCountTone`)
- Deep-link `section`: `pending` (+ awaiting/processing/verification aliases → Pending)
- Tab gate: `LabAwaitingResultsAtomPermissions.tab` = ∩ `lab:read` + `lab-workflows`
- Scope: `LabQueueScope.collection`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Create Lab Order**

- Search: `labSearchHint` / `labSearchLabel`
- Filters / Settings / Export / Print: shared chrome (Export/Print ∩ `evidence:export`)
- Print (toolbar): preview-first `printLabWorkspaceList` / `commonPrintActionLabel`
- Create: `labCreateAction` — `LabAwaitingResultsAtomPermissions.create`
- Date filter: **enabled** — `labOrderedDateFilterLabel`; From/To `opdDateFromLabel` / `opdDateToLabel`

## 3. Table

- Row model: `LabOrderSummary` (patient-grouped)
- Row select → `LabResultEntryDialog` after `selectOrder`
- Default columns (**5**; `next_action` alwaysVisible):
  1. Patient (`labPatientColumnLabel`)
  2. Orders (`labOrdersColumnLabel`)
  3. Tests (`labTestsColumnLabel`)
  4. Status (`labEntryStatusColumnLabel` via `labWorklistGlanceStatus`)
  5. Next action (`labNextActionColumnLabel`)
- Column choices: patient ID, encounter, lab encounter, source location, billing/payment, entry status, result status
- Storage: `lab_collection` / `lab_cw_collection`

## 4. Advanced filters / search fields

- Groups: queue (`labScopeFilterLabel`), payment (`labPaymentColumnLabel`), status (`labEntryStatusColumnLabel`), result flag (`labResultFlagFilterLabel`: critical / abnormal / any flagged)
- Footer: Clear filters (`opdClearFiltersAction`) → Apply filters (`opdApplyFiltersAction`) → Close (`commonCloseActionLabel`)
- Search fields: `labPatientFilterLabel`, `labPatientIdFilterLabel`, `labTestFilterLabel`, `labOrderIdFilterLabel`
- Queue values can switch section: `pending` | `critical` | `completed_today` | `all`
- Date range on ordered date (shares filter model with active tab badge via `labSectionTabCount`)

## 5. Primary / secondary / row actions

- Strip: Create Lab Order
- Next-action: Enter result (`labNextActionEnterResult`); Await payment / Review critical text variants; Collect **not mounted**
- Activatable when status ≠ `CANCELLED` | `COMPLETED`

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Result entry (`LabResultEntryDialog`) | Lab-owned |
| Create context (`LabOrderContextDialog`) | **shared** |
| Clinical lab order (`ClinicalLabOrderActionDialog`) | **reused** |
| Desk settings | Lab-owned |
| Report preview / settings / reopen | Lab-owned |

## 7. Nested / follow-on

From result entry:

1. Preview report (`labPreviewReportAction`) → preview ∪ `labReportPreviewRequirement`
2. Save results (`labSaveResultsAction`) → ∩ `lab:write`
3. Edit verified → reopen dialog
4. Print from preview (`commonPrintActionLabel` → `Print`) → `PrintDocumentTemplates.clinicalResult`
5. Collect / Receive / Reject / Reverse / Open billing / Create additional / Edit order / Critical notify — **not mounted**

From create: register patient when ∩ `patient:write`.

## 8. Forms (summary)

- Context: patient search, encounter, existing order, Next
- Clinical order: tests/panels + billing resolve
- Result drafts: value/unit/text/notes/range override; reopen notes

## 9. Print / labels / preview

- Table Print: preview-first worklist print (`commonPrintActionLabel`) when ∩ `evidence:export`
- Report: `PrintDocumentTemplates.clinicalResult` (`labReportTitle` / `labReportFooter`); preview columns `lab_report_preview_columns`

## 10. Loading / empty / error / success

- Workspace loading/empty; pagination `labPreviousPageLabel` / `labNextPageLabel` / `labPageLabel`
- Success keys as shared chrome

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / search / filters / settings / pagination / empty / loading / retry / rowSelect / nextAction | `LabAwaitingResultsAtomPermissions.*` → ∩ `lab:read` |
| Create | ∩ `lab:write` |
| createPatient (nested) | ∩ `patient:write` |
| previewReport | ∪ `lab:read` \| `lab:write` |
| resultEntry / workflowMutate | ∩ `lab:write` |
| Export | ∩ `evidence:export` (`LabAwaitingResultsAtomPermissions.export`) |
| Collect / Open billing / criticalNotify chrome | documented / residual — **not mounted** |
| Table Print | ∩ `evidence:export` (`LabAwaitingResultsAtomPermissions.print`) |
