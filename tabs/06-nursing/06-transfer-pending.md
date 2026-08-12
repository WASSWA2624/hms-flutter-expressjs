# Nursing tab — Transfer pending

## 1. Tab strip

- Label: `nursingScopeTransferPendingLabel`
- Icon: `Icons.transfer_within_a_station_outlined`
- Count source: `state.scopeCounts.transferPending` / `state.transferPendingCount` via `nursingScopeTabCount` (sibling unfiltered `NursingScopeCounts`); when this tab is selected and search/advanced filters narrow the list, badge uses filtered `worklist.totalItemCount`
- Sibling tabs: dedicated unfiltered `NursingScopeCounts`
- Count always shown including `0` (never null when zero)
- Count tone: `AppTabCountTone.warning`
- Deep-link `scope`: `transfer-pending` (aliases `transfer_pending`, `transfer`)
- Tab gate: `NursingTransferPendingAtomPermissions.tab` = `nursingWorkspaceReadRequirement` (∩ `nursing:read` + `inpatient-bed-management`)
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
- Scope: `NursingQueueScope.transferPending` — `matchesScope` = `hasPendingTransfer` (REQUESTED / APPROVED / IN_PROGRESS)
- Row select → `NursingPatientDetailDialog` (generic title `nursingPatientContextLabel`; identity in body)
- Default columns (~5): patient, location, **transfer_status**, status + next_action (Next action **omitted** when clinical write gate fails; justified ≤5 with always-visible next_action when write)
- Column choices (Settings exposes all): shared pool (priority, task_type, admission, due_time, responsible_nurse, observations, medication_due_count when pharmacy:read, discharge_status)
- Patient cell uses `bodyMedium` (no strong weight in rows — `tables.mdc`)
- Storage keys: `'nursing_transferPending'` / `'nursing_cw_transferPending'`
- Cell style: no bold/emphasis in row cells (`tables.mdc`)

## 4. Advanced filters / search fields

- Shared nursing filters including `transfer_status` (REQUESTED…CANCELLED) + date range
- Footer: Clear filters → Apply filters → Close
- Active badge reflects filtered membership when narrowed

## 5. Primary / secondary / row actions

- Next-action Acknowledge transfer → `NursingTransferDialog`
- Detail complementary Quick Actions when source write allows; Acknowledge transfer omitted when it is the row next-action

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Patient detail | Nursing-owned; generic title `nursingPatientContextLabel`; identity in body `AppPatientDetails` |
| `NursingTransferDialog` | Nursing-owned |
| Complementary Nursing/Clinical dialogs | Nursing / **reused** |
| Print summary | Nursing helper → clinical summary |

Deep link `panel=transfer` → focused transfer dialog when `NursingTransferPendingAtomPermissions.panelDeepLink` (`nursingClinicalWriteRequirement`) allows.

## 7. Nested / follow-on

- Meds panel when ∩ `pharmacy:read`
- Billing clearance panel + Open billing (`billingPanel` / `openBilling` on transfer atom map)
- Open ICU (`RouteAccessCatalog.icuEntry`)
- Admission checklist write steps; complementary detail writes

## 8. Forms (summary)

- Transfer: action select (APPROVE / START / COMPLETE / CANCEL) + optional to-bed if COMPLETE + confirm
- No tenant/facility/session fields on operator forms; dependent bed field when completing

## 9. Print / labels / preview

- Table Print: `commonPrintActionLabel` → preview-first `printNursingWorkspaceList`
- Detail Print: `commonPrintActionLabel` (`Print`) → `showNursingPrintSummary` / `PrintDocumentTemplates.clinicalSummary`

## 10. Loading / empty / error / success

- Shared nursing loading / empty feedback
- Stage success / validation use `nursingClinicalWriteRequirement`
- Mutations refresh worklist + sibling `scopeCounts`

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / detail / transfer_status chrome | `nursingWorkspaceReadRequirement` |
| Export / Print | ∩ `evidence:export` |
| Stage write / nextActionTransfer / acknowledgeTransfer / success / validation / panelDeepLink | `nursingClinicalWriteRequirement` |
| complementaryWrite / checklist / vitals / note | `nursingWriteRequirement` |
| medicationsPanel / administerMedication | pharmacy / med administer ∩ |
| billingPanel / openBilling | ∩ `billing:read` + `billing-payments` |
| openIcu / navigation | `RouteAccessCatalog.icuEntry` |
| shiftContext | shift context req |
| Route entry | catalog ∩ `nursing:read` + module |
