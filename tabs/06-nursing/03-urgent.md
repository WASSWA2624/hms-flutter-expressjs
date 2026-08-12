# Nursing tab — Urgent

## 1. Tab strip

- Label: `nursingScopeUrgentLabel`
- Icon: `Icons.priority_high_outlined`
- Count source: `state.scopeCounts.urgent` / `state.urgentCount` via `nursingScopeTabCount` (sibling unfiltered `NursingScopeCounts`); when this tab is selected and search/advanced filters narrow the list, badge uses filtered `worklist.totalItemCount`
- Sibling tabs: dedicated unfiltered `NursingScopeCounts`
- Count always shown including `0` (never null when zero)
- Count tone: `AppTabCountTone.danger`
- Deep-link `scope`: `urgent` (alias `critical`)
- Tab gate: `NursingUrgentAtomPermissions.tab` = `nursingWorkspaceReadRequirement` (∩ `nursing:read` + `inpatient-bed-management`)
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
- Scope: `NursingQueueScope.urgent` — `matchesScope` = `isUrgent` (critical alert / CRITICAL|URGENT|transfer-in-progress markers)
- Row select → `NursingPatientDetailDialog` (generic title `nursingPatientContextLabel`; identity in body)
- Default columns (~5): patient, **priority**, location, status + next_action (Next action **omitted** when write gate fails; justified ≤5 with always-visible next_action when write)
- Mobile meta includes priority
- Column choices (Settings exposes all): shared pool (task_type, admission, due_time, responsible_nurse, observations, medication_due_count when pharmacy:read, transfer_status, discharge_status)
- Patient cell uses `bodyMedium` (no strong weight in rows — `tables.mdc`)
- Storage keys: `'nursing_urgent'` / `'nursing_cw_urgent'`
- Cell style: no bold/emphasis in row cells (`tables.mdc`)

## 4. Advanced filters / search fields

- Shared nursing worklist text filters + option groups + date range (priority group especially relevant)
- Footer: Clear filters → Apply filters → Close
- Active badge reflects filtered membership when narrowed

## 5. Primary / secondary / row actions

- Next-action: if `hasCriticalAlert` → Escalate; else task-type cascade (med / handover / transfer / discharge / vitals)
- Detail: complementary Quick Actions; Escalate omitted when it is the row next-action

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Patient detail | Nursing-owned; generic title `nursingPatientContextLabel`; identity in body `AppPatientDetails` |
| Escalation (`NursingEscalationDialog` → handover escalated) | Nursing-owned |
| Handover / med / transfer / discharge / vitals / print summary | Nursing-owned (vitals wraps **reused**) |
| Clinical free-text / orders | **reused** clinical |

## 7. Nested / follow-on

- Meds panel when ∩ `pharmacy:read`
- Billing clearance panel + Open billing (`billingPanel` / `openBilling` on urgent atom map)
- Open ICU (`RouteAccessCatalog.icuEntry`)
- `panel=` deep links under matching write gates (incl. `transfer`)

## 8. Forms (summary)

- Escalation / handover notes; shared nursing forms when complementary actions run
- No tenant/facility/session fields on operator forms

## 9. Print / labels / preview

- Table Print: `commonPrintActionLabel` → preview-first `printNursingWorkspaceList`
- Detail Print: `commonPrintActionLabel` (`Print`) → `showNursingPrintSummary` / `PrintDocumentTemplates.clinicalSummary`

## 10. Loading / empty / error / success

- Shared nursing loading / empty / success feedback
- Mutations refresh worklist + sibling `scopeCounts` (urgent contributes to shell `nursingWorkloadCount`)

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / detail / priority chrome | `nursingWorkspaceReadRequirement` |
| Export / Print | ∩ `evidence:export` |
| write / nextActionEscalate / escalate / complementary writes / printSummary | `nursingWriteRequirement` |
| Medication stage | medication administer ∩ |
| Stage handover / transfer / discharge next-actions | pending-tab `nursingClinicalWriteRequirement` |
| medicationsPanel | ∩ `pharmacy:read` |
| shiftContext | shift context req |
| billingPanel / openBilling | ∩ `billing:read` + `billing-payments` |
| openIcu / navigation | `RouteAccessCatalog.icuEntry` |
| Route entry | catalog ∩ `nursing:read` + module |
