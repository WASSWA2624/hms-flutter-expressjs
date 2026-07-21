# Limit Reception Flow Actions to Front-Desk Duties

Hide clinician writes on `/reception` Flow Actions; show journey as status; allow only Follow up, Correct stage, and Print summary. Follow `prompts/.cursor/prompt.mdc`.

## Context

`allowClinicalActions: false` still leaks Disposition / Open admission, blocks Follow up, and may hide service progress. Reception tracks status without doctor or department work.

**Clinician write actions:** clinical notes, diagnosis, lab/radiology request, prescribe, procedure, refer, disposition, open admission, collect sample, perform imaging, dispense.

**Allowed actions:** Follow up, Correct stage, Print summary.

**Progress status:** read-only lab/sample, imaging, pharmacy labels—not department actions.

## Requirements

1. Omit clinician write actions when `allowClinicalActions: false`; never offer Disposition or Open admission.
2. Keep authorized Follow up, Correct stage, and Print summary on non-terminal visits; omit when unauthorized.
3. Show clinical-service rows as status-only when present; hide results and request/collect/perform/dispense controls.
4. Keep stepper and Current step / Next action read-only; invent no transitions.
5. Preserve loading, empty, error, success, busy, permission states; sync after mutations; omit unauthorized UI.

## Constraints

- Reuse Flow Actions, clinical-services panel, follow-up/stage/print dialogs, auth, localization, design-system; no new contracts.
- Leave OPD/clinic `allowClinicalActions: true` unchanged.
- Support themes and viewports.

## Acceptance Criteria

- R1: No clinician writes, Disposition, or Open admission on Reception.
- R2: Follow up, Correct stage, Print summary remain when authorized.
- R3: Status-only progress; no results or department writes.
- R4–R5: Labels read-only; states/sync intact; unauthorized UI absent.
- Update flow-actions/reception tests; run Flutter analysis.

## Relevant Files

- `frontend/lib/shared/opd_actions/`
- `frontend/lib/features/reception/`
- `frontend/test/shared/opd_actions/`
