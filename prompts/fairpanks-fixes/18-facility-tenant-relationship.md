# 18 — Fix Facility and Tenant Relationship Display

**Source:** [fairpanks-fixes.md](../fairpanks-fixes.md) → Phase 6, Step 18
**Depends on:** 07
**Applies to:** development and production

## Context

Facility Details shows `Tenant: Not Available` instead of the owning tenant. The relationship must be correct at the database, API, authorization, and frontend layers; a display-only patch is not acceptable. Surfaces: `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_management_dialogs.dart` and `backend/src/modules/facility/`.

## Requirements

1. Verify at the database level that every facility row has a valid tenant reference, and report any orphaned or mismatched row.
2. Verify at the API level that facility read endpoints include the tenant identity (identifier and display name) needed by the UI, within the caller authorized scope.
3. Verify at the authorization level that including tenant identity does not leak data across tenants and that a cross-tenant read is still denied.
4. Verify at the frontend level that the tenant field maps to the returned data and renders the tenant name, with a defined state for a genuinely unassigned facility.
5. Fix the actual break wherever it is (missing relation, missing include or projection, DTO mapping, or serializer), and state the root cause in the pull request description.
6. Backfill or correct any facility row with a missing or wrong tenant reference, idempotently, in both databases.
7. Add a database-level constraint or validation preventing creation of a facility without a tenant, where the schema allows it.
8. Add backend tests for the payload contract and cross-tenant denial, and a frontend test asserting the tenant name renders.
9. Ship the change to both development and production per **Rollout** below.

## Constraints

- Do not hardcode a fallback tenant name or hide the field to make the symptom disappear.
- Reuse the existing DTO, repository, and dialog components.
- Keep tenant isolation from step 07 intact.

## Acceptance Criteria

- [ ] **AC1 (R1, R6)** No facility row has a missing or invalid tenant reference in either database.
- [ ] **AC2 (R2, R5)** The facility payload contains tenant identity and the root cause is documented.
- [ ] **AC3 (R3)** A cross-tenant facility read remains denied and leaks no tenant information.
- [ ] **AC4 (R4)** Facility Details displays the correct tenant name, with a defined state for an unassigned facility.
- [ ] **AC5 (R7)** Creating a facility without a tenant is rejected.
- [ ] **AC6 (R8)** New backend and frontend tests pass.
- [ ] **AC7 (R9)** The correct tenant renders in development and on `https://app.hosspi.com` after deployment.

## Verification

- `npm run test:backend`, `npm run lint`, `npm run openapi:validate` in `backend/`.
- `flutter analyze`, `flutter test` in `frontend/`.
- Manual: open Facility Details for several facilities in both environments, in both themes and at representative viewports.

## Rollout — Development and Production

- Behavior must be identical under `NODE_ENV=development` and `NODE_ENV=production`.
- Config: no environment-specific behavior is permitted; document any new key in `backend/env.template.txt` and set it in both env files if one is introduced.
- Schema/data: apply the relation or constraint change with `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host; run the idempotent tenant-reference backfill in development, then in production after backup, logging corrected row counts.
- Release: `python deploy/deploy-backend.py` and `python deploy/deploy-frontend.py`, then re-check Facility Details in production.

## Relevant Files

- `backend/src/modules/facility/` (controllers, repositories, schemas, services)
- `backend/src/modules/tenant/`, `backend/src/modules/tenant-facility-workspace/`
- `backend/prisma/schema.prisma`, `backend/prisma/migrations/`
- `frontend/lib/features/tenant_facility/data/dtos/tenant_facility_dtos.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_management_dialogs.dart`
