# Improve Reception Appointment Reschedule

Upgrade `OpdRescheduleAppointmentDialog` so Reception can change date, time, duration, and doctor with availability checks and durable persistence. Follow `prompts/.cursor/prompt.mdc`.

## Context

From `/reception` Appointments, Reschedule edits only date and start/end. Patient context is a triage summary; doctor reassignment and duration linkage are missing though schedule-appointment already supports providers and duration.

## Requirements

1. Replace the reschedule triage summary with `AppPatientDetails` for patient identity and status.
2. Allow optional doctor reassignment; reuse provider options and schedule data so availability is visible before save.
3. Keep start time editable; add duration that auto-derives end time, and end time that auto-derives duration; validate end after start.
4. Persist changed `scheduled_start`, `scheduled_end`, and `provider_user_id` via existing update contracts; leave unchanged fields untouched.
5. After success, close and synchronize Appointments, search, filters, and counts.
6. Improve form layout with design-system fields; preserve loading, validation, error, success, and permission states; omit unauthorized UI.

## Constraints

- Reuse provider-select, schedule helpers, localization, theme tokens, and responsive patterns from schedule-appointment.
- Do not invent clinical transitions or alter cancel/start-encounter flows.
- Backend authorization remains authoritative.

## Acceptance Criteria

- R1: Reschedule shows `AppPatientDetails`, not the triage tile row.
- R2–R3: Doctor and duration/end-time stay linked and availability-aware.
- R4–R5: Saved changes persist and Reception lists refresh.
- R6: States remain clear; unauthorized UI is absent.
- Extend reschedule dialog tests; run Flutter analysis.

## Relevant Files

- `frontend/lib/shared/opd_actions/opd_reschedule_appointment_dialog.dart`
- `frontend/lib/shared/opd_actions/opd_provider_options.dart`
- `frontend/lib/shared/opd_actions/patient_appointment_quick_dialog.dart`
- `frontend/lib/shared/components/app_patient_details.dart`
- `frontend/lib/features/opd/presentation/controllers/opd_workspace_controller.dart`
- `frontend/test/shared/opd_actions/opd_reschedule_appointment_dialog_test.dart`
