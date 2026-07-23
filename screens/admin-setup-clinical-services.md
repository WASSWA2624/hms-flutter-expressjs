# `/admin/setup?section=clinical-services` action button inventory

**Primary UI:** Clinical Services desk section on `/admin/setup`, rendered by `FacilityCatalogConfigPanel` via `_SetupBody` → `_buildClinicalCatalogBody`.

**Permission gates:**
- Section visible when `canManageFacility || canManageTenant` (same Catalog gate as other facility-setup tabs).
- Mutating chrome (`Configure`, Add, row Edit/Delete, empty-state primary, row-select → edit) requires `enabled: canManageFacility || canManageTenant`. When `enabled` is false, tables remain browse-only (search / Filter / Settings still present).

**Catalog model:** Desk tables load the **global** catalog (radiology tests, lab tests+panels, diagnosis terms). Facility context from the setup snapshot only prefills Configure / create tenant scope; it does not filter the desk lists to facility offerings.

---

## Screen chrome (parent `/admin/setup` while this section is active)

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Desk section tabs | `AppTabStrip` in `_SetupBody` | Switches Tenants / Facility / Departments / Units / Wards / Rooms / Beds / Roles / Permissions / Users / Clinical Services (subset by permissions). Synced to `?section=` (kebab-case); `?tab=` accepted as alias. Selecting another desk tab leaves this inventory’s scope. |
| Retry / reload setup | `AsyncStateScaffold` failure view (`onRetry`) | Reloads facility setup snapshot for the page. |

---

## Clinical Services panel chrome (`FacilityCatalogConfigPanel`)

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Radiology / Lab / Diagnoses | Inner `AppTabStrip` | Switches nested catalog table; reloads that category’s global list. Default tab: Radiology. |

Shared per nested tab (when `enabled`):

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Filter | `AppListTable` search bar (`commonFilterActionLabel`) | Opens advanced-filter dialog for that category; footer **Apply filters** / **Clear filters**. |
| Settings | Column-visibility control (`commonTableSettingsActionLabel`) | Opens column-settings dialog (**Apply columns** / **Reset columns** / **Close** defaults). Storage keys: `admin_catalog_radiology`, `admin_catalog_lab`, `admin_catalog_diagnoses`. |
| Configure | Search trailing (`tenantFacilityCatalogConfigureAction`) | Opens **Select tenant and facility** scope picker, then the category enable dialog. Does not switch the desk table into facility-only mode. |
| Edit | Row actions (`clinicalLabRequestEditSelectionAction`) | Opens global catalog edit/mutation dialog for that row. |
| Delete | Row actions (label varies by category) | Opens `LabDeleteReasonDialog` delete confirm for that catalog item. |
| Row select | Non-disabled row | Same as **Edit** (opens mutation dialog). |

No pager buttons: these tables are not wired to `AppPage` pagination.

---

## Radiology nested tab

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Create imaging test | Search trailing; empty-state primary (`radiologyCreateImagingTestAction`) | May open **Select tenant and facility** when `tenantId` is missing; then `RadiologyCatalogMutationDialog` (create). |
| Edit | Row actions / row select | `RadiologyCatalogMutationDialog` (edit). |
| Delete | Row actions (`clinicalRadiologyDeleteSelectionAction`) | `LabDeleteReasonDialog` titled with `radiologyDisableOfferingDialogTitle`; submit **Delete**; calls `deleteRadiologyCatalogTest`. |

**Filter groups:** modality (from loaded rows).

### `RadiologyCatalogMutationDialog` (create / edit)

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Cancel | Footer | Dismisses without save. |
| Save | Footer (`commonSaveActionLabel`) | Creates or updates radiology catalog test; pops `true` on success. |

Title: **Create imaging test** (create) or **Edit** (edit).

---

## Lab nested tab

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Add test | Search trailing; empty-state primary (`labCreateTestAction`) | May open scope picker when `tenantId` missing; then `LabCatalogItemMutationDialog` for `LabCatalogItemType.test`. |
| Add panel | Search trailing only (`labCreatePanelAction`) | Same create flow for `LabCatalogItemType.panel`. |
| Edit | Row actions / row select | `LabCatalogItemMutationDialog` for the row’s kind. |
| Delete | Row actions (`tenantFacilityDeleteAction` → **Delete**) | `LabDeleteReasonDialog`; submit **Delete test** or **Delete panel**. |

**Filter groups:** type (test / panel); category (from loaded rows).

### `LabCatalogItemMutationDialog` (create / edit)

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Cancel | Footer | Dismisses without save. |
| Save | Footer | Creates or updates lab test/panel; pops `true` on success. |

Titles use lab create/configure dialog title keys (test vs panel; edit reuses panel create title / configure-test title).

---

## Diagnoses nested tab

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Add service | Search trailing; empty-state primary (`tenantFacilityCatalogAddServiceAction`) | May open scope picker when `tenantId` missing; then `DiagnosisCatalogMutationDialog` (create). |
| Edit | Row actions / row select | `DiagnosisCatalogMutationDialog` (edit). |
| Delete | Row actions (**Delete**) | `LabDeleteReasonDialog` titled `clinicalDiagnosisFormTitle`; submit **Delete**; calls `deleteClinicalCatalogTerm`. |

**Filter groups:** category (from loaded rows).

### `DiagnosisCatalogMutationDialog` (create / edit)

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Cancel | Footer | Dismisses without save. |
| Save | Footer | Creates or updates diagnosis catalog term; pops `true` on success. |

Title: **Add service** (create) or `clinicalDiagnosisFormTitle` (edit).

---

## Configure scope picker (`showCatalogFacilityScopePicker` → `_CatalogFacilityScopePickerDialog`)

Opened by **Configure** on every nested tab, and by Add/create when panel `tenantId` is absent (create path uses returned `tenantId` only).

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Cancel | Footer | Aborts; pops `null`. |
| Next | Footer (`commonNextActionLabel`) | Validates tenant + facility; pops `FacilityCatalogScope`. |

Dialog title default: **Select tenant and facility**.

---

## Lab enable offering dialog (`LabEnableFacilityOfferingDialog`)

Opened after Configure → Next when the Lab nested tab is active.

**Note from source:** `_openLabConfigureDialog` always passes `kind: LabEnableOfferingKind.test`. Panel enable is **not** reachable from this screen’s Configure path (dialog supports panels when called with `LabEnableOfferingKind.panel` elsewhere).

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Laboratory filters / Filter | Catalog search (`labFiltersLabel`) | Category + result-kind filter groups; **Apply filters** / **Clear filters**. |
| Settings | Column visibility (when >1 columns) | Column-settings dialog. |
| Row select (not yet offered) | Catalog row | Opens nested `_LabEnableOfferingPriceDialog`. |
| Close | Footer | Dismisses picker (`false`). |

### Nested `_LabEnableOfferingPriceDialog`

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Cancel | Footer (`_dialogActions`) | Aborts enable. |
| Enable test | Footer primary (`labEnableTestAction`; would be **Enable panel** for panel kind) | Upserts facility lab offering with unit price; pops `true` (parent then pops `true`). |

---

## Radiology enable offering dialog (`RadiologyEnableFacilityOfferingDialog`)

Opened after Configure → Next when the Radiology nested tab is active.

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Filters | Catalog search (`radiologyFiltersLabel`) | Modality filters; **Apply filters** / **Clear filters** (`radiologyClearFiltersAction`). |
| Settings | Column visibility (when >1 columns) | Column-settings dialog. |
| Row select (not yet offered) | Catalog row | Opens `RadiologyEnableOfferingPriceDialog`. |
| Close | Footer | Dismisses picker (`false`). |

### Nested `RadiologyEnableOfferingPriceDialog`

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Enable procedure | Footer primary only (`radiologyEnableProcedureAction`) | Upserts facility radiology offering with unit price; pops `true`. No footer Cancel — abort via dialog title-bar **Close**. |

---

## Diagnosis enable offering dialog (`DiagnosisEnableFacilityOfferingDialog`)

Opened after Configure → Next when the Diagnoses nested tab is active. Title: `tenantFacilityCatalogBrowseTitle`.

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Filter | Catalog search (when categories exist) | Category filters; **Apply filters** / **Clear filters**. |
| Settings | Column visibility (`setup_catalog_diagnosis_enable`) | Column-settings dialog. |
| Row select / Add service | Catalog row or row **Add service** (`tenantFacilityCatalogAddServiceAction`) | Upserts facility diagnosis offering (`upsertFacilityCatalogOffering`); on success pops `true`. Already-enabled rows show disabled **Configured**. |
| Close | Footer | Dismisses picker. |

---

## Delete confirms (`LabDeleteReasonDialog`)

Used for radiology / lab / diagnosis global catalog deletes from this panel. Call sites pass `showCancelButton: false` (default).

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Submit (dynamic label) | Footer primary | Confirms delete after required reason text: **Delete** (radiology / diagnosis), **Delete test**, or **Delete panel**. |
| Close | Title bar | Aborts (no footer Cancel on this screen’s call sites). |

---

## Shared dialog / table actions (reachable surfaces)

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Cancel | Footers that include it (scope picker, mutation dialogs, lab price dialog) | Dismisses without applying. |
| Close | Title bar of reachable `AppDialog`s; enable-dialog footers | Dismisses; often disabled while saving. |
| Maximize / Restore | Title bar of `AppDialog` with default window controls | Expands or restores dialog size. Advanced-filter and column-settings dialogs disable this control. |
| Apply filters / Clear filters | Advanced-filter footer | Applies or resets filter value. |
| Apply columns / Reset columns / Close | Column-settings dialog | Applies, resets, or dismisses column visibility. |

---

## Reachable modal chain

- Clinical Services → nested Radiology / Lab / Diagnoses tables
- **Configure** → **Select tenant and facility** →
  - Radiology → `RadiologyEnableFacilityOfferingDialog` → `RadiologyEnableOfferingPriceDialog`
  - Lab → `LabEnableFacilityOfferingDialog` (tests only from this route) → `_LabEnableOfferingPriceDialog`
  - Diagnoses → `DiagnosisEnableFacilityOfferingDialog` (row enable; no nested price dialog)
- Add / Create (no tenant) → **Select tenant and facility** → category mutation dialog
- Add / Create (tenant present) → category mutation dialog
- Edit / row select → category mutation dialog
- Delete → `LabDeleteReasonDialog`

---

## Helpers / actions not reachable from this section

| Helper | Would open or do |
| ------ | ---------------- |
| `LabEnableFacilityOfferingDialog` with `LabEnableOfferingKind.panel` | Enable lab panels for a facility — used from lab workspace Configure, not from this panel’s Configure |
| Procedures / Prescriptions / Budget catalog tabs | l10n keys exist; not mounted in `FacilityCatalogConfigPanel` nested strip |
| Other `/admin/setup` desk tabs’ tenant/facility/structure/access dialogs | Reachable only after leaving Clinical Services |

---

## Main implementation sources

- `frontend/lib/app/router/app_routes.dart` (`/admin/setup`)
- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart` (`clinical-services` query)
- `frontend/lib/features/tenant_facility/presentation/widgets/facility_catalog_config_panel.dart`
- `frontend/lib/shared/facility_catalog/clinical_catalog_admin_dialogs.dart`
- `frontend/lib/shared/lab_catalog/lab_catalog_dialogs.dart`
- `frontend/lib/shared/radiology_catalog/radiology_catalog_dialogs.dart`
- `frontend/lib/shared/components/app_dialog.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/components/app_search_bar.dart`
