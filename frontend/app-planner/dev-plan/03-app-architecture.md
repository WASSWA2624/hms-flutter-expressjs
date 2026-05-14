# 03 - App architecture

## Goal
Implement the feature-first clean architecture foundation and dependency boundaries.

## Applies app rules
- [`architecture.md`](../app-rules/architecture.md)
- [`project_structure.md`](../app-rules/project_structure.md)
- [`state_management.md`](../app-rules/state_management.md)
- [`data_modeling.md`](../app-rules/data_modeling.md)

## Implementation tasks
1. Follow [`00-execution-policy.md`](./00-execution-policy.md).
2. Create or normalize `app`, `core`, `features`, `l10n`, and `shared` folders.
3. Add a minimal `home` feature only as the runnable starter screen.
4. Add domain/data/presentation subfolders only when a feature needs those layers.
5. Document dependency direction in `docs/architecture/`.
6. Ensure examples do not allow widgets to call APIs, databases, or storage directly.

## Expected output
- Canonical architecture folders.
- Minimal home feature or equivalent starter route.
- Architecture documentation.

## Acceptance criteria
- Widgets do not call APIs or storage directly.
- Domain code does not depend on Flutter widgets.
- Feature boundaries are clear and testable.
