# 38 — Implement Update and Upsert

**Source:** [fairbanks-fixes.md](../fairbanks-fixes.md) → Phase 10, Step 38
**Depends on:** 37
**Applies to:** development and production

## Context

Imports must be able to add new records, update existing ones, merge where supported, prevent duplicates, and report conflicts, using the reliable identifiers defined in step 35.

## Requirements

1. Resolve each row to an existing record using the declared exchange identifier, with a documented fallback rule when the identifier is absent.
2. Implement upsert semantics per entity: create when unmatched, update when matched, and skip or merge according to the declared rule, with the chosen action shown per row in the preview.
3. Update only the columns present in the file, leaving unlisted fields untouched, and state this rule in the template documentation.
4. Prevent duplicates at the database level with the constraints defined in step 35, and surface a constraint violation as a row-level conflict rather than a failed batch.
5. Detect and report conflicts explicitly: same identifier with differing content, concurrent modification since the file was produced, and rows that would violate a business rule.
6. Never modify platform-owned preset definitions or fields marked non-importable in step 35.
7. Write an audit entry per updated record with before and after values, linked to the import batch.
8. Make repeated import of the same file idempotent: the second run reports no changes.
9. Add backend tests for create, update, merge, duplicate prevention, conflict reporting, non-importable field protection, and idempotent re-import.
10. Ship the change to both development and production per **Rollout** below.

## Constraints

- Reuse the staged validation and preview flow from step 37; upsert never bypasses preview and confirmation.
- Do not silently overwrite a conflicting value; a conflict is a reportable outcome that the user resolves.
- Keep tenant isolation and scope enforcement intact for every write.

## Acceptance Criteria

- [ ] **AC1 (R1, R2)** Each row resolves to create, update, merge, or skip, and the preview shows the action before confirmation.
- [ ] **AC2 (R3)** Fields absent from the file remain unchanged after an update.
- [ ] **AC3 (R4, R5)** Duplicates are prevented and conflicts are reported per row with enough detail to resolve them.
- [ ] **AC4 (R6)** Platform-owned and non-importable fields are never modified by an import.
- [ ] **AC5 (R7)** Every update has an audit entry with before and after values linked to the batch.
- [ ] **AC6 (R8)** Re-importing the same file reports zero changes.
- [ ] **AC7 (R9)** New tests pass.
- [ ] **AC8 (R10)** Upsert behaves identically in development and production.

## Verification

- `npm run test:backend`, `npm run lint`, `npm run openapi:validate` in `backend/`.
- `flutter analyze`, `flutter test` in `frontend/`.
- Manual: import a file twice, then import a modified version, in each environment, and verify records and audit entries.

## Rollout — Development and Production

- Behavior must be identical under `NODE_ENV=development` and `NODE_ENV=production`.
- Config: no environment-specific behavior is permitted; document any new key in `backend/env.template.txt` and set it in both env files if one is introduced.
- Schema/data: add unique constraints and identifier indexes with `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host; resolve existing duplicates idempotently in both databases before the constraints apply, using the friendly-identifier collision scripts where relevant.
- Release: `python deploy/deploy-backend.py` and `python deploy/deploy-frontend.py`, then repeat the upsert checks in production with disposable data.

## Relevant Files

- `backend/src/modules/` (target entity modules), `backend/src/lib/identifiers/`
- `backend/prisma/schema.prisma`, `backend/prisma/scripts/check-friendly-id-collisions.js`, `resolve-friendly-id-collisions.js`
- `backend/src/modules/audit-log/`
- `frontend/lib/shared/management/`, `frontend/lib/shared/data/`
