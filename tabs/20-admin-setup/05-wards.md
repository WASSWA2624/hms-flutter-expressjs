# Admin setup tab — Wards

## 1. Tab strip

- Label: `tenantFacilityWizardStepWards`
- Icon: `Icons.maps_home_work_outlined`
- Count source: **none**
- Count tone: n/a
- Deep-link `section`: `wards`
- Tab gate: facility\|tenant manage
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Hint: `tenantFacilityWardSearchHint`
- Add: `tenantFacilityAddWardAction`; block `tenantFacilityGateNeedDepartmentForWards`
- Export default; Print off

## 3. Table

- Default extras: type only; department/facility/tenant nested under name
- Details: `ward_details_dialog.dart`

## 4. Advanced filters / search fields

- `TenantFacilityWardsFilterKeys`: `tenant`, `facility`, `department`, `type`, `active`

## 5. Primary / secondary / row actions

- CRUD + permanent delete

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Ward form (`showTenantFacilityWardFormDialog`) | Setup-owned |
| Details / similarity | Setup-owned |

## 7. Nested / follow-on

- Similarity + details edit/delete

## 8. Forms (summary)

- Tenant/facility, name, type (`WardSetupType`), department, active

## 9. Print / labels / preview

- None

## 10. Loading / empty / error / success

- Empty: `tenantFacilityNoWards`; retry error panel

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab | facility\|tenant manage |
| Mutations | `canEditStructure` |
| Export | ungated |
