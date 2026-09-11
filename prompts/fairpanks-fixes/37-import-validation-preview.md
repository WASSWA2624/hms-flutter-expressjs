# 37 — Implement Safe Import Validation

**Source:** [fairpanks-fixes.md](../fairpanks-fixes.md) → Phase 10, Step 37
**Depends on:** 36
**Applies to:** development and production

## Context

Uploaded Excel data must never reach production records directly. The flow must be `Upload → Validate → Preview → Show Errors → Confirm → Import`, with row-level errors such as `Row 24: Supplier ID does not exist`, `Row 31: Invalid date`, `Row 42: Duplicate Medicine ID`.

## Requirements

1. Implement a staged import: upload stores the file, validation produces a per-row result set, preview renders valid and invalid rows, and nothing is written until an explicit confirmation.
2. Validate template identity and version first, rejecting an unrecognized or incompatible file with a clear message.
3. Validate each row for required fields, data types, allowed values, relationship existence, duplicates within the file, and conflicts with existing records, producing a specific message per failing row and column.
4. Enforce permission and scope for the target entity before validation begins, and reject any row that targets data outside the authorized scope.
5. Support the four outcomes: accept all valid rows, reject all invalid rows, select specific valid rows, and correct and revalidate failed rows without re-uploading the whole file where practical.
6. Support merge behavior where the entity allows it, making the merge rule explicit in the preview before confirmation.
7. Make the confirmed import atomic per batch, with a clear result summary of created, updated, skipped, and failed rows, and no partial write on failure.
8. Record the import in the audit trail with actor, entity, template version, file identity, row counts, and outcome, and retain the staged file per the documented retention rule.
9. Add backend tests for validation rules, scope rejection, partial selection, revalidation, atomicity, and result reporting; add frontend tests for the upload, preview, error, and confirmation states.
10. Ship the change to both development and production per **Rollout** below.

## Constraints

- Never write to live tables during validation or preview.
- Reuse the standard response contract for errors and the shared table and dialog components for the preview.
- Enforce a documented maximum file size and row count with a clear message when exceeded.
- Follow `prompts/.cursor/tables.mdc`, `dialogs.mdc`, and `localization.mdc`.

## Acceptance Criteria

- [ ] **AC1 (R1)** No record is created or modified before confirmation, verified by inspecting the database after validation and preview.
- [ ] **AC2 (R2, R3)** Wrong-version files are rejected, and each invalid row reports its row number, column, and reason.
- [ ] **AC3 (R4)** Rows targeting out-of-scope data are rejected regardless of file content.
- [ ] **AC4 (R5, R6)** All four selection outcomes and the merge rule work as documented.
- [ ] **AC5 (R7)** A failure during import leaves no partial write, and the result summary is accurate.
- [ ] **AC6 (R8)** Every import appears in the audit trail with full context.
- [ ] **AC7 (R9)** New backend and frontend tests pass.
- [ ] **AC8 (R10)** The import flow behaves identically in development and production.

## Verification

- `npm run test:backend`, `npm run lint`, `npm run openapi:validate` in `backend/`.
- `flutter analyze`, `flutter test` in `frontend/`.
- Manual: import a clean file, a mixed file, an out-of-scope file, and an oversized file in each environment.

## Rollout — Development and Production

- Behavior must be identical under `NODE_ENV=development` and `NODE_ENV=production`; validation must not be relaxed locally.
- Config: document upload storage path, size limits, row limits, and retention in `backend/env.template.txt` with dev and prod guidance and set them in both env files; confirm production storage is writable and included in backups.
- Schema/data: create staging and import-audit tables with `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host.
- Release: `python deploy/deploy-backend.py`, `python deploy/deploy-frontend.py`, and `python deploy/deploy-android.py`, then repeat the four import cases in production with disposable data and remove it afterwards.

## Relevant Files

- `backend/src/modules/` (target entity modules), `backend/src/middlewares/validate.middleware.js`
- `backend/src/lib/response/`, `backend/src/modules/audit-log/`
- `backend/uploads/`, `backend/scripts/`
- `frontend/lib/shared/management/`, `frontend/lib/shared/data/`, `frontend/lib/features/settings/`
