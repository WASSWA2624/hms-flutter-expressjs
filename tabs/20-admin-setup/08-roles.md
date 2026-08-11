# Admin setup tab — Roles

## 1. Tab strip

- Label: `tenantFacilitySetupTabRoles`
- Icon: `Icons.badge_outlined`
- Count source: **none**
- Count tone: n/a
- Deep-link `section`: `roles`
- Tab gate: `canManageAccess` (admins ∪ **`hr:write`**) — not platform-only
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Hosted by **reused** `ManageRolesPermissionsPanel` (`panel: AccessAdminPanel.roles`)
- Search/filters/settings from access-admin scoped list
- Create: `accessAdminCreateRoleAction` when `canWrite` (workspace `canWrite` ∩ matrix)
- Export default AppListTable; Print off

## 3. Table

- Roles table; row → role detail
- Columns/actions from access-admin panel

## 4. Advanced filters / search fields

- Tenant/facility/scope filters (widest list by actor)

## 5. Primary / secondary / row actions

- Create/Edit/Delete/Restore/Permanent (busy keys); system-critical protections

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Create/edit role / similarity | **reused** access-admin (`role_mutation_dialog.dart`, `role_similarity_dialog.dart`) |
| Role detail / permission editor | **reused** access-admin |

## 7. Nested / follow-on

- Nested permission editor / assign flows inside role detail

## 8. Forms (summary)

- Role create/edit forms in access-admin widgets

## 9. Print / labels / preview

- None dedicated

## 10. Loading / empty / error / success

- Empty/create affordances from access-admin panel

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab | `canManageAccess` (includes `hr:write`) |
| Documented atoms | `AccessAdminRolesAtomPermissions` — read ∪ `tenant:admin|facility:admin|platform:admin`; write ∩ `tenant:admin` + `canWrite` |
| Mismatch | Setup tab gate includes `hr:write` but AccessRequirement atoms do **not** list `hr:write` |
| Export | ungated |
