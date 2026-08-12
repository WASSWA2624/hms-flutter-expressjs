# Radiology tab — Reporting

## 1. Tab strip

- Label: `radiologyReportingSummaryLabel` → `For reporting`
- Icon: `Icons.edit_note_outlined`
- Count source: sibling `state.reportingCount` (unfiltered summary); when active + narrowed, `state.orders.totalItemCount` via `radiologySectionTabCount`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `reporting` (aliases `reports`, `draft`)
- Stage applied: `REPORTING`
- Tab gate: `RadiologyReportingAtomPermissions.tab` = ∩ `radiology:read` + `radiology-workflows`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Request imaging**

- Labels / date filter / Export+Print gates: identical to [01-worklist.md](01-worklist.md)
  - Filters: `commonFiltersActionLabel`; Apply / Clear / Close shared footers
  - Settings: `commonTableSettings*`; Close `commonCloseActionLabel`
  - Export: ∩ `evidence:export` (`RadiologyReportingAtomPermissions.export`)
  - Print: `commonPrintActionLabel` → preview-first `printRadiologyWorkspaceList`; same export gate
- Request imaging omitted without ∩ `radiology:write`
- Nested Print triggers use `commonPrintActionLabel` → `Print`

## 3. Table

- Same `RadiologyOrder` board, **5** default columns, storage pattern, and billing-optional column as Worklist
- Scoped to reporting stage membership via controller `applyStage('REPORTING')`
- Storage: `radiology_reporting_<view>` / `radiology_cw_…`
- Row select / next-action → report composer when waiting-for-report (write); detail/print shortcuts by status

## 4. Advanced filters / search fields

Same as Worklist (Stage / Status / Modality / Priority / optional Billing gate + ordered date). Footer: Clear filters → Apply filters → Close.

## 5. Primary / secondary / row actions

- Strip: Request imaging
- Primary path: open report composer / release for awaiting-report rows when write-authorized
- Assign / Start imaging: **not mounted** (tested product exception on composer hop)

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Report composer (`radiologyReportDialogTitle`) | Radiology-owned (primary hop) |
| Print preview (`printPreviewTitle`) | Radiology-owned |
| Order detail (`radiologyDetailTitle`) | Radiology-owned (alternate statuses) |
| Cancel order | Radiology-owned |
| Request imaging | **reused** clinical radiology order dialog |
| Configurations (not strip) | Radiology-owned + **reused** catalog |

## 7. Nested / follow-on

Release keeps draft→finalize path inside report dialog. Print from composer/detail uses shared preview. Assign / Start imaging omitted.

## 8. Forms (summary)

Report narrative dominant: Findings / Impression / Recommendation / narrative; Draft / Release / Preview / Print.

## 9. Print / labels / preview

- Table Print: `commonPrintActionLabel` → preview-first list print (gated ∩ `evidence:export`)
- Composer / detail Print: `commonPrintActionLabel` → `printPreviewTitle` → `PrintDocumentTemplates.clinicalResult`
- Report preview: `radiologyReportPreviewAction` / `radiologyReportPreviewDialogTitle`
- Reported-status row open may short-circuit to print dialog

## 10. Loading / empty / error / success

Same workspace / empty / snackbar patterns as Worklist (scaffold retry; mutation snackbars; validation on empty findings).

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome / search / filters / settings | `RadiologyReportingAtomPermissions.*` read ∩ |
| Desk Export / table Print | ∩ `evidence:export` |
| Request imaging / report / cancel / configure | write ∩ `radiology:write` |
| Billing filter/column | billing hold ∩ |
| Print report (composer/detail) | print ∩ `radiology:read` |
| Request-from-clinical | clinical radiology ∪ (not strip) |
| Deep-link entry | ∪ radiology\|clinical\|billing |
