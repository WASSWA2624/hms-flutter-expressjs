# Schedule Appointments for Existing or New Patients

Replace Reception’s patient-picker-first flow with one reusable **Schedule appointment** dialog. Follow `prompts/.cursor/prompt.mdc`.

## Context

Scheduling currently requires a separate picker and cannot register a patient within the same task.

## Requirements

1. Open a calendar-icon **Schedule appointment** dialog with design-system tabs **Existing patient** and **New patient**; default to Existing patient.
2. Existing patient must reuse patient search/selection, then show the existing appointment form in the same flow.
3. New patient must reuse registration scope, duplicate detection, form, and validation. After registration, retain the dialog, auto-select the created patient, and show the appointment form.
4. Reuse appointment contracts and validation. Prevent duplicate submission and unsafe dismissal; show loading, no-results, field-error, failure, and success states.
5. After success, synchronize the Reception appointment table, search, filters, and counts immediately.
6. Make `AppTimeField` reject incomplete input and enforce hours `1–12` in 12H, hours `0–23` in 24H, and minutes/seconds `0–59`. Format switching must preserve the time.

## Constraints

- Keep authorization authoritative; omit unauthorized UI.
- Reuse shared components, localization, theme tokens, and responsive behavior; preserve backend contracts.

## Acceptance Criteria

- R1–R3: Both patient paths complete in one dialog with correct defaulting and handoff.
- R4–R5: States are visible, one appointment is created, and Reception updates.
- R6: Boundary and format-toggle tests pass in both formats.
- Add authorization, widget, synchronization, responsive/theme, and time-field tests; run Flutter analysis.

## Relevant Files

- `frontend/lib/features/reception/presentation/widgets/reception_patient_actions.dart`
- `frontend/lib/shared/patient_actions/register_new_patient_dialog.dart`
- `frontend/lib/shared/opd_actions/patient_appointment_quick_dialog.dart`
- `frontend/lib/shared/components/app_time_field.dart`
