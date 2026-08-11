# Reception tab — Appointments

## 1. Tab strip

- Label: `receptionSectionAppointments`
- Icon: `Icons.event_available_outlined`
- Count source: loaded `state.appointments.items` filtered by `isReceptionPreEncounterAppointment` (client list length; not a separate server total field)
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `appointments` (alias `meetings`)
- Tab gate: `ReceptionAppointmentsAtomPermissions.tab` = ∩ `patient:read` + modules `patient-registry`, `scheduling-queue`
- **Omitted when unauthorized** (not disabled)

## 2. Search / Filters / Settings / Export / Print / context

- Search hint: `receptionSearchHint`
- Clear: `receptionClearFiltersAction`
- Filters: `receptionFiltersLabel` → Advanced filters (`commonAdvancedFiltersTitle`); Apply `opdApplyFiltersAction`; Clear `receptionClearFiltersAction`; Close `commonCloseActionLabel`
- Settings: Table Settings (`commonTableSettings*`, Apply/Reset reception column keys)
- Export: present (default table Export)
- Print (toolbar): **absent**
- Context: Schedule (`receptionScheduleAppointmentAction`), Register (`receptionRegisterPatientAction`) — omitted without ∩ `patient:write`
- Date filter: **enabled** — label `receptionScheduledTimeLabel`; From/To `opdDateFromLabel` / `opdDateToLabel`

## 3. Table

- Row model: `_ReceptionDeskRow.appointment(OpdAppointment)` — pre-encounter appointments only
- Row select: opens Appointment Actions hub (`onRowSelected`)
- Default columns:
  1. Patient (`opdPatientNameLabel`, alwaysVisible) — subtitle identifier; visitor badge `receptionVisitorMeetingBadge`
  2. Scheduled time (`receptionScheduledTimeLabel`)
  3. Current step (`receptionCurrentStepLabel`) — badge via `opdAppointmentCurrentStepLabel`
  4. Next action (`opdNextActionFilterLabel`) — **only if** `receptionAppointmentsShowsNextActionColumn` (front-desk write)
- Column choices (Settings):
  - Patient ID (`opdPatientIdLabel`)
  - Phone (`patientsPhoneIdentifierColumnLabel`)
  - Appointment ID (`receptionAppointmentIdLabel`)
  - Provider (`opdProviderColumnLabel`)
  - Reason (`opdReasonLabel`)
  - Facility (`patientsFacilityLabel`)
- Mobile: `_ReceptionDeskMobileRow`; next-action tap can run Check in / Continue / Reschedule

## 4. Advanced filters / search fields

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
  - Continue → Flow Actions
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

From Flow Actions: Assign/Change doctor, Follow up, Print summary, … (billing/vitals/clinical stripped).

## 8. Forms (summary)

- Cancel appointment: cancellation reason
- Reschedule: appointment schedule fields (shared OPD dialog)
- Encounter check-in: arrival / provider / encounter form (shared)
- Schedule visitor: visitor name, phone, organization, host, date, time, duration, reason
- Schedule / register patient: patient identity + appointment quick fields / registration field groups

## 9. Print / labels / preview

- Table Print: **absent**
- From Flow Actions (Continue path): `opdPrintSummaryAction` → `showPrintOpdSummaryDialog` → `PrintDocumentTemplates.clinicalSummary`
- No Reception-owned label print on this tab

## 10. Loading / empty / error / success

- Loading: workspace `receptionLoadingTitle` / `receptionLoadingBody`
- Empty: `receptionEmptyTitle` / `receptionEmptyBody`
- Error: scaffold retry; snackbars via `showAppFailureSnackBar`
- Success: `opdSavedMessage` after mutations; `patientsSavedMessage` after register create

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list chrome / search / filters / settings / empty / loading / retry | ∩ `patient:read` (+ modules) |
| Register / Schedule | ∩ `patient:write` |
| Next-action Check in / Continue / Reschedule; hub front-desk writes | `receptionFrontDeskWriteRequirement` (source front-desk) |
| Cancel in hub | same front-desk (not ∩ `patient:delete` — packs omit delete) |
| Nested billing/clinical in hub | stripped (n/a) |
| Deep-link workspace entry | ∪ `patient:read` \| `last_office:read` |
