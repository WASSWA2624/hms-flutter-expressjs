# Refresh Reception Data Without Page-Level Loading

Make Reception refresh synchronize every section while keeping unrelated controls visually stable. Follow `prompts/.cursor/prompt.mdc`.

## Context

Refresh currently leaks loading state into toolbar actions, search, and the table, causing distracting indicators and disabled controls.

## Requirements

1. On **Refresh**, reload Appointments, Desk queue, Active visits, and Payment gate, including database changes absent from local state.
2. Recalculate every Reception tab badge from the refreshed section data, even when that tab is not selected.
3. Keep current rows visible during requests, then replace rows and badges with successful results; never clear or rebuild the surrounding page.
4. Keep refresh loading state out of **Register patient**, **Schedule appointment**, navigation actions, tabs, search, filters, settings, and table overlays. Deduplicate concurrent refresh requests.
5. Preserve the selected tab, query, filters, sorting, column settings, scroll position, authorization, and responsive layout.
6. If one section fails, retain its data, apply successful results, and show concise localized feedback without replacing the table.

## Constraints

- Reuse existing controllers, contracts, access gates, localization, and design-system feedback.
- Do not change mutation loading states, backend contracts, or non-Reception screens.
- Support loading, empty, partial-error, success, themes, and mobile/tablet/desktop states.

## Acceptance Criteria

- R1–R4: One click silently refreshes all section rows and badges; toolbar, search, and table overlays remain stable.
- R5–R6: View state survives refresh, and partial failure preserves usable data.
- Add widget/controller tests for synchronization, duplicate clicks, stable controls, state retention, authorization, partial failure, themes, and viewports; run Flutter analysis.

## Relevant Files

- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
- `frontend/lib/features/reception/presentation/controllers/reception_payment_gate_controller.dart`
- `frontend/lib/features/opd/presentation/controllers/`
- `frontend/test/features/reception/`
