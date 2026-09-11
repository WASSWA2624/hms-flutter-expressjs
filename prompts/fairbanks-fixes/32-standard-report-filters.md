# 32 — Implement Standard Reporting Dimensions

**Source:** [fairpanks-fixes.md](../fairpanks-fixes.md) → Phase 9, Step 32
**Depends on:** 30, 31
**Applies to:** development and production

## Context

Reports should share a consistent filter vocabulary — date range, tenant, facility, department, staff, service, patient, status, payment method, category, supplier, and other relevant dimensions — and combinations must not produce contradictory results.

## Requirements

1. Define a shared filter model with one canonical definition per dimension, including value type, source of options, and scope dependency.
2. Declare per report which dimensions it supports, and render only those, sourcing options from scope-filtered endpoints.
3. Make filter combinations consistent: dependent dimensions narrow their options (facility narrows department, department narrows staff) and an invalid combination is prevented rather than silently returning an empty or wrong result.
4. Standardize date-range handling: named presets, explicit custom ranges, inclusive boundary rules, and a single timezone rule applied identically on backend and frontend.
5. Apply the same filter semantics to the on-screen report, its drill-downs, its scheduled runs, and its exports so all four agree for identical inputs.
6. Persist the active filter set within the session so navigating between reports in a tab does not discard a user selection where it still applies.
7. Validate filters on the backend and reject unknown or out-of-scope dimensions using the standard response contract.
8. Add backend tests for filter validation, dependency narrowing, boundary and timezone handling, and combination consistency; add frontend tests for the shared filter component states.
9. Ship the change to both development and production per **Rollout** below.

## Constraints

- Reuse the shared filter dialog and reporting components; do not build per-report filter widgets.
- Filters narrow within the resolved scope only, per step 31.
- Follow `prompts/.cursor/forms.mdc`, `dialogs.mdc`, and `localization.mdc`.

## Acceptance Criteria

- [ ] **AC1 (R1, R2)** Every report declares its dimensions and renders only those, with scope-filtered options.
- [ ] **AC2 (R3)** Dependent dimensions narrow correctly and invalid combinations are prevented.
- [ ] **AC3 (R4)** Date ranges, boundaries, and timezone handling produce identical results across backend and frontend.
- [ ] **AC4 (R5)** Screen, drill-down, scheduled run, and export agree for the same filter set.
- [ ] **AC5 (R6)** Filter selections persist across reports within a tab where applicable.
- [ ] **AC6 (R7)** Unknown or out-of-scope dimensions are rejected with the standard contract.
- [ ] **AC7 (R8)** New backend and frontend tests pass.
- [ ] **AC8 (R9)** Filters behave identically in development and production.

## Verification

- `npm run test:backend`, `npm run lint`, `npm run openapi:validate` in `backend/`.
- `flutter analyze`, `flutter test` in `frontend/`.
- Manual: apply at least five filter combinations per tab in each environment and reconcile against raw data.

## Rollout — Development and Production

- Behavior must be identical under `NODE_ENV=development` and `NODE_ENV=production`, including timezone handling; production must not rely on a different server timezone than the documented rule.
- Config: document the reporting timezone and any default range key in `backend/env.template.txt` with dev and prod guidance, set it in both env files, and mirror client-visible values in both `frontend/env` example files.
- Schema/data: add supporting indexes with `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host.
- Release: `python deploy/deploy-backend.py`, `python deploy/deploy-frontend.py`, and `python deploy/deploy-android.py`, then reconcile a filtered report in production.

## Relevant Files

- `backend/src/modules/report-definition/`, `reports-workspace/`, `report-run/`
- `frontend/lib/features/reports/presentation/widgets/pharmacy_reporting_filters_dialog.dart` and sibling filter widgets
- `frontend/lib/shared/reporting/`, `frontend/lib/shared/forms/`
- `frontend/lib/core/utils/`
