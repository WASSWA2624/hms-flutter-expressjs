# Clarify the Reception Desk Queue

Update `/reception?section=desk-queue` so receptionists can see each patient’s current and next workflow steps without performing clinical actions.

## Context

The Desk queue currently shows generic statuses such as “In Progress” and exposes “Start consultation” as an action. Follow `prompts/.cursor/prompt.mdc`.

## Requirements

1. On Desk queue selection, render synchronized non-terminal queue data, including visits that progressed beyond waiting.
2. Replace generic progress text with the most specific current label supported by linked queue/visit data, such as waiting for consultation, consultation in progress, awaiting diagnostics, or awaiting disposition. Do not invent stages.
3. Rename **Actions** to **Next action** and display each row’s actual workflow next-step label.
4. Render next steps as read-only guidance. Do not expose clinical controls such as **Start consultation**; retain row details and authorized receptionist queue operations.
5. Make search, filters, sorting, settings, counts, and mobile cards use the revised values.

## Constraints

- Reuse existing synchronization, stage mapping, authorization, localization, and design-system components.
- Do not change backend contracts or clinical workflow transitions.
- Support loading, empty, error, themes, and responsive states.

## Acceptance Criteria

- R1–R3: Desk queue shows current non-terminal patients with specific current and next-step labels.
- R4: No clinical action can be initiated from Next action; authorized receptionist operations remain available.
- R5: Search, filters, settings, counts, and responsive views use the same values.
- Add/update reception widget tests and run Flutter analysis.

## Relevant Files

- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
- `frontend/lib/shared/opd_actions/`
- `frontend/lib/shared/workflow_actions/`
- `frontend/test/features/reception/presentation/`
