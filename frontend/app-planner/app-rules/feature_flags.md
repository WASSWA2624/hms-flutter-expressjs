# Feature Flags

## Scope
Defines how optional or staged features are controlled.

## Mandatory rules
- Keep feature flags typed and centralized.
- Use safe defaults for missing flag values.
- Do not use feature flags to hide incomplete security rules.
- Do not leave dead flags permanently in the codebase.
- Avoid scattering raw flag string names through widgets.

## Implementation standard
- Feature flags may come from environment config, local config, or a backend service in product-specific apps.
- Flag checks should be testable through provider overrides.

## Acceptance checklist
- Disabled features do not appear in navigation or accessible routes unless intentionally allowed.
- Flag behavior is documented for release builds.

## Related rules
- [`environment_configuration.md`](./environment_configuration.md)
- [`navigation.md`](./navigation.md)
- [`testing.md`](./testing.md)
