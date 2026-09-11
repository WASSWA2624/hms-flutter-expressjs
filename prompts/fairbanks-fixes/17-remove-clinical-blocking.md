# 17 — Remove Unnecessary Clinical Blocking

**Source:** [fairpanks-fixes.md](../fairpanks-fixes.md) → Phase 5, Step 17
**Depends on:** 13
**Applies to:** development and production

## Context

Clinical steps block each other more than patient flow requires — for example prescribing depending on triage completion. The governing principle: a clinical action may block another only when the dependency is genuinely necessary for clinical safety, regulatory compliance, data integrity, or a clearly required business rule.

## Requirements

1. Inventory every workflow dependency across consultation, prescription, laboratory, radiology, procedures, pharmacy, vital signs, clinical notes, diagnoses, referrals, follow-up, discharge, admission, and remaining clinical workflows, recording where each is enforced (`clinical-guard.middleware.js`, service rules, flow modules, or frontend action guards).
2. Classify each dependency as necessary (safety, compliance, data integrity, explicit business rule) or unnecessary, with a one-line justification for each decision.
3. Remove the unnecessary dependencies so the dependent action can proceed directly, while still recording that the prerequisite step was not completed.
4. Keep necessary dependencies and give each a specific, localized explanation in the API response and the UI.
5. Where a prerequisite is merely recommended, replace the hard block with a non-blocking prompt or warning that the clinician can proceed past.
6. Preserve data completeness: an action performed without its optional prerequisite must still produce a complete, auditable record.
7. Ensure the clinical queue, patient timeline, and flow status remain coherent when steps are performed out of the previous order.
8. Add tests proving each removed dependency no longer blocks and each retained dependency still does.
9. Ship the change to both development and production per **Rollout** below.

## Constraints

- Do not remove allergy checks, dose or interaction safety checks, controlled-substance rules, identity verification, or any regulatory control.
- Reuse the existing flow modules (`opd-flow`, `ipd-flow`, `theatre-flow`, `therapy-flow`) and shared clinical action helpers; do not fork the workflow engine.
- Backend remains authoritative; removing a frontend guard alone is not a fix.

## Acceptance Criteria

- [ ] **AC1 (R1, R2)** The dependency inventory lists every clinical block with its enforcement point, classification, and justification.
- [ ] **AC2 (R3)** Prescribing succeeds without prior triage, and each other removed dependency is demonstrably non-blocking.
- [ ] **AC3 (R4)** Each retained block returns and displays a specific, localized clinical reason.
- [ ] **AC4 (R5)** Recommended-but-optional prerequisites present a dismissible warning rather than a block.
- [ ] **AC5 (R6, R7)** Records created out of order remain complete and the queue, timeline, and flow status stay coherent.
- [ ] **AC6 (R8)** Tests cover removed and retained dependencies and pass.
- [ ] **AC7 (R9)** Behavior is identical in development and production after deployment.

## Verification

- `npm run test:backend`, `npm run lint` in `backend/`.
- `flutter analyze`, `flutter test` in `frontend/`.
- Manual: out-of-order clinical journeys (prescribe before triage, order labs before notes, discharge planning before final billing) in both environments.

## Rollout — Development and Production

- Behavior must be identical under `NODE_ENV=development` and `NODE_ENV=production`; clinical gating must not differ by environment.
- Config: document any tenant-configurable clinical rule in `backend/env.template.txt` or tenant settings with dev and prod guidance, and apply the same defaults in both.
- Schema/data: apply flow or status schema changes with `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host.
- Release: `python deploy/deploy-backend.py`, `python deploy/deploy-frontend.py`, and `python deploy/deploy-android.py`, then repeat the out-of-order journeys in production.

## Relevant Files

- `backend/src/middlewares/clinical-guard.middleware.js`
- `backend/src/modules/opd-flow/`, `ipd-flow/`, `theatre-flow/`, `therapy-flow/`, `triage/`, `triage-assessment/`, `encounter/`, `clinical-note/`, `vital-sign/`, `diagnosis/`, `referral/`, `follow-up/`, `discharge-summary/`, `admission/`
- `frontend/lib/shared/clinical_actions/`, `opd_actions/`, `ipd_actions/`, `workflow_actions/`, `patient_actions/`
- `frontend/lib/features/clinical/`, `opd/`, `ipd/`, `nursing/`
