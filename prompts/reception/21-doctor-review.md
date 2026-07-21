# Center Logo Loading and Polish Workflow Steps

Keep the branded logo loader centered and sized inside its loading parent, and sharpen current/next step presentation in the shared workflow stepper. Follow `prompts/.cursor/prompt.mdc`.

## Context

`AppLoadingIndicator` sometimes renders left-aligned and undersized in busy dialogs/panels (e.g. Flow Actions). `AppWorkflowStepper` needs clearer current vs next hierarchy.

**Loading parent:** the bounded busy region (dialog content, panel, or overlay)—not the full screen unless that region is full-screen.

## Requirements

1. Center the logo (and optional title/body) within the loading parent’s bounds whenever shown; never leave it left-aligned in a stretched column.
2. Size the logo mark to fit the parent (compact in dialogs/panels; larger only for page-scale parents) without clipping or overflow.
3. Apply centering/sizing via shared `expand`/layout in existing hosts (including Flow Actions busy state)—no one-off hacks.
4. Improve current-step and next-step look in `AppWorkflowStepper`; keep other states readable and not color-only.
5. Preserve loading, busy, empty, error, success, permission, and sync; omit unauthorized UI.

## Constraints

- Reuse `AppLoadingIndicator`, `AppLogo`, `AppWorkflowStepper`, tokens, and localization; no new contracts or clinical transitions.
- Do not change workflow order, stage mapping, or action availability.
- Support themes and representative viewports.

## Acceptance Criteria

- R1–R3: Busy parents show a centered, proportionally sized logo loader; no left-aligned mark.
- R4: Current and next steps are clearer; other states remain distinct and accessible.
- R5: States/sync intact; unauthorized UI absent.
- Update loading-indicator and workflow-stepper tests; run Flutter analysis.

## Relevant Files

- `frontend/lib/shared/components/{app_loading_indicator,app_workflow_stepper,app_state_view}.dart`
- `frontend/lib/shared/opd_actions/opd_flow_actions_dialog.dart`
- `frontend/test/shared/{components,opd_actions}/`
