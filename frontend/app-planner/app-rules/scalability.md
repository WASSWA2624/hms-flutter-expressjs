# Scalability Strategy

## Scope
Defines how the template remains maintainable as more features, platforms, and teams are added.

## Mandatory rules
- Keep features independent and feature-first.
- Keep cross-cutting services in `core` only when multiple features use them.
- Keep shared UI generic and business-free.
- Keep public feature exports intentional.
- Avoid global mutable state.
- Use clear contracts between layers.
- Document architecture decisions that affect future development.
- Avoid copying whole screens to support new layouts.

## Scaling patterns
| Problem | Required pattern |
|---|---|
| many features | feature-first modules |
| many screens | route groups and shell routes |
| many data records | pagination, streams, local indexes |
| many UI variants | theme tokens and component composition |
| many developers | rules, linting, tests, PR checklist |

## Acceptance checklist
- Adding a new feature does not require modifying unrelated features.
- Shared components do not become product-specific dumping grounds.
- Architecture boundaries remain enforceable by review and tests.

## Related rules
- [`architecture.md`](./architecture.md)
- [`project_structure.md`](./project_structure.md)
- [`feature_workflow.md`](./feature_workflow.md)
- [`performance.md`](./performance.md)
