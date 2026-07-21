# Remove Manual Start Consultation Action

Remove **Start consultation** as a user-triggered control so consultation start and end come from workflow progression, not a manual button. Follow `prompts/.cursor/prompt.mdc`.

## Context

Queue Actions still exposes **Start consultation** as next-action guidance and a quick-action confirm dialog. After triage and doctor assignment that step is redundant. Consultation is inferred from prior completed steps.

**Start consultation action:** any control, confirm dialog, home shortcut, or launcher coded to start a consultation (`START_CONSULTATION` / `opdStartConsultation*`).

## Requirements

1. Remove **Start consultation** quick actions, confirm dialogs, and launchers from Reception, Desk queue next-action controls, OPD/clinic, Emergency if present, Patient registry, and Home.
2. Stop advertising it as an actionable next step; keep prioritize, change status, and change doctor when authorized.
3. Do not add a replacement begin-consultation control; rely on existing workflow/stage progression.
4. Preserve loading, empty, error, success, busy, permission states, and list sync for remaining actions; omit unauthorized UI.

## Constraints

- Reuse queue/flow dialogs, stage mapping, authorization, localization, and design-system; no new start-consultation contracts.
- Do not invent clinical transitions or change triage/doctor-assignment beyond this removal.
- Support themes and viewports.

## Acceptance Criteria

- R1–R2: No Start consultation button, confirm flow, or actionable launcher remains on listed surfaces.
- R3: Consultation progress still reflects from existing stage data without manual start.
- R4: Remaining actions sync; states clear; unauthorized UI absent.
- Update queue-actions, reception, OPD, and home tests; run Flutter analysis.

## Relevant Files

- `frontend/lib/shared/opd_actions/`
- `frontend/lib/features/{reception,opd,home}/`
- `frontend/test/shared/opd_actions/`
- `frontend/test/features/{reception,opd,home}/`
