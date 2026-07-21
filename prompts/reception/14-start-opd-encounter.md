# Align Start OPD Encounter with Visit Reality

Make Reception **Start OPD encounter** match the patient’s real open-visit state so actions never contradict Current step. Follow `prompts/.cursor/prompt.mdc` and `.cursor/flows/opd-flow.mdc`.

## Context

Appointments can still offer **Start OPD encounter** while an open OPD visit already exists (for example With doctor). Starting a second OPD, or an OPD beside an open IPD admission, must stay blocked except via the explicit supersede path.

## Requirements

1. Derive Appointments Current step and Next action from appointment status plus the patient’s open encounter or admission. Offer **Start OPD encounter** only when start is eligible; when an open OPD exists, prefer Continue or Edit guidance.
2. Enforce one active OPD/Emergency encounter per patient. Block OPD start when an open IPD admission conflicts. Allow a replacement OPD only through the existing cancel-old-and-start-new confirmation.
3. Keep `OpdEncounterDialog` Active-encounter notice, Continue, Edit, and guarded Start new. Label optional provider selection as doctor assignment, not generic staff.
4. After start, continue, edit, cancel, close, or supersede, synchronize Appointments, Desk queue, Active visits, counts, and badges immediately.
5. Cover permission, loading, empty-eligible, validation, error, success, and blocked-start feedback; omit unauthorized controls.

## Constraints

- Reuse encounter dialogs, active-OPD lock, authorization, localization, theme tokens, and design-system components.
- Do not invent stages or bypass backend conflict rules.

## Acceptance Criteria

- R1: Appointments with an open OPD no longer present Start as the true next action.
- R2: Concurrent active OPD or conflicting open IPD cannot create another OPD without supersede confirmation.
- R3–R4: Dialog actions and doctor labels match visit state; lists update after mutation.
- R5: Authorization absence and required UI states are tested; run Flutter analysis and backend conflict tests.

## Relevant Files

- `frontend/lib/shared/components/opd_encounter_dialog.dart`
- `frontend/lib/shared/opd_actions/opd_appointment_actions_dialog.dart`
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
- `backend/src/lib/opd-active-encounter.js`
- `backend/src/modules/opd-flow/`
