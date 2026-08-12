# Nursing tab — Assigned ward

## 1. Tab strip

- Label: `nursingScopeAssignedWardLabel`
- Icon: `Icons.local_hospital_outlined`
- Count source: `state.scopeCounts.assignedWard` / `state.assignedWardCount` via `nursingScopeTabCount` (sibling unfiltered `NursingScopeCounts`); when this tab is selected and search/advanced filters narrow the list, badge uses filtered `worklist.totalItemCount`
- Sibling tabs: dedicated unfiltered `NursingScopeCounts`
- Count always shown including `0` (never null when zero)
- Count tone: `AppTabCountTone.info`
- Deep-link `scope`: `assigned-ward` (aliases `assigned_ward`, `ward`)
- Tab gate: `NursingAssignedWardAtomPermissions.tab` = `nursingWorkspaceReadRequirement` (∩ `nursing:read` + `inpatient-bed-management`)
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Shift context** (unauthorized Export/Print/Shift omitted)

- Search: `nursingSearchLabel` / `nursingSearchHint` (clear → `applySearch('')`)
- Filters: `commonFiltersActionLabel` → `commonAdvancedFiltersTitle`; Apply `opdApplyFiltersAction`; Clear `opdClearFiltersAction`; Close `commonCloseActionLabel`
- Settings: `commonTableSettingsActionLabel` → `commonTableSettingsTitle`; Reset/Apply/Close via reception/common keys
- Export: `commonTableExportActionLabel` gated by `canExportNursingWorkspace` (∩ `evidence:export`)
- Print: `commonPrintActionLabel` gated by `canPrintNursingWorkspace`; preview-first `printNursingWorkspaceList`
- Shift context: `nursingShiftContextTitle` when `nursingShiftContextRequirement`
- Date filter: **enabled** — `nursingDateFilterLabel` / From / To

## 3. Table

- Row model: `NursingWorkItem` via `NursingWorklistPanel`
- Scope: `NursingQueueScope.assignedWard` — `matchesScope` = `hasActiveBed` (patients currently on a ward bed)
- Row select → `NursingPatientDetailDialog` (generic title `nursingPatientContextLabel`; identity in body)
- Default columns (~5): patient, location, task_type, status + next_action (Next action **omitted** when write gate fails; justified ≤5 with always-visible next_action when write)
- Column choices (Settings exposes all): shared pool (priority, admission, due_time, responsible_nurse, observations, medication_due_count when pharmacy:read, transfer_status, discharge_status)
- Patient cell uses `bodyMedium` (no strong weight in rows — `tables.mdc`)
- Storage keys: `'nursing_assignedWard'` / `'nursing_cw_assignedWard'`
- Cell style: no bold/emphasis in row cells (`tables.mdc`)

## 4. Advanced filters / search fields

- Shared nursing worklist text filters + option groups + date range
- Footer: Clear filters → Apply filters → Close
- Active badge reflects filtered membership when narrowed

## 5. Primary / secondary / row actions

- Same next-action cascade and detail Quick Actions as All (task-type → med / handover / transfer / discharge / vitals)

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Patient detail | Nursing-owned; generic title `nursingPatientContextLabel`; identity in body `AppPatientDetails` |
| Vitals / medication / handover / escalation / transfer / discharge / note / shift / print summary | Nursing-owned (vitals wraps **reused**) |
| Free-text / prescribe / lab / radiology | **reused** clinical |

## 7. Nested / follow-on

- Billing clearance panel + Open billing
- Open ICU when ACTIVE (`RouteAccessCatalog.icuEntry`)
- Print summary; clinical nested orders
- `panel=` deep links under matching write gates (incl. `transfer`)

## 8. Forms (summary)

Same as All — vitals, med admin, handover, escalation, transfer, discharge clearance, note, checklist.

## 9. Print / labels / preview

- Table Print: `commonPrintActionLabel` → preview-first `printNursingWorkspaceList`
- Detail Print: `commonPrintActionLabel` (`Print`) → `showNursingPrintSummary` / `PrintDocumentTemplates.clinicalSummary`

## 10. Loading / empty / error / success

- Loading / empty / success: shared nursing feedback (`nursingLoading*`, `nursingNoWorklist*`, `nursingSavedMessage`)
- Mutations refresh worklist + sibling `scopeCounts` (incl. assigned-ward badge used in shell workload)

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list chrome / search / filters / settings / detail | `nursingWorkspaceReadRequirement` |
| Export / Print | ∩ `evidence:export` |
| Writes / next-action mutations / printSummary | `nursingWriteRequirement` |
| Medication atoms | medication administer ∩ |
| medicationsPanel | ∩ `pharmacy:read` |
| shiftContext | shift context req |
| billingPanel / openBilling | ∩ `billing:read` + `billing-payments` |
| openIcu / navigation | `RouteAccessCatalog.icuEntry` |
| Route entry | catalog ∩ `nursing:read` + module |
