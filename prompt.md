# Feature: Refine Radiology facility catalog configuration dialogs

## Goal

Polish the **Radiology configurations** flow (opened from the Radiology workspace toolbar) so admins can enable, review, and manage facility offerings with immediate feedback, less redundant copy, and a picker UX consistent with Lab.

## Current state (keep)

The following already work well—do not regress:

- **Radiology configurations** dialog: tenant/facility scope selectors, search, modality filters, table with Name / Code / Modality / Unit price, **Enable procedure**, **Refresh**, and **Table settings**.
- **Enable radiology offering** picker: platform catalog search, modality filter, row select → price step.
- **Enable procedure** price dialog: procedure name, code · modality subtitle, required unit price + currency, Cancel / **Enable procedure** (see screenshot—keep this dialog as-is).

## Problems

| Area | Issue |
|------|-------|
| **Configurations dialog copy** | Redundant guidance text clutters the header: dialog body (*"Select a tenant and facility, then enable platform radiology procedures with facility-specific pricing."*) and scope subtitle (*"Configuring radiology catalog for {facility}"*). |
| **Stale list after enable** | Newly enabled procedures (e.g. Abdomen MR angiography, transvaginal ultrasound) do not appear in the configurations table immediately; users must wait or refresh manually. |
| **Enable offering loading UX** | Initial load uses a full `AppWorkspaceStatePanel.loading` block. Prefer the slim **linear progress** pattern used elsewhere (e.g. `clinical_procedure_catalog_dialog.dart`, workspace loading bars). |
| **Enable offering table** | **Action** column shows *Select* for every row. Users need a clear **enabled vs available** indicator instead. Already-enabled procedures should appear **at the top** of the list. |
| **Catalog visibility** | Enable-offering search should show the **merged platform + facility status** view for the logged-in facility scope—not a filtered subset that hides enabled items. Clinicians configuring offerings must see what is already enabled without guessing. |

## Reference implementation

Mirror the Lab enable-offering pattern in `frontend/lib/shared/lab_catalog/lab_catalog_dialogs.dart` (`LabEnableFacilityOfferingDialog`):

- Show **all** catalog rows (`_filteredCatalogItems`), not only not-yet-offered rows.
- **Status column** (reuse `radiologyEnableOfferingAlreadyOfferedLabel` / Lab equivalent): muted *Already offered* for enabled rows; empty or selectable affordance for available rows.
- Disable row tap / selection when `isOfferedAtFacility`.
- Sort or comparator: **offered items first**, then name.
- Table `isLoading` + `AppListTableSearch.isLoading` for in-table refresh; **linear progress** on first load instead of blocking panel when possible.

**Primary files:**

- Configurations dialog: `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.configurations.dart`
- Enable / edit dialogs: `frontend/lib/shared/radiology_catalog/radiology_catalog_dialogs.dart`
- Controller & merge logic: `frontend/lib/features/radiology/presentation/controllers/radiology_workspace_controller.dart` (`searchPlatformRadiologyCatalogForOffering`, `upsertRadiologyTestOffering`, `loadFacilityCatalogConfig`)
- Shared scope UI: `frontend/lib/shared/facility_catalog/facility_catalog_scope_section.dart`
- Localization: `frontend/lib/l10n/app_en.arb` (`radiologyConfigurationsDialogBody`, `radiologyConfigurationsFacilityContextLabel`, `radiologyEnableOfferingAlreadyOfferedLabel`, etc.)

## Required changes

### 1. Remove redundant configurations copy

- Remove the dialog body paragraph (`radiologyConfigurationsDialogBody`) from `_RadiologyConfigurationsDialog`.
- Suppress the post-selection scope guidance line from `FacilityCatalogScopeSection` for radiology (the *"Configuring radiology catalog for …"* muted text when scope is ready). Keep tenant/facility selectors and pre-scope prompts (*select tenant/facility first*) intact.

### 2. Immediate configurations table refresh

After a successful enable (and edit/delete if applicable):

- Optimistically append/update `catalogTests` in `RadiologyWorkspaceController` from the upsert response, **or** await `loadFacilityCatalogConfig` and sync dialog state before closing nested dialogs.
- Ensure `_RadiologyConfigurationsDialog` listener (`ref.listen` + `_shouldSyncCatalogState`) reflects new offerings without requiring manual **Refresh**.
- Avoid leaving `isMutating` / `isLoadingCatalog` true long enough to block the table after success.

### 3. Enable radiology offering picker

In `RadiologyEnableFacilityOfferingDialog`:

- Replace initial `AppWorkspaceStatePanel.loading` with `LinearProgressIndicator(minHeight: 2)` (or equivalent shared loading bar) while keeping existing data visible on subsequent searches.
- Bind `AppListTable.isLoading` and search `isLoading` to `_isSearching` (Lab pattern).
- List `_filteredCatalogItems` (all rows with facility status), not `_availableItems`.
- Replace **Action / Select** column with **Status**: *Already offered* when `isOfferedAtFacility`; otherwise leave cell empty and keep row selectable.
- Sort: `isOfferedAtFacility` descending, then name.
- On successful enable from price dialog: update local `_catalogItems` status immediately so the parent configurations table and picker stay in sync.

### 4. Enable procedure price dialog

No layout changes. Only ensure successful submit triggers the refresh behavior in §2.

## Implementation rules

- Reuse shared components (`AppDialog`, `AppListTable`, `AppSearchBar`, `FacilityCatalogScopeSection`, `LinearProgressIndicator`)—match Lab catalog dialogs, do not fork new patterns.
- Localization: add/adjust ARB keys only if new labels are needed; remove unused strings if body copy is deleted.
- Scope: radiology facility catalog configuration dialogs only; do not change the main Radiology worklist (see `prompt1.md`).

## Acceptance criteria

- [ ] Radiology configurations dialog shows tenant/facility selectors without redundant body or *"Configuring radiology catalog for …"* subtitle when scope is ready.
- [ ] Enabling a procedure updates the configurations table immediately (no manual refresh required).
- [ ] Enable radiology offering uses a linear progress indicator for loading; table remains visible during search refresh when data already loaded.
- [ ] Enable offering table shows **Status** (already offered vs available), not a **Select** action column.
- [ ] Already-enabled procedures appear at the top of the enable-offering list.
- [ ] Already-enabled rows are not selectable; available rows open the existing **Enable procedure** price dialog unchanged.
- [ ] Behavior and sorting align with `LabEnableFacilityOfferingDialog`.
- [ ] Edit and delete offering still work; list stays consistent after mutations.
