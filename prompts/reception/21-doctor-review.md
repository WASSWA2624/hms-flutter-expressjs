# Limit Reception Flow Actions to Front-Desk Duties

On `/reception` Flow Actions, hide clinician writes; show journey as status; allow only Follow up, Correct stage, and Print summary among care-adjacent controls. Follow `prompts/.cursor/prompt.mdc`.

## Context

`allowClinicalActions: false` still leaks Disposition / Open admission, blocks Follow up, and may hide service progress. Reception tracks status without doctor or department work.

**Clinician write actions:** clinical notes, diagnosis, lab/radiology request, prescribe, procedure, refer, disposition, open admission, collect sample, perform imaging, dispense.

**Allowed care-adjacent actions:** Follow up, Correct stage, Print summary (start → current step).

**Progress status:** read-only lab/sample, imaging, pharmacy labels—not department actions.

## Requirements

1. With `allowClinicalActions: false`, omit all clinician write actions; never offer Disposition or Open admission.
2. Keep authorized Follow up, Correct stage, and Print summary on non-terminal visits; omit when unauthorized.
3. Show clinical-service rows as status-only when present; hide results and request/collect/perform/dispense controls.
4. Keep stepper and Current step / Next action read-only; invent no clinical transitions.
5. Preserve loading, empty, error, success, busy, permission states; sync after allowed mutations; omit unauthorized UI.

## Constraints

- Reuse Flow Actions, clinical-services panel, follow-up / stage / print dialogs, auth, localization, design-system; no new contracts.
- Do not change OPD/clinic `allowClinicalActions: true` surfaces.
- Support themes and viewports.

## Acceptance Criteria

- R1: No clinician writes, Disposition, or Open admission on Reception.
- R2: Follow up, Correct stage, Print summary remain when authorized.
- R3: Status-only service progress; no results or department writes.
- R4–R5: Labels read-only; states/sync intact; unauthorized UI absent.
- Update flow-actions and reception tests; run Flutter analysis.

## Relevant Files

- `frontend/lib/shared/opd_actions/{opd_flow_actions_dialog,opd_encounter_clinical_services}.dart`
- `frontend/lib/features/reception/presentation/`
- `frontend/test/shared/opd_actions/`
