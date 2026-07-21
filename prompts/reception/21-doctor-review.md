# Rename Doctor Review to Clinical Notes

Rename **Doctor review** to **Clinical notes**; hide clinician actions and vital results from Reception; clinical modules only. Follow `prompts/.cursor/prompt.mdc`.

## Context

At **With doctor**, Flow Actions shows **Doctor review** and a required clinical-note dialog. Reception sees vital results and clinician quick actions—a clinician note action, not a front-desk step.

**Clinical notes action:** `DOCTOR_REVIEW` / `ClinicalFreeTextActionDialog` (today Doctor review).
**Clinician-only quick actions:** diagnosis, lab, radiology, prescribe, procedure, refer, follow-up.
**Clinical modules:** OPD, Patients, Emergency, ICU/clinical, Physiotherapy.
**Non-clinical:** Reception plus ancillary/admin modules.

## Requirements

1. Rename Doctor review action, dialog title, and submit to **Clinical notes**; keep backend codes/stages.
2. On Reception Flow Actions and Active visits: omit Clinical notes and clinician-only quick actions; keep front-desk actions.
3. On Reception clinical-services UI: show recorded status/location without results.
4. Expose Clinical notes only in clinical modules for authorized clinicians when with-doctor / review-eligible; omit elsewhere.
5. Preserve loading, busy, required-note validation, error, success, sync, and permission omission; omit unauthorized UI.

## Constraints

- Reuse flow/clinical dialogs, clinical-services panel, authorization, localization, design-system; no new contracts.
- Do not invent stages or change progression beyond labels/visibility.
- Support themes and viewports.

## Acceptance Criteria

- R1: Labels say Clinical notes.
- R2–R3: Reception omits Clinical notes/clinician quick actions; vitals recorded without results.
- R4–R5: Action only in clinical modules when authorized; states/sync intact; unauthorized UI absent.
- Update flow-actions and reception tests; run Flutter analysis.

## Relevant Files

- `frontend/lib/shared/opd_actions/`
- `frontend/lib/shared/clinical_actions/dialogs/`
- `frontend/lib/features/reception/`
- `frontend/lib/l10n/app_en.arb`
- `frontend/test/shared/opd_actions/`
