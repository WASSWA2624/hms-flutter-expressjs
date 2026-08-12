# Reception tab — Appointments

## 1. Tab strip

- Label: `receptionSectionAppointments`
- Icon: `Icons.event_available_outlined`
- Count source: authoritative pre-encounter scope total from workspace appointments (`isReceptionPreEncounterAppointment`); when this tab is active and search/advanced filters/date narrow the list, badge uses the filtered membership total
- Sibling tabs: dedicated unfiltered scope totals (shared chrome sibling model)
- Count tone: `AppTabCountTone.info` (non-urgent schedule scope)
- Deep-link `section`: `appointments` (alias `meetings`)
- Tab gate: `ReceptionAppointmentsAtomPermissions.tab` = ∩ `patient:read` + modules `patient-registry`, `scheduling-queue`
- **Omitted when unauthorized** (not disabled)

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Schedule → Register**

- Search hint: `receptionSearchHint`
- Clear: `receptionClearFiltersAction`
- Filters: `commonFiltersActionLabel` → Advanced filters (`commonAdvancedFiltersTitle`); Apply `opdApplyFiltersAction`; Clear `receptionClearFiltersAction`; Close `commonCloseActionLabel`
- Settings: Table Settings (`commonTableSettings*`, Apply/Reset reception column keys)
- Export: gated by `ReceptionAppointmentsAtomPermissions.export` / `receptionDeskExportRequirement` (∩ `evidence:export`); omitted when denied
- Print (toolbar): `commonPrintActionLabel` → preview-first `printReceptionDeskList` / `PrintDocumentTemplates.registry`; omitted without export/print gate
- Context: Schedule (`receptionScheduleAppointmentAction`), Register (`receptionRegisterPatientAction`) — omitted without ∩ `patient:write`
- Date filter: **enabled** — label `receptionScheduledTimeLabel`; From/To `opdDateFromLabel` / `opdDateToLabel`

## 3. Table

- Row model: `_ReceptionDeskRow.appointment(OpdAppointment)` — pre-encounter appointments only
- Row select: opens Appointment Actions hub (`onRowSelected`)
- Default columns (prefer **5** data columns; next-action optional chrome):
  1. Patient (`opdPatientNameLabel`, alwaysVisible) — name + identifier subtitle only (atomic)
  2. Phone (`patientsPhoneIdentifierColumnLabel`)
  3. Scheduled time (`receptionScheduledTimeLabel`)
  4. Current step (`receptionCurrentStepLabel`) — badge via `opdAppointmentCurrentStepLabel`
  5. Provider / Doctor (`opdProviderColumnLabel`)
  6. Next action (`opdNextActionFilterLabel`) — **only if** `receptionAppointmentsShowsNextActionColumn` (front-desk write)
- Column choices (Settings; every available column):
  - Patient ID (`opdPatientIdLabel`)
  - Appointment ID (`receptionAppointmentIdLabel`)
  - Reason (`opdReasonLabel`)
  - Facility (`patientsFacilityLabel`)
- Reset columns restores the five defaults (+ next-action when authorized)
- Mobile: `_ReceptionDeskMobileRow`; next-action tap can run Check in / Continue / Reschedule

## 4. Advanced filters / search fields

Same filter model as the table and active tab count:

- Filter groups (multi-select):
  - Status (`receptionStatusLabel`) — appointment status codes
  - Next action (`opdNextActionFilterLabel`)
  - Provider (`opdProviderFilterLabel`)
- Search fields: patient, record (`receptionRecordIdSearchLabel`), staff, reason, status
- Date range on scheduled start

## 5. Primary / secondary / row actions

- Strip: Schedule, Register (see shared)
- Next-action column / mobile: Check in / Continue / Reschedule via `resolveOpdAppointmentPrimaryAction` (labels from OPD helpers)
  - Visitor meeting Check in → snackbar `receptionVisitorMeetingBannerBody` (no encounter)
  - Check in → encounter dialog
  - Reschedule → reschedule dialog
  - Continue → Flow Actions (`printActionLabel: Print`)
- Row select → Appointment Actions (primary Check in/Continue **omitted** in hub; `omitPrimaryAction: true`)

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Appointment Actions (`opdAppointmentActionsTitle`) | Reception wrapper → **reused** `OpdAppointmentActionsDialog` |
| Schedule appointment shell | Reception-owned |
| Register patient | **reused** |
| Encounter (check-in / walk-in deep link) | **reused** `showOpdEncounterDialog` |
| Flow Actions (Continue) | **reused** |

## 7. Nested / follow-on

From Appointment Actions (`allowClinicalActions: false`, `allowVitalsActions: false`):

1. Reschedule → **reused** `showOpdRescheduleAppointmentDialog`
2. Cancel → **reused** `showOpdCancelAppointmentDialog` (confirm + cancellation reason)
3. Check in / Continue (only if hub not omitting primary) → encounter / Flow Actions

From Schedule shell: Existing / New / Visitor nested forms (see shared chrome).

From Register: patient detail editor (`showPatientDetailDialog`).

From Flow Actions: Assign/Change doctor, Follow up, Print (`Print`), … (billing/vitals/clinical stripped).

## 8. Forms (summary)

- Cancel appointment: cancellation reason
- Reschedule: appointment schedule fields (shared OPD dialog)
- Encounter check-in: arrival / provider / encounter form (shared)
- Schedule visitor: visitor name, phone, organization, host, date, time, duration, reason
- Schedule / register patient: patient identity + appointment quick fields / registration field groups

## 9. Print / labels / preview

- Table Print: present when authorized; preview before device print; section/column options aligned to exportable fields
- From Flow Actions (Continue path): trigger `Print` (`commonPrintActionLabel`) → `showPrintOpdSummaryDialog` → `PrintDocumentTemplates.clinicalSummary`
- No Reception-owned label print on this tab

## 10. Loading / empty / error / success

- Loading: workspace `receptionLoadingTitle` / `receptionLoadingBody`
- Empty: `receptionEmptyTitle` / `receptionEmptyBody`
- Error: scaffold retry; snackbars via `showAppFailureSnackBar`
- Success: `opdSavedMessage` after mutations; `patientsSavedMessage` after register create
- After mutations: refresh table rows and all visible tab counts

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list chrome / search / filters / settings / empty / loading / retry | ∩ `patient:read` (+ modules) |
| Export / Print | ∩ `evidence:export` (`receptionDeskExportRequirement`) |
| Register / Schedule | ∩ `patient:write` |
| Next-action Check in / Continue / Reschedule; hub front-desk writes | `receptionFrontDeskWriteRequirement` (source front-desk) |
| Cancel in hub | same front-desk (not ∩ `patient:delete` — packs omit delete) |
| Nested billing/clinical in hub | stripped (n/a) |
| Deep-link workspace entry | ∪ `patient:read` \| `last_office:read` |
