# Nursing tab — All

## 1. Tab strip

- Label: `nursingScopeAllLabel`
- Icon: `Icons.inventory_2_outlined`
- Count source: `nursingPageTotal(worklist)` (null when 0)
- Count tone: default (unset)
- Deep-link `scope`: `all` (default `/nursing`)
- Tab gate: `NursingAllAtomPermissions.tab` = `nursingWorkspaceReadRequirement`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Shift context**

- Search: `nursingSearchHint`
- Filters / Settings / Export: shared; Print toolbar **absent**
- Shift context: when `nursingShiftContextRequirement`
- Date filter: **enabled**

## 3. Table

- Row model: `NursingWorkItem` via `NursingWorklistPanel`
- Row select → `NursingPatientDetailDialog` (`omitNextActionKind` = stage next)
- Default columns: patient, location, task_type, status + next_action (when write)
- Column pool: patient, location, task_type, priority, status, admission, due_time, responsible_nurse, observations, medication_due_count (pharmacy:read), transfer_status, discharge_status, next_action
- Storage: `nursing_all` / `nursing_cw_all`

## 4. Advanced filters / search fields

- Text: patient, admission, encounter, ward, room, bed, observation, task_type, assigned_nurse, shift
- Groups: scope, status, priority, transfer_status, handover_status, discharge_status
- Date range enabled

## 5. Primary / secondary / row actions

- Next-action cascade by `taskTypeCode` → med / handover / transfer / discharge / else vitals
- Detail Quick Actions: handover, vitals, note, lab, radiology, med, prescribe, escalate, transfer, discharge, open ICU, print, accept handover, open billing (when gated)

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Patient detail | Nursing-owned |
| Vitals / medication / handover / escalation / transfer / discharge / note / shift / print | Nursing-owned (vitals wraps **reused**) |
| Free-text / prescribe / lab / radiology | **reused** clinical |

## 7. Nested / follow-on

- Billing clearance panel + Open billing
- Open ICU when ACTIVE
- Clinical order nested billing when mounted
- Checklist free-text steps

## 8. Forms (summary)

- Vitals set; med admin; handover (+ attachments); escalation; transfer APPROVE/START/COMPLETE/CANCEL; discharge clearance checkboxes; note + optional charge; free-text checklist

## 9. Print / labels / preview

- Worklist Print: **absent**
- Detail: `nursingActionPrintSummary` → `showNursingPrintSummary` / `PrintDocumentTemplates.clinicalSummary` (`nursingReportTitle` / `nursingReportFooter`)

## 10. Loading / empty / error / success

- Loading: `nursingLoadingTitle` / `nursingLoadingBody`
- Empty: `nursingNoWorklistTitle` / `nursingNoWorklistBody`
- Success: `nursingSavedMessage`
- After mutations: refresh worklist + visible tab counts

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / search / filters / settings / empty / loading / retry / rowSelect / detail | `nursingWorkspaceReadRequirement` |
| write / nextAction / vitals / escalate / note / prescribe / lab / radiology / printSummary / checklist / panelDeepLink | `nursingWriteRequirement` |
| nextActionMedication / administerMedication | medication administer ∩ |
| medicationsPanel | pharmacy:read |
| shiftContext | shift context req |
| billingPanel / openBilling | billing read |
| openIcu / navigation | empty `AccessRequirement()` |
| routeEntry | catalog `nursing:read` |
