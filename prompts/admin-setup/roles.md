# Roles Tab — Create Scope, Similarity, Then Permissions

Refine create-role on `/admin/setup?section=roles` so scope and identity save first, with similarity review, then permissions on role details.

## Context

- Inventoried in `screens/admin-setup/roles.md`.
- `showRoleMutationDialog` create mode already has actor-aware tenant/facility scope, name/display/description, and inline permissions; platform create still prompts “Choose a tenant above…” when the tenant picker is empty.
- Roles require `tenant_id` and optional `facility_id` (tenant-wide vs one facility). Soft delete already exists. Role similarity does not; reuse department/tenant `similar_exists` + `confirm_similar` patterns and scoring primitives.

## Requirements

1. Keep **Create role** opening `showRoleMutationDialog` in **Create** mode when workspace `canWrite` is true.
2. Show scope controls by actor only: platform/cross-tenant admins pick tenant then Entire organization vs One facility (facility required for facility scope); tenant-wide role creators pick facility when facility-scoped; facility-locked actors get no unauthorized tenant/facility pickers and create for their facility. Do not invent cross-tenant (all-tenants) roles.
3. Require **Role name** and **Display name**; keep **Description** optional. Omit permission assignment from create; create saves identity + scope only.
4. On create save, run scope-matched similarity (name, display name, description, spelling/fuzzy) within the same tenant and same facility scope (tenant-wide vs that facility). On conflict return 409 `similar_exists` with scores and candidates; reuse create-flow similarity review UI and `confirm_similar` override. Unchanged re-saves after confirm still succeed; no review when no similar roles.
5. After successful create, refresh the list and open `_AccessAdminRoleDetailDialog` with Edit, Delete (non-system-critical soft delete), and Add permissions. Assign/remove permissions only from details (or edit), with loading, empty, error, and success feedback.

## Constraints

- Reuse role mutation/details dialogs, access-admin APIs, RBAC/ABAC, and tenant/department similarity patterns; extend create/update contracts with `confirm_similar` and a role-similarity helper as needed.
- Unauthorized scope controls must not render.
- Cover validation, loading, empty, error, success, and visible feedback; theme tokens; mobile/tablet/desktop.
- No unrelated refactoring; do not redesign list filters, pagination, or Retry.

## Acceptance Criteria

- Create opens create dialog; unauthorized scope pickers are absent (Req 1–2).
- Display name is required; create form has no permission picker (Req 3).
- Similar roles trigger scored review; confirm creates; no match creates directly (Req 4).
- Success opens details with Edit, Delete, and Add permissions; list refreshes (Req 5).
- Backend similarity tests and widget tests cover scope gating, required display name, deferred permissions, and review flow; `flutter analyze` and backend tests pass (Req 1–5).

## Relevant Files

- `frontend/lib/features/access_admin/presentation/widgets/role_mutation_dialog.dart`
- `frontend/lib/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart`
- `frontend/lib/features/access_admin/presentation/widgets/access_admin_dialogs.dart`
- `backend/src/modules/role/services/role.service.js`
- `backend/src/modules/role/schemas/role.schema.js`
- `backend/src/lib/tenant/tenant-similarity.js`
- `screens/admin-setup/roles.md`
