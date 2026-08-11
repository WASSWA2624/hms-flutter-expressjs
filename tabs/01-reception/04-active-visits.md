# Reception tab — Active visits

## 1. Tab strip

- Label: `receptionSectionActiveVisits`
- Icon: `Icons.pending_actions_outlined`
- Count source: `state.flows.items` where `isReceptionActiveVisit`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `active` (aliases `active-visits`, `active_visits`, `visits`, `in-progress`, `turnaround_pressure`)
- Also: `flowId=` opens Flow Actions when row-select allowed
- Tab gate: `ReceptionActiveVisitsAtomPermissions.tab` = ∪ patient/clinical/billing/operations/emergency **read** + module `scheduling-queue`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Search hint: `receptionSearchHint`
- Filters / Settings / Export: present
- Print (toolbar): **absent**
- Schedule / Register: ∩ `patient:write` (`scheduleAppointment` / `register`)
- Date filter: **enabled** — `receptionStartedAtLabel`

## 3. Table

- Row model: `_ReceptionDeskRow.flow(OpdFlowSummary)` — active visits only
- Row select → **reused** Flow Actions (`allowBilling/Vitals/Clinical: false`)
- Default columns:
  1. Patient
  2. Started at (`receptionStartedAtLabel`)
  3. Current step (`receptionCurrentStepLabel`)
  4. Next action label — if `receptionActiveVisitsShowsNextActionColumn` (read-only)
- Column choices:
  - Patient ID, Phone, Provider, Assigned doctor (`receptionAssignedDoctorLabel`), Chief complaint (`opdChiefComplaintLabel`), Payment status, Consultation fee (`receptionConsultationFeeLabel`)

## 4. Advanced filters / search fields

- Groups: Current step / stage (`receptionCurrentStepLabel` via `_stageFilterKey`), Next action, Provider, Payment status
- Search fields: patient, record, staff, reason, status
- Date range on started-at

## 5. Primary / secondary / row actions

- Strip: Schedule, Register
- Row: Flow Actions only (no separate mutation buttons on next-action column)

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Flow Actions | **reused** `showFlowActionsDialog` |
| Schedule / Register | shared |

## 7. Nested / follow-on (Flow Actions from Reception)

Included when stage/permission allow and flags permit:

- Assign / Change doctor → `showAssignDoctorDialog`
- Follow up → `showFollowUpDialog`
- Print summary → `showPrintOpdSummaryDialog` / `PrintDocumentTemplates.clinicalSummary`
- Correct stage / other front-desk stage actions per hub

**Stripped / not mounted from Reception:** billing (Pay/Manage consultation), vitals, route decision, doctor review, diagnosis, lab/radiology/prescription/procedure/referral, clinical disposition, department handoff, admission handoff paths that require clinical flag.

Optional care handoff dialogs exist in shared hub but clinical-gated paths stay off.

## 8. Forms (summary)

- Assign doctor: provider select
- Follow up: schedule + notes (shared clinical follow-up dialog)
- Print summary: section picker in preview
- Schedule / Register: shared

## 9. Print / labels / preview

- Table Print: **absent**
- Nested: OPD print summary preview (`showPrintOpdSummaryDialog`) — template `PrintDocumentTemplates.clinicalSummary`
- Label: hub uses `opdPrintSummaryAction` (not bare table `Print`)

## 10. Loading / empty / error / success

- Empty: `receptionEmptyTitle` / `receptionEmptyBody`
- Success: `opdSavedMessage` when Flow Actions reports change
- Loading / retry: workspace scaffold

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome / next-action label / row select | ∪ `receptionActiveVisitsRequirement` |
| Register / Schedule | ∩ `patient:write` |
| Nested matrix write ∪ clinical\|patient write | `receptionActiveVisitsNestedWriteRequirement` (documented; hub still uses source stage gates) |
| Nested billing write | `opdBillingActionRequirement` but **off** via flag |
| Delete | not mounted |
| Deep link `flowId` | requires Active visits row-select |
