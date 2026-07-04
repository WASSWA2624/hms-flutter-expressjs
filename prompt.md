# Lab Configurations Dialog — UX & Enable-Offering Flow

Fix the **Lab Configurations** modal (`_LabConfigurationsDialog` in `lab_workspace_page.dart`) and the **Enable lab offering** flow (`LabEnableFacilityOfferingDialog` in `lab_catalog_dialogs.dart`). Screenshots show scope-selection bugs, toggle styling issues, and empty enable dialogs that should list searchable platform catalog items.

## Scope

| Area | Primary files |
|------|---------------|
| Configurations modal | `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart` |
| Enable offering dialog | `frontend/lib/shared/lab_catalog/lab_catalog_dialogs.dart` |
| Catalog data | `frontend/lib/features/lab/presentation/controllers/lab_workspace_controller.dart`, `lab_repository_impl.dart` |
| Shared UI | `AppListTable`, `AppCurrencyAmountField` (`app_currency_amount_field.dart`) |
| Strings | `frontend/lib/l10n/app_en.arb` |

---

## 1. Scope selection (tenant / facility)

**Problem:** On first open, neither tenant nor facility is selected, yet misleading context text appears (e.g. *"Configuring lab catalog for `fbb67a68-…`"* — a raw UUID).

**Required behavior:**

- **Facility context** dropdown must be **disabled** until a tenant is selected. Show the existing tooltip/snackbar (`labConfigurationsSelectTenantFirstTooltip`) when the user interacts with the disabled field.
- **Do not show** the *"Configuring lab catalog for …"* label until **both** tenant and facility are resolved to **human-readable names** from lookups. Never fall back to displaying a raw ID.
- When tenant is set but facility is missing, show only the informational banner (*"Select a facility for {tenantName}…"*). Hide the catalog table, search bar, and enable actions until scope is ready.

---

## 2. Tests / Panels toggle styling

**Problem:** `_LabConfigurationTypeSelector` renders two pill-shaped options that touch edge-to-edge on wide screens, with rounded corners, borders, and filled backgrounds.

**Required styling:**

- Add horizontal **gap** between Tests and Panels on large screens (do not let options touch).
- Remove container **border**, **background fill**, and **rounded corners** from each option.
- Each option should show only: **radio indicator**, **icon**, and **label** — minimal, flat appearance consistent with secondary segmented controls elsewhere in the app.

---

## 3. Enable lab offering dialog (tests & panels)

**Problem:** Clicking **Enable test** or **Enable panel** opens `LabEnableFacilityOfferingDialog`, which shows *"No platform lab catalog items are available for this tenant"* with no selectable items.

**Required two-step flow:**

### Step A — Browse & search platform catalog

Replace the single searchable dropdown with an **`AppListTable`** (same pattern as the main configurations list):

- **Enable test** → searchable table of **platform tests** (CBC, LFT, etc.).
- **Enable panel** → searchable table of **platform panels**.
- Columns: at minimum name, code, category; match existing lab catalog table conventions.
- Support live search/filter while typing.
- Row click (`onRowSelected`) advances to Step B.

**Data source:** Load the **tenant platform master catalog**, not only items already offered at the facility. Use `LabRepository.listTests` / `listPanels` (or the correct platform-catalog API if facility-catalog endpoints return empty). `searchPlatformLabCatalogForOffering` currently calls `listFacilityLabTests` / `listFacilityLabPanels` — verify and fix if that is why the list is empty. Exclude or badge items already offered (`isOfferedAtFacility`).

### Step B — Confirm selection & set price

On row selection, open a **secondary modal** showing:

- Selected test/panel summary (name, code, category, specimen/unit as applicable).
- **Facility price** via existing **`AppCurrencyAmountField`** (currency + amount), required, `allowZero: false`.
- Primary action: **Enable test** / **Enable panel** → calls existing `onEnable` / `upsertFacilityLabTestOffering` / `upsertFacilityLabPanelOffering` with `{ is_active: true, unit_price, currency }`.
- Cancel returns to Step A without losing search state.

### After enable

- Close dialogs, show success snackbar (`labSavedMessage`).
- Reload facility catalog for the current tenant + facility scope.
- Reopening Lab Configurations with the same scope must show the newly enabled item in the Tests or Panels table.

---

## Acceptance criteria

- [ ] Facility dropdown disabled until tenant is selected; no raw UUIDs shown anywhere in the dialog.
- [ ] Tests/Panels toggle is flat (icon + label + radio only), spaced apart on wide screens.
- [ ] Enable test/panel dialogs list searchable platform catalog items in a table.
- [ ] Selecting a row opens a price-confirmation sub-dialog using `AppCurrencyAmountField`.
- [ ] Enabling an item persists it; it appears in the facility catalog list after reload.
- [ ] Empty states remain correct: no platform items for tenant, or all items already offered.
- [ ] Existing tests pass; add/update widget tests for scope gating and enable flow if coverage exists (`lab_workspace_controller_test.dart`).

## Out of scope

- QC logs section behavior (unchanged).
- Backend seeding of platform catalog data (unless API wiring is the root cause of empty lists).
