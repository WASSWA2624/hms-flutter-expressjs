# Remove Billing Navigation from Reception

Audit `/reception` and remove every Reception-originated control or fallback that navigates to the Billing workspace. Follow `prompts/.cursor/prompt.mdc`.

## Context

Reception and Billing are separate workspaces. Reception may display authorized, read-only payment information, but no control reachable from Reception may open `/billing`.

## Requirements

1. Inspect every Reception tab, toolbar, table/card action, row hub, overflow menu, nested dialog, empty/error state, and responsive variant for direct or indirect Billing navigation.
2. Remove Reception’s **Billing**, **Open billing workbench**, and equivalent controls, callbacks, route builders, and workflow fallbacks that resolve to `AppRoutes.billing` or `/billing`.
3. Ensure billing-related next-step labels are read-only when shown at Reception; tapping a row, card, label, or nested action must never route to Billing.
4. Preserve Payment gate’s authorized read-only outstanding-charge data, details, filters, totals, counts, and synchronization. Do not remove billing data needed to render Reception.
5. Keep shared components context-aware: block Billing navigation only when reached from Reception, without breaking valid Billing navigation from other workspaces.
6. Remove Reception-only dead navigation wiring and localization entries when truly unused; preserve unrelated actions and routes.

## Constraints

- Keep authorization authoritative; do not render removed controls as disabled or show routine access-denied feedback.
- Reuse existing route context, localization, and design-system patterns; preserve backend contracts.
- Preserve existing loading, empty, error, success, validation, theme, and responsive behavior.

## Acceptance Criteria

- R1–R3: No authorized or unauthorized interaction reachable from `/reception` navigates to `/billing`.
- R4–R6: Read-only Payment gate behavior and non-Reception Billing entry points still work.
- Add route-absence and regression widget tests across tabs, nested dialogs, permissions, and representative viewports; run Flutter analysis.

## Relevant Files

- `frontend/lib/features/reception/`
- `frontend/lib/shared/opd_actions/`
- `frontend/lib/app/router/`
- `frontend/test/features/reception/`