# 47 — Test Complete Facility Journeys

**Source:** [fairpanks-fixes.md](../fairpanks-fixes.md) → Phase 14, Step 47
**Depends on:** 01–46
**Applies to:** development and production

## Context

Features must be proven together, not only in isolation. Each journey below must complete end to end, in both environments, with data, permissions, billing, and printouts correct at every step.

## Requirements

1. **New facility:** `Create Tenant → Create Facility → Configure Presets → Create Users → Assign Roles → Login`, ending with zero operational records per step 05.
2. **Consultation:** `Login → Patient → Consultation → Payment or Pending → Complete`, including the pending-payment path from step 13.
3. **Pharmacy:** `Prescription → Pharmacy → Dispensing → Payment → Receipt`, using the simplified journey from step 25 and a structured drug strength from step 26.
4. **Laboratory:** `Order → Payment or Pending → Sample → Result → Completion`.
5. **Refund:** `Transaction → Refund Request → Approval → Refund`, including an unauthorized approval attempt that is denied.
6. **Staff:** `Create Staff → Assign Role → Login → Perform Activity → Receive Payment`, exercising the permission from step 15.
7. **Reporting:** `Login → Resolve Roles/Permissions → Resolve Scope → Display Authorized Analytics Tabs → Filter → View Report → Export`.
8. Automate each journey where the existing integration or Patrol test infrastructure supports it, and script the remainder as a repeatable manual checklist with expected results per step.
9. Assert cross-cutting invariants within every journey: tenant isolation, scope enforcement, audit entries written, payment status correctness, and printout correctness.
10. Record results per journey per environment, with defects linked back to the step that owns them.
11. Run every journey in both development and production per **Rollout** below.

## Constraints

- Do not stub backend behavior in the automated journeys; they must exercise the real API.
- Production runs must use disposable tenants and test patients, cleaned up afterwards with a logged removal.
- A journey that requires a manual workaround has not passed.

## Acceptance Criteria

- [ ] **AC1 (R1–R7)** Every journey completes with the expected end state in both environments.
- [ ] **AC2 (R8)** Automated journeys run in CI or by a single documented command; manual checklists list expected results per step.
- [ ] **AC3 (R9)** Isolation, scope, audit, payment status, and printout assertions hold inside every journey.
- [ ] **AC4 (R5)** The unauthorized refund approval attempt is denied by the API.
- [ ] **AC5 (R10)** Results and defects are recorded and linked to their owning step.
- [ ] **AC6 (R11)** Production runs are completed and their test data removed.

## Verification

- `frontend/integration_test/` and `frontend/patrol_test/` suites, run via `frontend/tool/run_patrol_tests.ps1`.
- `npm run test:backend:integration` in `backend/`.
- `pwsh scripts/delivery-gate.ps1` for the full gate.

## Rollout — Development and Production

- Every journey must pass in both environments; a development-only pass does not satisfy this step.
- Config: confirm `.env.development` and `.env.production` are aligned on every key introduced in steps 01–46 and documented in `backend/env.template.txt`.
- Schema/data: confirm both databases are at the same migration revision before the runs.
- Release: `python deploy/deploy-backend.py`, `python deploy/deploy-frontend.py`, and `python deploy/deploy-android.py` before the production runs, then execute the journeys against `https://app.hosspi.com` and `https://api.hosspi.com`.

## Relevant Files

- `frontend/integration_test/`, `frontend/patrol_test/`, `frontend/tool/run_patrol_tests.ps1`
- `backend/src/tests/`, `backend/scripts/verify-onboarding-e2e.js`
- `scripts/delivery-gate.ps1`, `scripts/delivery-gate.sh`
- `deploy/deploy-backend.py`, `deploy/deploy-frontend.py`, `deploy/deploy-android.py`
