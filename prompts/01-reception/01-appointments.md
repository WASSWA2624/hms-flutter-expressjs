# Reception Appointments tab — rule compliance

## Context

Make the Appointments desk section (`ReceptionDeskSection.appointments`) fully compliant with `tabs.mdc`, `tables.mdc`, `dialogs.mdc`, `forms.mdc`, `printing.mdc`, and `screens.mdc`. Inventory baseline: `tabs/01-reception/01-appointments.md`. Apply shared chrome fixes from `prompts/01-reception/00-shared-chrome.md` first when this tab depends on them (counts, Print, Export gate, tones).

## Requirements

1. Keep strip label `receptionSectionAppointments`, query `section=appointments` (alias `meetings`), and omit the tab without ∩ `patient:read` (+ modules) (`tabs.mdc`).
2. Badge count must be the authoritative pre-encounter appointments total for the tab scope; when Filters/search/date are applied, the **active** badge must reflect the filtered total (`tabs.mdc`). Stop using painted-row length alone when a total is available or can be derived from the same filter model.
3. Use an urgency-appropriate `AppTabCountTone` (default `info` unless product-justified `warning` is documented in test) (`tabs.mdc`).
4. Toolbar: Filters → Settings → Export → Print → Schedule → Register with exact shared labels; date filter remains enabled on scheduled time (`tables.mdc`, `printing.mdc`).
5. Mount table Print with preview-first shared printing and column/section options aligned to this tab’s exportable fields. Omit Print/Export/Schedule/Register when unauthorized.
6. Keep default visible columns at **5** unless a justified exception is recorded (today’s 3–4 defaults need either a fifth meaningful default or an explicit justified set in code + test) (`tables.mdc`). Settings must list every available column; Reset restores the default set.
7. Advanced filters remain comprehensive for appointments (status, next action, provider, scheduled date range, search fields) and edit the **same** filter model as the table and active count (`tabs.mdc`, `tables.mdc`).
8. Preserve row-select → Appointment Actions (generic title) with clinical/vitals stripped; next-action Check in / Continue / Reschedule stay front-desk gated and omitted when unauthorized (`dialogs.mdc`, `screens.mdc`).
9. Nested reschedule / cancel / encounter / Flow Actions stay in-desk dialogs; reuse shared forms; cancel reason and schedule fields use shared validators (`forms.mdc`).
10. Any print entry from Continue → Flow Actions must use trigger label `Print` and shared preview (`printing.mdc`).
11. Cover empty (`receptionEmpty*`), loading, error/retry, success (`opdSavedMessage` / `patientsSavedMessage`), and validation feedback. Refresh table + all affected tab counts after mutations.

## Constraints

- Do not fork a Reception-only appointment actions shell; keep wrapping `OpdAppointmentActionsDialog`.
- Do not add cashier controls on this tab.
- Do not invent columns that duplicate the same fact (`tables.mdc`).

## Acceptance Criteria

- [ ] Appointments tab count matches authoritative / filtered rules in Requirements 2–3.
- [ ] Toolbar order and labels match Requirement 4; Print preview opens before print.
- [ ] Default column policy satisfies Requirement 6; Settings exposes all columns.
- [ ] Unauthorized tab, next-action, Schedule, Register, Export, and Print controls are absent.
- [ ] Appointment Actions and nested dialogs keep generic titles and shared form fields.
- [ ] `tabs/01-reception/01-appointments.md` updated to match.

## Verification

- Tests: tab omit gate; front-desk next-action omit; filtered count; toolbar Print/Export presence matrix.
- Manual: check-in, reschedule, cancel, schedule visitor/patient paths remain in-desk; light/dark + narrow viewport.

## Relevant Files

- `tabs/01-reception/01-appointments.md`
- `prompts/01-reception/00-shared-chrome.md`
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
- `frontend/lib/features/reception/presentation/widgets/reception_appointment_actions_dialog.dart`
- `frontend/lib/features/reception/presentation/widgets/reception_patient_actions.dart`
- `frontend/lib/features/reception/presentation/reception_access.dart`
- `frontend/lib/shared/opd_actions/`
- `frontend/test/features/reception/`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/printing.mdc`
- `prompts/.cursor/screens.mdc`
