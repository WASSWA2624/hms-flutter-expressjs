# Documentation

This directory holds setup notes, architecture references, and decisions for the
Flutter template.

- `architecture/` explains the structure and major app boundaries.
  - `app-architecture.md` documents dependency direction, layer boundaries, and
    provider placement.
  - `performance-and-scalability.md` documents rebuild, list pagination,
    startup, and release-readiness checks.
  - `project-structure.md` documents the canonical repository layout.
- `decisions/` records architecture decisions that affect future work.
  - `0000-template.md` is the ADR template for major dependency and
    architecture decisions.
  - `0001-project-setup.md` records the initial Flutter template scaffold.
  - `0002-storage-and-offline-sync-foundation.md` documents Drift,
    preferences, secure storage, sync queue, and conflict boundaries.
  - `0003-auth-session-security-and-permissions.md` documents session,
    protected route, and permission boundaries.
- `setup/` contains local development and platform setup notes.
  - `development.md` documents local prerequisites, first run, tests, and
    platform notes.
  - `environment.md` documents required public runtime configuration values.
  - `platform-behavior.md` documents safe areas, keyboard input,
    accessibility, and platform limitations.
- `release/` contains CI, build, versioning, and release readiness notes.
  - `build-ci-release.md` documents local quality gates, CI checks, platform
    release commands, and the release checklist.
- `workflows/` contains repeatable development workflows.
  - `feature-workflow.md` documents the standard route, state, data,
    localization, responsive, testing, and documentation process for new
    features.

Rule sources for documentation:

- [`app-rules/documentation_standards.md`](../app-planner/app-rules/documentation_standards.md)
- [`app-rules/feature_workflow.md`](../app-planner/app-rules/feature_workflow.md)
- [`app-rules/checklists.md`](../app-planner/app-rules/checklists.md)
- [`app-rules/coding_conventions.md`](../app-planner/app-rules/coding_conventions.md)
