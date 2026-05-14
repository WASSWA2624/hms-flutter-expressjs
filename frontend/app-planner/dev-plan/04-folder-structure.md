# 04 - Folder structure

## Goal
Finalize concrete source, test, docs, assets, environment, and tooling folders.

## Applies app rules
- [`project_structure.md`](../app-rules/project_structure.md)
- [`coding_conventions.md`](../app-rules/coding_conventions.md)
- [`testing.md`](../app-rules/testing.md)
- [`documentation_standards.md`](../app-rules/documentation_standards.md)

## Implementation tasks
1. Follow [`00-execution-policy.md`](./00-execution-policy.md).
2. Create the exact folders required by `project_structure.md`.
3. Mirror source folders in `test/` when tests are added.
4. Add `.gitkeep` only where an empty required folder must be retained.
5. Keep `l10n.yaml` at the project root and ARB files under `lib/l10n/`.
6. Update `README.md` with a short folder summary.

## Expected output
- Stable folder tree.
- Matching test folders where useful.
- Updated documentation.

## Acceptance criteria
- A developer can find startup, routing, theme, networking, storage, layout, and features quickly.
- No duplicate responsibility folders exist.
