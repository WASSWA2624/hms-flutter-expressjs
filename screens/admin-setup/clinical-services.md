
## Clinical Services panel chrome (`FacilityCatalogConfigPanel`)
---

## Lab nested tab

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Create test | Search trailing; empty-state primary (`labCreateTestAction`) | May open scope picker when `tenantId` missing; then `LabCatalogItemMutationDialog` for `LabCatalogItemType.test`. |
| Create panel | Search trailing only (`labCreatePanelAction`) | Same create flow for `LabCatalogItemType.panel`. |
| Row select | Table / mobile list row | Opens `showLabCatalogItemDetailsDialog` for that test or panel (does **not** open edit). |
| Edit | Row actions only | `LabCatalogItemMutationDialog` for the row’s kind. |
| Delete | Row actions (`tenantFacilityDeleteAction` → **Delete**) | `LabDeleteReasonDialog`; submit **Delete test** or **Delete panel**. |

**Filter groups:** type (test / panel); category; result kind; specimen type; source (from loaded rows).

### `showLabCatalogItemDetailsDialog` (details)

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Edit | Footer (when mutable) | Pops `LabCatalogItemDetailsAction.edit`; parent opens `LabCatalogItemMutationDialog` via existing edit path. Omitted for unauthorized or standard items. |
| Delete | Footer (when mutable) | Pops `LabCatalogItemDetailsAction.delete`; parent opens `LabDeleteReasonDialog` via existing delete path. Omitted for unauthorized or standard items. |
| Close | Footer | Dismisses details. |

### `LabCatalogItemMutationDialog` (create / edit)

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Cancel | Footer (tests; panel details step) | Dismisses without save. Remains available during similarity scan; disabled only while saving. Dialog close (X) stays available except while saving. |
| Next / Back | Footer (panels only) | Panels are a **three-step wizard** (`AppWizardStepper`): step 1 **Panel details**, step 2 **Panel tests**, step 3 **Similarity**. Next validates details (name required) before advancing; from tests, Next requires ≥1 member then opens similarity review. Back returns to the previous step. Stepper nodes are also tappable. |
| Save | Footer (tests; panel similarity step) | For **tests**: runs similarity scan (button loading). Always opens `showLabCatalogSimilarityDialog`, including **0% / no matches** (Continue save). Near/exact matches use Create/Save anyway and send `confirm_similar: true`. For **panels**: Save appears on the **Similarity** step after review proceeds; panels also require ≥1 member test. Backend 409 name/code conflicts jump panels back to the details step with field errors. |
| Similarity review | Modal after Save (tests) or Next from Panel tests (panels) | Opens for empty, near, and exact scans. Exact clashes and near matches send `confirm_similar: true` on proceed. Actions: Cancel / Use this test or **Use this panel** / Continue save or Create/Save anyway. Use this pops `LabCatalogItem` so the parent opens details. Panel review scores name, code/id, category, and member-test composition (including slight overlaps / shared members) with per-parameter scores and overall %. |
| Details | After successful create/edit or Use this test/panel | Parent opens `showLabCatalogItemDetailsDialog` (with Edit/Delete when mutable) for the selected, created, or updated test/panel. Panel details include description, selected-test count, and a numbered member-test list (code · unit when present). |
| Add reference range | Top of test form range list | Appends another age/gender reference-range row (tests only); blocks duplicate label+gender+age-band keys. |
| Remove reference range | Per range row | Removes that reference-range row (tests only). |
| Add unit / qualitative value | Test form option lists | Adds chip values for unit or qualitative options (by result kind). |
| Remove unit / qualitative value | Option chips | Removes the selected option chip. |
| Select / deselect test | Panel tests step (`LabPanelTestSelectionTable` → `AppListTable`) | Searchable multi-select via shrink-wrapped `AppListTable` (dialog-body scroll only; no nested scroll). Selected members sort to the top; row tap or checkbox toggles. Shows selected count + truncated name summary; create requires at least one. |

Titles: create uses lab create dialog title keys; edit uses **Edit Lab Test** / **Edit Lab Panel** by kind.

**Test form field order:** framed sections — **Test identity** (name → code → searchable category select) → **Result configuration** (specimen select → result kind → default unit select / options by kind → description) → **Reference ranges** (preset labels + age/gender rows; Add at top). Category, specimen, and unit options combine known catalogs with loaded rows. **Panel form:** three-step wizard — step 1 **Panel details** (name → code → searchable category select → description), step 2 **Panel tests** shrink-wrapped searchable `AppListTable` multi-select (tenant and standard catalog tests; single dialog scroll), step 3 **Similarity** (opens `showLabCatalogSimilarityDialog` with per-parameter + overall %; Save after proceed). Create/edit payloads include `panel_items`. Selecting a standard (`STD_LAB_TEST:…`) member adopts that test into the tenant catalog on save. Create/configure dialogs share `LabTestDefinitionForm` for tests. Catalog mutate actions require `canMutateLabCatalog` (lab:write or tenant/facility/system admin).

---

## Diagnoses nested tab

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Create diagnosis | Search trailing; empty-state primary (`clinicalCreateDiagnosisAction`) | May open scope picker when `tenantId` missing; then `DiagnosisCatalogMutationDialog` (create). |
| Edit | Row actions / row select | `DiagnosisCatalogMutationDialog` (edit). |
| Delete | Row actions (**Delete**) | `LabDeleteReasonDialog` titled `clinicalDiagnosisFormTitle`; submit **Delete**; calls `deleteClinicalCatalogTerm`. |

**Filter groups:** category (from loaded rows).

### `DiagnosisCatalogMutationDialog` (create / edit)

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Cancel | Footer | Dismisses without save. |
| Save | Footer | Creates or updates diagnosis catalog term; pops `true` on success. |

Title: **Create diagnosis** (create) or **Edit diagnosis** (edit).

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

Opened after Configure → Next when the Lab nested tab is active. Wizard: **catalog → batch prices → preview → one batch enable** (same pattern as Radiology).

**Note from source:** `_openLabConfigureDialog` passes `kind: LabEnableOfferingKind.all` so both tests and panels are listed (type filter available). Catalog merges platform/tenant rows with facility offerings (matched by id/code/name) so already-offered rows stay visible as **Configured** even when they fall outside the current platform page. Configured rows have disabled select and are excluded from select-all / batch enable. Catalog rows are deduped by type + identity before render and enable.

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Laboratory filters / Filter | Catalog search (`labFiltersLabel`) | Type (when all), **status** (Available / Configured), category, result-kind, specimen type, and source filter groups; **Apply filters** / **Clear filters**. |
| Settings | Column visibility (when >1 columns) | Column-settings dialog. |
| Select-all header checkbox | Select column header (tristate, left-aligned) | Checks all currently listed available rows; unchecks to clear those listed rows. Shows indeterminate when only some listed rows are selected. Tooltip reflects Select all / partial count / Clear selection. |
| Row select / checkbox | Catalog row | Toggles multi-select for available rows only (selection updates without rebuilding the full table). Every row shows Status **Available** or **Configured**. Configured rows have disabled checkboxes and are excluded from select-all. Selection count appears under the dialog body; Next shows `(count)` when ≥1 available selected. Catalog load uses `AppLoadingIndicator`; in-place refresh uses a thin progress bar. |
| Back | Footer leftmost | Catalog: returns to scope picker when `showBackAction` (pops `backResult`); otherwise dismisses. Price → catalog; Preview → price. |
| Next | Footer middle (`commonNextActionLabel`) | Always visible on catalog/price. Catalog: disabled with `labSelectAtLeastOneItemMessage` until ≥1 available selected; then opens batch price. Price: validates required unit prices, then opens preview. |
| Close | Footer rightmost | Aborts without further enable (pops whether any were already enabled this session). |
| Enable selected | Preview footer primary (`labEnableSelectedItemsAction`) | Enables all remaining selected via `onEnable`; shows failure banner; on success stays on catalog with those rows marked Configured and cleared from selection (no re-enable in-session). Disabled with reason when selection empty or prices invalid. |

### Batch price step

Stacked fields for each selected test/panel: name/subtitle plus required `AppCurrencyAmountField` keyed per catalog identity (no shared controllers across items; no per-item nested price dialogs). Each row has a **Remove** icon action (`commonRemoveActionLabel`) to deselect that item from the batch without returning to catalog. Tests may suggest catalog unit prices (comma-grouped). **Panels always start blank** so facility panel price is independent of member-test pricing. Catalog rows are deduped by type + `apiId` (else code/id) before selection and pricing.

### Preview step

Table of name / type (when all) / code / category / **Unit price** (`alwaysVisible`); checkboxes remove items from the batch before submit.

### Standalone `LabEnableOfferingPriceDialog`

Single-item price enable used by other callers, not by this panel’s Configure wizard.

---

## Radiology enable offering dialog (`RadiologyEnableFacilityOfferingDialog`)

Opened after Configure → Next when the Radiology nested tab is active. Wizard: **catalog → batch prices → preview → one batch enable**.

Catalog lists only procedures **not** already offered at the scoped facility.

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Filters | Catalog search (`radiologyFiltersLabel`) | Modality filters; **Apply filters** / **Clear filters** (`radiologyClearFiltersAction`). |
| Settings | Column visibility (when >1 columns) | Column-settings dialog. |
| Row select / checkbox | Catalog row (available only) | Toggles multi-select for batch enable. |
| Back | Footer leftmost | Catalog: returns to scope picker when `showBackAction` (pops `backResult`); otherwise dismisses. Price → catalog; Preview → price. |
| Next | Footer middle (`commonNextActionLabel`) | Always visible on catalog/price. Catalog: disabled with `radiologySelectAtLeastOneTestMessage` until ≥1 selected; then opens batch price. Price: validates required unit prices, then opens preview. |
| Close | Footer rightmost | Aborts without enable (pops whether any were already enabled this session). |
| Enable selected | Preview footer primary (`radiologyEnableSelectedProceduresAction`) | Enables all remaining selected via `onEnable`; shows failure banner; pops `true` on full success. Disabled with reason when selection empty or prices invalid. |

### Batch price step

Stacked fields for each selected procedure: name/code/modality plus required `AppCurrencyAmountField` (no per-item nested price dialogs).

### Preview step

Table of name / code / modality / price; checkboxes remove items from the batch before submit.

### Standalone `RadiologyEnableOfferingPriceDialog`

Single-procedure price enable used by other callers (e.g. workspace nested flows), not by this panel’s Configure wizard.

---

## Diagnosis enable offering dialog (`DiagnosisEnableFacilityOfferingDialog`)

Opened after Configure → Next when the Diagnoses nested tab is active. Title: **Enable clinical diagnoses** (`tenantFacilityCatalogBrowseTitle`).

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Filter | Catalog search (when categories exist) | Category filters; **Apply filters** / **Clear filters**. |
| Settings | Column visibility (`setup_catalog_diagnosis_enable`) | Column-settings dialog. |
| Row select / Add diagnosis | Catalog row or row **Add diagnosis** (`clinicalAddDiagnosisAction`) | Upserts facility diagnosis offering (`upsertFacilityCatalogOffering`); on success pops `true`. Already-enabled rows show disabled **Configured**. |
| Close | Footer | Dismisses picker. |

---

## Delete confirms

### Radiology catalog soft-delete / restore / permanent-delete

Uses shared Admin Setup dialogs (`AppConfirmActionDialog` / `AppTextInputActionDialog`). Soft-delete copy states tenant catalog ownership (not facility offering removal). Permanent delete requires soft-delete first and type-name confirmation.

### Lab / diagnosis deletes (`LabDeleteReasonDialog`)

Used for lab / diagnosis global catalog deletes from this panel. Call sites pass `showCancelButton: false` (default).

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Submit (dynamic label) | Footer primary | Confirms delete after required reason text: **Delete test**, **Delete panel**, or **Delete** (diagnosis). |
| Close | Title bar | Aborts (no footer Cancel on this screen’s call sites). |

---

## Shared dialog / table actions (reachable surfaces)

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Cancel | Footers that include it (scope picker, mutation dialogs, lab price dialog) | Dismisses without applying. |
| Maximize / Restore | Title bar of reachable `AppDialog`s | Expands or restores dialog size. |
| Close | Title bar of reachable `AppDialog`s; enable-dialog footers | Dismisses; often disabled while saving. |
| Apply filters / Clear filters | Advanced-filter footer | **Apply filters** applies criteria (dialog shows loading, disables chrome until done) or **Clear filters** resets filter value. |
| Apply columns / Reset columns / Close | Column-settings dialog | Applies, resets, or dismisses column visibility. |

---

## Reachable modal chain

- Clinical Services → nested Radiology / Lab / Diagnoses tables
- **Configure** → **Select tenant and facility** →
  - Radiology → `RadiologyEnableFacilityOfferingDialog` (catalog → batch prices → preview → batch enable; Back can return to scope)
  - Lab → `LabEnableFacilityOfferingDialog` (catalog → batch prices → preview → batch enable for tests and panels; offered rows stay visible as Configured; Back can return to scope; Close returns whether any were enabled)
  - Diagnoses → `DiagnosisEnableFacilityOfferingDialog` (row enable; no nested price dialog)
- Add / Create (no tenant) → **Select tenant and facility** → category mutation dialog
- Add / Create (tenant present) → category mutation dialog
- Edit / row select → category mutation dialog (radiology skips soft-deleted / standard rows)
- Lab row select → `showLabCatalogItemDetailsDialog` (Edit/Delete from details when mutable)
- Radiology Delete (active) → soft-delete `AppConfirmActionDialog` (tenant catalog scope copy)
- Radiology Restore / Permanent delete (soft-deleted) → restore confirm / type-name + permanent confirm
- Lab / Diagnoses Delete → `LabDeleteReasonDialog`

---

## Helpers / actions not reachable from this section

| Helper | Would open or do |
| ------ | ---------------- |
| `LabEnableFacilityOfferingDialog` with `LabEnableOfferingKind.test` / `panel` only | Lab workspace Configure still opens kind-specific dialogs; Clinical Services Configure uses `all` |
| `LabEnableOfferingPriceDialog` | Standalone single-item enable; Clinical Services Lab Configure uses the batch wizard |
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
