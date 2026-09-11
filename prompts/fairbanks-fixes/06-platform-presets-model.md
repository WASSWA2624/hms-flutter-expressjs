# 06 — Implement Proper Platform Presets

**Source:** [fairbanks-fixes.md](../fairbanks-fixes.md) → Phase 2, Step 6
**Depends on:** 04, 05
**Applies to:** development and production

## Context

Master data must separate centrally owned **global platform presets** from **tenant/facility configuration**. Tenant administrators may adopt and customize presets, but must not modify or delete the platform source definitions. The repo already has facility catalog modules (`facility-lab-catalog`, `facility-pharmacy-catalog`, `facility-radiology-catalog`) and shared catalog UI under `frontend/lib/shared/lab_catalog/`, `radiology_catalog/`, `facility_catalog/` to build on.

## Requirements

1. Define the preset model explicitly: a platform-owned definition table (no tenant scope) and a tenant/facility adoption table that references it and carries permitted overrides.
2. Apply the model consistently to laboratory tests and panels, radiology procedures, theatre procedures, clinical diagnoses, currencies, consultations, pharmacy master data, units, departments, and remaining master data listed in the source plan.
3. Allow tenant administrators to view available presets, activate or deactivate them for their facility, add presets to a facility, customize only the permitted properties (such as price, local name, availability), and create facility-specific entries.
4. Enforce at the API layer that no tenant-scoped actor can update or delete a platform preset definition; only a platform-level role may do so.
5. Ensure a customization made by one tenant never alters the source definition or the adoption of another tenant.
6. Migrate existing per-tenant duplicated master data onto the preset model without losing tenant customizations or breaking references from existing operational records.
7. Update the frontend catalog surfaces so preset selection, adoption, and customization are explicit, permission-gated, and consistent across modules.
8. Add backend tests for definition immutability, adoption, override isolation, and cross-tenant safety, plus frontend tests for the adoption UI states.
9. Ship the change to both development and production per **Rollout** below.

## Constraints

- Reuse the existing catalog modules, permission catalog, and shared catalog widgets; do not build a parallel master-data system.
- Backend RBAC and ABAC stay authoritative; unauthorized preset-management UI must not render.
- Preserve referential integrity for historical records that already point at master data.
- Follow the surface rules in `prompts/.cursor/tables.mdc`, `dialogs.mdc`, and `forms.mdc`.

## Acceptance Criteria

- [ ] **AC1 (R1, R2)** Every listed master-data domain exposes platform definitions and tenant adoptions through the same model.
- [ ] **AC2 (R3)** A tenant administrator can browse, adopt, customize permitted fields, and create facility-specific entries.
- [ ] **AC3 (R4)** A tenant-scoped update or delete against a platform definition is rejected by the API with the standard forbidden response, not merely hidden in the UI.
- [ ] **AC4 (R5)** A customization in tenant A leaves both the platform definition and tenant B unchanged.
- [ ] **AC5 (R6)** Existing tenants retain their master data and customizations after migration, with no broken references.
- [ ] **AC6 (R7)** Catalog screens render correct permission, loading, empty, error, and success states in both themes and at representative viewports.
- [ ] **AC7 (R8)** New backend and frontend tests pass.
- [ ] **AC8 (R9)** The same behavior is confirmed on the development stack and in production after deployment and migration.

## Verification

- `npm run lint`, `npm run test:backend`, `npm run openapi:validate` in `backend/`.
- `flutter analyze`, `flutter test` in `frontend/`.
- Manual: adopt and customize a preset in two tenants and confirm isolation in both environments.

## Rollout — Development and Production

- Behavior must be identical under `NODE_ENV=development` and `NODE_ENV=production`; preset ownership must not be relaxed locally.
- Config: document any preset-seeding or platform-admin key in `backend/env.template.txt` with dev and prod guidance and set it in `.env.development` and `.env.production`.
- Schema/data: create the definition and adoption tables with `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host; run the idempotent migration backfill in development first, then in production after backup, logging counts for both.
- Release: `python deploy/deploy-backend.py` and `python deploy/deploy-frontend.py`, then repeat the adoption and isolation checks in production.

## Relevant Files

- `backend/src/modules/facility-lab-catalog/`, `facility-pharmacy-catalog/`, `facility-radiology-catalog/`
- `backend/src/modules/lab-test/`, `lab-panel/`, `radiology-procedure/`, `procedure/`, `diagnosis/`, `unit/`, `department/`, `drug/`, `formulary-item/`
- `backend/prisma/schema.prisma`, `backend/prisma/migrations/`
- `backend/scripts/seeders/seed-catalog.js`, `seed-clinical-catalog-pack.js`, `seed-lab-catalog-pack.js`
- `frontend/lib/shared/facility_catalog/`, `lab_catalog/`, `radiology_catalog/`
- `frontend/lib/features/settings/`, `frontend/lib/features/tenant_facility/`
