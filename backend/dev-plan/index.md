# Backend Development Plan
Follow this chronology to produce the reproducible HOSSPI HMS backend.

## Execution Order

Phases must run without skipping: `P000_setup`, `P001_core`, `P002_prisma`, `P003_app`, `P004_i18n`, `P005_ws`, `P006_storage`, `P007_tests`, `P008_perf`, `P009_models`, `P010_api_endpoints`, `P011_modules`, `P012_seeder`, `P013_ws_features`, `P014_locales`, then `P015_offline`.

## Release Gates

- Each phase must satisfy its acceptance criteria before the next begins.
- Module names, permission keys, entitlements, and route families must remain aligned with `../../.cursor/app-write-up.mdc` and `../../.cursor/api-contract.mdc`.
- Implementations must preserve multi-role RBAC with ABAC, unit-manager roster authority, biomedical ownership, first-class Mortuary workflows, `snake_case`, documentation, and script hygiene.
- Existing broad module coverage may be reused, but it must converge on this plan and `backend/.cursor/*`.
