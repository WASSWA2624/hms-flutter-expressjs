# Action button inventory — `/admin/setup?section=tenants`

Route mounts `TenantFacilitySetupPage` → `_SetupBody` → `ManageTenantsPanel` for the Tenants desk tab. There is **no** separate page-chrome Create/Add Tenant button outside `ManageTenantsPanel` (`tenantFacilitySetupDeskCreateLabel` exists in helpers but is unused by the setup page).

**Modes**

| Mode | Condition | UI |
| ---- | --------- | -- |
| Platform list | `canCreateTenant()` (not scoped) | Searchable tenants table with create + row actions |
| Scoped tenant manager | `canManageTenant() && !canCreateTenant()` | Single-tenant summary with **Edit tenant** only |

**Permission gates (omit when unauthorized, unless noted disabled)**

| Capability | Gate |
| ---------- | ---- |
| Add tenant / soft-delete / restore / permanent delete | `canCreateTenant()` (`_canCreate` / `_canDelete`) |
| Edit row actions column, row → details, scoped Edit | `canManageTenant()` (`_canEdit`) |
| Tenant details footer Edit | `canManageTenant()` and tenant not soft-deleted |
| Tenant details footer Delete tenant | `canCreateTenant()` and tenant not soft-deleted |
| Facility row Edit/Delete inside tenant details | `canManageFacility()` and tenant not soft-deleted |
| Facility details Edit/Delete / logo / users CRUD | `canManageFacility()` and facility not soft-deleted |
| Facility structure Add/Edit/Delete/Restore | `canEditFacilitySetupStructure()` (wards/rooms/beds also require `canManageFacility()`); Add unit disabled when no departments |

**Facilities nested from tenant details:** In scope. Row select / Edit on facilities inside `_TenantDetailsDialog` open facility form and `_FacilityDetailsDialog` (and their nested dialogs). There is **no** Add facility control on the tenants→tenant-details facilities panel.

---

## Tenants panel (`ManageTenantsPanel`) — platform list mode

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Add tenant | Search trailing (`tenantFacilityAddTenantAction`); empty-state primary | `_SetupProfileDialog` via `showTenantFacilityTenantFormDialog` / `_openTenantProfileModal` (**Create tenant**). Omitted when `!canCreateTenant`. Disabled while list loading. |
| Row select | Active (non-deleted) tenant row | `_TenantDetailsDialog` via `showTenantDetailsDialog`. Soft-deleted rows do not open details. |
| Edit | Row actions (`tenantFacilityEditAction`) | `_SetupProfileDialog` (**Edit tenant**). Actions column omitted when `!canManageTenant`. |
| Delete | Row actions (`tenantFacilityDeleteAction`) | Soft-delete `AppConfirmActionDialog`. Omitted when `!canCreateTenant`. Active tenants only. |
| Restore | Row actions (`tenantFacilityRestoreTenantAction`) | Restore `AppConfirmActionDialog`. Soft-deleted only; requires `canCreateTenant`. |
| Permanent delete | Row actions (`tenantFacilityPermanentDeleteAction`) | Type-name `AppTextInputActionDialog` → final `AppConfirmActionDialog`. Soft-deleted only; requires `canCreateTenant`. |

---

## Tenants panel (`ManageTenantsPanel`) — scoped tenant manager mode

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Edit tenant | Summary header (`tenantFacilityEditTenantAction` on `_TenantDetailsSummary`) | `_SetupProfileDialog` (**Edit tenant**). Omitted when `!canManageTenant` or tenant soft-deleted. |

No Add tenant, row actions, or facilities list in this mode.

---

## Soft-delete tenant confirm (`AppConfirmActionDialog`)

Opened by row **Delete** or tenant-details **Delete tenant**.

Title: **Delete record**. Submit: **Delete**.

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Cancel | Footer | Dismisses without delete. |
| Delete | Footer primary (destructive) | Soft-deletes tenant (and cascades facility soft-delete per copy). |

---

## Restore tenant confirm (`AppConfirmActionDialog`)

Opened by row **Restore**.

Title: **Restore tenant**. Submit: **Restore**.

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Cancel | Footer | Dismisses without restore. |
| Restore | Footer primary | Restores tenant. |

---

## Permanent delete — type name (`AppTextInputActionDialog`)

Opened by row **Permanent delete**. Requires typed name to equal tenant name before the final confirm; mismatch aborts with no second dialog.

Title: **Permanent delete — irreversible**. Submit: **Permanent delete**.

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Cancel | Footer | Aborts. |
| Permanent delete | Footer primary (destructive) | If name matches, opens final permanent-delete `AppConfirmActionDialog`. |

### Permanent delete — final confirm (`AppConfirmActionDialog`)

Title: **Permanent delete — irreversible**. Submit: **Permanent delete**.

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Cancel | Footer | Aborts. |
| Permanent delete | Footer primary (destructive) | Permanently deletes tenant and related data. |

---

## Tenant form (`_SetupProfileDialog` + `_TenantProfileForm`)

Opened by **Add tenant** / **Edit** / scoped **Edit tenant** / tenant-details **Edit tenant** via `showTenantFacilityTenantFormDialog`.

Titles: **Create tenant** / **Edit tenant**. Footer save: **Create tenant** (create) or **Edit tenant** (`tenantFacilitySaveTenantAction`, edit).

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Cancel | Footer | Dismisses without save. |
| Create tenant / Edit tenant | Footer primary | Saves tenant; on create may open similarity dialog first. Disabled while submitting; create requires `canCreateTenant`, edit requires `canManageTenant` (form fields disabled / permission banner when unauthorized). |

### Similar tenant found (`showTenantSimilarityDialog` → `AppDialog`)

Opened on create submit when non-exact similar matches exist and not yet accepted.

Title: **Similar tenant found**.

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Cancel | Footer | Aborts create; warning panel may remain on form. |
| Proceed anyway | Footer primary | Accepts similarity and continues create submit. |

---

## Tenant details (`_TenantDetailsDialog`)

Opened by platform-list row select (non-deleted).

Title: **Tenant details**.

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Hide details | Summary header icon (`tenantFacilityTenantDetailsHideSummaryAction`) | Hides summary pane (no dialog). |
| Show details | Facilities heading icon when summary hidden (`tenantFacilityTenantDetailsShowSummaryAction`) | Shows summary pane (no dialog). |
| Row select | Active facility row | `_FacilityDetailsDialog` via `showFacilityDetailsDialog`. Soft-deleted facilities ignored. |
| Edit | Facility row actions (`tenantFacilityEditAction`) | `_SetupProfileDialog` facility form (**Edit facility**). Omitted when `!canManageFacility` or tenant deleted; soft-deleted facility rows show no actions. |
| Delete | Facility row actions (`tenantFacilityDeleteAction`) | Soft-delete facility `AppConfirmActionDialog`. Same gating as Edit. |
| Edit tenant | Footer (`tenantFacilityEditTenantAction`) | Tenant `_SetupProfileDialog` (edit). Omitted when unauthorized or tenant deleted. |
| Delete tenant | Footer (`tenantFacilityDeleteTenantAction`) | Soft-delete tenant `AppConfirmActionDialog` (same as row Delete); on success pops details. Omitted when `!canCreateTenant` or tenant deleted. |
| Close | Footer | Pops; returns `true` if mutated. |

Facilities empty state has **no** Add facility action.

### Soft-delete facility confirm (`AppConfirmActionDialog`)

Opened by facility row **Delete** inside tenant details (and facility-details footer Delete).

Title: **Delete record**. Submit: **Delete**.

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Cancel | Footer | Dismisses. |
| Delete | Footer primary (destructive) | Soft-deletes facility. |

### Facility form (`_SetupProfileDialog` + `_FacilityProfileForm`)

Opened by facility row **Edit** or facility-details **Edit facility** (edit path only from this section — create / similarity not reachable here).

Title: **Edit facility**. Save: **Edit facility**.

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Cancel | Footer | Dismisses without save. |
| Edit facility | Footer primary | Updates facility. Requires `canManageFacility`. |

---

## Facility details (`_FacilityDetailsDialog`) — nested from tenant details

Opened by facility row select in `_TenantDetailsDialog`. Title uses facility details chrome; footer Close always present.

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Add logo / Change logo | Summary (`tenantFacilityDetailsAddLogoAction` / `ChangeLogo`) | `pickAppImageFile` → `_AppImageCropDialog` (`showAppImageCropDialog`); then uploads. Omitted when `!canManageFacility` or facility deleted. |
| Remove logo | Summary (`tenantFacilityDetailsRemoveLogoAction`) | Remove-logo `AppConfirmActionDialog`. Shown only when logo present. |
| Create user | Users panel trailing (`accessAdminCreateUserAction`) | `showUserMutationDialog` create via `openAccessAdminCreateUserDialog`. Omitted when unauthorized / facility deleted. |
| Edit | Users row (`tenantFacilityEditAction`) | `showUserMutationDialog` edit via `openAccessAdminEditUserDialog`. |
| Delete | Users row (`tenantFacilityDeleteAction`) | Soft-delete user `AppConfirmActionDialog`. Disabled for demo / system-critical users. |
| Restore user | Soft-deleted users row (`accessAdminRestoreUserAction`) | Restore user `AppConfirmActionDialog`. |
| Add department / unit / ward / room / bed | Structure panel trailing | Matching structure form dialog (`_DepartmentFormDialog`, `_UnitFormDialog`, `_WardFormDialog`, `_RoomFormDialog`, `_BedFormDialog`). Add unit disabled (tooltip = gate message) when no departments. |
| Edit | Structure row | Same structure form in edit mode. |
| Delete | Structure row | Soft-delete structure `AppConfirmActionDialog`. |
| Restore | Soft-deleted structure row (`tenantFacilityRestoreStructureAction`) | Restore structure `AppConfirmActionDialog`. |
| Edit facility | Footer (`tenantFacilityEditFacilityDetailsAction`) | Facility `_SetupProfileDialog` (edit). |
| Delete facility | Footer (`tenantFacilityDeleteFacilityDetailsAction`) | Soft-delete facility `AppConfirmActionDialog`; on success pops details. |
| Close | Footer | Pops; returns `true` if mutated. |

Panel metric chips (Users / Departments / …) only switch the right pane; not inventoried as dialog actions.

### Remove logo confirm (`AppConfirmActionDialog`)

Title: **Remove facility logo**. Submit: **Remove logo**.

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Cancel | Footer | Aborts. |
| Remove logo | Footer primary (destructive) | Deletes facility logo. |

### Image crop (`_AppImageCropDialog`)

Opened after file pick from Add/Change logo.

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Cancel | Footer | Aborts pick/crop. |
| Apply crop | Crop step footer (`appImageCropApplyAction`) | Produces preview. |
| Adjust crop | Preview footer (`appImageCropRecropAction`) | Returns to crop step. |
| Use image | Preview footer (`appImageCropConfirmAction`) | Confirms cropped bytes for upload. |

### Create / Edit user (`showUserMutationDialog`)

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Cancel | Footer | Dismisses without save. |
| Save | Footer primary (`commonSaveActionLabel`) | Creates or updates user. |

### Soft-delete user confirm (`AppConfirmActionDialog`)

Title: **Delete user**. Submit: **Delete**.

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Cancel | Footer | Aborts. |
| Delete | Footer primary (destructive) | Soft-deletes user. |

### Restore user confirm (`AppConfirmActionDialog`)

Title: **Restore user**. Submit: **Restore user**.

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Cancel | Footer | Aborts. |
| Restore user | Footer primary | Restores user. |

### Structure form dialogs (`_DepartmentFormDialog` / `_UnitFormDialog` / `_WardFormDialog` / `_RoomFormDialog` / `_BedFormDialog`)

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Cancel | Footer | Dismisses without save. |
| Create / Save | Footer primary (`tenantFacilityCreateAction` / `tenantFacilitySaveAction`) | Creates or updates structure record. |

### Soft-delete structure confirm (`AppConfirmActionDialog`)

Title: **Delete record**. Submit: **Delete**.

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Cancel | Footer | Aborts. |
| Delete | Footer primary (destructive) | Soft-deletes structure record. |

### Restore structure confirm (`AppConfirmActionDialog`)

Title: **Restore record**. Submit: **Restore**.

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Cancel | Footer | Aborts. |
| Restore | Footer primary | Restores structure record. |

---

## Shared dialog chrome (reachable `AppDialog`s)

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Cancel | Footers that include it (forms, confirms, similarity, type-name, crop) | Dismisses without applying. |
| Close | Tenant / facility details footers; title-bar Close on `AppDialog` | Dismisses; often disabled while saving. |
| Maximize / Restore | Title bar of reachable desktop `AppDialog`s | Expands or restores dialog size. |

---

## Reachable modal chain

- Tenants tab → `ManageTenantsPanel`
  - **Platform list:** Add tenant / Edit → tenant form → (create only) **Similar tenant found**
  - Row select → **Tenant details** → Edit tenant / Delete tenant; facility Edit / Delete / row select
  - Delete → soft-delete confirm; Restore → restore confirm; Permanent delete → type-name → final confirm
  - **Scoped:** Edit tenant → tenant form only
- Tenant details → facility row select → **Facility details**
  - Edit / Delete facility; logo Add/Change → crop; Remove logo confirm
  - Users: Create/Edit user dialogs; Delete/Restore confirms
  - Structure: Add/Edit forms; Delete/Restore confirms

---

## Helpers / actions not reachable from this section

| Helper | Would open or do |
| ------ | ---------------- |
| Setup page desk Create label (`tenantFacilitySetupDeskCreateLabel` for tenants) | Defined in helpers; **not** mounted on `_SetupBody` chrome |
| `ManageTenantsPanel(dialogMode: true)` footer Add tenant / Close | Used by `showManageTenantsDialog`, not the setup Tenants tab (`dialogMode: false`) |
| Add facility / facility create form / `showFacilitySimilarityDialog` | Facilities tab / other entry points; not on tenant-details facilities panel |
| Facility restore / permanent delete row actions | `ManageFacilitiesPanel` only |
| Other `/admin/setup` desk tabs | Reachable only after leaving Tenants |

---

## Main implementation sources

- `frontend/lib/app/router/app_routes.dart` (`/admin/setup`)
- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart` (`_SetupBody`, `_SetupProfileDialog`, `_TenantProfileForm`, `_FacilityProfileForm`, structure form dialogs, `showTenantFacilityTenantFormDialog` / `showTenantFacilityFacilityFormDialog` / structure form show helpers)
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_management_dialogs.dart` (`ManageTenantsPanel`, `_TenantDetailsDialog`, `_FacilityDetailsDialog`, row-action widgets, structure/users panels)
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_similarity_dialog.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart` (scoped-panel gate; unused desk create label)
- `frontend/lib/features/access_admin/presentation/widgets/access_admin_dialogs.dart` / `user_mutation_dialog.dart`
- `frontend/lib/shared/actions/app_action_dialogs.dart` (`AppConfirmActionDialog`, `AppTextInputActionDialog`)
- `frontend/lib/shared/components/app_dialog.dart`
- `frontend/lib/shared/components/app_image_crop_dialog.dart` / `app_image_upload_field.dart` (`pickAppImageFile`)
- `frontend/lib/shared/components/app_list_table.dart` / `app_search_bar.dart`
