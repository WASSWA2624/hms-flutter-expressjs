# Align Start OPD Encounter with Visit Reality

Make Reception **Start OPD encounter** match open-visit state so Next action never contradicts Current step. Follow `prompts/.cursor/prompt.mdc` and `.cursor/flows/opd-flow.mdc`.

## Context

Appointments can offer Start while an open OPD exists. Block a second OPD, or OPD beside open IPD, except via supersede.

## Requirements

1. Derive Appointments Current step and Next action from appointment status plus open encounter or admission. Show **Start OPD encounter** only when eligible; prefer Continue or Edit when an open OPD exists.
2. Enforce one active OPD/Emergency encounter per patient. Block OPD start when an open IPD admission conflicts. Allow replacement only through cancel-old-and-start-new.
3. Keep `OpdEncounterDialog` Active-encounter notice, Continue, Edit, and guarded Start new. Label optional provider selection as doctor assignment.
4. After start, continue, edit, cancel, close, or supersede, synchronize Appointments, Desk queue, Active visits, counts, and badges.
5. Cover permission, loading, empty-eligible, validation, error, success, and blocked-start states; omit unauthorized controls.

## Constraints

- Reuse encounter dialogs, active-OPD lock, authorization, localization, theme tokens, and design-system components.
- Do not invent stages or bypass backend conflict rules.

## Acceptance Criteria

- R1: Open-OPD appointments no longer present Start as next action.
- R2: Concurrent active OPD or conflicting open IPD cannot create another OPD without supersede.
- R3–R4: Dialog actions and doctor labels match visit state; lists update after mutation.
- R5: Authorization and UI states tested; run Flutter analysis and backend tests.

## Relevant Files

- `frontend/lib/shared/components/opd_encounter_dialog.dart`
- `frontend/lib/shared/opd_actions/`
- `frontend/lib/features/reception/`
- `backend/src/lib/opd-active-encounter.js`
- `backend/src/modules/opd-flow/`
