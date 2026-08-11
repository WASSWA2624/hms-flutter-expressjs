# Reception tab — Active visits

## 1. Tab strip

- Label: `receptionSectionActiveVisits`
- Icon: `Icons.pending_actions_outlined`
- Count source: authoritative active-visit scope total (`isReceptionActiveVisit`); when this tab is active and stage/next-action/provider/payment/date/search narrow the list, badge uses the filtered membership total
- Sibling tabs: dedicated unfiltered scope totals (shared chrome sibling model)
- Count tone: `AppTabCountTone.warning` — product-justified in-facility turnaround pressure (documented in Active visits permission tests)
- Deep-link `section`: `active` (aliases `active-visits`, `active_visits`, `visits`, `in-progress`, `turnaround_pressure`)
- Also: `flowId=` opens Flow Actions when row-select allowed
- Tab gate: `ReceptionActiveVisitsAtomPermissions.tab` = ∪ patient/clinical/billing/operations/emergency **read** + module `scheduling-queue`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Schedule → Register**

- Search hint: `receptionSearchHint`
- Filters / Settings: shared labels
- Export: gated by `ReceptionActiveVisitsAtomPermissions.export` / `receptionDeskExportRequirement` (∩ `evidence:export`); omitted when denied
- Print (toolbar): `commonPrintActionLabel` → preview-first `printReceptionDeskList` / `PrintDocumentTemplates.registry`; omitted without export/print gate
- Schedule / Register: ∩ `patient:write` (`scheduleAppointment` / `register`)
- Date filter: **enabled** — `receptionStartedAtLabel`

## 3. Table

- Row model: `_ReceptionDeskRow.flow(OpdFlowSummary)` — active visits only
- Row select → **reused** Flow Actions (`allowBilling/Vitals/Clinical: false`, `printActionLabel: Print`)
- Default columns (prefer **5** data columns; next-action is read-only guidance):
  1. Patient
  2. Phone
  3. Started at (`receptionStartedAtLabel`)
  4. Current step (`receptionCurrentStepLabel`)
  5. Provider / Doctor
  6. Next action label — if `receptionActiveVisitsShowsNextActionColumn` (read-only text, not a mutation button)
- Column choices (Settings):
  - Patient ID, Assigned doctor (`receptionAssignedDoctorLabel`), Chief complaint (`opdChiefComplaintLabel`), Payment status, Consultation fee (`receptionConsultationFeeLabel`)
- Reset restores the five defaults (+ next-action when readable)

## 4. Advanced filters / search fields

Same filter model as the table and active tab count:

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
- Print → `showPrintOpdSummaryDialog` / `PrintDocumentTemplates.clinicalSummary` (trigger label **`Print`**)
- Correct stage / other front-desk stage actions per hub

**Stripped / not mounted from Reception:** billing (Pay/Manage consultation), vitals, route decision, doctor review, diagnosis, lab/radiology/prescription/procedure/referral, clinical disposition, department handoff, admission handoff paths that require clinical flag.

## 8. Forms (summary)

- Assign doctor: provider select
- Follow up: schedule + notes (shared clinical follow-up dialog)
- Print summary: section picker in preview
- Schedule / Register: shared
- No tenant/facility/session context prompts on desk hubs

## 9. Print / labels / preview

- Table Print: present when authorized; preview before device print; options aligned to exportable fields
- Nested: OPD print summary preview — trigger label `Print` (`commonPrintActionLabel`); template `PrintDocumentTemplates.clinicalSummary`

## 10. Loading / empty / error / success

- Empty: `receptionEmptyTitle` / `receptionEmptyBody`
- Success: `opdSavedMessage` when Flow Actions reports change
- Loading / retry: workspace scaffold
- After mutations: refresh table + all visible tab counts

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome / next-action label / row select | ∪ `receptionActiveVisitsRequirement` |
| Export / Print | ∩ `evidence:export` |
| Register / Schedule | ∩ `patient:write` |
| Nested matrix write ∪ clinical\|patient write | `receptionActiveVisitsNestedWriteRequirement` (documented; hub still uses source stage gates) |
| Nested billing write | `opdBillingActionRequirement` but **off** via flag |
| Delete | not mounted |
| Deep link `flowId` | requires Active visits row-select |
| Deep-link workspace entry | ∪ `patient:read` \| `last_office:read` |
