# Reception Vitals Read-Only; Decongest Shared Record Vitals

Make Reception show **Record/Edit vitals** as guidance only; refine the shared vitals dialog for clinical modules. Follow `prompts/.cursor/prompt.mdc`.

## Context

Reception still opens **Record vitals** from Flow Actions. Receptionists must see vitals as next, not enter them. Shared `RecordVitalsDialog` is congested (duplicate triage, unlabeled pain scores, dense form).

**Record/Edit vitals action:** any control that opens the mutating vitals dialog.

## Requirements

1. On Reception, keep vitals Current/Next labels read-only; omit Record/Edit vitals quick actions and openers.
2. Keep authorized Record/Edit vitals on clinical owners (OPD, nursing); reuse one shared dialog.
3. Drop triage priority; keep one searchable **Triage level** (default Normal). Keep optional chief complaint, symptoms, allergies, notes, emergency toggle, risk flags; searchable labeled **Pain severity**.
4. Replace inline vitals with buttons opening sub-dialogs for BP, temperature, HR, RR, SpO2, weight, height (defaults mmHg, °C, kg, cm). Derive BMI; show age/gender ranges; require ≥1 vital.
5. Preserve loading, empty, error, validation, busy, success, permission, sync; omit unauthorized UI.

## Constraints

- Reuse `AppRecordVitalsDialog`, `RecordVitalsDialog`, flow dialogs, authorization, localization, design-system; no Reception vitals fork.
- Do not invent stages or change mutators beyond hiding Reception entry points; support themes and viewports.

## Acceptance Criteria

- R1: Reception never opens Record/Edit vitals; next-step text still shows.
- R2–R4: Shared dialog matches fields, sub-dialogs, BMI, ranges; ≥1 vital.
- R5: States and sync clear; unauthorized UI absent.
- Update reception, flow-actions, record-vitals tests; run Flutter analysis.

## Relevant Files

- `frontend/lib/shared/{opd_actions,components}/`
- `frontend/lib/features/reception/`
- `frontend/test/{shared/opd_actions,features/reception}/`
