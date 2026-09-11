# 35 — Design the Import, Update, and Export Data Model

**Source:** [fairbanks-fixes.md](../fairbanks-fixes.md) → Phase 10, Step 35
**Depends on:** 06, 12
**Applies to:** development and production

## Context

Before any Excel template exists, the exchangeable entities and their relationships must be mapped: medicines, suppliers, patients, users, roles, permissions, diagnoses, laboratory tests, laboratory panels, radiology, theatre, departments, consultations, sales, purchases, stock, and remaining master data.

## Requirements

1. Produce a data-exchange map at `backend/docs/data-exchange-model.md` listing every exchangeable entity, its fields, types, required status, allowed values, and relationships.
2. Define the stable unique identifier used for each entity in exchange (friendly identifier, natural key, or code), and state how it resolves to an internal record.
3. Define relationship representation: how a row references a supplier, a department, a facility, a role, or a catalog entry, and what happens when the reference does not exist.
4. Classify each entity as import-capable, update-capable, export-only, or excluded, with the permission and scope required for each operation.
5. Mark every field that is platform-owned per step 06 and therefore not importable by a tenant.
6. State the tenant and scope rule for every entity so an import can never write outside the authorized scope.
7. Define the versioning scheme for templates and the compatibility rule for older versions.
8. Identify the entities that carry patient or sensitive data and the extra handling they require.
9. Review the map against the actual Prisma schema and record any field that exists in one and not the other.
10. Ship the artifacts to both development and production per **Rollout** below.

## Constraints

- This step produces specification only; no import or export implementation yet.
- Reuse the existing friendly-identifier helpers rather than inventing new external keys.
- Do not include platform-owned preset definitions as tenant-importable entities.

## Acceptance Criteria

- [ ] **AC1 (R1, R9)** The map covers every listed entity and matches `backend/prisma/schema.prisma`, with discrepancies recorded.
- [ ] **AC2 (R2, R3)** Every entity has a defined exchange identifier and relationship representation, including missing-reference behavior.
- [ ] **AC3 (R4, R5, R6)** Each entity states its allowed operations, required permission, scope rule, and platform-owned fields.
- [ ] **AC4 (R7)** The template versioning and compatibility rule is documented.
- [ ] **AC5 (R8)** Sensitive entities are identified with their handling requirements.
- [ ] **AC6 (R10)** The map reflects the schema deployed in both environments at the same revision.

## Verification

- Peer review of the document against the Prisma schema and the permission catalog.
- `npm run lint` in `backend/` if any tooling is added.

## Rollout — Development and Production

- The map must describe one model valid for both environments; no entity may be exchangeable only in development.
- Config: none expected.
- Schema/data: confirm both databases are at the same migration revision, and record that revision in the document.
- Release: no deployment required; record the deployed backend commit used for verification.

## Relevant Files

- `backend/prisma/schema.prisma`
- `backend/src/lib/identifiers/`, `backend/src/modules/` (entity modules listed in the plan)
- `backend/src/modules/permission/`, `abac-policy/`
- `backend/docs/` (new data-exchange document)
