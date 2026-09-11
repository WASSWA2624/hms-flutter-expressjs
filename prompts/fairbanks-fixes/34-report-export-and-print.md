# 34 — Implement Report Export and Print Integration

**Source:** [fairbanks-fixes.md](../fairbanks-fixes.md) → Phase 9, Step 34
**Depends on:** 31, 32, 33
**Applies to:** development and production

## Context

Reports must be viewable on screen, printable, and exportable to PDF and Excel or CSV, with exports honoring exactly the same permissions, tenant and facility boundaries, filters, and scope as the on-screen report.

## Requirements

1. Add export and print actions to every report that is authorized for the requester, using the shared printing and export components.
2. Generate exports on the backend from the same scoped query as the on-screen report, so filters, totals, and row sets match exactly.
3. Enforce permission, tenant, facility, and scope checks on every export endpoint, independently of the UI, per step 31.
4. Produce readable PDF output that respects the print rules, including headers, facility identity, filter summary, pagination, and page breaks.
5. Produce Excel or CSV output with typed columns, a header row, a filter summary sheet or header block, and encoding that opens correctly in common spreadsheet software.
6. Handle large exports without blocking the UI or timing out: stream or queue with progress feedback, and a defined limit with a clear message when exceeded.
7. Record every export in the audit trail with actor, report, filters, scope, row count, format, and timestamp.
8. Add backend tests proving export content equals on-screen content for identical filters, plus authorization tests for export endpoints; add frontend tests for the export and print action states.
9. Ship the change to both development and production per **Rollout** below.

## Constraints

- Never generate an export client-side from partially loaded data.
- Reuse `frontend/lib/shared/printing/` and the existing print helpers; follow `prompts/.cursor/printing.mdc`.
- Exported files must not contain data the user could not see on screen.

## Acceptance Criteria

- [ ] **AC1 (R1, R2)** Export and print are available on every authorized report, and exported content matches the on-screen result exactly for identical filters.
- [ ] **AC2 (R3)** An unauthorized or out-of-scope export request is denied at the API.
- [ ] **AC3 (R4)** PDF output is legible and correctly paginated, with facility identity and a filter summary.
- [ ] **AC4 (R5)** Spreadsheet output opens cleanly with correct types, headers, and encoding.
- [ ] **AC5 (R6)** A large export completes or fails gracefully with progress feedback and a clear limit message.
- [ ] **AC6 (R7)** Every export appears in the audit trail with full context.
- [ ] **AC7 (R8)** New backend and frontend tests pass.
- [ ] **AC8 (R9)** Export and print behave identically in development and production.

## Verification

- `npm run test:backend`, `npm run lint`, `npm run openapi:validate` in `backend/`.
- `flutter analyze`, `flutter test` in `frontend/`.
- Manual: export and print at least one report per tab in each environment, including a large data set.

## Rollout — Development and Production

- Behavior must be identical under `NODE_ENV=development` and `NODE_ENV=production`.
- Config: document export size limits, temporary storage paths, and queue or timeout keys in `backend/env.template.txt` with dev and prod guidance and set them in both env files; confirm the production host has writable temporary storage and sufficient limits.
- Schema/data: apply export-audit schema changes with `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host.
- Release: `python deploy/deploy-backend.py`, `python deploy/deploy-frontend.py`, and `python deploy/deploy-android.py`, then repeat the export and print checks in production, including PDF rendering in the deployed web build.

## Relevant Files

- `backend/src/modules/report-run/`, `reports-workspace/`, `report-definition/`, `audit-log/`
- `frontend/lib/shared/printing/`, `frontend/lib/shared/printing/templates/`, `frontend/lib/core/platform/app_print*.dart`
- `frontend/lib/features/reports/presentation/widgets/reports_workspace_print_helpers.dart`, `reports_workspace_table_helpers.dart`
