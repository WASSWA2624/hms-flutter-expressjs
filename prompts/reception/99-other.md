# Build a Compact Shared Patient Progress Stepper

Replace oversized workflow controls with a reusable, accessible progress stepper. Follow `prompts/.cursor/prompt.mdc`, `.cursor/flows/opd-flow.mdc`, and `frontend/.cursor/index.mdc`.

## Context

Reception action dialogs use excessive space and do not clearly communicate the patient’s journey.

## Requirements

1. Create one presentation-only shared component accepting ordered completed, current, and next steps plus optional concise guidance.
2. Show the first known step through the next action. Differentiate states with localized text, icons, connectors, and semantics—not color alone.
3. Use a compact horizontal layout when possible and a readable wrapping or vertical layout on narrow screens, without clipping or scrolling.
4. Replace compatible progress views in Reception appointment, queue, and flow dialogs; migrate other patient progress views only when behavior matches.
5. Preserve workflow order, permissions, actions, and synchronization. Omit unauthorized content; never expose raw enums or database IDs.
6. Handle missing or invalid data safely, preserve host loading/empty/error/success feedback, and support keyboard and screen-reader use.

## Constraints

- Reuse tokens, localization, registries, and action controls; do not invent transitions or embed business logic.
- Support both themes, text scaling, and all representative widths.

## Acceptance Criteria

- R1–R4: Dialogs show a compact, reusable, ordered journey without compatible duplication.
- R5–R6: Authorized behavior remains unchanged; restricted UI is absent and every state is accessible.
- Add component and dialog widget tests for states, permissions, themes, scaling, and widths; run Flutter analysis and tests.

## Relevant Files

- `frontend/lib/shared/`
- `frontend/lib/shared/opd_actions/`
- `frontend/lib/shared/workflow_actions/`
- `frontend/lib/features/reception/presentation/`
- `frontend/test/`