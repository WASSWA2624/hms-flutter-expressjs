# 26 — Implement Flexible Drug Strength

**Source:** [fairbanks-fixes.md](../fairbanks-fixes.md) → Phase 8, Step 26
**Depends on:** 06
**Applies to:** development and production

## Context

Create Drug stores strength as a single uncontrolled text field, which cannot express combination products such as `Amoxicillin 500 mg + Clavulanic Acid 125 mg` and cannot be validated or searched reliably. Strength must become structured and extensible while preserving the original formulation exactly.

## Requirements

1. Model strength as a structured list of components, each with an active ingredient, a numeric value, a unit, and an optional denominator (value and unit) for concentrations such as mg per 5 mL.
2. Support a single component, multiple components, ratios and concentrations, and unit systems already used by the formulary, with an extensible structure for future formulations.
3. Validate units against the existing unit master data, validate numeric ranges, and reject inconsistent combinations with localized messages.
4. Render a canonical display string from the structured data so existing screens, prescriptions, labels, and printouts show a consistent, human-readable strength.
5. Preserve the original formulation accurately: migration must not round, truncate, reorder, or lose any part of an existing strength value.
6. Migrate existing free-text strengths by parsing what is unambiguous, keeping the original text alongside the structured value, and flagging unparsed entries for manual review rather than guessing.
7. Provide entry assistance in the create and edit drug form: unit suggestions, common strength suggestions, component add and remove, and immediate preview of the canonical display.
8. Keep search, prescribing, dispensing, stock, and reporting working against the new structure, including any code that currently matches on the text value.
9. Add backend tests for the model, validation, canonical rendering, and migration parsing; add frontend tests for single and multi-component entry and validation states.
10. Ship the change to both development and production per **Rollout** below.

## Constraints

- Do not drop the original text value during migration; keep it until every record is reconciled.
- Reuse the unit master data and the preset ownership model from step 06; do not introduce an independent unit list.
- Follow `prompts/.cursor/forms.mdc` and `localization.mdc`.

## Acceptance Criteria

- [ ] **AC1 (R1, R2)** Single-component, multi-component, and concentration strengths are stored structurally and round-trip without loss.
- [ ] **AC2 (R3)** Invalid units, values, and combinations are rejected with localized field-level messages.
- [ ] **AC3 (R4)** The canonical display string renders identically on screens, prescriptions, labels, and printouts.
- [ ] **AC4 (R5, R6)** Migration preserves every original value, parses unambiguous entries, and lists unparsed entries for review.
- [ ] **AC5 (R7)** The form supports adding and removing components with live preview and suggestions.
- [ ] **AC6 (R8)** Search, prescribing, dispensing, stock, and reporting behave correctly against the new structure.
- [ ] **AC7 (R9)** New backend and frontend tests pass.
- [ ] **AC8 (R10)** Behavior and migrated data are correct in development and production.

## Verification

- `npm run test:backend`, `npm run lint`, `npm run openapi:validate` in `backend/`.
- `flutter analyze`, `flutter test` in `frontend/`.
- Manual: create one single-component drug, one combination drug, and one concentration drug in each environment, then prescribe and dispense each.

## Rollout — Development and Production

- Behavior must be identical under `NODE_ENV=development` and `NODE_ENV=production`.
- Config: document any parsing or suggestion key in `backend/env.template.txt` with dev and prod guidance and set it in both env files.
- Schema/data: apply the strength schema with `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host; run the idempotent parsing migration in development, review the unparsed report, then run it in production after backup and publish the production review list.
- Release: `python deploy/deploy-backend.py`, `python deploy/deploy-frontend.py`, and `python deploy/deploy-android.py`, then verify migrated strengths and new entries in production.

## Relevant Files

- `backend/src/modules/drug/`, `drug-batch/`, `formulary-item/`, `unit/`
- `backend/prisma/schema.prisma`, `backend/prisma/migrations/`, `backend/scripts/`
- `frontend/lib/features/pharmacy/presentation/`
- `frontend/lib/shared/printing/templates/`
