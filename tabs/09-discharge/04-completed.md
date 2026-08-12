# Discharge tab — Completed

## 1. Tab strip

- Label: `dischargeSectionCompleted`
- Icon: `Icons.check_circle_outline`
- Count source: `DischargeSectionCounts.completed` (catalog); active + search/filters → filtered section membership
- Sibling tabs: dedicated unfiltered `DischargeSectionCounts` sibling-count model
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `completed` (alias `discharged`)
- Tab gate: `DischargeCompletedAtomPermissions.tab`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print**

- Same queue chrome; date filter **on**; strip Plan/Clearance **not mounted** (justified)
- Export: ∩ `evidence:export` (`canExportDischargeWorkspace`)
- Print (toolbar): `commonPrintActionLabel` → `printDischargeWorkspaceList` (same export gate)

## 3. Table

- Row model: `IpdAdmissionSummary` (completed only)
- Row select → detail
- Default columns:
  1. Patient
  2. Location
  3. Discharged at (`ipdDischargedAtLabel`)
  4. Status
  5. Next action
- Storage: `discharge_completed` / `discharge_cw_completed`
- Mobile: discharged date

## 4. Advanced filters / search fields

- Status group; date filter **on** (`dischargeDateFilterLabel` / From / To)

## 5. Primary / secondary / row actions

- Next-action: Print only (`dischargePrintSummaryAction` → "Print" / `nextActionPrint` read)
- Detail **hides** Continue when `detail.isCompleted`
- Open billing / Request medicines remain gated when present

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Detail | Discharge-owned |
| Planning (`showDischargePlanningDialog` + Completed create/update gates) | Discharge-owned; Continue omitted when completed |
| Print clinical summary | **reused** `PrintDocumentTemplates.clinicalSummary` (trigger `Print`) |
| Pharmacy | reachable only if actions still shown |

## 7. Nested / follow-on

Print preview path; Open billing navigate; pharmacy if write still exposed.

## 8. Forms (summary)

No plan/finalize when completed Continue hidden; pharmacy form if Request medicines shown.

## 9. Print / labels / preview

- Table Print: preview-first `printDischargeWorkspaceList` (`commonPrintActionLabel`)
- Next-action / detail footer → clinicalSummary template (`dischargeReport*`; trigger `Print`)

## 10. Loading / empty / error / success

Shared Discharge patterns.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome / detail | `DischargeCompletedAtomPermissions.*` → workspace read ∪ |
| nextActionPrint / printSummary | read ∪ |
| create / update (planning dialog) | Completed atom map (section-scoped); Continue unmounted when completed |
| continue / plan / finalize (billing inventory) | documented **unmounted** where completed |
| Export / Print (toolbar) | ∩ `evidence:export` |
