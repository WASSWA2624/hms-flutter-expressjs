# Testing Strategy

## Scope
Defines the minimum testing structure for the reusable app foundation.

## Mandatory rules
- Use `flutter_test` for unit and widget tests.
- Use `integration_test` for startup, navigation, and important flows.
- Use `mocktail` or provider overrides for repository/data-source tests.
- Keep tests close to source structure where practical.
- Test controllers, value objects, mappers, validators, and shared components.
- Test responsive behavior for important shared layouts and page shells.
- Tests must not depend on real production services.
- Tests must not require secrets.

## Test types
| Test type | Target |
|---|---|
| Unit | validators, mappers, use cases, value objects |
| Widget | components, pages, responsive layout, forms |
| Integration | startup, routing, auth shell, platform-critical flows |
| Golden | optional, for stable shared UI only |

## Acceptance checklist
- `flutter test` passes.
- Important components have widget tests.
- Providers can be overridden in tests.
- Responsive layout utilities have tests.

## Related rules
- [`ci_cd_quality_gates.md`](./ci_cd_quality_gates.md)
- [`state_management.md`](./state_management.md)
- [`reusable_components.md`](./reusable_components.md)
- [`responsive_adaptive_design.md`](./responsive_adaptive_design.md)
