# Feature: Fix Radiology facility catalog configuration (Configurations + Enable Offering)

## Goal

Make **Radiology configurations** reliable for facility admins: enable platform procedures with a price, see them immediately in the list with complete metadata, edit unit price, and remove offerings (single or batch). This is **facility-level offering configuration only**—not platform catalog authoring.

## Current state (screenshots)

Two dialogs in the Radiology workspace **Configurations** flow:

| Dialog | Purpose |
|--------|---------|
| **Radiology configurations** | Lists procedures already enabled for the selected tenant/facility (name, code, modality, unit price, actions). |
| **Enable Radiology Offering** | Searchable platform catalog picker; user sets facility price to enable a procedure. |

What already works (keep):

- Tenant / facility context selectors and scope gating.
- Search, **Radiology filters**, **Table settings**, **Refresh**, and **Enable procedure** toolbar actions.
- Row click on non-offered catalog items opens the price dialog.
- Edit and delete affordances exist in the configurations table (icon buttons).

## Problems

### 1. Enable Offering — misleading empty Action column

The last column is labeled **Action** but is blank for procedures not yet enabled at the facility. Only already-offered rows show “Already offered.”

**Expected:** Rename the column to **Status** and show a clear state for every row, e.g.:

| State | Display |
|-------|---------|
| Not yet enabled | “Available” / “Not enabled” (muted) |
| Already at facility | “Already offered” (existing label) |

Do not leave cells empty. Match the intent of the Lab enable-offering dialog but use a **Status** label (not Action).

### 2. Enable / list sync — offerings missing or incomplete after save

Observed failures:

- Enabling a procedure sometimes does not appear in **Radiology configurations** after save.
- One offering persisted with **unit price only**—name, code, and modality showed “Not available”; the row vanished after closing and reopening the dialog.
- Frontend and backend are out of sync.

**Expected:** After a successful enable (or edit/delete):

1. **Backend:** `PUT /facility-radiology-catalog/tests/:radiology_test_id` persists the offering; list/search responses return merged master + offering fields (`name`, `code`, `modality`, `unit_price`, `currency`).
2. **Frontend:** Configurations table updates immediately (optimistic merge **and** reload from server). No ghost rows with missing catalog metadata.
3. **Enable dialog close:** Parent configurations dialog refreshes facility catalog (`loadFacilityCatalogConfig`) so new items are visible without manual refresh.

Investigate end-to-end: `RadiologyEnableFacilityOfferingDialog` → `upsertRadiologyTestOffering` → `mapMergedRadiologyTestRecord` → `RadiologyCatalogTestDto.toEntity()`.

### 3. Edit and delete actions inactive

In **Radiology configurations**, edit (pencil) and delete (trash) icons appear but do not work reliably.

**Expected:**

- **Edit** opens `RadiologyEditFacilityOfferingDialog` and updates unit price/currency only (facility offering—not platform test fields).
- **Delete** opens the existing reason dialog and calls `disableRadiologyTestOffering` (soft-disable facility offering).
- Buttons are enabled when scope is ready and not blocked by a stuck `isMutating` / `isLoadingCatalog` state. Surface API failures via snackbar or inline banner.

### 4. Batch delete for facility offerings

Add multi-select removal for configured procedures:

- **Selection column** as the leftmost column (checkbox per row + header select-all for current page/filter).
- Toolbar action **Delete selected** (enabled when ≥1 row selected).
- Confirm once (reuse `LabDeleteReasonDialog` pattern); disable each selected offering via existing delete API; refresh list and clear selection on success.

Scope: remove **facility offerings** only—never delete platform `radiology_test` records.

### 5. Dialog footer polish

If the footer **Close** button remains, add a leading icon (e.g. `Icons.close`) for consistency with other dialogs.

## Reference implementation

**Primary files:**

| Layer | Path |
|-------|------|
| Configurations dialog | `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.configurations.dart` |
| Enable / edit dialogs | `frontend/lib/shared/radiology_catalog/radiology_catalog_dialogs.dart` |
| Controller | `frontend/lib/features/radiology/presentation/controllers/radiology_workspace_controller.dart` |
| DTO / entity | `frontend/lib/features/radiology/data/dtos/radiology_dtos.dart`, `radiology_entities.dart` |
| Backend routes | `backend/src/modules/facility-radiology-catalog/routes/facility-radiology-catalog.routes.js` |
| Backend service / merge | `backend/src/modules/facility-radiology-catalog/services/facility-radiology-catalog.service.js`, `facility-radiology-catalog.merge.js` |

**Patterns to mirror:**

- Lab enable-offering status column: `frontend/lib/shared/lab_catalog/lab_catalog_dialogs.dart` (`_enableOfferingColumns`)—but use **Status** label for radiology.
- Delete reason dialog: `LabDeleteReasonDialog` (already used for single delete).
- Shared table/search: `AppListTable`, `AppSearchBar`, `FacilityCatalogScopeSection`.

## Implementation rules

- **Facility scope only:** upsert/disable offerings; no create/update/delete of platform radiology catalog tests.
- **Reload after mutations:** call `loadFacilityCatalogConfig` after enable dialog closes with success, and after batch delete completes.
- **Merged API responses:** list and upsert must always include master test fields; fix mapping if upsert returns offering-only payloads.
- **Localization:** add keys in `frontend/lib/l10n/app_en.arb` (e.g. status labels, batch delete action, selection column).
- **No new visual language**—match Lab catalog configuration spacing, badges, and dialog patterns.
- **Error visibility:** failed enable/edit/delete must show user-visible errors; do not fail silently.

## Acceptance criteria

- [ ] Enable Offering table column is **Status**; every row shows Available or Already offered—no empty cells.
- [ ] Enabling a procedure adds it to configurations with correct name, code, modality, and price without requiring a manual refresh.
- [ ] Reopening configurations shows the same data persisted in the database (no disappearing or partial rows).
- [ ] Edit updates unit price/currency and reflects immediately in the table.
- [ ] Single delete removes the facility offering and updates the table.
- [ ] Checkbox selection + **Delete selected** removes multiple offerings in one confirmed action.
- [ ] Close button includes an icon when shown in dialog footers.
- [ ] All mutations surface errors on failure; `isMutating` does not leave actions permanently disabled.
