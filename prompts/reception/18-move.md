# Redesign Queue Status Radio Selection

Improve Change Queue Status and reusable `AppRadioGroup` so status choices read clearly at a glance. Follow `prompts/.cursor/prompt.mdc`.

## Context

Change Queue Status lists six visit-queue statuses as plain dense `RadioListTile`s in one column. Options look indistinct.

**Layout mode:** vertical, horizontal, or wrapping grid. Change status uses a two-column wrap.

## Requirements

1. Redesign shared `AppRadioGroup` / `AppRadioOption` into distinct selectable surfaces with selected, unselected, focus, disabled, and error states via theme tokens.
2. Keep description optional; show only when provided, secondary to the label.
3. Support vertical, horizontal, and wrapping layouts; Change Queue Status uses two columns on tablet/desktop and one on narrow mobile.
4. Keep Change Queue Status status-only with the same six lifecycle values and existing labels/descriptions; tighten spacing so purpose is obvious.
5. Preserve validation, error, busy, success, and permission behavior; synchronize after save; omit unauthorized UI.
6. Keep Settings and other callers working with defaults (vertical).

## Constraints

- Reuse design-system tokens, form validation, move/status contracts, localization, and queue-actions authorization; no new lifecycle values.
- Do not change Assign/Change doctor or clinical stages.
- Support themes and viewports without clipping.

## Acceptance Criteria

- R1–R3: Options visually distinct; optional descriptions work; Change status uses two columns where width allows.
- R4–R5: Status dialog remains status-only; states and sync unchanged.
- R6: Existing radio callers still select correctly.
- Update radio-group, queue-actions, and reception tests; run Flutter analysis.

## Relevant Files

- `frontend/lib/shared/components/app_radio_group.dart`
- `frontend/lib/shared/opd_actions/opd_queue_actions_dialog.dart`
- `frontend/test/shared/components/`
- `frontend/test/shared/opd_actions/`
