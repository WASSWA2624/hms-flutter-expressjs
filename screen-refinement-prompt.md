# Action Button Inventory — Target Screen: `/admin/setup`

Produce a complete inventory of every action button on the target screen, including buttons inside modal dialogs and any nested dialogs those modals open. Save the inventory under `screens/`.

## Context

- Treat the route, page, feature widgets, shared components, and reachable dialogs associated with the target screen as the audit scope.
- Include shared dialogs and workflows only when they are reachable from the target screen.

## Requirements

1. Locate the target screen from its route, then review its complete UI and every dialog reachable from it, including nested dialogs.
2. List each action button with: visible label (or icon-only description), location (page chrome, row/toolbar, dialog name), and whether it opens a modal.
3. When a button opens a modal, name the dialog and recursively list that dialog’s action buttons the same way.
4. Include primary, secondary, text, icon, and `WorkflowActionButton` actions; exclude non-action chrome (close affordances that only dismiss without a labeled action may be noted once per dialog).
5. Deliver the inventory as a structured list grouped by surface (screen → dialog → nested dialog).
6. Save the completed inventory as `screens/[screen-name].md`, replacing `[screen-name]` with the target screen’s lowercase kebab-case name without a leading slash.

## Constraints

- Read-only audit; do not change code, copy, or behavior.
- Do not modify application source files; creating or replacing the required inventory file is allowed.
- Scope is the target screen and dialogs opened from it only.
- Prefer source of truth in Dart presentation widgets over runtime speculation.
- This prompt is inventory-only.

## Acceptance Criteria

- Every action button reachable from the target screen appears exactly once in the inventory under its surface.
- Every button that opens a modal names that modal; nested modal buttons are listed under their parent modal.
- Grouping makes parent → child dialog relationships obvious.
- No implementation or refactor recommendations unless a button cannot be identified from source.
- The final inventory exists at `screens/[screen-name].md` and contains the complete result rather than only a link or summary.

## Relevant Files

- Route definitions that map to the target screen.
- The target screen’s page, feature widgets, and action handlers.
- Shared components, dialogs, and workflow actions invoked by those handlers.
- Tests may confirm conditional actions and dialog behavior but do not replace presentation source as the source of truth.
- `screens/` (output directory).
