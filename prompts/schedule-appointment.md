# Schedule appointment dialog polish

## Context

Refine the Reception **Schedule appointment** dialog (`openReceptionScheduleAppointment` → `_ReceptionScheduleAppointmentDialog`) so the post-patient schedule step and the **Visitor / staff meeting** tab match shared dialog/form conventions.

Surfaces in scope:

- Patient schedule step after **Existing patient** or **New patient** selection (`PatientAppointmentQuickDialog` embedded in the parent dialog).
- **Visitor / staff meeting** tab (`ReceptionVisitorAppointmentDialog` embedded in the parent dialog).

Cross-cutting rules: [`.cursor/prompt.mdc`](.cursor/prompt.mdc), [`.cursor/dialogs.mdc`](.cursor/dialogs.mdc), [`.cursor/forms.mdc`](.cursor/forms.mdc), [`.cursor/tabs.mdc`](.cursor/tabs.mdc). Do not restate localization, theming, or responsiveness rules—follow [`.cursor/localization.mdc`](.cursor/localization.mdc), [`.cursor/theming.mdc`](.cursor/theming.mdc), [`.cursor/responsiveness.mdc`](.cursor/responsiveness.mdc).

## Requirements

1. **Pinned dialog footer for patient schedule step.** When a patient is selected (existing or newly registered), move **Schedule appointment** and **Close** out of the embedded form body (`Wrap` under the form) into the parent `AppDialog` `actions`. Keep `pinActionsToBottom: true` for that step. Author footer actions as `[Close, Schedule appointment]` so shared `AppDialog` two-action reverse places **Close** extreme-right (same convention as `showAppWorkspaceMutationDialog` / `clinicalActionDialogActions`). Do not leave commit/cancel controls only inside the scrollable body.

2. **Same footer ownership for visitor submit.** Keep visitor **Schedule appointment** / **Close** on the parent dialog footer (already true for the visitor tab). Do not reintroduce in-body action rows for embedded visitor or patient schedule forms.

3. **Mode tab strip stays fixed.** On the patient-selection step, keep the `AppTabStrip` (**Existing patient** / **New patient** / **Visitor / staff meeting**) outside the dialog’s scrollable body so it does not scroll away with the tab content. Only the active tab’s body (picker, registration form, or visitor form) scrolls. Reuse `AppTabStrip`; do not invent a parallel tab bar.

4. **Scheduling triad on one responsive row.** On both patient and visitor schedule forms, place **Appointment date**, **Start time**, and **Duration minutes** in a single `AppResponsiveFieldRow` so they sit on one row on large screens and stack on small screens. Reuse `AppDateField`, `AppTimeField`, and the existing duration field; keep required validation.

5. **Patient provider = searchable doctors.** On the patient schedule form, **Provider** must be an `AppSelectField.searchable` whose options are all doctors available in the current tenant/facility scope (existing `listProviders` / `ensureAppointmentFormOptionsLoaded` path). Operators must be able to search the full doctor list; do not present a non-searchable or silently truncated queue-only subset when a full doctor list is already available via that API.

6. **Remove visitor meeting info banner.** On the visitor / staff meeting form, remove the `AppFormInformationBanner` that shows **Non-patient meeting** / “Book a visitor or guest…”. Do not replace it with another badge or callout.

7. **Visitor phone uses shared phone field.** Replace the visitor phone `AppTextField` with the shared `AppPhoneField`. Keep the field optional.

8. **Hosting staff searchable within scope.** Keep **Hosting staff** as a required `AppSelectField.searchable` backed by `listMeetingHosts` (facility staff / meeting hosts in scope). Loading, empty, and error states for the host list must remain visible; search must filter the loaded host options.

9. **Reuse and sync.** Reuse existing create-appointment contracts, validators, busy/loading wiring (`onBusyChanged`), and post-save pops. After a successful schedule, synchronize affected Reception / OPD appointment lists via existing controller refresh paths. Omit unauthorized schedule entry points and actions per RBAC/ABAC.

10. **UI states.** Cover loading (providers/hosts, submit), empty option lists, validation errors, API failure banners, success (dialog closes / parent notified), and busy-disabled close/submit. Do not leave silent no-ops on failed load or submit.

## Constraints

- Prefer extending `PatientAppointmentQuickDialog`, `ReceptionVisitorAppointmentDialog`, and `_ReceptionScheduleAppointmentDialog` over new shells or parallel dialogs.
- Do not invent one-off field widgets, footers, or banners when shared `AppDialog` / `AppFormShell` / field components already cover the need.
- Do not change appointment create payloads or backend contracts except as required to bind `AppPhoneField` output correctly.
- Do not expand scope to unrelated Reception tabs, OPD board chrome, or print/export work.

## Acceptance Criteria

| ID | Criterion | Traces to |
| --- | --- | --- |
| A1 | After selecting an existing or new patient, **Schedule appointment** and **Close** appear only in the parent dialog footer (pinned), not as an in-body `Wrap` under the form. | R1, R2 |
| A2 | On the patient schedule step footer, visual order is **Schedule appointment** then **Close** (Close extreme-right), matching shared two-action `AppDialog` behavior. | R1 |
| A3 | On the patient-selection step, the mode `AppTabStrip` remains visible/fixed while the active tab body scrolls; the strip itself is not inside the scrolling region. | R3 |
| A4 | On patient and visitor forms, date / start time / duration share one `AppResponsiveFieldRow` and stack on narrow viewports. | R4 |
| A5 | Patient **Provider** is searchable and lists doctors from the existing providers API for the current scope. | R5 |
| A6 | Visitor form no longer shows the Non-patient meeting information banner. | R6 |
| A7 | Visitor phone uses `AppPhoneField` (optional). | R7 |
| A8 | Hosting staff remains required, searchable, and populated from meeting-host options with loading/empty/error feedback. | R8 |
| A9 | Successful schedule closes the dialog and refreshes dependent workspace data; failed validation/API shows field or form-level feedback; unauthorized schedule actions stay omitted. | R9, R10 |

## Verification

- Update / extend widget tests for:
  - `frontend/test/shared/opd_actions/patient_appointment_quick_dialog_test.dart` (footer chrome, date/time/duration row, provider select).
  - Reception schedule dialog / visitor embedding tests under `frontend/test/features/reception/` (add or extend coverage for banner removal, `AppPhoneField`, host searchable select, footer ownership when embedded).
- Manual checks on mobile, tablet, and desktop widths: triad stacks vs single row; footer stays reachable while the body scrolls; mode tabs stay fixed while long tab content scrolls.
- Confirm light/dark themes still render shared field and footer chrome correctly.
- Confirm unauthorized users never see Schedule appointment entry points already gated by reception/patient registry permissions.

## Relevant Files

- `frontend/lib/features/reception/presentation/widgets/reception_patient_actions.dart` (`openReceptionScheduleAppointment`, `_ReceptionScheduleAppointmentDialog`)
- `frontend/lib/features/reception/presentation/widgets/reception_visitor_appointment_dialog.dart`
- `frontend/lib/shared/opd_actions/patient_appointment_quick_dialog.dart`
- `frontend/lib/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart`
- `frontend/lib/shared/components/app_dialog.dart`
- `frontend/lib/shared/components/app_tab_strip.dart`
- `frontend/lib/shared/components/app_phone_field.dart`
- `frontend/lib/shared/forms/app_responsive_field_row.dart`
- `frontend/lib/features/opd/presentation/controllers/opd_workspace_controller.dart` (`ensureAppointmentFormOptionsLoaded`, `listProviders`)
- `frontend/lib/features/opd/data/repositories/opd_repository_impl.dart` (`listProviders`, `listMeetingHosts`)
- `frontend/test/shared/opd_actions/patient_appointment_quick_dialog_test.dart`
- `frontend/test/features/reception/presentation/` (schedule / visitor coverage)
- `frontend/lib/l10n/app_en.arb` (only if labels/helpers change)
