# 20 — Fix Create Staff in Facility Details

**Source:** [fairpanks-fixes.md](../fairpanks-fixes.md) → Phase 6, Step 20
**Depends on:** 08, 18
**Applies to:** development and production

## Context

Under Facility Details, the Create Staff action must open the existing Create Staff dialog with the correct facility and tenant context, rather than a broken or duplicated flow. The staff creation dialog already exists in the HR and access administration surfaces and must be reused.

## Requirements

1. Locate the canonical Create Staff dialog and workflow and reuse it from Facility Details; delete or redirect any duplicate implementation introduced for this surface.
2. Pass facility and tenant context into the dialog so the new staff member is created against the facility being viewed, with the context visible and not silently defaulted.
3. Preserve the full validation, permission, loading, empty, error, and success states of the canonical dialog.
4. Enforce the authorization rules from steps 11 and 12: a user may only create staff within their resolved scope, and unauthorized entry points must not render.
5. Refresh the facility staff list and any dependent counters immediately after a successful creation, without reloading unrelated Facility Details data.
6. Handle the duplicate-staff and duplicate-user cases with the field-level messages established in step 08.
7. Add a frontend test asserting the dialog opens with the correct context and the list refreshes after creation, and a backend test for facility-scoped staff creation.
8. Ship the change to both development and production per **Rollout** below.

## Constraints

- Do not create a second staff-creation form, DTO, or endpoint.
- Follow `prompts/.cursor/dialogs.mdc` for nesting, sizing, and action placement, plus `forms.mdc` and `localization.mdc`.
- Backend remains authoritative for scope and permission checks.

## Acceptance Criteria

- [ ] **AC1 (R1)** Facility Details opens the canonical Create Staff dialog, and no duplicate implementation remains.
- [ ] **AC2 (R2)** The created staff member belongs to the facility and tenant being viewed, with the context displayed in the dialog.
- [ ] **AC3 (R3)** All dialog states render correctly in both themes and at representative viewports.
- [ ] **AC4 (R4)** An out-of-scope user cannot see or invoke the action, and a crafted request is rejected by the API.
- [ ] **AC5 (R5)** The staff list and counters refresh after creation without a full dialog reload.
- [ ] **AC6 (R6)** Duplicate cases show localized field-level messages.
- [ ] **AC7 (R7)** New tests pass.
- [ ] **AC8 (R8)** The flow works identically in development and production after deployment.

## Verification

- `flutter analyze`, `flutter test` in `frontend/`.
- `npm run test:backend`, `npm run lint` in `backend/`.
- Manual: create staff from Facility Details in both environments and log in as the created user.

## Rollout — Development and Production

- Behavior must be identical under `NODE_ENV=development` and `NODE_ENV=production`.
- Config: no environment-specific behavior is permitted; document any new key in `backend/env.template.txt` and set it in both env files if one is introduced.
- Schema/data: no schema change is expected; if staff-facility linkage changes, apply it with `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host.
- Release: `python deploy/deploy-frontend.py` and `python deploy/deploy-backend.py` when the API changes, plus `python deploy/deploy-android.py`, then repeat the flow in production.

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_management_dialogs.dart`
- `frontend/lib/features/hr/`, `frontend/lib/features/access_admin/`
- `frontend/lib/shared/management/`, `frontend/lib/shared/forms/`
- `backend/src/modules/staff-profile/`, `user/`, `user-role/`, `facility/`, `hr-workspace/`
