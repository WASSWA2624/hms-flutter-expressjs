# Refine Reception Appointments and Toolbars

## Objective
Make the `/reception` tabs and toolbars predictable, permission-aware, and synchronized with backend state, with a clear appointment workflow.

## Context
The reception workspace contains Appointments, Desk Queue, Active Visits, and Payment Gate tabs. Preserve existing workflows, routes, dialogs, state management, design-system components, and localization.

## Requirements
1. Make Appointments a first-class workspace tab. Selecting it must update the URL, preserve deep-link and browser navigation behavior, and render backend-sourced current, scheduled, and due appointments using the existing responsive list/table.
2. Show the authorized tab-specific primary action only on its tab:
   - Appointments: **Schedule appointment**
   - Payment Gate: **Billing**
   - Desk Queue and Active Visits: preserve their existing primary action
3. Use a consistent secondary toolbar:
   - Every tab: **Register patient** and **Refresh**
   - Appointments: **Full registry**
   - Desk Queue, Active Visits, and Payment Gate: **Full OPD**
4. Keep actions wired to their existing dialogs and destinations. Refresh must reload the active workspace data, prevent duplicate requests, show progress, and preserve the selected tab and valid filters.
5. Re-fetch or update affected workspace data after successful mutations. Derive loading, enabled, and visible states from current data, request state, and permissions rather than stale local copies.
6. Enforce authorization through existing backend permissions. Omit unauthorized tabs and actions from the widget tree. Disable an authorized action only when temporarily unavailable because of workflow state, missing selection, or an in-flight request; provide a concise tooltip stating the reason.
7. Provide localized loading, empty, error, retry, validation, and success feedback. Keep desktop and mobile layouts usable without clipped, duplicated, or overflowing actions.

## Constraints
- Follow `prompts/.cursor/prompt.mdc`.
- Reuse existing reception widgets, controllers/providers, routes, API contracts, permissions, and localization keys.
- Do not add parallel appointment state, duplicate business rules, weaken backend authorization, or perform unrelated refactoring.
- Treat backend responses as the source of truth.

## Acceptance Criteria
1. Selecting or deep-linking to Appointments activates the tab, updates the URL, and displays backend appointment data; browser back/forward restores the correct tab. [R1]
2. Each tab shows exactly its authorized primary action and the secondary actions defined above, on desktop and mobile. [R2, R3, R7]
3. Schedule appointment, Register patient, Billing, Full registry, and Full OPD invoke their existing flow or route. [R2-R4]
4. Refresh cannot run concurrently, visibly reports progress, preserves workspace context, and updates the displayed data. [R4]
5. Successful create/update actions are reflected without a full-page reload; failures retain recoverable context and show actionable feedback. [R5, R7]
6. Unauthorized controls are absent. Authorized but contextually unavailable controls are disabled with an explanatory tooltip and become enabled when their condition is met. [R6]
7. Existing reception widget tests pass; add or update tests for routing, toolbar variants, authorization absence, disabled tooltips, refresh concurrency, mutation synchronization, and loading/empty/error states. [R1-R7]
8. `flutter analyze` and the relevant Flutter tests complete without new errors. [R1-R7]

## Relevant Files
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
- `frontend/lib/features/reception/presentation/widgets/reception_patient_actions.dart`
- `frontend/lib/features/reception/presentation/widgets/reception_appointment_actions_dialog.dart`
- Existing reception providers/controllers, route definitions, localization files, and widget tests discovered from these entry points
