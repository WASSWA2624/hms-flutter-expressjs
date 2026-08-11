# Admin setup tab — Departments

## 1. Tab strip

- Label: `tenantFacilityWizardStepDepartments`
- Icon: `Icons.domain_outlined`
- Count source: **none**
- Count tone: n/a
- Deep-link `section`: `departments`
- Tab gate: facility\|tenant manage
- List scope: `tenantFacilityDepartmentsListScope` → platform / tenant / facility
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Search hint: `tenantFacilityDepartmentSearchHint`
- Filters / Settings: storage `setup_structure_departments_${scope}_v4`
- Export default; Print off
- Add: `tenantFacilityAddDepartmentAction` when `canEditStructure` + prerequisites (facility scope needs facility else `tenantFacilityGateNeedFacility`)

## 3. Table

- `_SearchableEntityGroup` / `AppListTable`: name (+ id/shortName/type), optional facility/tenant/type columns by scope, status, actions
- Row → `DepartmentDetailsDialog`

## 4. Advanced filters / search fields

- `TenantFacilityDepartmentsFilterKeys`: `tenant`, `facility`, `type`, `active` (`yes`/`no`), plus shared `status` active/deleted

## 5. Primary / secondary / row actions

- Add; Edit/Delete/Restore/Permanent (`tenantFacilityRestoreStructureAction`, etc.)

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Department form (`showTenantFacilityDepartmentFormDialog`) | Setup-owned |
| Details `department_details_dialog.dart` | Setup-owned |
| Similarity `department_similarity_dialog.dart` | Setup-owned |

## 7. Nested / follow-on

- Similarity review before save; details → edit/delete soft

## 8. Forms (summary)

- Tenant/facility pickers (create, by scope), name, short name, type, active

## 9. Print / labels / preview

- None

## 10. Loading / empty / error / success

- Compact loader / failure text / empty `tenantFacilityNoDepartments` / no-results `tenantFacilitySearchNoResults`
- Success: `tenantFacilitySavedMessage`

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab | facility\|tenant manage |
| Mutations | `canEditStructure` (`canManageFacility`) — Add/actions omitted without |
| Export | ungated |
