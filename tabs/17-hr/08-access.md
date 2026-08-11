# HR tab — Access

## 1. Tab strip

- Label: `hrManageAccessAction`
- Icon: `Icons.manage_accounts_outlined`
- Count source: **always `0`**
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `access` (aliases `roles`, `permissions`)
- Tab gate: `HrManageUsersRolesAtomPermissions.tab` = `hrAccessReadRequirement` (∩ `hr:read` + ∪ tenant/facility/platform admin + module) **or** `policy.isElevated`
- Panel shrinks if `!canReadHrAccess`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Embedded `HrAccessWorkspacePanel`:

- Description: `hrAccessWorkspaceDescription`
- Toggle: `hrAccessPanelUsers` / `Roles` / `Permissions`
- Search: `hrAccessSearchLabel` / `hrAccessSearchHint`
- Filters button: **`hrFiltersLabel`** (not `commonFiltersActionLabel`); title same
- Settings: label present; **no storage keys**
- Export: default on, ungated
- Print: off
- Context/actions wrap: Refresh (`commonRefreshActionLabel`); Create user/role/permission when `canCreateHrAccess` (`hr:write`)
- Date: **false**

## 3. Table / panel

- Users: staff, email, roles, status, optional position — row → `showHrAccessUserDetailDialog`
- Roles: name, description, permission/user counts, system — detail dialog
- Permissions: name, description, role count — detail dialog
- Columns lack stable `id`s / `columnChoices`

## 4. Advanced filters / search fields

- Users: position text + status ACTIVE/INACTIVE/SUSPENDED (hardcoded English labels in choices)
- Roles: system yes/no
- Permissions: none

## 5. Primary / secondary / row actions

- Create user / role / permission
- Detail edit / assign / open staff profile — gates `canCreate/Update/DeleteHrAccess`

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Create/edit role/permission; assign permissions; edit user | HR-owned wrappers (`hr_access_dialogs.dart`) |
| Open staff profile | HR-owned |

## 7. Nested / follow-on

- Assign permissions nested in role/user flows
- Staff profile handoff to staff detail when opened

## 8. Forms (summary)

- Role / permission / user edit forms

## 9. Print / labels / preview

- No Access list print

## 10. Loading / empty / error / success

- Tenant-required: `hrAccessTenantContextRequiredTitle` / `Body`
- Failure + retry; empty panel labels; `hrSavedMessage`

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Entire tab | `hrAccessReadRequirement` / elevated |
| Creates | `canCreateHrAccess` (`hr:write`) — omitted |
| Update / delete | `canUpdate/DeleteHrAccess` — omitted |
| Panel unmounted | if read fails |
| Export | ungated |
| Count badge | always 0 (convention gap) |
