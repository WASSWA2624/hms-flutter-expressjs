# Schedule Appointment dialog — Visitor tab shell parity

## Context

Reception opens **Schedule appointment** via `openReceptionScheduleAppointment` → `_ReceptionScheduleAppointmentDialog` (`frontend/lib/features/reception/presentation/widgets/reception_patient_actions.dart`).

**Current behavior (as shipped / screenshots):**

1. **Existing patient** — `AppTabStrip` stays visible; body is the embedded patient picker table; dialog footer shows **Close** (pinned). Behavior is acceptable; do not regress.
2. **New patient** — Same tab strip; body is `RegisterNewPatientForm` in `AppFormShell`; dialog footer shows **Register patient** + **Close** (pinned). Behavior is acceptable; do not regress.
3. **Visitor / staff meeting** — Selecting the tab sets `_mode == visitor` and replaces **entire** `AppDialog.content` with `ReceptionVisitorAppointmentDialog(embedded: true)`, which:
   - Omits the shared `AppTabStrip` (tabs appear to vanish / be “shadowed”).
   - Renders its own in-body **Cancel** + **Schedule appointment** `Wrap` instead of the parent dialog footer (`actions: const <Widget>[]`, `pinActionsToBottom: false` while visitor is shown).

**Intended behavior:** Visitor / staff meeting must use the **same tabbed shell** as Existing / New patient: tabs always visible above the body; visitor form is the tab body (like the picker table / registration form); primary actions live in the **dialog footer**, pinned while the body scrolls.

Cross-cutting: [prompt.mdc](.cursor/prompt.mdc), [dialogs.mdc](.cursor/dialogs.mdc), [forms.mdc](.cursor/forms.mdc), [tabs.mdc](.cursor/tabs.mdc), [localization.mdc](.cursor/localization.mdc), [responsiveness.mdc](.cursor/responsiveness.mdc).

## Requirements

1. Keep the three modes in one dialog under a single shared `AppTabStrip`: **Existing patient**, **New patient**, **Visitor / staff meeting** (`receptionScheduleExistingPatientTab` / `receptionScheduleNewPatientTab` / `receptionScheduleVisitorTab`). Do not open a nested dialog or replace the shell when switching to visitor.
2. When **Visitor / staff meeting** is selected and no patient is mid-flow (`_patient == null`), keep the tab strip mounted and render the visitor meeting form as the tab body only (banner + fields). Do not swap `AppDialog.content` to a standalone embedded visitor tree that drops the tabs.
3. Move visitor primary outcomes into the parent `AppDialog.actions` footer (same pattern as New patient):
   - **Close** / cancel — dismisses the schedule dialog without saving (same as Existing / New patient Close).
   - **Schedule appointment** — submits the visitor form (`receptionScheduleAppointmentAction`).
   - Pin footer actions while the body scrolls (`pinActionsToBottom: true` whenever the patient-step / visitor-step shell is showing).
4. Stop rendering the embedded visitor form’s in-body action `Wrap` when it is hosted inside `_ReceptionScheduleAppointmentDialog`. Prefer a body-only embedded API (callback / `GlobalKey` / controller) so the parent owns submit and busy state—mirror how `RegisterNewPatientForm` + `_registerPatient` work for New patient.
5. Preserve visitor domain behavior already implemented in `ReceptionVisitorAppointmentDialog`: fields, validation, host loading, schedule conflict / failure banners, `createAppointment` payload (`subject_type: VISITOR`, host, times, reason), busy disablement, and success → `Navigator.pop(true)` after a successful save.
6. Preserve Existing patient and New patient flows unchanged except for shared shell fixes required by requirements 1–4 (tab visibility, footer ownership, pin). Do not change picker columns, registration fields, or post-select `PatientAppointmentQuickDialog` continue flow unless needed for the shell.
7. Tab switching: while not busy, operators can move among Existing / New / Visitor without losing the shared chrome; block tab changes while register/save is in flight (keep existing `_isBusy` guard).
8. Cover UI states for the visitor-in-shell path: hosts loading, validation errors, submit loading on the footer primary, failure banner in the form body, success close; omit unauthorized schedule entry points per existing reception RBAC (do not invent new permission gates in this prompt).

## Constraints

- Reuse `AppDialog`, `AppTabStrip`, `AppFormShell` / shared fields, `buildAppDialogFormActions` (or the same footer button primitives already used for New patient), and existing `ReceptionVisitorAppointmentDialog` / OPD `createAppointment` logic—extend rather than fork a second visitor form.
- Do not nest another `AppDialog` for visitor inside Schedule appointment.
- Do not expand scope to redesign Existing/New patient UX, remove Tenant/Facility from registration, or change search-bar separators / list-table chrome unless required to keep the shared shell consistent.
- Follow [dialogs.mdc](.cursor/dialogs.mdc) (flat body, pinned footer, generic title already `patientsAppointmentDialogTitle`) and [forms.mdc](.cursor/forms.mdc) for the visitor body.

## Acceptance Criteria

1. With Schedule appointment open, selecting **Visitor / staff meeting** keeps **Existing patient**, **New patient**, and **Visitor / staff meeting** visible and selectable in the tab strip (requirement 1–2).
2. Visitor fields (banner, visitor name, phone, organization, hosting staff, date, time, duration, reason) appear in the dialog body under the tabs—not in a chrome that replaces the tabs (requirement 2, 5).
3. **Schedule appointment** and **Close** appear in the dialog footer (not as an in-body action row) while the visitor tab is active; footer stays pinned when the body scrolls (requirement 3–4).
4. Successful visitor submit still creates the visitor appointment and closes the dialog with success; validation / load / failure states remain visible without silent failure (requirement 5, 8).
5. Existing patient picker + Close footer and New patient register + Close footer still behave as before (requirement 6).
6. Widget/integration tests (or an extended reception schedule dialog test) prove visitor tab keeps the strip mounted and footer actions; unauthorized schedule entry remains omitted where existing reception tests already require it (requirement 7–8).

## Relevant Files

- `frontend/lib/features/reception/presentation/widgets/reception_patient_actions.dart` — `_ReceptionScheduleAppointmentDialog` shell, tabs, footer ownership
- `frontend/lib/features/reception/presentation/widgets/reception_visitor_appointment_dialog.dart` — visitor form body / embedded actions
- `frontend/lib/shared/opd_actions/patient_appointment_quick_dialog.dart` — post-patient continue flow (do not regress)
- `frontend/lib/shared/forms/app_form_shell.dart` — `buildAppDialogFormActions`
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` — entry (`_scheduleAppointment`)
- Tests: extend or add under `frontend/test/features/reception/presentation/` (e.g. schedule dialog / visitor tab shell); keep existing reception schedule permission coverage green

## Verification

- Manual: open Schedule appointment from Reception → cycle Existing / New / Visitor; confirm tabs never disappear on Visitor; footer shows correct actions per tab; visitor submit succeeds and refreshes desk data as today.
- Automated: tab strip findable on visitor mode; footer **Schedule appointment** / **Close**; no in-body duplicate primary row when embedded in the schedule shell; Existing/New regressions covered.
- `dart analyze` on touched files; representative mobile/desktop widths for pinned footer + scrolling visitor form.
