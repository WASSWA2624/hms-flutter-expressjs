
## Clinical Services panel chrome (`FacilityCatalogConfigPanel`)
---

## Lab nested tab

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Create test | Search trailing; empty-state primary (`labCreateTestAction`) | May open scope picker when `tenantId` missing; then `LabCatalogItemMutationDialog` for `LabCatalogItemType.test`. |
| Create panel | Search trailing only (`labCreatePanelAction`) | Same create flow for `LabCatalogItemType.panel`. |
| Edit | Row actions / row select | `LabCatalogItemMutationDialog` for the row’s kind. |
| Delete | Row actions (`tenantFacilityDeleteAction` → **Delete**) | `LabDeleteReasonDialog`; submit **Delete test** or **Delete panel**. |

**Filter groups:** type (test / panel); category (from loaded rows).

### `LabCatalogItemMutationDialog` (create / edit)

| Action button / control | Location | Modal opened or function |
| ----------------------- | -------- | ------------------------ |
| Cancel | Footer | Dismisses without save. Remains available during similarity scan; disabled only while saving. |
| Save | Footer | For **tests**: runs similarity scan (button loading), then creates/updates; pops `true` on success. For **panels**: validates and saves directly. |
| Similarity review | Modal after Save (tests) | Exact name/code conflicts set field errors and block save. Near matches open `showLabCatalogSimilarityDialog` (Cancel / Use this test / Create or Save anyway). Create with no matches opens no-similar confirm. Proceed sends `confirm_similar: true`. Use existing pops `LabCatalogItem` so the parent can open edit. |
| Add reference range | Top of test form range list | Appends another age/gender reference-range row (tests only); blocks duplicate label+gender+age-band keys. |
| Remove reference range | Per range row | Removes that reference-range row (tests only). |
| Add unit / qualitative value | Test form option lists | Adds chip values for unit or qualitative options (by result kind). |
| Remove unit / qualitative value | Option chips | Removes the selected option chip. |

Titles: create uses lab create dialog title keys; edit uses **Edit Lab Test** / **Edit Lab Panel** by kind.

**Test form field order:** framed sections — **Test identity** (name → code → searchable category select) → **Result configuration** (specimen select → result kind → default unit select / options by kind → description) → **Reference ranges** (preset labels + age/gender rows; Add at top). Category, specimen, and unit options combine known catalogs with loaded rows. Panel form uses a single **Panel details** section. Create/configure dialogs share `LabTestDefinitionForm`. Catalog mutate actions require `canMutateLabCatalog` (lab:write or tenant/facility/system admin).

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

Opened after Configure → Next when the Lab nested tab is active.

**Note from source:** `_openLabConfigureDialog` passes `kind: LabEnableOfferingKind.all` so both tests and panels are listed (type filter available). Row enable routes to test or panel upsert by item type.

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
  - Lab → `LabEnableFacilityOfferingDialog` (tests and panels) → `_LabEnableOfferingPriceDialog`
  - Diagnoses → `DiagnosisEnableFacilityOfferingDialog` (row enable; no nested price dialog)
- Add / Create (no tenant) → **Select tenant and facility** → category mutation dialog
- Add / Create (tenant present) → category mutation dialog
- Edit / row select → category mutation dialog (radiology skips soft-deleted / standard rows)
- Radiology Delete (active) → soft-delete `AppConfirmActionDialog` (tenant catalog scope copy)
- Radiology Restore / Permanent delete (soft-deleted) → restore confirm / type-name + permanent confirm
- Lab / Diagnoses Delete → `LabDeleteReasonDialog`

---

## Helpers / actions not reachable from this section

| Helper | Would open or do |
| ------ | ---------------- |
| `LabEnableFacilityOfferingDialog` with `LabEnableOfferingKind.test` / `panel` only | Lab workspace Configure still opens kind-specific dialogs; Clinical Services Configure uses `all` |
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
