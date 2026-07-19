# Clarify the Reception Patient Registry Shortcut

Rename Reception’s ambiguous registry action and keep it as a direct shortcut to the patient registry. Follow `prompts/.cursor/prompt.mdc`.

## Context

The secondary toolbar action labeled **Full registry** opens `/patients`, but its label does not identify which registry it opens.

## Requirements

1. Replace **Full registry** with the localized label **Patient registry** everywhere the Reception toolbar exposes this action.
2. Keep the action secondary and preserve its current placement, icon, responsive behavior, and availability across Reception tabs.
3. On activation, navigate directly to the existing patient registry route (`AppRoutes.patients` / `/patients`). Do not open a dialog, preselect a patient, mutate data, or add an intermediate step.
4. Reuse the existing route authorization requirement. Render the action for authorized users and omit it entirely when patient-registry access is unauthorized or the module is inactive.
5. Update the localization source, generated localization output, semantic label, tooltip, and tests wherever they derive from the old wording. Remove the old wording if it has no remaining use.

## Constraints

- Reuse existing routes, access gates, localization generation, and design-system toolbar components.
- Do not change the patient registry, other Reception actions, backend contracts, or Reception state.
- Preserve loading, error, theme, keyboard, screen-reader, and mobile/tablet/desktop behavior.

## Acceptance Criteria

- R1–R2: Every authorized Reception toolbar shows one secondary **Patient registry** action without clipping or duplication.
- R3: Activating it opens `/patients` directly and causes no other side effect.
- R4–R5: Unauthorized users see no action; localized visible and accessible text contains no stale **Full registry** wording.
- Add/update widget tests for label, route, authorization, tabs, semantics, and representative viewports; run localization generation and Flutter analysis.

## Relevant Files

- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
- `frontend/lib/features/reception/presentation/reception_access.dart`
- `frontend/lib/l10n/app_en.arb`
- `frontend/test/features/reception/`
