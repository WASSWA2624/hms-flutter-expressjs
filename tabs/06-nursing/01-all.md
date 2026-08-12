# Nursing tab — All

## 1. Tab strip

- Label: `nursingScopeAllLabel`
- Icon: `Icons.inventory_2_outlined`
- Count source: `state.scopeCounts.all` via `nursingScopeTabCount` (sibling unfiltered `NursingScopeCounts`); when this tab is selected and search/advanced filters narrow the list, badge uses filtered `worklist.totalItemCount` (fallback `worklist.items.length`)
- Sibling tabs: dedicated unfiltered `NursingScopeCounts`
- Count always shown including `0` (never null when zero)
- Count tone: `AppTabCountTone.info`
- Deep-link `scope`: `all` (default `/nursing`; alias `''`)
- Tab gate: `NursingAllAtomPermissions.tab` = `nursingWorkspaceReadRequirement` (∩ `nursing:read` + `inpatient-bed-management`)
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Shift context** (unauthorized Export/Print/Shift omitted)

- Search: `nursingSearchLabel` / `nursingSearchHint` (clear → `applySearch('')`)
- Filters: `commonFiltersActionLabel` → `commonAdvancedFiltersTitle`; Apply `opdApplyFiltersAction`; Clear `opdClearFiltersAction`; Close `commonCloseActionLabel`
- Settings: `commonTableSettingsActionLabel` → `commonTableSettingsTitle`; Reset/Apply/Close via reception/common keys
- Export: `commonTableExportActionLabel` gated by `canExportNursingWorkspace` (∩ `evidence:export`)
- Print: `commonPrintActionLabel` gated by `canPrintNursingWorkspace`; preview-first `printNursingWorkspaceList` (`nursing_workspace_print_helpers.dart` → `PrintDocumentTemplates.registry`)
- Shift context: `nursingShiftContextTitle` when `nursingShiftContextRequirement`
- Date filter: **enabled** — `nursingDateFilterLabel` / From / To

## 3. Table

- Row model: `NursingWorkItem` via `NursingWorklistPanel`
- Scope: `NursingQueueScope.all` (`matchesScope` → always true)
- Row select → `NursingPatientDetailDialog` (`omitNextActionKind` = stage next)
- Default columns (~5): patient, location, task_type, status + next_action (Next action **omitted** when write gate fails; justified ≤5 with always-visible next_action when write)
- Column choices (Settings exposes all): priority, admission, due_time, responsible_nurse, observations, medication_due_count (pharmacy:read), transfer_status, discharge_status (plus defaults)
- Patient cell uses `bodyMedium` (no strong weight in rows — `tables.mdc`)
- Storage keys: `'nursing_all'` / `'nursing_cw_all'`
- Cell style: no bold/emphasis in row cells (`tables.mdc`)

## 4. Advanced filters / search fields

- Text: patient, admission, encounter, ward, room, bed, observation, task_type, assigned_nurse, shift
- Groups: scope, status, priority, transfer_status, handover_status, discharge_status
- Date range enabled
- Active badge reflects filtered membership when narrowed (same filter model as table)

## 5. Primary / secondary / row actions

- Next-action cascade by `taskTypeCode` → med / handover / transfer / discharge / else vitals
- Detail Quick Actions: handover, vitals, note, lab, radiology, med, prescribe, escalate, transfer, discharge, open ICU, print, accept handover, open billing (when gated)

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Patient detail (`NursingPatientDetailDialog`) | Nursing-owned; generic title `nursingPatientContextLabel`; identity in body `AppPatientDetails` |
| Vitals / medication / handover / escalation / transfer / discharge / note / shift | Nursing-owned (vitals wraps **reused** `AppRecordVitalsDialog`) |
| Print summary (`showNursingPrintSummary`) | Nursing helper → `PrintDocumentTemplates.clinicalSummary` |
| Free-text / prescribe / lab / radiology | **reused** clinical |

## 7. Nested / follow-on

- Billing clearance panel + Open billing (∩ `billing:read` + `billing-payments`)
- Open ICU when ACTIVE (`RouteAccessCatalog.icuEntry`)
- Clinical order nested billing when mounted
- Checklist free-text steps
- `panel=` deep links (`checklist` / `vitals` / `medication` / `handover` / `transfer` / `discharge`) under matching write gates

## 8. Forms (summary)

- Vitals set; med admin; handover (+ attachments); escalation; transfer APPROVE/START/COMPLETE/CANCEL; discharge clearance checkboxes; note + optional charge; free-text checklist
- No tenant/facility/session fields on operator forms

## 9. Print / labels / preview

- Table Print: `commonPrintActionLabel` → preview-first `printNursingWorkspaceList`
- Detail Print: `commonPrintActionLabel` (`Print`) → `showNursingPrintSummary` / `PrintDocumentTemplates.clinicalSummary` (`nursingReportTitle` / `nursingReportFooter`)

## 10. Loading / empty / error / success

- Loading: `nursingLoadingTitle` / `nursingLoadingBody` (`AsyncStateScaffold`)
- Empty: `nursingNoWorklistTitle` / `nursingNoWorklistBody`
- Success: `nursingSavedMessage` via `nursingShowActionResult`
- After mutations: refresh worklist + sibling `scopeCounts`

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / search / filters / settings / empty / loading / retry / rowSelect / detail | `nursingWorkspaceReadRequirement` |
| Export / Print | ∩ `evidence:export` |
| write / nextAction / vitals / escalate / note / prescribe / lab / radiology / printSummary / checklist / panelDeepLink | `nursingWriteRequirement` |
| nextActionMedication / administerMedication | medication administer ∩ |
| medicationsPanel | ∩ `pharmacy:read` |
| shiftContext | shift context req |
| billingPanel / openBilling | ∩ `billing:read` + `billing-payments` |
| openIcu / navigation | `RouteAccessCatalog.icuEntry` |
| Route entry | catalog ∩ `nursing:read` + module |
