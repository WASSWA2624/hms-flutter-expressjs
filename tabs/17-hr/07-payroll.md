# HR tab — Payroll

## 1. Tab strip

- Label: `hrPayrollDraftsSummaryLabel`
- Icon: `Icons.payments_outlined`
- Count source: `summary.payrollDraftRuns`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `payroll` (alias `payroll-drafts`)
- Queue: `PAYROLL_DRAFTS`
- Tab gate: `HrPayrollDraftsAtomPermissions.tab`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Search hint: `hrPayCompensationSearchHint`
- Filters: status Outstanding-as-all (`hrPayCompensationFilterOutstanding`) + DRAFT/PROCESSED/PAID/CANCELLED labels
- Context: `hrPayCompensationGenerateAction` if `create` (∩ `hr:write`)
- No queue facet (`showQueueFacet` false for payroll)
- Export ungated; Print off on list
- Storage: `hr_work_queue_payrollDrafts_v4`

## 3. Table

- Columns: period, run id, staff count, total, lane, status, next action
- Next labels via `hrPayrollNextActionLabel` (Review & approve / Mark paid / Preview)
- Row select → payroll detail

## 4. Advanced filters / search fields

- Status group (outstanding + lifecycle); no queue facet

## 5. Primary / secondary / row actions

- Strip: Generate payroll
- Next-action / detail process: `HrPayrollDraftsAtomPermissions.process` / `nextAction` = `hrPayrollRequirement` (∩ `hr:write` + ∪ `financial:approve` + module)
- Preview: `preview` = `hr:read`

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Generate payroll | HR-owned |
| Payroll detail (approve/send, mark paid, cancel, print) | HR-owned |
| Process fields (`HrProcessPayrollFields`) | HR-owned |
| Preview dialog | HR-owned |

## 7. Nested / follow-on

- Process notes/replace; lifecycle confirms; print from detail

## 8. Forms (summary)

- Period start/end generate
- Process notes/replace
- Lifecycle confirms

## 9. Print / labels / preview

- Detail Print (`commonPrintActionLabel`) → registry; strip Generate is create, not print

## 10. Loading / empty / error / success

- Empty: `hrPayCompensationEmptyTitle` / `Body`
- Success: `hrSavedMessage`

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / preview | ∩ `hr:read` (+ payroll tab atoms) |
| Generate | ∩ `hr:write` — omitted |
| Process / next | `hrPayrollRequirement` — omitted |
| Export | ungated |
| List Print | absent |
