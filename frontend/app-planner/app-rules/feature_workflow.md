# Feature Workflow

## Scope
Defines the repeatable process for adding a new feature to the template or an app built from it.

## Mandatory rules
- Start every feature by identifying its route, state, data needs, validation, localization, responsive behavior, and tests.
- Create the feature folder using the standard `data/domain/presentation` structure.
- Define domain models and repository contracts before wiring UI to real data sources when the flow is non-trivial.
- Add localization keys before adding user-facing text to widgets.
- Use shared components before creating feature-specific widgets.
- Add tests for controller logic, repository mapping, and important widgets.
- Update docs when the feature changes app structure or conventions.

## Implementation standard
- Small purely presentational features may omit use cases but must keep boundaries clear.
- Feature changes should be reviewable by files with focused responsibilities.

## Acceptance checklist
- The feature works at supported breakpoints.
- No architecture boundary is violated.
- Tests and localization are included.

## Related rules
- [`architecture.md`](./architecture.md)
- [`project_structure.md`](./project_structure.md)
- [`reusable_components.md`](./reusable_components.md)
- [`testing.md`](./testing.md)
- [`localization_i18n.md`](./localization_i18n.md)
