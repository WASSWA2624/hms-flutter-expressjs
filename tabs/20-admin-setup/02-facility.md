# Admin setup tab — Facility

## 1. Tab strip

- Label: `tenantFacilitySetupTabFacilities` or scoped `tenantFacilitySetupTabFacility`
- Icon: `Icons.apartment_outlined`
- Count source: **none**
- Count tone: n/a
- Deep-link `section`: `facility` (alias `facilities`)
- Tab gate: `canManageFacility || canManageTenant`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Search: `tenantFacilitySearchLabel`
- Filters / Settings: keys `setup_manage_facilities_v4` / `setup_manage_facilities_tenant_v2`
- Export default on; Print off
- Add: `tenantFacilityAddFacilityAction` if `canCreateFacility()` (elevated ∪ `tenant:admin`|`platform:admin`)
- Scoped (`canManageFacility && !canCreateFacility`): summary card + edit only

## 3. Table

- `AppListTable<FacilityProfile>`: name (+ code/phone/email details by scope), optional tenant, type, status, actions
- Row → `showFacilityDetailsDialog`

## 4. Advanced filters / search fields

- Tenant (platform), type (`FacilitySetupType` api values), soft-delete status, active yes/no

## 5. Primary / secondary / row actions

- Add; Edit/Delete/Restore/Permanent; row details
- Create/delete lifecycle ≡ `canCreateFacility` / `canDeleteFacility`

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Facility form (`showTenantFacilityFacilityFormDialog`) | Setup-owned |
| Facility details with nested users/departments/units/wards/rooms/beds | Setup-owned |
| Facility similarity | Setup-owned |

## 7. Nested / follow-on

- Structure CRUD from facility details (reuses submission + form dialogs)
- **Reused** access-admin user create/edit from facility users panel

## 8. Forms (summary)

- Name, type, currency, fee, logo upload, phone, email, address, city, country, active; tenant picker when required

## 9. Print / labels / preview

- None

## 10. Loading / empty / error / success

- Empty: `tenantFacilityNoFacilities`; loading/error panels; saved snackbar

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab | facility\|tenant manage |
| Add / soft-delete facility | `canCreateFacility` — omitted for facility-admin-only |
| Export | ungated |
| Nested user CRUD | access-admin write |
