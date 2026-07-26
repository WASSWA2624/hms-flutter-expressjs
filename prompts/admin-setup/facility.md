# Facilities Tab — Edit Similarity, Details Lifecycle, Filters, Retry Removal

Align facility edit, details lifecycle, filters, and failure states on `/admin/setup?section=facility`.

## Context

- Inventoried in `screens/admin-setup/facility.md`.
- `updateFacility` skips create similarity; `checkFacilityDuplicates` accepts `excludeFacilityId` and is tenant-scoped.
- Details lacks Restore/Permanent delete; filters/columns omit fields.

## Requirements

1. Keep Edit opening `_SetupProfileDialog` in edit mode when `canManageFacility()`.
2. Enforce create-facility similarity on updates within that facility tenant, excluding via `excludeFacilityId`, reusing 409 `similar_exists`, `confirm_similar`, and create-flow similarity UI (validation, loading, error, success).
3. Keep Delete soft-deleting; expose Edit/Delete for active and Restore/Permanent delete for soft-deleted from list and details, each confirmed then refreshed.
4. Expand columns to all `FacilityProfile` fields and filters to tenant, type, active/deleted, and contact/location params.
5. Remove Retry from facility-tab and details failure states; still render errors.

## Constraints

- Reuse existing dialogs, endpoints, permissions, and similarity logic; extend list filters only if needed.
- Keep similarity tenant-scoped; do not change create-facility behavior.
- No unrelated refactoring.

## Acceptance Criteria

- Editing into conflict triggers similarity review; confirming saves (Req 2).
- Re-saving unchanged shows no similarity prompt (Req 2).
- Edit/Delete for active and Restore/Permanent delete only after soft delete (Req 3).
- Settings list every facility column; each supported filter narrows results (Req 4).
- No Retry in facility-tab or details failure states (Req 5).
- Tests cover update similarity, exclusion, filters, Retry absence, and columns; `flutter analyze` passes (Req 1-5).

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_management_dialogs.dart`
- `backend/src/modules/facility/services/facility.service.js`
- `backend/src/lib/facility/facility-similarity.js`
