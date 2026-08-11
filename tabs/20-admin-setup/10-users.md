# Admin setup tab — Users

## 1. Tab strip

- Label: `tenantFacilitySetupTabUsers`
- Icon: `Icons.people_outline`
- Count source: **none**
- Count tone: n/a
- Deep-link `section`: `users`
- Tab gate: `canManageAccess`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- **Reused** `ManageUsersPanel` (access-admin)
- Create: `accessAdminCreateUserAction` when canWrite
- Filters: tenant/facility/role/status
- Storage: `access_admin_manage_users_v4`
- Export default; Print off

## 3. Table

- Users table; row → user detail (unless custom `onOpenDetail`)
- Columns from access-admin ManageUsers

## 4. Advanced filters / search fields

- Keys `tenant` / `facility` / `role` / `status`
- allTenants/allFacilities by create-tenant / tenant-wide role rights

## 5. Primary / secondary / row actions

- Create/Edit/Delete/Restore
- Platform-admin user mutations need `canManagePlatformAdmins()`

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Create/edit user / similarity | **reused** access-admin (`user_mutation_dialog.dart`, `user_similarity_dialog.dart`) |
| User detail / role assignment | **reused** access-admin |

## 7. Nested / follow-on

- Nested role/permission assignment in user detail

## 8. Forms (summary)

- User forms in access-admin

## 9. Print / labels / preview

- None

## 10. Loading / empty / error / success

- Standard empty/create from panel

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab | `canManageAccess` (hr:write opens tab) |
| Create | canWrite ∩ tenant:admin — omitted |
| Platform users | `canManagePlatformAdmins()` |
| Atoms | `AccessAdminDirectoryAtomPermissions` |
| Export | ungated |
