# 23 - Final validation checklist

## Goal
Validate the whole starter against all rules and the execution policy.

## Applies app rules
- [`checklists.md`](../app-rules/checklists.md)
- [`validation_report.md`](../app-rules/validation_report.md)
- [`scope.md`](../app-rules/scope.md)
- [`ci_cd_quality_gates.md`](../app-rules/ci_cd_quality_gates.md)

## Implementation tasks
1. Follow [`00-execution-policy.md`](./00-execution-policy.md).
2. Read every rule file and confirm there are no contradictions.
3. Confirm every dev-plan file references relevant rules.
4. Run final quality commands:
   ```bash
   flutter pub get
   dart format --set-exit-if-changed .
   flutter analyze
   flutter test
   ```
5. Run code generation first when generated files are used.
6. Validate supported screen-size behavior, including `320px` mobile and large desktop widths.
7. Validate desktop menu bar, side navigation, and collapsed navigation behavior.
8. Confirm the starter remains backend-agnostic and reusable.
9. Update `app-rules/validation_report.md` with actual results from the generated project.

## Expected output
- Updated validation report.
- Final checklist results.
- Ready-to-use Flutter starter.

## Acceptance criteria
- A developer can follow `00` through `23` in order.
- The result is a working reusable Flutter foundation.
- Architecture, UI behavior, and conventions are deterministic.
