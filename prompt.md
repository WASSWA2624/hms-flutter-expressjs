# Inventory Reception Screen Action Buttons

Produce a complete inventory of every action button on the `/reception` workspace, including buttons inside modal dialogs and any nested dialogs those modals open.

## Context

- Route: `/reception` (`AppRoutes.reception`).
- Primary page: `ReceptionWorkspacePage` and its widgets under `frontend/lib/features/reception/`.
- Reception composes shared OPD, patient, billing, and workflow dialogs; include those when opened from reception.

## Requirements

1. Review the reception workspace UI and every dialog reachable from it (including nested dialogs).
2. List each action button with: visible label (or icon-only description), location (page chrome, row/toolbar, dialog name), and whether it opens a modal.
3. When a button opens a modal, name the dialog and recursively list that dialog’s action buttons the same way.
4. Include primary, secondary, text, icon, and `WorkflowActionButton` actions; exclude non-action chrome (close affordances that only dismiss without a labeled action may be noted once per dialog).
5. Deliver the inventory as a structured list grouped by surface (workspace → dialog → nested dialog).

## Constraints

- Read-only audit; do not change code, copy, or behavior.
- Scope is `/reception` and dialogs opened from it only.
- Prefer source of truth in Dart presentation widgets over runtime speculation.
- Follow existing prompt standards in `prompts/.cursor/prompt.mdc` for clarity; this prompt is inventory-only.

## Acceptance Criteria

- Every reception-reachable action button appears exactly once in the inventory under its surface.
- Every button that opens a modal names that modal; nested modal buttons are listed under their parent modal.
- Grouping makes parent → child dialog relationships obvious.
- No implementation or refactor recommendations unless a button cannot be identified from source.

## Relevant Files

- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
- `frontend/lib/features/reception/presentation/widgets/reception_queue_actions_dialog.dart`
- `frontend/lib/features/reception/presentation/widgets/reception_appointment_actions_dialog.dart`
- `frontend/lib/features/reception/presentation/widgets/reception_patient_actions.dart`
- `frontend/lib/features/reception/presentation/widgets/reception_billing_guidance.dart`
- `frontend/lib/shared/opd_actions/` (dialogs composed by reception)
- `frontend/lib/shared/workflow_actions/workflow_action_button.dart`
