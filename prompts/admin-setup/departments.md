# Departments Tab — Role-Scoped List and Columns

Scope the departments list and table columns on `/admin/setup?section=departments` by admin role.

## Context

- Inventoried in `screens/admin-setup/departments.md`.
- Departments currently load facility-scoped via setup snapshot (`_listDepartments` with tenant + facility); the table shows name, type, short name, status, and row actions—not department ID, facility, or tenant columns.
- Super/platform admins can access all tenants and facilities; tenant and facility admins are narrower.

## Requirements

1. Load departments for the signed-in admin’s scope:
   - Super/platform admin: all departments across all tenants and facilities.
   - Tenant admin: all departments under that tenant (all facilities).
   - Facility admin: departments for the active facility only.
2. Show columns by role:
   - Super/platform admin: Department ID, Department, Facility, Tenant, Actions.
   - Tenant admin: Department ID, Department, Facility, Actions (omit Tenant).
   - Facility admin: Department ID, Department, and remaining department detail columns (e.g. type, short name, status); omit Facility and Tenant.
3. Keep Actions as Edit and Delete for active departments when `canEditFacilitySetupStructure()`:
   - Edit opens `_DepartmentFormDialog` in edit mode.
   - Delete opens the soft-delete department `AppConfirmActionDialog`.
4. Keep Restore and Permanent delete for soft-deleted rows as inventoried; do not change those dialogs.

## Constraints

- Reuse existing department dialogs, permissions (`canEditFacilitySetupStructure`), and soft-delete lifecycle.
- Prefer extending list query scope over new endpoints when the existing departments list API already supports optional tenant/facility filters.
- No unrelated refactoring of units, wards, rooms, or beds tabs.

## Acceptance Criteria

- Super/platform admin sees departments from every tenant/facility with Facility and Tenant columns (Req 1–2).
- Tenant admin sees only their tenant’s departments and no Tenant column (Req 1–2).
- Facility admin sees only their facility’s departments and no Facility or Tenant column (Req 1–2).
- Edit opens the edit dialog; Delete opens soft-delete confirm (Req 3).
- Soft-deleted rows still expose Restore and Permanent delete (Req 4).
- Widget/source tests cover role-scoped columns and list scope; `flutter analyze` passes (Req 1–4).

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`
- `frontend/lib/features/tenant_facility/presentation/controllers/tenant_facility_setup_controller.dart`
- `frontend/lib/features/tenant_facility/data/repositories/tenant_facility_repository_impl.dart`
- `frontend/lib/core/permissions/access_policy.dart`
- `backend/src/modules/department/services/department.service.js`
- `screens/admin-setup/departments.md`
