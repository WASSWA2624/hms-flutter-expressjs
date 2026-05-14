# Code Generation Strategy

## Scope
Defines generated Dart code and maintenance rules.

## Approved generated code
- Immutable classes and unions through `freezed` where useful.
- JSON serialization through `json_serializable`.
- Riverpod providers through `riverpod_generator`.
- Drift database code through Drift tooling.
- Typed GoRouter routes only when the project adopts route generation consistently.

## Mandatory rules
- Do not edit generated files manually.
- Keep source files readable without opening generated files whenever possible.
- Run code generation before analysis, tests, and release builds.
- Keep generator versions compatible with Dart and Flutter SDK constraints.
- Do not hide business logic inside generated code.
- Commit generated files only if the project standard requires it; be consistent.

## Standard command
```bash
dart run build_runner build --delete-conflicting-outputs
```

## Acceptance checklist
- Generated files are current.
- CI fails when generated files are stale if the repository commits them.
- Source models remain readable and testable.

## Related rules
- [`dependencies.md`](./dependencies.md)
- [`data_modeling.md`](./data_modeling.md)
- [`ci_cd_quality_gates.md`](./ci_cd_quality_gates.md)
