# Remove Manual Start Consultation Action

Remove **Start consultation** as a user-triggered control so consultation start and end come from workflow progression, not a manual button. Follow `prompts/.cursor/prompt.mdc`.

## Context

Queue Actions still shows **Start consultation** as next-action guidance and a quick action with confirm dialog. After triage and doctor assignment, that step is redundant and makes care overly manual. Consultation is a process stage inferred from prior completed steps.

**Start consultation action:** any control, confirm dialog, home shortcut, or launcher labeled or coded to start a consultation (`START_CONSULTATION` / `opdStartConsultation*`).

## Requirements

1. Remove **Start consultation** quick actions, confirm dialogs, and launchers from Reception Queue Actions, Desk queue actionable next-action controls, OPD/clinic, Emergency if present, Patient registry, and Home dashboard shortcuts.
2. Stop advertising **Start consultation** as an actionable next step in queue/encounter context; keep authorized receptionist queue ops (prioritize, change status, change doctor) and other non-clinical actions.
3. Do not add a replacement manual begin-consultation control; rely on existing workflow/stage progression for in-progress and completed consultation.
4. After unrelated queue/visit mutations, continue synchronizing Desk queue, Active visits, OPD lists, search, filters, and counts.
5. Preserve loading, empty, error, success, busy, and permission states for remaining actions; omit unauthorized UI.

## Constraints

- Reuse queue/flow dialogs, stage mapping, authorization, localization, and design-system; no new start-consultation contracts.
- Do not invent clinical transitions or change triage/doctor-assignment semantics beyond removing this action.
- Support themes and viewports.

## Acceptance Criteria

- R1–R2: No Start consultation button, confirm flow, or actionable launcher remains in Reception, OPD/clinic, Emergency, registry, or Home.
- R3: Consultation progress still reflects from existing stage data without a manual start control.
- R4–R5: Remaining actions sync and show clear states; unauthorized UI absent.
- Update queue-actions, reception, OPD, and home tests; run Flutter analysis.

## Relevant Files

- `frontend/lib/shared/opd_actions/opd_queue_actions_dialog.dart`
- `frontend/lib/features/reception/presentation/`
- `frontend/lib/features/opd/presentation/`
- `frontend/lib/features/home/`
- `frontend/test/shared/opd_actions/`
- `frontend/test/features/reception/`
- `frontend/test/features/opd/`
- `frontend/test/features/home/`
