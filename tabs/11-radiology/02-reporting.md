# Radiology tab — Reporting

## 1. Tab strip

- Label: `radiologyReportingSummaryLabel`
- Icon: `Icons.edit_note_outlined`
- Count source: sibling `state.reportingCount`; when active, `state.orders.totalItemCount`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `reporting` (aliases `reports`, `draft`)
- Stage applied: `REPORTING`
- Tab gate: `RadiologyReportingAtomPermissions.tab` = ∩ `radiology:read` + `radiology-workflows`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Same order-board chrome as Worklist: **Filters → Settings → Request imaging**

- Labels / date filter / missing Export+table Print: identical to [01-worklist.md](01-worklist.md)
- Request imaging omitted without ∩ `radiology:write`

## 3. Table

- Same `RadiologyOrder` board, columns, storage pattern, and billing-optional column as Worklist
- Scoped to reporting stage membership via controller `applyStage('REPORTING')`
- Row select / next-action → detail (often report composer when waiting-for-report)

## 4. Advanced filters / search fields

Same as Worklist (Stage / Status / Modality / Priority / optional Billing gate + ordered date).

## 5. Primary / secondary / row actions

- Strip: Request imaging
- Primary path: open report composer / release for awaiting-report rows when write-authorized
- Assign / Start imaging: **not mounted**

## 6. Dialogs from this tab

Same set as Worklist (detail, report composer, print, cancel, request imaging, configurations-not-strip). Owners unchanged.

## 7. Nested / follow-on

Same chains as Worklist; Release keeps draft→finalize path inside report dialog.

## 8. Forms (summary)

Same as Worklist — report narrative dominant on this section.

## 9. Print / labels / preview

- Table Print: **absent**
- Report preview + Print report → `PrintDocumentTemplates.clinicalResult`
- Reported-status row open may short-circuit to print dialog

## 10. Loading / empty / error / success

Same workspace / empty / snackbar patterns as Worklist.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome | `RadiologyReportingAtomPermissions.*` read ∩ |
| Request imaging / report / cancel / configure | write ∩ `radiology:write` |
| Billing filter/column | billing hold ∩ |
| Print report | print ∩ `radiology:read` |
