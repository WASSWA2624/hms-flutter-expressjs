# Departments Tab — Actions Visibility, Delete Lifecycle, Loading Feedback

Expose add, edit, soft-delete, restore, permanent-delete, and loading feedback on `/admin/setup?section=departments`.

## Context

- Inventoried in `screens/admin-setup/departments.md`.
- Facility-scoped; Add/Edit/Delete/Restore gate on `canEditFacilitySetupStructure()` and a facility id; Permanent delete is absent.

## Requirements

1. Show **Add department** in search-bar trailing and empty-state when `canEditFacilitySetupStructure()` and a facility is available; omit when unauthorized; without a facility, gate Add with the facility prerequisite message.
2. Keep **Edit** and soft-**Delete** on active rows under that permission; Edit opens `_DepartmentFormDialog`; Delete confirms, soft-deletes, and refreshes.
3. On soft-deleted rows only, show **Restore** and **Permanent delete**; confirm each (reuse facility/tenant patterns), then refresh.
4. Add permanent-delete mirroring facility/tenant contracts, permissions, and confirm UX; require prior soft delete.
5. Show informative loading, empty, error, success, and validation feedback on mutations.

## Constraints

- Reuse `_SearchableEntityGroup`, `_DepartmentFormDialog`, soft-delete/restore, permissions, and design-system components; extend permanent-delete only to match facility/tenant.
- Keep facility scope; no unauthorized controls; no unrelated refactoring.

## Acceptance Criteria

- Authorized users with a facility see Add on empty state and search bar (Req 1).
- Unauthorized users never see Add or row mutation actions (Req 1–3).
- Active rows show Edit/Delete only; soft-deleted show Restore/Permanent delete only (Req 2–3).
- Permanent delete requires soft delete and removes the department after confirm (Req 3–4).
- Mutations show informative loading feedback and refresh (Req 5).
- Tests cover gating and permanent delete; `flutter analyze` passes (Req 1–5).

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`
- `frontend/lib/features/tenant_facility/presentation/controllers/tenant_facility_setup_controller.dart`
- `backend/src/modules/department/services/department.service.js`
