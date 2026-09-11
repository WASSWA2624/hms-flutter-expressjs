# 46 — Re-test Performance

**Source:** [fairbanks-fixes.md](../fairbanks-fixes.md) → Phase 13, Step 46
**Depends on:** 43, 44, 45
**Applies to:** development and production

## Context

Compare before and after for application startup, route changes, facility dialog opening, staff dialog opening, pharmacy, billing, reporting and analytics, and large tables, using the same method as the baseline so the numbers are comparable.

## Requirements

1. Re-run the step 43 measurement method unchanged: same devices, network profiles, dataset sizes, warm and cold states, and repetition counts.
2. Measure application startup, route changes, facility dialog opening, staff dialog opening, pharmacy flows, billing flows, reporting and analytics loading, and large table rendering.
3. Produce a before-and-after comparison per measured surface, including variance, and mark each as improved, unchanged, or regressed.
4. Investigate every regression and either fix it or document why it is acceptable, with sign-off.
5. Confirm no optimization changed behavior: run the authorization, tenant isolation, and scope tests from steps 07, 11, 12, and 31 and report their status.
6. Record the results in the performance document alongside the baseline, naming the commits compared.
7. State the remaining slowest surfaces and whether they are acceptable for release.
8. Complete the comparison in both development and production per **Rollout** below.

## Constraints

- Do not change the measurement method between baseline and re-test; a changed method invalidates the comparison.
- Do not accept an improvement that weakens isolation, authorization, financial integrity, clinical safety, auditability, or reporting accuracy.

## Acceptance Criteria

- [ ] **AC1 (R1, R2)** Every listed surface is re-measured with the unchanged method.
- [ ] **AC2 (R3)** The comparison shows before, after, variance, and a verdict per surface.
- [ ] **AC3 (R4)** Every regression is fixed or explicitly accepted with sign-off.
- [ ] **AC4 (R5)** Isolation, authorization, and scope test suites pass unchanged.
- [ ] **AC5 (R6, R7)** Results are recorded with the compared commits and a statement on remaining slow surfaces.
- [ ] **AC6 (R8)** Both environments are measured and compared.

## Verification

- Re-run of the step 43 instrumentation in both environments.
- `npm run test:backend` and `flutter test` including the isolation and authorization suites.
- Peer review of the comparison document.

## Rollout — Development and Production

- The comparison must cover both environments; production numbers are the ones that gate release.
- Config: restore any tracing or logging setting changed for measurement, in both `.env.development` and `.env.production`.
- Schema/data: record the dataset size and migration revision per environment for both baseline and re-test.
- Release: measure the deployed production build after `python deploy/deploy-backend.py` and `python deploy/deploy-frontend.py`, and record its commit.

## Relevant Files

- `backend/docs/performance-baseline.md` (extended with the comparison)
- `backend/src/middlewares/performance.middleware.js`
- `frontend/lib/core/logging/`, `frontend/lib/core/network/`
- `scripts/delivery-gate.ps1`, `scripts/delivery-gate.sh`
