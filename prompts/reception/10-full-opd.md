# Align Reception Shortcuts and Refresh

Match Reception shortcuts to main navigation and show local refresh progress. Follow `prompts/.cursor/prompt.mdc`.

## Context

**Full OPD** differs from navigation, Patient registry uses a mismatched icon, and refresh lacks visible progress.

## Requirements

1. Rename **Full OPD** to the localized navigation label **Outpatient (OPD)** wherever rendered or announced.
2. Navigate directly through `AppRoutes.opd` (`/opd`), without dialogs, mutations, or intermediate steps.
3. Use `AppRouteIcons.opd` for Outpatient and `AppRouteIcons.patients` for Patient registry; do not duplicate constants.
4. During refresh, replace only its icon with a compact animated indicator. Retain the label and progress semantics, prevent duplicate requests, preserve dimensions, and restore the icon after success or failure.
5. Omit each shortcut when its existing route requirement denies access or its module is inactive.
6. Update localization sources/output, semantics, tooltips, inventory, and tests; remove stale **Full OPD** text.

## Constraints

- Reuse existing routes, gates, refresh logic, localization, and toolbar components.
- Do not change refresh scope, contracts, Reception state, or unrelated actions.
- Preserve content, responsive layout, and themes. Empty and validation behavior remain unchanged; failures retain data and existing localized feedback.

## Acceptance Criteria

- R1–R3: Authorized toolbars show consistent shortcuts, and Outpatient opens `/opd` directly.
- R4: Only Refresh shows progress, remains single-flight, and restores its icon after success or error.
- R5–R6: Unauthorized shortcuts are absent and accessible text contains no stale wording.
- Test routes, icons, authorization, completion states, semantics, tabs, themes, and viewports; generate localization and run Flutter analysis.

## Relevant Files

- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
- `frontend/lib/app/router/app_route_icons.dart`
- `frontend/lib/l10n/app_en.arb`
- `frontend/test/features/reception/`
- `screens/reception.md`