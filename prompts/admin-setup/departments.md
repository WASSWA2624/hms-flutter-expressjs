# Departments Tab — Details, Edit Entry Points, Edit Similarity

Align department details, edit entry points, and update similarity on `/admin/setup?section=departments`.

## Context

- Inventoried in `screens/admin-setup/departments.md`.
- Create department already enforces similarity via `checkDepartmentDuplicates` and the create-flow similarity review UI.
- `checkDepartmentDuplicates` accepts `excludeDepartmentId`; updates must reuse that exclusion so the department being edited is not treated as its own conflict.

## Requirements

1. Keep row select opening department details (`showDepartmentDetailsDialog`).
2. Keep Edit opening `_DepartmentFormDialog` / `showTenantFacilityDepartmentFormDialog` in **Edit department** mode when `canEditFacilitySetupStructure()`, from both the active department row actions and the Edit department action in department details.
3. Enforce the create-department similarity check on updates within that facility, excluding the edited department via `excludeDepartmentId`, reusing 409 `similar_exists`, `confirm_similar`, and the create-flow similarity UI (validation, loading, error, success).
4. Re-saving a department with unchanged identity fields must not prompt similarity review.

## Constraints

- Reuse existing dialogs, endpoints, permissions, and similarity logic; add no endpoints.
- Keep similarity facility-scoped; do not change create-department behavior.
- Do not inventory or redesign dialog-internal chrome beyond edit + similarity.
- No unrelated refactoring.

## Acceptance Criteria

- Selecting a department row opens department details (Req 1).
- Edit from the table and from department details both open the edit dialog (Req 2).
- Editing into conflict with another department triggers similarity review; confirming saves (Req 3).
- Re-saving a department unchanged shows no similarity prompt (Req 4).
- Tests cover update similarity, exclusion of the edited department, and both edit entry points; `flutter analyze` passes (Req 1–4).

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/department_details_dialog.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/department_similarity_dialog.dart`
- `backend/src/modules/department/services/department.service.js`
- `backend/src/lib/department/department-similarity.js`
