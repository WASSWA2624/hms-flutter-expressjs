# Documentation Standards

## Scope
Defines required documentation for setup, architecture, decisions, components, and workflows.

## Mandatory rules
- Keep README setup instructions current.
- Document supported platforms and build commands.
- Document architecture, folder structure, state management, routing, localization, testing, and code generation commands.
- Use ADRs for major dependency or architecture decisions.
- Document non-obvious algorithms, provider contracts, and shared component APIs.
- Do not let documentation contradict app rules or dev-plan steps.

## Implementation standard
- Docs should be concise, actionable, and version-friendly.
- Every dev-plan file should state its goal, rule references, tasks, and acceptance criteria.

## Acceptance checklist
- A new developer can set up, run, test, and build the app using the docs.
- Architecture decisions can be traced to the relevant rules.

## Related rules
- [`checklists.md`](./checklists.md)
- [`feature_workflow.md`](./feature_workflow.md)
- [`ci_cd_quality_gates.md`](./ci_cd_quality_gates.md)
