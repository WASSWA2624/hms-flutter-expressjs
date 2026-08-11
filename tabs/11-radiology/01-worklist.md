# Radiology tab — Worklist

## 1. Tab strip

- Label: `radiologyWorklistSummaryLabel`
- Icon: `Icons.pending_actions_outlined`
- Count source: sibling `state.workloadCount`; when active, `state.orders.totalItemCount`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `worklist` (alias `work`)
- Stage applied: `WORKLIST`
- Tab gate: `RadiologyWorklistAtomPermissions.tab` = ∩ `radiology:read` + `radiology-workflows`
- **Omitted when unauthorized** (not disabled)

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Request imaging**

- Search hint: `radiologySearchHint`
- Filters: `commonFiltersActionLabel` → Advanced filters; Apply `opdApplyFiltersAction`; Reset `radiologyClearFiltersAction`
- Settings: Table Settings (`commonTableSettings*`, Apply/Reset radiology column keys)
- Export: **absent** on this table
- Print (toolbar): **absent**; print from detail / reported shortcut
- Context: Request imaging (`radiologyRequestImagingAction`) — omitted without ∩ `radiology:write`
- Date filter: **enabled** — `radiologyOrderDateFilterLabel` / pick `radiologyPickOrderDateAction`

## 3. Table

- Row model: `RadiologyOrder` (`AppListTable<RadiologyOrder>`)
- Row select → detail hub (`_openRadiologyDetailDialog`)
- Default columns (**patients** view — default query):
  1. Patient (`radiologyPatientColumnLabel`) — subtitle patient id
  2. Study (`radiologyStudyColumnLabel`)
  3. Priority (`radiologyPriorityColumnLabel`)
  4. Status (`radiologyStatusColumnLabel`) — `AppWorkspaceStatusBadge`
  5. Next action (`radiologyNextActionColumnLabel`, alwaysVisible) — `RadiologyNextActionCell`
- Default columns (**orders** view, if query.view set):
  1. Order (`radiologyOrderColumnLabel`)
  2. Patient
  3. Study
  4. Status
  5. Next action
- Column choices (Settings; optional):
  - Patient ID, Orders count (patients view id), Priority, Modality, Body region, Laterality, Encounter
  - Payment auth (`radiologyPaymentAuthColumnLabel`) — **only if** billing hold ∩ `billing:read`
  - Ordered at
- Storage keys: `radiology_worklist_<view>` / `radiology_cw_…`

## 4. Advanced filters / search fields

- Groups: Stage (`radiologyStageFilterLabel`), Status, Modality, Priority
- Billing gate filter (`radiologyBillingGateFilterLabel`) — **omitted** without ∩ `billing:read`
- Search matcher: worklist patient/order/study fields (`_radiologyWorklistSearchMatcher`)
- Date range on ordered date

## 5. Primary / secondary / row actions

- Strip: Request imaging
- Next-action cell / row select → detail (or print/report shortcuts by status)
- Assign / Start imaging: **not mounted** on workbench header

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Order detail (`radiologyDetailTitle`) | Radiology-owned |
| Report composer (`radiologyReportDialogTitle`) | Radiology-owned |
| Print report (`radiologyPrintReportDialogTitle`) | Radiology-owned |
| Cancel order | Radiology-owned (`_showCancelDialog`) |
| Request imaging | **reused** clinical radiology order dialog |
| Configurations (not strip) | Radiology-owned + **reused** catalog / `LabDeleteReasonDialog` |

## 7. Nested / follow-on

From detail procedure workbench: Mark done → confirm; Report → draft/release/preview; Print → `PrintDocumentTemplates.clinicalResult`; Undo; Cancel → reason confirm.

From Request imaging: clinical request / billing state nested flows (**reused**).

From Configurations (if opened): Enable / Edit offering → radiology catalog dialogs; Disable / Delete selected → **reused** `LabDeleteReasonDialog`; Assign form (`_AssignForm`) for assignee.

## 8. Forms (summary)

- Report: narrative text + preview; Release / Draft
- Cancel: cancellation confirm/reason
- Request imaging: patient / study / clinical request field groups (**reused**)
- Assign (configurations path): assignee
- Offering enable/edit: facility offering fields (**reused** catalog)

## 9. Print / labels / preview

- Table Print: **absent**
- Detail / reported shortcut: Print report → preview options → `PrintDocumentTemplates.clinicalResult`
- Report composer: Preview (`radiologyReportPreviewAction` / `radiologyReportPreviewDialogTitle`)
- No label print on this tab

## 10. Loading / empty / error / success

- Loading: workspace `radiologyLoadingTitle` / `radiologyLoadingBody`; table `isRefreshing`
- Empty: `radiologyNoOrdersTitle` / `radiologyNoOrdersBody` (or patients variants)
- Detail loading/empty: `radiologyDetailLoading*` / `radiologyNoSelection*`
- Error: scaffold retry; mutation snackbars
- Success: write-gated mutation feedback

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list chrome / search / filters / settings / empty / loading / retry | ∩ `radiology:read` |
| Billing gate filter / billing column / payment field | ∩ `billing:read` |
| Request imaging | ∩ `radiology:write` |
| Detail mutations (done / report / cancel / undo) | ∩ `radiology:write` |
| Print report | ∩ `radiology:read` |
| Configurations nested | ∩ `radiology:write` |
| Request-from-clinical (cross-module) | clinical radiology ∪ (not strip) |
| Deep-link workspace entry | ∪ radiology\|clinical\|billing |
