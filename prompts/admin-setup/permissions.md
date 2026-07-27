# Permissions Tab — Read-Only Catalog, Columns, Table Density, Completeness

Improve the permissions list on `/admin/setup?section=permissions` and harden the shared table plus permission catalog.

## Context

- Permissions panel is `ManageRolesPermissionsPanel` with `AccessAdminPanel.permissions` from `tenant_facility_setup_page.dart`.
- Setup permissions table currently shows generic **ID** / **Name** only; `onRowSelected` is null (no details). Create/edit must stay unavailable.
- Workspace permissions already define fuller columns (`perm_id`, `perm_name`, `perm_description`, …) and a read-only detail path; reuse those patterns where they fit the setup tab.
- Shared table is `AppListTable`; single-line rows still reserve large `dataRowMinHeight`, and infinite-scroll load-more must not leave blank filler rows without a loading cue.
- Canonical catalogs: `backend/src/config/permissions.js`, `AppPermissions` in `access_policy.dart`, plus role/module mappings (`PermissionModuleMap`, role permission seeds).

## Requirements

1. On the setup permissions table, label columns **Permission ID** and **Permission Name**, and show a **Description** column (permission description/subtitle). Reuse or add l10n keys; do not rely on generic ID/Name/Details for this panel.
2. On row select, open a read-only permission details view showing at least ID, name, code, description, and status when present. Do not offer create, edit, delete, or other mutations for permissions.
3. Keep permissions assignable only via existing role, user, and module entitlement flows; do not add permission CRUD.
4. In `AppListTable`, size row height to single-line content by default (no excess vertical padding when cells are one line); still allow growth for wrapped multi-line cells without clipping. Apply at the shared component so all consumers benefit.
5. When infinite scroll fetches the next page, show a clear load-more indicator (reuse existing footer/`AppLoadingIndicator` patterns). Do not present empty spacer rows as if they were unloaded data.
6. Audit the permission catalog for completeness and atomicity: each permission must grant exactly one access capability. Align backend catalog, frontend `AppPermissions`, seeds, role defaults, and `PermissionModuleMap` so every module has accurate, attachable rights. Add only missing atomic permissions; split any bundled multi-capability keys.

## Constraints

- Reuse existing access-admin entities, dialogs, endpoints, RBAC/ABAC, and table APIs; add endpoints only if catalog/seed sync requires them.
- Unauthorized UI must not render; permissions remain read-only in this tab.
- Cover loading, empty, error, and success/feedback states for list and details.
- No unrelated refactoring.

## Acceptance Criteria

- Setup permissions columns read Permission ID, Permission Name, Description (Req 1).
- Row select opens read-only details; no create/edit/delete controls (Req 2–3).
- Single-line `AppListTable` rows are content-tight; multi-line cells still expand safely (Req 4).
- Loading the next infinite-scroll page shows a load-more indicator, not blank filler-only chrome (Req 5).
- Catalog is atomic and complete across backend, frontend, seeds, role defaults, and module maps; tests cover column labels, details read-only, row density, load-more, and catalog/module alignment; `flutter analyze` and backend permission tests pass (Req 1–6).

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`
- `frontend/lib/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart`
- `frontend/lib/features/access_admin/presentation/widgets/access_admin_workspace_table.dart`
- `frontend/lib/features/access_admin/presentation/pages/access_admin_workspace_page.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/core/permissions/access_policy.dart`
- `frontend/lib/core/permissions/permission_module_map.dart`
- `backend/src/config/permissions.js`
