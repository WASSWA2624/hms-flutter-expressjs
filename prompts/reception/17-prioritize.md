# Surface High-Priority Desk Queue Patients

Make Reception **Prioritize** mark desk-queue patients with clear recognition and a High priority tab. Follow `prompts/.cursor/prompt.mdc`.

## Context

**Prioritize** only bumps `queued_at`, leaving no durable visible high-priority state. Receptionists need VIP/urgent patients recognizable at any non-terminal desk-queue step.

**High priority:** non-terminal visit-queue entry marked via authorized Prioritize.

## Requirements

1. Persist high-priority on prioritize (optional reason); keep workflow status unchanged; preserve original queued-at for wait display.
2. Keep authorized **Prioritize** on Queue Actions for every non-terminal Desk queue entry; hide when terminal or unauthorized.
3. Mark prioritized Desk queue rows in table and mobile cards; sort them ahead of routine within existing list rules.
4. Add a Reception **High priority** tab of only those entries, reusing Desk queue labels and queue actions.
5. After success, synchronize Desk queue, High priority, search, filters, counts, and badges; show success feedback.
6. Preserve loading, empty, error, validation, busy, and permission states; omit unauthorized UI.

## Constraints

- Reuse prioritize endpoint, queue actions, authorization, localization, and design-system; extend visit-queue contracts only for durable priority.
- Do not invent clinical stages or replace triage/emergency priority.
- Support themes and viewports.

## Acceptance Criteria

- R1–R3: Prioritize persists and surfaces without changing workflow status or true queued-at.
- R4: High priority tab lists only marked non-terminal entries with working queue actions.
- R5–R6: Lists refresh; states clear; unauthorized UI absent.
- Update visit-queue, queue-actions, and reception tests; run Flutter analysis.

## Relevant Files

- `frontend/lib/shared/opd_actions/opd_queue_actions_dialog.dart`
- `frontend/lib/features/reception/`
- `backend/src/modules/visit-queue/`
- `frontend/test/features/reception/`
