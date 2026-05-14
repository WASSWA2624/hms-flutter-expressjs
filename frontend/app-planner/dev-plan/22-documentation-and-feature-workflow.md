# 22 - Documentation and feature workflow

## Goal
Finalize README, architecture docs, ADRs, and the repeatable feature workflow.

## Applies app rules
- [`documentation_standards.md`](../app-rules/documentation_standards.md)
- [`feature_workflow.md`](../app-rules/feature_workflow.md)
- [`checklists.md`](../app-rules/checklists.md)
- [`coding_conventions.md`](../app-rules/coding_conventions.md)

## Implementation tasks
1. Follow [`00-execution-policy.md`](./00-execution-policy.md).
2. Update `README.md` with purpose, platforms, setup, run, test, build, architecture, and folder structure.
3. Create or update `docs/architecture/`.
4. Add ADR template or initial ADRs for major choices.
5. Document the new feature workflow.
6. Ensure docs reference rule files instead of repeating long rule content.
7. Confirm docs match actual folders and commands.

## Expected output
- Complete README.
- Architecture docs.
- Feature workflow guide.
- ADR template or baseline ADRs.

## Acceptance criteria
- A new developer can set up and run the app using docs.
- Coding agents can follow the feature workflow consistently.
- Docs do not contradict app rules.
