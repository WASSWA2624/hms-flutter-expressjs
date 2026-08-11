# Discharge tab — Completed

## 1. Tab strip

- Label: `dischargeSectionCompleted`
- Icon: `Icons.check_circle_outline`
- Count source: `state.completedCount` (client filter `isCompletedDischarge`)
- Sibling tabs: loaded-queue / client-filter model (shared chrome)
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `completed` (alias `discharged`)
- Tab gate: `DischargeCompletedAtomPermissions.tab`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export**

- Same queue chrome; date filter **off**; no strip Plan; no table Print

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

- Status group; date filter **off**

## 5. Primary / secondary / row actions

- Next-action: Print only (`dischargePrintSummaryAction` / `nextActionPrint` read)
- Detail **hides** Continue when `detail.isCompleted`
- Open billing / Request medicines remain gated when present

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Detail | Discharge-owned |
| Print clinical summary | **reused** `PrintDocumentTemplates.clinicalSummary` |
| Pharmacy / planning | reachable only if actions still shown; Continue omitted when completed |

## 7. Nested / follow-on

Print preview path; Open billing navigate; pharmacy if write still exposed.

## 8. Forms (summary)

No plan/finalize when completed Continue hidden; pharmacy form if Request medicines shown.

## 9. Print / labels / preview

- Table Print: **absent**
- Next-action / detail footer → clinicalSummary template (`dischargeReport*`)

## 10. Loading / empty / error / success

Shared Discharge patterns.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome / detail | `DischargeCompletedAtomPermissions.*` → workspace read ∪ |
| nextActionPrint / printSummary | read ∪ |
| continue / plan / finalize (billing inventory) | documented **unmounted** where completed |
| Export | ungated |
| Table Print | n/a |
