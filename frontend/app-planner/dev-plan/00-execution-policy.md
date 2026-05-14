# 00 - Execution policy

## Goal
Define how developers and coding agents must execute every numbered development step.

## Applies app rules
- [`scope.md`](../app-rules/scope.md)
- [`project_structure.md`](../app-rules/project_structure.md)
- [`architecture.md`](../app-rules/architecture.md)
- [`checklists.md`](../app-rules/checklists.md)

## Required workflow for every step
1. Read the rule files referenced by the step.
2. Inspect the existing Flutter project before editing.
3. Keep correct existing files unchanged.
4. Patch incorrect, incomplete, duplicated, or non-compliant files.
5. Create missing files only when the step or rule set requires them.
6. Do not recreate working implementations under a new name.
7. Do not add product-specific features, real credentials, real backend assumptions, or unrelated requirements.
8. Run the smallest relevant validation command after the change when practical.
9. Record created files, modified files, and skipped files in the step notes or implementation summary.

## Minimal runnable starter target
By the end of the starter plan, the app must include:

- `main.dart` and `bootstrap.dart`.
- `MaterialApp.router` with `go_router`.
- Light, dark, and system theme mode.
- Generated localization readiness with English as the initial locale.
- A responsive shell that supports mobile, tablet, web, and desktop.
- Desktop menu bar, side navigation, and collapsible navigation state.
- A simple home route that runs without a backend.
- Baseline tests and quality commands.

## Non-recreation rule
When a file already satisfies the referenced rules, leave it in place and reference it. Improve it only if the step requires a missing capability, standardization, naming fix, portability fix, accessibility fix, or quality fix.

## Acceptance criteria
- Every numbered step can be executed independently without breaking previous steps.
- A coding agent can determine whether to reuse, patch, or create files.
- The final app remains minimal, portable, backend-agnostic, and runnable.
