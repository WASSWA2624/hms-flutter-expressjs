# Tenants Tab — Edit Similarity, Delete Lifecycle, Retry Removal

Align tenant edit, delete, and failure-state behavior on `/admin/setup?section=tenants`.

## Context

- Current tenants-tab actions are inventoried in `screens/admin-setup/tenants.md`.
- `updateTenant` skips the similarity check that create tenant enforces; `checkTenantDuplicates` accepts `excludeTenantId`.

## Requirements

1. Keep Edit opening `_SetupProfileDialog` in edit mode when `canManageTenant()`.
2. Enforce the create-tenant similarity check on updates, excluding the edited tenant via `excludeTenantId`, reusing the 409 `similar_exists` review flow and `confirm_similar` override.
3. Reuse the create-flow similarity review UI in the edit dialog, with matching validation, loading, error, and success feedback.
4. Keep Delete performing a soft delete; expose Restore and Permanent delete only for soft-deleted tenants in scope, each confirmed and followed by list refresh.
5. Remove the Retry button and handlers from tenant-list and scoped-tenant failure states; still render an error message.

## Constraints

- Reuse existing dialogs, endpoints, permissions, and similarity logic; add no endpoints.
- Do not change create-tenant behavior.
- No unrelated refactoring.

## Acceptance Criteria

- Editing a tenant into conflict triggers similarity review; confirming saves (Req 2–3).
- Re-saving a tenant unchanged shows no similarity prompt (Req 2).
- Restore and Permanent delete appear only after soft delete (Req 4).
- No Retry button renders in any tenants-tab failure state (Req 5).
- Backend tests cover update similarity and exclusion; widget tests prove Retry absent and edit similarity works; `flutter analyze` and backend tests pass (Req 1–5).

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`
- `frontend/lib/features/tenant_facility/presentation/controllers/tenant_facility_setup_controller.dart`
- `backend/src/modules/tenant/services/tenant.service.js`
- `backend/src/lib/tenant/tenant-similarity.js`
