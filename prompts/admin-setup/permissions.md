# Permissions Tab — Code Accuracy, Description Fallback, Dead Status Cleanup

Polish permission presentation on `/admin/setup?section=permissions` (and matching workspace permission surfaces) after the read-only catalog work.

## Context

- Setup panel already shows Permission ID / Permission Name / Description, opens read-only details via `showAccessAdminPermissionDetailDialog`, and has no permission CRUD.
- Shared columns live in `accessAdminPermissionColumns`; table density and infinite-scroll load-more are already done in `AppListTable`.
- Gaps: **Permission code** cells and details render `permissionCatalogLabelForCode` (friendly label) instead of the machine code (`domain:action`). **Status** is offered as a column choice but `serializePermission` never sends `status`, so it is always empty. Description falls back to `—` / omitted when `subtitle` is blank, while `permissionCatalogDescriptionForCode` currently stubs to the label.

## Requirements

1. Keep setup defaults Permission ID, Permission Name, Description; keep row select opening read-only details with Close only (no create/edit/delete).
2. Show the machine permission code (`permissionName` / `name`, e.g. `patient:read`) under **Permission code** in the optional column, setup details, and workspace permission details. Keep the localized display name on Permission Name only.
3. When description/subtitle is blank, fall back to a real catalog description (extend `permissionCatalogDescriptionForCode` / backend metadata), not the display-name label; show `—` only if no description exists.
4. Remove the dead **Status** column from permission column choices (and omit status from permission details) unless the API starts returning a meaningful permission status.
5. Align setup and workspace permission detail fields: ID, name, machine code, description (when present); no mutation actions.

## Constraints

- Reuse existing access-admin entities, dialogs, catalogs, and table APIs; add no permission CRUD endpoints.
- Do not reopen AppListTable density/load-more or FE↔BE key-parity work unless a regression appears.
- Cover loading, empty, error, and visible feedback for list and details; theme tokens; mobile/tablet/desktop.
- No unrelated refactoring.

## Acceptance Criteria

- Permission code column/details show machine codes, not friendly labels (Req 2, 5).
- Blank descriptions use catalog description fallback before `—` (Req 3).
- Status is not offered for permissions unless API-backed (Req 4).
- Details remain read-only; defaults and Close-only behavior unchanged (Req 1).
- Widget tests cover code vs name, description fallback, and Status absence; `flutter analyze` passes (Req 1–5).

## Relevant Files

- `frontend/lib/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart`
- `frontend/lib/features/access_admin/presentation/widgets/access_admin_workspace_table.dart`
- `frontend/lib/features/access_admin/presentation/pages/access_admin_workspace_page.dart`
- `frontend/lib/core/permissions/app_permission_catalog_localizations.dart`
- `backend/src/modules/access-admin-workspace/services/access-admin-workspace.service.js`
- `backend/src/lib/authorization/permission-catalog-metadata.js`
