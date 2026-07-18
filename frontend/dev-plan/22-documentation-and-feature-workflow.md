# 22 - Documentation and Feature Workflow
Keep setup, architecture, decisions, and feature delivery accurate and repeatable.

## Applicable Rules
You must follow [`00-execution-policy.md`](./00-execution-policy.md), [`documentation_standards.mdc`](../.cursor/documentation_standards.mdc), [`feature_workflow.mdc`](../.cursor/feature_workflow.mdc), [`checklists.mdc`](../.cursor/checklists.mdc), and [`coding_conventions.mdc`](../.cursor/coding_conventions.mdc).

## Implementation
1. Update `README.md` with purpose, platforms, setup, run, test, build, architecture, and folder structure.
2. Create or update `docs/architecture/`.
3. Add an ADR template or baseline ADRs for major decisions.
4. Document the new-feature workflow.
5. Documentation should link to rules instead of duplicating lengthy requirements.
6. Documentation must match actual folders and commands.

## Acceptance Criteria
- A new developer must be able to set up and run the app from documentation.
- Coding agents must be able to repeat the feature workflow.
- Documentation must not contradict app rules.
- README, architecture docs, workflow guidance, and ADR support must exist.
