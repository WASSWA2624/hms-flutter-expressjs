# Admin setup tab — Tenants

## 1. Tab strip

- Label: `tenantFacilitySetupTabTenants` or scoped `tenantFacilitySetupTabTenant` when `canManageTenant && !canCreateTenant`
- Icon: `Icons.corporate_fare_outlined`
- Count source: **none**
- Count tone: n/a
- Deep-link `section`: `tenants` (alias `tenant`)
- Tab gate: `canManageTenant()` (elevated ∪ `tenant:admin`) — **not** platform-only
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Search: `tenantFacilitySearchLabel`
- Filters: `commonFilterActionLabel` → status
- Settings: `commonTableSettingsActionLabel` / storage `setup_manage_tenants_v3`
- Export: default AppListTable on (no `evidence:export`)
- Print: off
- Context Add: `tenantFacilityAddTenantAction` only if `canCreateTenant()` (elevated ∪ `platform:admin`/`platform:owner`)
- Scoped mode: **no table** — detail summary + edit

## 3. Table

- Row model: `AppListTable<TenantProfile>` (platform list) or `_TenantDetailsSummary` (scoped)
- Columns: name (+ displayId/slug details), status; optional slug; actions if `_canEdit`
- Row → tenant details

## 4. Advanced filters / search fields

- Status group key `status` — Active `tenantFacilityTenantStatusActive` / Deleted `tenantFacilityTenantStatusDeleted`
- Client-side filter on loaded page; no date

## 5. Primary / secondary / row actions

- Add tenant; row Edit/Delete/Restore/Permanent delete (`tenantFacilityEditAction`, `Delete`, `RestoreTenant`, `PermanentDelete`)
- Soft/permanent gated by `_canDelete` ≡ `canCreateTenant`

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Tenant form (`showTenantFacilityTenantFormDialog`) | Setup-owned |
| Tenant details (`showTenantDetailsDialog`) | Setup-owned |
| Confirm delete/restore/permanent | Setup-owned |

## 7. Nested / follow-on

- Similarity `tenant_similarity_dialog.dart`
- Permanent-delete typed confirm; blocked-active-subscription force path
- Facility create from tenant details → facility form

## 8. Forms (summary)

- Name, slug, active switch, contact name/phone/email, currency, consultation fee; create requires contact/email/phone

## 9. Print / labels / preview

- None

## 10. Loading / empty / error / success

- Loading/error `AppFailureStateView`
- Empty: `tenantFacilityManageTenantsTitle` / `tenantFacilityNoTenants`
- Success: `tenantFacilitySavedMessage`

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab | `canManageTenant` |
| Add / soft-delete lifecycle | `canCreateTenant` — omitted |
| Export | ungated |
| Route catalog | ∩ `setup:read` ≠ in-page `tenant:admin` |
