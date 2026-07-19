# Make Shared Failure Retry Functional and Polished

Center retryable failures and visibly reload their content. Follow `prompts/.cursor/prompt.mdc`.

## Context

Reception retry lacks reliable reload and progress. Shared failures place the icon above a start-aligned title.

## Requirements

1. Render the shared failure icon and title in one centered row, with centered body, detail, and action below.
2. Center full-page failures in available shell content at a responsive width. Keep embedded views parent-constrained and overflow-free.
3. Invoke the asynchronous callback once. In Reception, reuse reload logic for required OPD and Payment gate data.
4. During retry, retain the message, show `AppButton` loading inside **Try again**, block duplicates, preserve dimensions, and announce progress.
5. On success, replace the failure with synchronized content. On failure, restore the localized failure and enabled action.
6. Implement this in shared components. Never add retry to non-retryable, forbidden, or unauthorized states.

## Constraints

- Reuse controllers, failure mapping, localization, theme tokens, `AppButton`, and state views.
- Do not change contracts, authorization, messages, or unrelated loading behavior.
- Support both themes and mobile, tablet, and desktop.

## Acceptance Criteria

- R1–R2: Failure content is centered, responsive, and unclipped.
- R3–R5: One activation visibly reloads required Reception data, blocks duplicates, and settles correctly.
- R6: Shared retryable states inherit this behavior; excluded states remain actionless.
- Test layout, callback count, progress semantics, success, repeat failure, authorization, themes, and viewports; run Flutter analysis.

## Relevant Files

- `frontend/lib/shared/components/app_state_view.dart`
- `frontend/lib/shared/components/app_button.dart`
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
- `frontend/test/shared/components/app_state_view_test.dart`
- `frontend/test/features/reception/presentation/reception_workspace_page_test.dart`