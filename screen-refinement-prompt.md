# Action Button Inventory — Target Screen: `[tartget-screen]`

Produce an inventory that lists **only** the action buttons on the target screen and the dialogs those buttons open (including nested dialogs). Save the inventory under `screens/`.

## Context

- Treat the route, page, feature widgets, shared components, and reachable dialogs associated with the target screen as the audit scope.
- Include shared dialogs only when an action button on the target screen (or on a dialog opened from it) opens them.

## Requirements

1. Locate the target screen from its route, then identify every action button on that screen.
2. For each action button, record: visible label (or icon-only description), location on the screen, and the dialog it opens (if any).
3. When a button opens a dialog, name that dialog and list **only** that dialog’s action buttons the same way—including any further dialogs those buttons open.
4. Include primary, secondary, text, icon, and `WorkflowActionButton` actions.
5. Deliver the inventory as a structured list grouped by surface: screen → dialog → nested dialog.
6. Save the completed inventory as `screens/[screen-name].md`, replacing `[screen-name]` with the target screen’s lowercase kebab-case name without a leading slash.

## Constraints

- Inventory contents are limited to action buttons and the dialogs they open. Do not catalog filters, filter groups, checkboxes, column settings, empty states, banners, tabs, search fields, or other non-action chrome.
- Close / Cancel / dismiss actions that only close a dialog without opening another may be listed once per dialog as footer actions; do not expand beyond that.
- Read-only audit; do not change code, copy, or behavior.
- Do not modify application source files; creating or replacing the required inventory file is allowed.
- Scope is the target screen and dialogs opened from its action buttons only.
- Prefer source of truth in Dart presentation widgets over runtime speculation.
- This prompt is inventory-only.

## Acceptance Criteria

- Every action button on the target screen appears exactly once under the screen surface.
- Every button that opens a dialog names that dialog; that dialog’s action buttons appear under it (and so on for nested dialogs).
- The inventory contains nothing except action buttons and the dialogs they open.
- Grouping makes parent → child dialog relationships obvious.
- No implementation or refactor recommendations unless a button cannot be identified from source.
- The final inventory exists at `screens/[screen-name].md` and contains the complete result rather than only a link or summary.

## Relevant Files

- Route definitions that map to the target screen.
- The target screen’s page, feature widgets, and action handlers.
- Shared components, dialogs, and workflow actions invoked by those handlers.
- Tests may confirm conditional actions and dialog behavior but do not replace presentation source as the source of truth.
- `screens/` (output directory).
