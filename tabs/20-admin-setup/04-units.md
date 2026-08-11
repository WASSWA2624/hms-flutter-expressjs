# Admin setup tab — Units

## 1. Tab strip

- Label: `tenantFacilityWizardStepUnits`
- Icon: `Icons.account_tree_outlined`
- Count source: **none**
- Count tone: n/a
- Deep-link `section`: `units`
- Tab gate: facility\|tenant manage (same visibility as departments)
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Hint: `tenantFacilityUnitSearchHint`
- Storage: `setup_structure_units_${scope}_v2`
- Add: `tenantFacilityAddUnitAction`; block `tenantFacilityGateNeedDepartmentForUnits`
- Export default; Print off

## 3. Table

- Columns: name, department (default extra), optional facility/tenant, status, actions
- Details: `unit_details_dialog.dart`

## 4. Advanced filters / search fields

- `TenantFacilityUnitsFilterKeys`: `tenant`, `facility`, `department`, `active` (+ status)

## 5. Primary / secondary / row actions

- Same CRUD pattern as departments

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Unit form (`showTenantFacilityUnitFormDialog`) | Setup-owned |
| Details / similarity | Setup-owned |

## 7. Nested / follow-on

- Similarity → optional open details on save

## 8. Forms (summary)

- Tenant/facility (create), name, department, active

## 9. Print / labels / preview

- None

## 10. Loading / empty / error / success

- Loading titles `tenantFacilityUnitsLoadingTitle/Body`
- Error panel + `commonRetryActionLabel`
- Empty: `tenantFacilityNoUnits`

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab | facility\|tenant manage |
| Mutations | `canEditStructure` |
| Export | ungated |
