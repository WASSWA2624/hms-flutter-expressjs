# Departments Tab — Role-Aware Create, Similarity, Details

Implement scoped create, similarity, and details on `/admin/setup?section=departments`.

## Context

- Inventoried in `screens/admin-setup/departments.md`.
- Create uses `_DepartmentFormDialog` against session facility only; no role-aware pickers, similarity, or details.
- Mirror tenant/facility similarity (`confirm_similar`, scores, near matches).

## Requirements

1. Role-aware create: platform admin picks tenant then facility; tenant admin picks a facility in their tenants; facility admin uses known tenant/facility. Block create without facility.
2. Fields: required name; optional short name defaulting to name when empty; `DepartmentSetupType` with type-specific icons.
3. On Create, always show facility-scoped similarity (including zero matches) with submitted fields, per-parameter/overall scores, and near matches; offer **Use this department** (adopt match) and **Create anyway** (`confirm_similar`).
4. After create and on row select, open department details with Edit (reuse form) and soft Delete (reuse confirm). Keep list Restore / Permanent delete for soft-deleted rows.
5. Cover permission, loading, empty, error, success, validation; refresh after mutations.

## Constraints

- Reuse dialogs, selects, `canEditFacilitySetupStructure`, and similarity contracts; add department similarity only as needed.
- Facility-scoped; no unrelated work.

## Acceptance Criteria

- Correct pickers by role; create blocked without facility (Req 1).
- Short name defaults to name; type icons shown (Req 2).
- Similarity always appears; Use this / Create anyway work (Req 3).
- Details open after create and row select; Edit/soft Delete work (Req 4).
- Unauthorized mutate UI absent; tests cover scoping, similarity, details; analyze and backend tests pass (Req 1-5).

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`
- `backend/src/modules/department/services/department.service.js`
