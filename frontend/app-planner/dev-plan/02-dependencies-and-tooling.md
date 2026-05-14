# 02 - Dependencies and tooling

## Goal
Add the approved starter dependency stack and configure linting, generation readiness, and test tooling.

## Applies app rules
- [`dependencies.md`](../app-rules/dependencies.md)
- [`code_generation.md`](../app-rules/code_generation.md)
- [`coding_conventions.md`](../app-rules/coding_conventions.md)
- [`ci_cd_quality_gates.md`](../app-rules/ci_cd_quality_gates.md)

## Implementation tasks
1. Follow [`00-execution-policy.md`](./00-execution-policy.md).
2. Add required starter dependencies only: `flutter_riverpod`, `go_router`, Flutter localization SDK support, and `intl`.
3. Add approved optional dependencies only when later steps actually implement that capability.
4. Configure `analysis_options.yaml` with Flutter lints and Riverpod lint readiness.
5. Add code-generation tooling only if generated providers, models, JSON, or Drift are used.
6. Document local quality commands in `README.md`.

## Expected output
- Minimal `pubspec.yaml` with no duplicate package responsibilities.
- Analyzer/lint configuration.
- Documented format, analyze, test, and generation commands.

## Acceptance criteria
- `flutter pub get` succeeds.
- Dependency choices match `dependencies.md`.
- No unused optional dependency is added to the starter.
