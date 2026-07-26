# Action inventory — `/admin/setup?section=tenants`

## Platform tenant list

- **Add tenant**
  - Location: Search-bar trailing action and empty-state primary action.
  - Condition: Shown when `canCreateTenant()`; disabled while the list is loading.
  - Immediate result: Opens `_SetupProfileDialog` in **Create tenant** mode.

- **Open tenant details** (tenant row)
  - Location: Active tenant table or mobile-list row.
  - Condition: The tenant must not be soft-deleted.
  - Immediate result: Opens `_TenantDetailsDialog`.

- **Edit**
  - Location: Active tenant row actions.
  - Condition: The actions column is shown when `canManageTenant()`; disabled while loading.
  - Immediate result: Opens `_SetupProfileDialog` in **Edit tenant** mode.

- **Delete**
  - Location: Active tenant row actions.
  - Condition: Shown when `canCreateTenant()`; disabled while loading.
  - Immediate result: Opens the soft-delete tenant `AppConfirmActionDialog`.

- **Restore**
  - Location: Soft-deleted tenant row actions.
  - Condition: Shown when `canCreateTenant()`; disabled while loading.
  - Immediate result: Opens the restore tenant `AppConfirmActionDialog`.

- **Permanent delete**
  - Location: Soft-deleted tenant row actions.
  - Condition: Shown when `canCreateTenant()`; disabled while loading.
  - Immediate result: Opens the permanent-delete `AppTextInputActionDialog`.

- **Previous page**
  - Location: Tenant-list pagination controls.
  - Condition: Enabled when a previous page is available.
  - Immediate result: Loads the previous tenant page.

- **Next page**
  - Location: Tenant-list pagination controls.
  - Condition: Enabled when a next page is available.
  - Immediate result: Loads the next tenant page.

- **Retry**
  - Location: Tenant-list failure state.
  - Condition: Shown when loading the tenant list fails.
  - Immediate result: Reloads the first tenant page.

## Scoped tenant summary

- **Edit tenant**
  - Location: Tenant summary header.
  - Condition: This mode is used when `canManageTenant()` and not `canCreateTenant()`; omitted for a soft-deleted tenant.
  - Immediate result: Opens `_SetupProfileDialog` in **Edit tenant** mode.

- **Retry**
  - Location: Scoped tenant failure state.
  - Condition: Shown when loading the scoped tenant fails and no tenant is available.
  - Immediate result: Reloads the scoped tenant.
