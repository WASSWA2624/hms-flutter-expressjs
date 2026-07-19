# Refine Reception Appointment Toolbar and Table

Update `/reception` so its toolbar is consistent across tabs and its Appointments table exposes appointment-specific data and controls.

## Context

The screen contains Appointments, Desk queue, Active visits, and Payment gate tabs. Follow `prompts/.cursor/prompt.mdc`.

## Requirements

1. Make **Register patient** the sole primary action on every tab.
2. Show **Schedule appointment**, **Refresh**, **Full registry**, and **Full OPD** as secondary toolbar actions on every tab. Enable **Schedule appointment** only while Appointments is active; keep it visible but disabled elsewhere.
3. Preserve each action’s existing handler, loading feedback, route, authorization, and responsive toolbar behavior. Do not render unauthorized actions.
4. On Appointments, display all non-terminal appointment statuses, including NEW and CONFIRMED, using existing appointment data and synchronization.
5. Make appointment search match the displayed appointment fields. Populate Advanced filters with the statuses represented by the appointment dataset and filter correctly.
6. Ensure Settings offers only relevant appointment columns and persists valid visibility choices.

## Constraints

- Reuse existing controllers, routes, localization, access gates, and design-system components.
- Do not alter unrelated tabs, workflows, backend contracts, or appointment lifecycle rules.
- Support loading, empty, error, light/dark theme, and mobile/tablet/desktop states.

## Acceptance Criteria

- R1–R3: Authorized users see the specified toolbar on every tab with correct enabled, loading, and navigation behavior.
- R4–R6: NEW and CONFIRMED appointments are visible, searchable, filterable, and configurable by relevant columns.
- Existing reception widget tests pass; add tests for toolbar visibility/state, authorization, status filtering, search, and column settings.

## Relevant Files

- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
- `frontend/lib/features/reception/presentation/reception_access.dart`
- `frontend/lib/shared/components/app_list_table.dart`