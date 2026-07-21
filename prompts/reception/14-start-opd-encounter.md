# Collapse Reception Check-In to Start OPD Encounter

Remove the separate **Queue** appointment action from `/reception` so check-in is one **Start OPD encounter** step. Follow `prompts/.cursor/prompt.mdc`.

## Context

Appointment actions offer **Queue** (desk queue only) beside **Start OPD encounter**. The row next-action is effectively unreachable for visible statuses, and starting an encounter already creates the visit-queue entry.

## Requirements

1. Remove **Queue** from Reception appointment next-action labels and appointment-actions quick actions, including the shared dialog when hosted from Reception.
2. Keep **Start OPD encounter** as the primary authorized next action for non-terminal appointments without an open encounter; preserve continue/edit, reschedule, and cancel when authorized.
3. Ensure starting an encounter still creates or links the desk-queue entry via existing contracts so the patient appears on Desk queue after success.
4. After success, synchronize Appointments, Desk queue, Active visits, search, filters, and counts.
5. Preserve loading, error, success, validation, and permission states; omit unauthorized UI.

## Constraints

- Reuse existing encounter, queue, authorization, localization, and design-system paths.
- Do not remove Desk queue prioritize/move actions or invent clinical transitions.
- Limit scope to Reception check-in unless shared dialog reuse requires it.

## Acceptance Criteria

- R1–R2: Reception hides **Queue**; Start OPD encounter and remaining authorized actions still work.
- R3–R4: Successful start places the patient on Desk queue and refreshes lists.
- R5: Loading, error, success, and permission states remain clear; unauthorized UI is absent.
- Update reception and shared appointment-action tests; run Flutter analysis.

## Relevant Files

- `frontend/lib/shared/opd_actions/opd_appointment_actions_dialog.dart`
- `frontend/lib/shared/opd_actions/opd_appointment_eligibility.dart`
- `frontend/lib/features/reception/presentation/`
- `frontend/test/features/reception/`
- `frontend/test/shared/opd_actions/`
