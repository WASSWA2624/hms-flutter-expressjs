# Refine Follow-up Contact Capture and Scoped Tabs

Standardize Follow-up contact fields and add scoped Follow-ups tabs on clinical workspaces. Follow `prompts/.cursor/prompt.mdc`.


## Context

Follow-up opens from Flow Actions with a plain phone field, no email, and journey stepper. Reception has Follow-ups; OPD and peer workspaces lack a scoped worklist.

**Contact capture:** required phone and email; prefilled when present; confirmed or supplied before save; persisted.

**Scoped Follow-ups tab:** patients in that workspace domain—not hospital-wide.

## Requirements

1. Keep patient identity; omit the visit journey stepper.
2. Show phone and email via `AppPhoneField` and `AppEmailField`; prefill when available.
3. Require both before save; persist to the patient when new or changed.
4. Keep schedule date/time and optional notes; Save creates and syncs.
5. Add Follow-ups tabs on OPD, inpatient, ICU, clinical, physiotherapy, theater, discharge, lab, radiology—scoped per workspace.
6. Omit Follow-ups tabs on pharmacy and billing.
7. Preserve loading, empty, error, success, busy, validation, permission states; omit unauthorized UI.

## Constraints

- Reuse follow-up dialogs, phone/email fields, patient APIs, lists, localization, auth, design-system; no new contracts.
- Do not change Follow-up authorization beyond contact UX.
- Support themes and viewports.

## Acceptance Criteria

- R1: Patient details remain; no journey stepper.
- R2–R3: Shared phone/email; prefilled; both required; contact persisted.
- R4: Schedule/notes unchanged; sync after save.
- R5–R6: Scoped tabs on listed workspaces; absent on pharmacy and billing.
- R7: States intact; unauthorized UI absent.
- Update follow-up/workspace tests; run Flutter analysis.

## Relevant Files

- `frontend/lib/shared/opd_actions/`
- `frontend/lib/features/{reception,opd}/`
- `frontend/test/shared/opd_actions/`
