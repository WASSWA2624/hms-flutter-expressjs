# `/admin/setup` action button inventory

**Primary UI:** desk tabs (`AppTabStrip` + `_SetupBody`), not the guided wizard. `_SetupBody` embeds section panels inline (`ManageTenantsPanel`, `ManageFacilitiesPanel`, structure sections, access-admin panels). `TenantFacilitySetupWizard` exists in the feature but has **no call site** from this route.

**Permission gates (section visibility):**
- Tenants tab: `canManageTenant`
- Facility + Departments/Units/Wards/Rooms/Beds: `canManageFacility || canManageTenant`
- Roles / Permissions / Users: `canManageAccess` (system/tenant/facility admin or HR write)
- HR-only users (`isHrSetupOnly`): replace desk tabs with `_HrFacilitySetupBody` (Departments + Units Manage cards only); catalog toolbar hidden unless a facility id exists for non-HR chrome
- Structure mutate on facility details / HR modals: `canEditFacilitySetupStructure` / facility manage as noted per surface

---

## Screen chrome

| Action button / control | Locations | Modal opened or function |
| ----------------------- | --------- | ------------------------ |
| Clinical service catalog | Workspace toolbar secondary (`AppTabToolbarAction`), when `snapshot.facility?.id != null` | Opens clinical-catalog `AppDialog` hosting `FacilityCatalogConfigPanel`. |
| Desk section tabs | `AppTabStrip` in `_SetupBody` | Switches Tenants / Facility / Departments / Units / Wards / Rooms / Beds / Roles / Permissions / Users (subset by permissions). |
| Try again | Async load failure (`AsyncStateScaffold` / detail dialog failure views) | Retries setup snapshot load. |

### HR-only body (`_HrFacilitySetupBody`)

| Action button / control | Locations | Modal opened or function |
| ----------------------- | --------- | ------------------------ |
| Manage | Departments card primary | Opens departments `_SetupDetailDialog` (same CRUD as Departments tab). Disabled when no facility id. |
| Manage | Units card primary | Opens units `_SetupDetailDialog`. Disabled when no facility id. |

---

## Tenants tab (`ManageTenantsPanel`, inline)

| Action button / control | Locations | Modal opened or function |
| ----------------------- | --------- | ------------------------ |
| Add tenant | Search trailing action; empty-state primary | Opens tenant form (`Create tenant` / save **Create tenant**). |
| Filter | `AppListTable` search bar | Opens advanced filter (status Active/Deleted); footer **Apply filters** / **Clear filters**. |
| Settings | Table column-visibility control | Opens column-settings dialog. |
| Previous staff page / Next staff page | Table pager | Changes tenants page. |
| Row select (non-deleted) | Tenant row | Opens `Tenant details` dialog. |
| Edit | Active-tenant row actions | Opens tenant form (**Edit tenant** title; save **Edit tenant**). |
| Delete | Active-tenant row actions (delete-capable users) | Opens soft-delete confirm (`AppConfirmActionDialog`; submit **Delete**). |
| Restore (icon-only) | Deleted-tenant row actions | Opens restore confirm (submit **Restore**). |
| Permanent delete (icon-only) | Deleted-tenant row actions | Opens type-name `AppTextInputActionDialog`, then final permanent-delete confirm (submit **Permanent delete**). |

---

## Facility tab (`ManageFacilitiesPanel`, inline)

| Action button / control | Locations | Modal opened or function |
| ----------------------- | --------- | ------------------------ |
| Add facility | Search trailing action; empty-state primary | Opens facility form (**Create facility**; save **Save facility**). |
| Filter | Search bar | Advanced filter (tenant + status); **Apply filters** / **Clear filters**. |
| Settings | Column visibility | Column-settings dialog. |
| Previous staff page / Next staff page | Table pager | Changes facilities page. |
| Row select (non-deleted) | Facility row | Opens `Facility details` dialog. |
| Edit | Active-facility row actions | Opens facility form (**Edit facility**; save **Edit facility**). |
| Delete | Active-facility row actions | Soft-delete confirm. |
| Restore (icon-only) | Deleted-facility row actions | Restore confirm. |
| Permanent delete (icon-only) | Deleted-facility row actions | Type-name dialog then permanent-delete confirm. |

---

## Structure desk tabs (Departments / Units / Wards / Rooms / Beds)

Shared pattern via `_SearchableEntityGroup` (and HR detail modals with `framed: false`).

| Action button / control | Locations | Modal opened or function |
| ----------------------- | --------- | ------------------------ |
| Add department / Add unit / Add ward / Add room / Add bed | Search trailing; empty-state primary | Opens matching structure form dialog. Disabled when prerequisites fail (facility / departments / wards gates). |
| Filter | Search bar | Scope (facility/department/ward) + status filters; apply/clear. |
| Settings | Column visibility | Column-settings dialog. |
| Edit | Active row | Opens edit form for that entity. |
| Delete | Active row | Soft-delete structure confirm (submit **Delete**). |
| Restore | Deleted row | Restore structure confirm (submit **Restore**). |

Dynamic form footer labels: **Create** (new) / **Save** (edit), plus **Cancel**.

---

## Roles tab (`ManageRolesPermissionsPanel`, roles)

| Action button / control | Locations | Modal opened or function |
| ----------------------- | --------- | ------------------------ |
| Create role | Search trailing; empty-state primary | Opens role mutation dialog (footer **Save** / **Cancel**; inline **Try again** when tenant/facility/permission lookups fail). |
| Filter | Search bar | Tenant / facility / scope filters when policy allows. |
| Settings | Column visibility | Column-settings dialog. |
| Row select | Role row | Opens role detail dialog. |
| Edit | Role row actions | Opens edit-role mutation dialog. |
| Delete | Role row actions (non–system-critical) | Delete-role confirm. |

### Role detail dialog

| Action button / control | Locations | Modal opened or function |
| ----------------------- | --------- | ------------------------ |
| Edit role | Footer | Closes detail and opens edit-role dialog. |
| Delete role | Footer (non–system-critical) | Closes detail and opens delete confirm. |
| Close | Footer | Dismisses detail. |

---

## Permissions tab (`ManageRolesPermissionsPanel`, permissions)

Read-only catalog list: search/filter/settings/pagination only. **No** Create / Edit / Delete / row-detail actions.

---

## Users tab (`ManageUsersPanel`, inline)

| Action button / control | Locations | Modal opened or function |
| ----------------------- | --------- | ------------------------ |
| Create user | Search trailing; empty-state primary | Opens user mutation dialog (**Save** / **Cancel**; inline **Try again** when tenant/facility/role-permission lookups fail). |
| Filter | Search bar | Tenant / facility / role / status filters. |
| Settings | Column visibility | Column-settings dialog. |
| Row select | User row | Opens user detail dialog. |
| Edit | Active-user row | Opens edit-user dialog. |
| Delete | Active-user row (not demo/system-critical) | Soft-delete user confirm. |
| Restore user | Deleted-user row | Restore-user confirm. |

### User detail dialog

| Action button / control | Locations | Modal opened or function |
| ----------------------- | --------- | ------------------------ |
| Add role | Assigned-roles section header | Opens assign-role dialog (**Add role** / **Cancel**). |
| Remove role | Role group card | Opens remove-role confirm. |
| Add permission | Direct-permissions section header | Opens direct-permission picker (**Save** / **Cancel**). |
| Remove permission | Direct-permission row | Syncs removal (no nested confirm). |
| Edit user | Footer | Closes detail and opens edit-user dialog. |
| Deactivate / Activate | Footer | Toggles ACTIVE ↔ inactive via status API. |
| Delete user | Footer (not demo/system-critical) | Soft-delete confirm. |
| Close | Footer | Dismisses detail. |

---

## Tenant details dialog (from Tenants row)

| Action button / control | Locations | Modal opened or function |
| ----------------------- | --------- | ------------------------ |
| Edit / Delete | Embedded facilities mini-table row actions | Facility form or facility soft-delete confirm. |
| Edit tenant | Footer (when mutable) | Tenant form. |
| Delete tenant | Footer (when deletable) | Soft-delete tenant confirm; pops details on success. |
| Close | Footer | Dismisses; returns mutated flag. |

---

## Facility details dialog (from Facility row)

| Action button / control | Locations | Modal opened or function |
| ----------------------- | --------- | ------------------------ |
| Add logo / Change logo | Summary (when can manage) | Picks/uploads facility logo. |
| Remove logo | Summary when logo present | Confirm remove-logo dialog. |
| Users / Departments / Units / Wards / Rooms / Beds metric chips | Summary structure heading | Switches right-hand panel. |
| Create user | Users panel header | Create-user mutation dialog. |
| Edit / Delete / Restore user | Users panel rows | Same as users tab patterns (confirmations). |
| Add department / unit / ward / room / bed | Structure panel headers | Matching structure form dialogs. |
| Edit / Delete / Restore | Structure panel rows | Form or soft-delete/restore confirms. |
| Edit facility | Footer | Facility form (edit). |
| Delete facility | Footer | Soft-delete facility confirm; pops details on success. |
| Close | Footer | Dismisses details. |

---

## Tenant / facility profile form dialogs (`_SetupProfileDialog`)

| Action button / control | Locations | Modal opened or function |
| ----------------------- | --------- | ------------------------ |
| Cancel | Footer | Dismisses without save. |
| Create tenant / Edit tenant | Tenant form save (dynamic; create vs edit) | Saves; may open **Similar tenant found** first. |
| Save facility / Edit facility | Facility form save (dynamic; create vs edit) | Saves; may open similarity dialog; edit may open **Confirm facility changes**. |
| Choose image | Facility logo `AppImageUploadField` add tile | Opens system/file image picker. |
| Remove | Logo preview tile (pending or existing) | Clears that logo from the form (persisted on save). |
| Close | Full-size logo preview dialog | Dismisses the image preview overlay. |

### Nested from profile save

| Action button / control | Locations | Modal opened or function |
| ----------------------- | --------- | ------------------------ |
| Cancel / Proceed anyway | `showTenantSimilarityDialog` | Abort or accept similar-tenant warning. |
| Cancel / Proceed anyway | `showFacilitySimilarityDialog` | Abort or accept similar-facility warning. |
| Cancel / Update facility | Confirm facility changes dialog | Abort or confirm field/logo diffs before update. |

---

## Structure entity form dialogs

Department / Unit / Ward / Room / Bed create-edit dialogs share:

| Action button / control | Locations | Modal opened or function |
| ----------------------- | --------- | ------------------------ |
| Cancel | Footer | Dismisses without save. |
| Create / Save | Footer (`tenantFacilityCreateAction` / `tenantFacilitySaveAction`) | Persists entity and closes. |

---

## Clinical service catalog dialog (`FacilityCatalogConfigPanel`)

Opened from workspace toolbar. Dialog chrome only (no footer actions beyond Close / Maximize).

| Action button / control | Locations | Modal opened or function |
| ----------------------- | --------- | ------------------------ |
| Add | Global catalog search result row (clinical mode) | Upserts facility clinical offering (no nested modal). |
| Enable test | Lab mode primary | Opens `LabEnableFacilityOfferingDialog`. |
| Enable panel | Lab mode secondary | Opens `LabEnableFacilityOfferingDialog` (panel kind). |
| Radiology catalog | Radiology mode primary | Opens `RadiologyEnableFacilityOfferingDialog`. |

Mode / term-type / catalog-source selects are field controls, not action buttons.

### Lab enable offering dialog

| Action button / control | Locations | Modal opened or function |
| ----------------------- | --------- | ------------------------ |
| Filter | Catalog search | Category / result-kind filters; **Apply filters** / **Clear filters**. |
| Settings | Column visibility (when shown) | Column-settings dialog. |
| Row select (not yet offered) | Catalog row | Opens nested price/enable dialog. |
| Close | Footer | Dismisses picker. |
| Cancel / Enable test or Enable panel | Nested price dialog (submit label by kind) | Abort or enable offering with unit price. |

### Radiology enable offering dialog

| Action button / control | Locations | Modal opened or function |
| ----------------------- | --------- | ------------------------ |
| Filter | Catalog search | Modality filters; **Apply filters** / **Clear filters**. |
| Row select (not yet offered) | Catalog row | Opens `RadiologyEnableOfferingPriceDialog`. |
| Close | Footer | Dismisses picker. |
| Enable procedure | Nested price dialog primary (no footer Cancel) | Enables radiology offering with unit price; dismiss via dialog Close to abort. |

---

## Soft-delete / restore / permanent-delete confirms

Shared `AppConfirmActionDialog` / `AppTextInputActionDialog` pattern:

| Action button / control | Locations | Modal opened or function |
| ----------------------- | --------- | ------------------------ |
| Cancel | Confirm / type-to-confirm footers | Aborts. |
| Delete | Soft-delete submits (`tenantFacilityDeleteConfirmAction`) | Confirms soft delete. |
| Restore / Restore user | Restore submits | Confirms restore. |
| Permanent delete | Type-name then final confirm | Irreversible purge after name match. |
| Remove role | User-detail role removal | Confirms role unassign. |

---

## Shared dialog / table actions

| Action button / control | Locations | Modal opened or function |
| ----------------------- | --------- | ------------------------ |
| Cancel | Footer of dialogs that permit cancellation | Dismisses without applying. Advanced-filter and column-settings dialogs use Apply/Clear instead of a footer Cancel. |
| Close | Title bar of reachable `AppDialog`s; some panel footers when `dialogMode: true` (not used on this route’s inline panels) | Dismisses; commonly disabled while saving. |
| Maximize / Restore | Title bar of `AppDialog` with default window controls | Expands or restores dialog size. |
| Filter | `AppSearchBar` / `AppListTable` search | Opens advanced filter sheet. |
| Apply filters / Clear filters | Advanced-filter footer | Applies or resets filter value. |
| Settings | `AppListTable` column visibility | Opens column-settings dialog. |
| Previous staff page / Next staff page | Paged tables (tenants, facilities, users, facility-details users) | Changes page. |

---

## Reachable modal chain

- Toolbar **Clinical service catalog** → `FacilityCatalogConfigPanel` → lab enable picker → lab price dialog; or radiology enable picker → radiology price dialog
- HR **Manage** → departments/units detail dialog → structure form / soft-delete / restore
- Tenants tab → tenant form (+ similarity); tenant soft-delete / restore / permanent-delete (type + confirm); row → **Tenant details** → facility edit/delete; tenant edit/delete
- Facility tab → facility form (+ similarity + confirm-update); facility soft-delete / restore / permanent-delete; row → **Facility details** → logo remove confirm; users create/edit/delete/restore; structure add/edit/delete/restore; facility edit/delete
- Structure tabs → entity forms; soft-delete / restore
- Roles tab → create/edit role mutation; role detail → edit/delete
- Users tab → create/edit user mutation; soft-delete / restore; user detail → add-role / remove-role confirm / add-permission / edit / activate-deactivate / delete

`ManageTenantsPanel` / `ManageFacilitiesPanel` / access panels are **inline** on this route (`dialogMode: false`); their dialog-shell **Close** footers are not shown here.

---

## Helpers / actions not reachable from `/admin/setup`

| Helper | Would open or do |
| ------ | ---------------- |
| `TenantFacilitySetupWizard` (+ step primary/secondary/next/fix actions, `TenantFacilityPermissionStrip`) | Guided wizard UI — **no constructor call sites** in the app |
| `showManageTenantsDialog` / `showManageFacilitiesDialog` | Dialog-mode wrappers around the same panels (used from settings/home, not this page) |
| `showAccessAdminWorkspaceDialog` | Full access-admin workspace shell |
| `RadiologyEditFacilityOfferingDialog` / other lab catalog CRUD not opened from `FacilityCatalogConfigPanel` | Edit/disable offerings outside this enable-only path |
| Wizard-only label helpers as UX (Create vs Manage by `hasRecords`) | Only matter if the wizard were mounted |

Panels and form dialogs themselves **are** reachable from desk tabs even when the dialog-wrapper entry points above are not.

---

## Main implementation sources

- `frontend/lib/app/router/app_routes.dart` (`/admin/setup`)
- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_management_dialogs.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/facility_catalog_config_panel.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/facility_similarity_dialog.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_similarity_dialog.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_setup_wizard.dart` (present; unused from route)
- `frontend/lib/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart`
- `frontend/lib/features/access_admin/presentation/widgets/access_admin_dialogs.dart`
- `frontend/lib/features/access_admin/presentation/widgets/user_mutation_dialog.dart`
- `frontend/lib/features/access_admin/presentation/widgets/role_mutation_dialog.dart`
- `frontend/lib/shared/lab_catalog/lab_catalog_dialogs.dart`
- `frontend/lib/shared/radiology_catalog/radiology_catalog_dialogs.dart`
- `frontend/lib/shared/actions/app_action_dialogs.dart`
- `frontend/lib/shared/components/app_dialog.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/components/app_search_bar.dart`
- `frontend/lib/shared/components/app_user_access_panel.dart`
- `frontend/lib/shared/layout/app_workspace_toolbar.dart`
