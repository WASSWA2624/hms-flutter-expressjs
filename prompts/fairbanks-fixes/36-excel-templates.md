# 36 — Create Official Excel Templates

**Source:** [fairbanks-fixes.md](../fairbanks-fixes.md) → Phase 10, Step 36
**Depends on:** 35
**Applies to:** development and production

## Context

Each exchangeable dataset from step 35 needs an official, versioned Excel template so imports are predictable and future changes do not silently break existing files.

## Requirements

1. Generate one template per dataset, with a defined worksheet name, column names, column order, field definitions, required or optional status, data types, allowed values, identifiers, relationship fields, and validation rules.
2. Include a documentation sheet in every template covering field meanings, formats, examples, and the rules for relationship columns.
3. Include example rows where they aid understanding, clearly marked so they are never imported as data.
4. Stamp every template with a template identifier and version, and validate both on import.
5. Provide in-sheet validation where the format supports it: dropdowns for allowed values, date formats, and numeric constraints.
6. Generate templates from the data model definition rather than hand-maintaining them, so a model change regenerates the template.
7. Make templates downloadable from the application for users authorized to import the corresponding entity, within their scope.
8. Define and document the compatibility rule: which older versions are accepted, which are rejected, and the message shown for each.
9. Add tests that generate every template, assert required columns and version stamps, and assert a model change is reflected.
10. Ship the templates to both development and production per **Rollout** below.

## Constraints

- Do not hand-edit generated templates; change the definition and regenerate.
- Templates must not contain live tenant data.
- Follow the localization rules for user-visible strings in the application download surface; the template content language must be stated explicitly.

## Acceptance Criteria

- [ ] **AC1 (R1, R2, R3)** Every dataset has a template with its worksheet, columns, definitions, documentation sheet, and marked examples.
- [ ] **AC2 (R4, R8)** Every template carries an identifier and version, and the documented compatibility rule is enforced on import.
- [ ] **AC3 (R5)** In-sheet validation works in common spreadsheet software.
- [ ] **AC4 (R6)** Regenerating after a model change updates the template automatically.
- [ ] **AC5 (R7)** Authorized users can download the templates they are permitted to import, and others cannot.
- [ ] **AC6 (R9)** Generation tests pass.
- [ ] **AC7 (R10)** Identical templates are available in development and production.

## Verification

- `npm run test:backend`, `npm run lint` in `backend/`.
- `flutter analyze`, `flutter test` in `frontend/` for the download surface.
- Manual: open each template in a spreadsheet application and confirm validation and readability.

## Rollout — Development and Production

- Templates must be byte-identical between environments for the same version; no environment-specific template content.
- Config: document any template storage path or version key in `backend/env.template.txt` with dev and prod guidance and set it in both env files.
- Schema/data: none beyond the model definitions; if templates are stored, apply the schema with `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host.
- Release: `python deploy/deploy-backend.py` and `python deploy/deploy-frontend.py`, then download and open each template from `https://app.hosspi.com`.

## Relevant Files

- `backend/docs/data-exchange-model.md`
- `backend/scripts/` (new template generation script)
- `backend/src/modules/` (entity schemas), `backend/src/lib/identifiers/`
- `frontend/lib/features/settings/`, `frontend/lib/shared/management/`
