# 50 — Full Regression Test and Release Gate

**Source:** [fairpanks-fixes.md](../fairpanks-fixes.md) → Phase 15, Step 50 and Final Release Gate
**Depends on:** 01–49
**Applies to:** development and production

## Context

The final pass covers the whole application and closes the release gate: `Correctness → Data Isolation → Authorization → Workflow Integrity → Reporting/Analytics → Performance → Security → Regression`.

## Requirements

1. Regression-test authentication, registration, persistent sessions, tenant creation, tenant isolation, facility creation, patient management, clinical workflows, pharmacy, laboratory, radiology, theatre, billing, payments, waivers, refunds, reporting, analytics, printing, PDF generation, staff management, roles and permissions, Excel import and export, communication, security, and audit trails.
2. Produce a regression checklist mapping every area to the steps that changed it and the tests that cover it, so an untested change is visible.
3. Run the complete automated suite: backend unit and integration tests, frontend analysis and tests, integration and Patrol journeys, OpenAPI validation, and locale checks.
4. Re-run the gating verifications from steps 07, 31, 46, 48, and 49 and attach their results.
5. Confirm no regression in performance against the step 46 numbers.
6. Record every defect found with severity, owning step, and resolution, and re-test each fix.
7. Confirm the final release gate explicitly: correctness, data isolation, authorization, workflow integrity, reporting and analytics accuracy, performance, security, and regression each signed off.
8. Confirm that no optimization or UI change compromised tenant isolation, authorization, financial integrity, clinical safety, auditability, or reporting accuracy.
9. Complete the regression in both development and production per **Rollout** below.

## Constraints

- Release is blocked while any gate item is unsigned or any high-severity defect is open.
- Production testing uses disposable tenants and test data, removed afterwards with a logged cleanup.
- Do not relax a test or a guard to close the gate.

## Acceptance Criteria

- [ ] **AC1 (R1, R2)** Every listed area is covered by the checklist and exercised, with no untested change.
- [ ] **AC2 (R3)** `pwsh scripts/delivery-gate.ps1` passes, along with the integration and journey suites.
- [ ] **AC3 (R4)** Isolation, reporting scope, performance, authorization, and audit verifications pass and are attached.
- [ ] **AC4 (R5)** Performance matches or improves on the step 46 numbers.
- [ ] **AC5 (R6)** Every defect is recorded, resolved or explicitly deferred with sign-off, and re-tested.
- [ ] **AC6 (R7, R8)** All eight gate items are signed off, with an explicit statement that no change compromised the protected properties.
- [ ] **AC7 (R9)** The regression passes in development and in production.

## Verification

- `pwsh scripts/delivery-gate.ps1` (frontend format, analyze, test; backend lint, delivery contract, OpenAPI validation).
- `npm run test:backend`, `npm run test:backend:integration`, `npm run i18n:check` in `backend/`.
- `frontend/tool/run_patrol_tests.ps1` and the `frontend/integration_test/` suite.
- Production smoke of every journey from step 47.

## Rollout — Development and Production

- The regression must pass in both environments; production is the gating environment for release.
- Config: perform a final parity review of `.env.development`, `.env.production`, `backend/env.template.txt`, `frontend/env/development.json.example`, and `frontend/env/production.json.example`, confirming every key added in steps 01–49 exists with correct per-environment values.
- Schema/data: confirm both databases are at the same migration revision, every backfill has run in both, and production has a verified backup before the final deployment.
- Release: `python deploy/deploy-backend.py`, `python deploy/deploy-frontend.py`, and `python deploy/deploy-android.py`, then run the production smoke and record the released commit in the gate sign-off.

## Relevant Files

- `scripts/delivery-gate.ps1`, `scripts/delivery-gate.sh`
- `backend/src/tests/`, `frontend/test/`, `frontend/integration_test/`, `frontend/patrol_test/`
- `deploy/README.md`, `deploy/deploy-backend.py`, `deploy/deploy-frontend.py`, `deploy/deploy-android.py`
- `backend/docs/` (verification documents from steps 04, 07, 35, 43, 48, 49)
- `prompts/fairpanks-fixes/progress-tracker.md`
