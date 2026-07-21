# Improve Reschedule Dialog Layout and Patient Context

Refine `OpdRescheduleAppointmentDialog` and `AppTimeField` for clearer rescheduling. Follow `prompts/.cursor/prompt.mdc`.

## Context

Reschedule on `/reception` has loose form alignment, thin patient context, missing default provider selection, and crowded 12H/24H controls.

## Requirements

1. Reorganize the form: patient context, then date/time/duration, then optional provider. Align fields across viewports without clipping or overflow.
2. When an assigned provider exists, preselect and display it after options load; keep the field optional and clearable.
3. Enrich `AppPatientDetails` with age, gender, and phone when known; keep status, schedule, and provider via progressive disclosure. Unknown only when missing.
4. Replace dual 12H/24H chips with one in-field toggle left of the clock picker. Show active mode; preserve time on switch.
5. Guard typed times: hours `1–12` in 12H, `0–23` in 24H, minutes/seconds `0–59`.
6. Preserve loading, validation, error, success, busy, and permission states; synchronize after save.

## Constraints

- Reuse reschedule contracts, authorization, localization, theme tokens, and design-system components.
- Map demographics only when the API returns them.
- Do not change eligibility or invent scheduling rules.

## Acceptance Criteria

- R1: Layout aligned at representative viewports and themes.
- R2: Assigned providers appear selected when in options.
- R3: Known age, gender, and phone show; missing stay unknown.
- R4–R5: Format toggle and range guards work; time tests pass.
- R6: Unauthorized UI hidden; success refreshes Reception.
- Update dialog and time-field tests; run Flutter analysis.

## Relevant Files

- `frontend/lib/shared/opd_actions/opd_reschedule_appointment_dialog.dart`
- `frontend/lib/shared/components/app_time_field.dart`
- `frontend/lib/features/opd/data/dtos/opd_dtos.dart`
- `frontend/test/shared/opd_actions/`
- `frontend/test/shared/components/app_time_field_test.dart`
