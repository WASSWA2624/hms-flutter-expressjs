# Align role Edit/Delete with create similarity and soft-delete lifecycle

On `/admin/setup?section=roles`, make **Edit** reuse the create-role form and similarity flow (excluding the edited role), and make **Delete** a soft-delete lifecycle with Restore and permanent delete. Space Edit/Delete row actions.

## Context

- Inventory: `screens/admin-setup/roles.md`. Row **Edit** / **Delete** appear when `canWrite`; delete hidden for system-critical roles.
- Create uses `showRoleMutationDialog` + `showRoleSimilarityDialog` + `confirm_similar`. Edit opens the same dialog in **Edit** mode with permissions, but skips similarity review before update.
- BE `assertRoleUniqueness` supports `excludeRoleId` on update; FE edit submit does not open review or pass `confirm_similar`.
- Delete confirms then soft-deletes via `deleteRole` / `roleRepository.softDelete` (cascades role permissions). Soft-deleted roles lack Restore / permanent delete.
- **Definitions:** Soft delete = set `deleted_at` with recoverable permission links. Restore = clear `deleted_at` on the role and restore role-permission rows soft-deleted with it. Permanent delete = hard-remove the role and remaining related records.
- Row Edit and Delete tertiary buttons sit flush with no gap.

## Requirements

1. Keep **Edit** opening `showRoleMutationDialog` in Edit mode with the same identity/scope fields as Create, plus Permissions to add/remove selections; Save updates the role and syncs `permission_ids`.
2. On Edit Save, run the Create similarity flow: open `showRoleSimilarityDialog` before update; peer scoring excludes the edited role; exact same-scope conflicts block proceed; near matches require `confirm_similar`. Reuse FE `_reviewRoleSimilarity` / BE `excludeRoleId`.
3. **Delete** on an active role confirms then soft-deletes only. Soft-deleted roles stay visible when include-deleted listing is on, marked deleted, with **Restore** and **Delete permanently** instead of Edit/Delete.
4. **Restore** recovers the role and attached permissions/related soft-deleted links. **Delete permanently** confirms then hard-deletes the role from the database.
5. Add theme-token spacing between adjacent row action buttons (Edit/Delete and Restore/permanent delete) so controls are not visually attached.
6. Preserve loading, empty, error, validation, success, and unauthorized states; keep unauthorized Edit/Delete/Restore/permanent-delete unrendered when `canWrite` is false; system-critical roles stay non-deletable.

## Constraints

Reuse access-admin dialogs, controllers, repositories, role similarity modules, tenant/user soft-delete UX patterns, l10n, and design-system components; no unrelated refactors. Backend RBAC/ABAC remains authoritative. Stay responsive on mobile/tablet/desktop; use theme tokens for light and dark.

## Acceptance Criteria

- AC1: Edit dialog matches Create form layout and includes permissions add/remove. → 1
- AC2: Edit Save opens similarity review excluding self; exact conflict blocks; near match needs confirm; successful update syncs list. → 2
- AC3: Delete soft-deletes; row shows Restore + Delete permanently; Restore recovers role+permissions; permanent delete removes DB row. → 3–4
- AC4: Adjacent action buttons have visible spacing. → 5
- AC5: Unauthorized actions unrendered; authorized actions available; system-critical not deletable. → 6

## Relevant Files

- `frontend/lib/features/access_admin/presentation/widgets/access_admin_dialogs.dart`
- `frontend/lib/features/access_admin/presentation/widgets/role_mutation_dialog.dart`
- `frontend/lib/features/access_admin/presentation/widgets/role_similarity_dialog.dart`
- `frontend/lib/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart`
- `frontend/lib/features/access_admin/data/repositories/access_admin_repository_impl.dart`
- `frontend/lib/features/access_admin/domain/repositories/access_admin_repository.dart`
- `backend/src/modules/role/services/role.service.js`
- `backend/src/modules/role/repositories/role.repository.js`
- `backend/src/modules/role/routes/role.routes.js`
- `frontend/test/features/access_admin/presentation/role_create_similarity_flow_test.dart`
- `screens/admin-setup/roles.md`

## Verification

- Unit/flow: edit similarity excludes self; soft-delete, restore (with permissions), permanent delete; unauthorized UI absent.
- Manual: Edit Accountant → review excludes self; Delete → soft-deleted row with Restore/permanent; spacing between Edit/Delete; dark/light; narrow viewport.
