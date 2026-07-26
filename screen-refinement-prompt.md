# Action Inventory — Target Screen: `/admin/setup?section=departments`

## Objective

Produce an inventory of only the actions directly rendered on the target screen and each action’s immediate result. Save it under `screens/`.

## Context

- Locate the screen from its route and audit its page and feature widgets.
- Use Dart presentation source as the authority.

## Requirements

1. Identify every direct screen action, including primary, secondary, text, icon, row, and `WorkflowActionButton` actions.
2. For each action, record its visible label (or icon-only description), screen location, permission or state condition, and immediate result.
3. If the action opens a modal dialog, name that dialog only.
4. If the action does not open a dialog, state the direct behavior it performs.
5. Save the inventory as `screens/[screen-name].md`, using the target screen’s lowercase kebab-case name without a leading slash.

## Constraints

- Include only actions directly present on `[target-screen]`.
- Do not inventory buttons or actions inside opened dialogs.
- Do not follow or list nested dialogs, modal workflows, or actions reachable from dialogs.
- Do not catalog filters, filter groups, checkboxes, column settings, banners, tabs, search fields, or other non-action chrome.
- Do not include unrelated actions from other tabs or screens.
- Read-only audit: do not modify application source, copy, or behavior.
- Creating or replacing the inventory file is allowed.
- Do not add implementation or refactor recommendations.

## Acceptance Criteria

- Every direct target-screen action appears exactly once.
- Each entry names its immediate dialog or direct behavior.
- No dialog-internal or nested action appears.
- The final inventory exists at `screens/[screen-name].md`.

## Relevant Files

- Route definitions for `[target-screen]`.
- The target page, feature widgets, and direct action handlers.
- Immediate dialog constructors called by those handlers.
- `screens/`.
