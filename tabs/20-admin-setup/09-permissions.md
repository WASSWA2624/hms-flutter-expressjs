# Admin setup tab — Permissions

## 1. Tab strip

- Label: `tenantFacilitySetupTabPermissions`
- Icon: `Icons.key_outlined`
- Count source: **none**
- Count tone: n/a
- Deep-link `section`: `permissions`
- Tab gate: `canManageAccess`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Same **reused** `ManageRolesPermissionsPanel` with `panel: AccessAdminPanel.permissions`
- Search/filters; **no Create** (`tenantFacilitySetupDeskCreateLabel` → null)
- Export default; Print off

## 3. Table

- Permissions catalog table/detail
- Read-focused catalog

## 4. Advanced filters / search fields

- Filter groups when provided by panel

## 5. Primary / secondary / row actions

- No create; detail view
- Write atoms reserved (`AccessAdminPermissionsAtomPermissions.write`) but UI is read-focused

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Permission detail | **reused** access-admin |

## 7. Nested / follow-on

- Nested detail only

## 8. Forms (summary)

- N/A create forms

## 9. Print / labels / preview

- None

## 10. Loading / empty / error / success

- Empty/loading from panel

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab | `canManageAccess` |
| Create chrome | absent |
| Same hr:write / AccessRequirement mismatch as Roles | |
| Export | ungated |
