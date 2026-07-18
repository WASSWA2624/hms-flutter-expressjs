# 04 - Folder Structure
Create a stable tree that makes every frontend responsibility easy to locate.

## Applicable Rules
You must follow [`00-execution-policy.md`](./00-execution-policy.md), [`project_structure.mdc`](../.cursor/project_structure.mdc), [`coding_conventions.mdc`](../.cursor/coding_conventions.mdc), [`testing.mdc`](../.cursor/testing.mdc), and [`documentation_standards.mdc`](../.cursor/documentation_standards.mdc).

## Implementation
1. Create the exact folders required by `project_structure.mdc`.
2. Mirror source folders under `test/` when corresponding tests are added.
3. Add `.gitkeep` only when an empty required directory must be retained.
4. Keep `l10n.yaml` at the frontend root and ARB files under `lib/l10n/`.
5. Summarize the folder tree in `README.md`.
6. Duplicate responsibility folders must not exist.

## Acceptance Criteria
- Startup, routing, theme, networking, storage, layout, and features must be quickly discoverable.
- The source, tests, documentation, assets, environments, and tools must follow one stable structure.
