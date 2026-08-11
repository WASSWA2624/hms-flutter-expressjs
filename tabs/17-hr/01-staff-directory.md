# HR tab — Staff directory

## 1. Tab strip

- Label: `hrStaffMembersSummaryLabel`
- Icon: `Icons.people_outlined`
- Count source: `state.staff.totalItemCount ?? items.length` (HR staff page — **not** ManageUsers row count)
- Sibling tabs: summary / positions totals from workspace overview
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `staff` (aliases `staff-directory`, `directory`); staff id query forces this tab
- Tab gate: `HrHumanResourcesAtomPermissions.tab` = `hrReadRequirement` (∩ `hr:read` + `hr-rosters`)
- **Omitted when unauthorized** (not disabled)

## 2. Search / Filters / Settings / Export / Print / context

Hosted by **reused** `ManageUsersPanel`.

- Search: `accessAdminSearchLabel` / `accessAdminSearchHint`
- Clear: via panel (`opdClearFiltersAction` on advanced reset)
- Filters: `commonFilterActionLabel` → `accessAdminUsersFiltersTitle`; groups tenant / facility / role / status
- Settings: `commonTableSettings*`
- Export: default on (no `evidence:export`)
- Print (toolbar): **off**
- Context: `accessAdminCreateUserAction` — omitted without Access Admin `permissions.canWrite`
- Date filter: **no** (`enableDateFilter: false`)

## 3. Table

- Row model: `AccessAdminItem` (users)
- Row select → `openHrStaffDetailForDirectoryUser` → HR staff detail (skips Access Admin user detail)
- Default columns: name (`accessAdminColumnName`), roles, status; actions when canWrite
- Column choices: id, facility, details
- Storage: `access_admin_manage_users_v4`
- Mobile / actions: Edit / Delete / Restore when Access Admin helpers allow

## 4. Advanced filters / search fields

- Filter groups: tenant, facility, role, status
- No date range

## 5. Primary / secondary / row actions

- Strip: Create user
- Row: Edit / Delete / Restore (Access Admin gated)
- Detail chrome: Edit staff (`hrEditStaffAction`), soft-delete user, Print (`commonPrintActionLabel`)

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Staff detail (`hrStaffDetailTitle`) | HR-owned |
| Create / edit / delete user | **reused** Access Admin |
| Staff print preview | HR-owned |

## 7. Nested / follow-on

From staff detail (`HrStaffDetailActions`, omitted via `hideWhenDenied` default true):

1. Assign dept / position
2. Roster (∪ `hr:write` \| `roster:write`)
3. Leave / compensation
4. Manage payroll (`hrPayrollRequirement`)
5. Assign role / module access / offboard
6. Nested onboarding, end assignment, schedule templates, payroll wizard

## 8. Forms (summary)

- Staff onboarding / edit identity
- Leave request fields
- Compensation lines
- Assign dept / position / role
- Offboard; payroll generate / process fields
- Access Admin user create/edit

## 9. Print / labels / preview

- No list Print
- Staff detail Print → `showHrStaffPrintPreview` (sections: overview / assignments / rosters / leaves / payroll / roles / permissions); preview-first `PrintDocumentTemplates.registry`

## 10. Loading / empty / error / success

- Loading: ManageUsers / workspace `hrLoading*`
- Empty: `accessAdminEmptyTitle` / `Body`
- Error: snackbars / panel failure
- Success: `hrSavedMessage` / Access Admin messages
- After mutations: refresh directory + workspace summary counts

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list chrome / search / filters / settings | ∩ `hr:read` (+ modules) |
| Create / Edit / Delete user | Access Admin write helpers |
| Detail quick actions | per `Hr*AtomPermissions` / hideWhenDenied |
| Export | ungated on table (convention gap) |
| Print (detail) | available from detail chrome when staff readable |
