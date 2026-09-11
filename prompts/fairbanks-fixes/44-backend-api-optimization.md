# 44 — Optimize the Backend and API

**Source:** [fairbanks-fixes.md](../fairbanks-fixes.md) → Phase 13, Step 44
**Depends on:** 43
**Applies to:** development and production

## Context

With the baseline from step 43 in hand, address the backend causes of slowness: duplicate calls, N+1 queries, missing indexes, oversized responses, unnecessary joins, repeated configuration queries, expensive report queries, and inefficient pagination.

## Requirements

1. Eliminate duplicate API calls caused by the backend contract, such as endpoints that force the client to fetch related data separately when one scoped response would serve.
2. Fix N+1 query patterns in the highest-impact endpoints from the baseline, using batched or included queries within the existing repository layer.
3. Add the indexes the captured query plans justify, and verify each one changes the plan as expected on production-like data volumes.
4. Reduce oversized responses by returning only the fields the client uses, with explicit projections instead of full entity serialization.
5. Remove unnecessary joins and redundant lookups, especially configuration and permission data fetched repeatedly per request.
6. Cache stable configuration, permission catalog, and preset data per request and, where safe, across requests with a scope-aware key and an explicit invalidation rule.
7. Fix inefficient pagination: keyset or indexed pagination for large lists, and a bounded maximum page size on every list endpoint.
8. Optimize the heaviest report and analytics queries, honoring the scope enforcement from step 31 with no shortcut that weakens it.
9. Re-measure each optimized endpoint against the baseline and record the before and after numbers.
10. Ship the change to both development and production per **Rollout** below.

## Constraints

- No optimization may weaken tenant isolation, scope enforcement, authorization, financial integrity, or auditability.
- Caches must be keyed by tenant and scope, with a documented invalidation rule; a cached value must never cross a scope boundary.
- Preserve the existing response contract unless a change is documented and the client is updated in the same release.

## Acceptance Criteria

- [ ] **AC1 (R1–R7)** Each listed problem class is addressed for the endpoints ranked highest in the baseline.
- [ ] **AC2 (R3)** Every added index is justified by a captured plan and verified on production-like volumes.
- [ ] **AC3 (R6)** Caches are scope-keyed, and a cross-scope cache-leak test passes.
- [ ] **AC4 (R8)** Report queries are faster with scope enforcement intact, verified by the step 31 tests.
- [ ] **AC5 (R9)** Before and after numbers are recorded for every optimized endpoint.
- [ ] **AC6** The full backend test suite passes with no contract regressions.
- [ ] **AC7 (R10)** Improvements are confirmed in both development and production measurements.

## Verification

- `npm run lint`, `npm run test:backend`, `npm run openapi:validate` in `backend/`.
- Query plan comparison before and after for each indexed query.
- Re-run of the step 43 measurement method on the affected endpoints in both environments.

## Rollout — Development and Production

- Behavior must be identical under `NODE_ENV=development` and `NODE_ENV=production`; no optimization may be enabled only in one environment.
- Config: document cache TTLs, page-size limits, and pool sizes in `backend/env.template.txt` with dev and prod guidance and set them in both env files, with production values sized for the deployed host.
- Schema/data: create indexes with `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host, scheduling large index builds to avoid production disruption.
- Release: `python deploy/deploy-backend.py`, then re-measure the optimized endpoints against `https://api.hosspi.com`.

## Relevant Files

- `backend/src/modules/**/repositories/`, `backend/src/modules/**/services/`
- `backend/prisma/schema.prisma`, `backend/prisma/migrations/`
- `backend/src/middlewares/performance.middleware.js`, `backend/src/lib/`
- `backend/docs/performance-baseline.md`
