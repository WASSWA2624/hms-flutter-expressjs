# Open Context-Aware Actions from Reception Rows

Open a reusable, permission-aware workflow dialog from every Reception record. Follow `prompts/.cursor/prompt.mdc`.

## Context

Reception tables have inconsistent workflow columns, row behavior, and duplicated patient summaries.

## Requirements

1. Show localized **Current step** and **Next action** columns in each table and equivalent card fields, derived from authoritative workflow state.
2. On row click, keyboard activation, or card tap, open the dialog matching the record type and next action.
3. Build one reusable shell containing shared patient details, completed/current/next progress, and concise next-step guidance.
4. Show the existing next-action control and Reception quick actions only when authorized; reuse workflow registries, executors, dialogs, and validation.
5. Otherwise show read-only details and guidance; omit restricted controls, data, and routine access-denied feedback.
6. Replace duplicated appointment and queue summaries/action grids. Keep Payment gate read-only unless an authorized existing action applies.
7. After mutations, synchronize affected rows and progress. Preserve loading, empty, error, success, and record-state-disabled feedback.

## Constraints

- Keep backend RBAC/ABAC authoritative; do not invent actions, transitions, contracts, or routes.
- Reuse localization and design-system components; preserve sorting, themes, accessibility, and responsive layouts.
- Do not navigate Reception users to Billing or expose unauthorized clinical actions.

## Acceptance Criteria

- R1–R3: Every record shows consistent workflow context and opens the correct accessible dialog.
- R4–R6: Authorized actions work, restricted actions are absent, and shared content replaces duplication.
- R7: Successful actions synchronize rows and progress while every state remains clear.
- Test all tables, states, activation methods, permissions, synchronization, themes, and viewports; run Flutter analysis.

## Relevant Files

- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
- `frontend/lib/features/reception/presentation/widgets/reception_*_actions_dialog.dart`
- `frontend/lib/shared/components/app_patient_details.dart`
- `frontend/lib/shared/workflow_actions/`
- `frontend/test/features/reception/presentation/`