# 02 - Dependencies and Tooling
Configure only the dependencies and tools needed by the runnable starter.

## Applicable Rules
You must follow [`00-execution-policy.md`](./00-execution-policy.md), [`dependencies.mdc`](../.cursor/dependencies.mdc), [`code_generation.mdc`](../.cursor/code_generation.mdc), [`coding_conventions.mdc`](../.cursor/coding_conventions.mdc), and [`ci_cd_quality_gates.mdc`](../.cursor/ci_cd_quality_gates.mdc).

## Implementation
1. Add `flutter_riverpod`, `go_router`, Flutter localization SDK support, and `intl`.
2. Optional packages must be added only when an implemented capability needs them; packages must not duplicate responsibilities.
3. Configure Flutter lints and Riverpod lint readiness in `analysis_options.yaml`.
4. Add generation tooling only when providers, models, JSON, or Drift are generated.
5. Document format, analyze, test, and generation commands in `README.md`.

## Acceptance Criteria
- `flutter pub get` must succeed.
- Dependency choices must match `dependencies.mdc`.
- The starter must contain no unused optional dependency.
