# 20 - Testing readiness

## Goal
Add unit, widget, and integration test foundations.

## Applies app rules
- [`testing.md`](../app-rules/testing.md)
- [`ci_cd_quality_gates.md`](../app-rules/ci_cd_quality_gates.md)
- [`state_management.md`](../app-rules/state_management.md)
- [`responsive_adaptive_design.md`](../app-rules/responsive_adaptive_design.md)

## Implementation tasks
1. Follow [`00-execution-policy.md`](./00-execution-policy.md).
2. Create test helper utilities for app setup and provider overrides.
3. Add tests for validators, mappers, responsive utilities, theme, and shared components.
4. Add shell tests for mobile and desktop layout decisions.
5. Add integration startup/navigation smoke test when host tooling supports it.
6. Document test commands.

## Expected output
- Test helpers.
- Baseline unit/widget/integration tests.
- Documented test commands.

## Acceptance criteria
- `flutter test` passes.
- Tests do not require production services.
- Important shared UI and responsive behavior have tests.
