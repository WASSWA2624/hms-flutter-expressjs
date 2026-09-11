# 31 — Implement Reporting Scope and Data Security

**Source:** [fairbanks-fixes.md](../fairbanks-fixes.md) → Phase 9, Step 31
**Depends on:** 12, 28
**Applies to:** development and production

## Context

Every report and analytic query must enforce the authorized scope of the requester automatically: tenant administrator sees tenant-wide data, facility administrator sees facility data, department user sees department data, service user sees authorized service data. No frontend filter or URL parameter may widen that scope.

## Requirements

1. Apply scope resolution from step 12 inside the reporting query layer so every query is scoped before any filter from the request is applied.
2. Treat request filters as narrowing only: a filter value outside the resolved scope must be rejected or ignored, never honored, and the response must state which happened.
3. Enforce the same scope for aggregates, counts, charts, drill-downs, scheduled runs, and exports, so no summary leaks data the detail view would hide.
4. Prevent identifier probing: a report requested for an out-of-scope facility, department, patient, or staff member must not reveal existence or counts.
5. Ensure scheduled and background report runs execute with the authorization of their owner, re-resolved at run time, not with elevated system rights.
6. Log report access for sensitive reports with actor, scope, filters, and timestamp, feeding the audit work in step 49.
7. Add backend tests attempting scope widening through every documented parameter, through export, and through a scheduled run.
8. Ship the change to both development and production per **Rollout** below.

## Constraints

- Reuse the ABAC policy and tenant scope middleware; do not implement report-specific authorization rules that can drift.
- No report query may accept a raw tenant, facility, or department identifier from the client without validating it against the resolved scope.
- Failures must use the standard response contract and must not disclose out-of-scope existence.

## Acceptance Criteria

- [ ] **AC1 (R1, R2)** Every report query is scoped before request filters, and out-of-scope filter values never widen results.
- [ ] **AC2 (R3)** Aggregates, charts, drill-downs, scheduled runs, and exports return the same scoped data set.
- [ ] **AC3 (R4)** Out-of-scope identifier probes reveal nothing about existence or counts.
- [ ] **AC4 (R5)** A scheduled report run produces exactly what its owner would see interactively at run time.
- [ ] **AC5 (R6)** Sensitive report access is logged with full context.
- [ ] **AC6 (R7)** Scope-widening tests pass and fail when the guard is deliberately removed.
- [ ] **AC7 (R8)** Enforcement is identical in development and production.

## Verification

- `npm run test:backend`, `npm run lint`, `npm run openapi:validate` in `backend/`.
- Manual: authenticated API probes with tenant, facility, department, and service tokens against both environments, including export endpoints.

## Rollout — Development and Production

- Enforcement must be identical under `NODE_ENV=development` and `NODE_ENV=production`; no environment may relax scope checks.
- Config: document any reporting cache or scheduler key in `backend/env.template.txt` with dev and prod guidance and set it in both env files; caches must be keyed by scope so no cached result crosses scopes.
- Schema/data: apply any scope or audit schema changes with `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host.
- Release: `python deploy/deploy-backend.py` and `python deploy/deploy-frontend.py`, then re-run the probe set against `https://api.hosspi.com`.

## Relevant Files

- `backend/src/modules/reports-workspace/`, `report-definition/`, `report-run/`, `report-schedule/`, `kpi-snapshot/`
- `backend/src/middlewares/abac.middleware.js`, `tenant-scope.middleware.js`, `request-context.middleware.js`
- `backend/src/modules/phi-access-log/`, `audit-log/`
- `frontend/lib/features/reports/presentation/reports_access.dart`
