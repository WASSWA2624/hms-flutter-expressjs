# 00 - Execution Policy
Use this workflow to execute each HOSSPI HMS frontend plan safely and consistently.

## Applicable Rules
You must follow [`scope.mdc`](../.cursor/scope.mdc), [`project_structure.mdc`](../.cursor/project_structure.mdc), [`architecture.mdc`](../.cursor/architecture.mdc), [`checklists.mdc`](../.cursor/checklists.mdc), and [`index.mdc`](../.cursor/index.mdc).

## Required Workflow
1. Read the rules referenced by the current step.
2. Inspect the existing Flutter project before editing.
3. Keep compliant implementations unchanged; patch incomplete, duplicated, or noncompliant work.
4. Create files only when the step or rules require them.
5. You must not recreate working code under another name or add out-of-scope requirements.
6. Run the smallest practical validation command.
7. Record created, modified, and skipped files in step notes.

## Acceptance Criteria
- Each step must run independently without breaking earlier steps.
- Reuse, patch, or creation decisions must be explicit.
- The app must remain aligned with product scope and backend API contracts.
