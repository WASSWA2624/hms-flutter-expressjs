# Lab Configurations UX refinement

Refine the **Lab Configurations** dialog (`_LabConfigurationsDialog` in `lab_workspace_page.dart`) and the **Enable lab offering** flow (`LabEnableFacilityOfferingDialog` in `lab_catalog_dialogs.dart`) so scope selection, catalog listing, and offering creation are clear and match facility-admin expectations.

## Problem

The current flow is confusing:

1. Empty-state copy is generic and does not reflect what the user has already selected.
2. The Tests/Panels tables list the **entire platform catalog**, mostly marked **Not offered** — users expect to see only what the facility already offers.
3. The **Enable test/panel** dialog should be the place to search and add catalog items; already-offered items need clear feedback.
4. **Unit price** uses a plain text field instead of the shared amount+currency component.
5. **Tenant** and **Facility context** selectors are fixed-width and not responsive; facility is selectable before a tenant is chosen.
6. **QC logs** at the bottom of Lab Configurations has no explained purpose.

## Requirements

### 1. Context-aware empty states

Replace generic prompts with step-specific guidance:

| State | Message intent |
|-------|----------------|
| No tenant, no facility | Ask user to select tenant and facility. |
| Tenant selected, no facility | Ask user to select a facility; optionally name the selected tenant. |
| Facility selected | Show configuring context (e.g. “Configuring lab catalog for {facilityName}.”). |

Use/update l10n keys: `labConfigurationsSelectScopeBody`, `labConfigurationsSelectFacilityOnlyBody`, `labConfigurationsFacilityContextLabel`.

### 2. Main catalog tables — offered items only

- **Tests** and **Panels** tabs must list **only facility-offered** items (`isOfferedAtFacility == true`).
- Load with `offeredOnly: true` via `loadFacilityCatalogConfig` / repository (`listFacilityLabTests`, `listFacilityLabPanels`).
- Remove or repurpose the **Offered** column (all visible rows are offered).
- Keep search, filters, edit, delete, and configure actions on offered items.
- Empty state when nothing is offered: prompt user to use **Enable test** / **Enable panel**.

### 3. Enable lab offering dialog

- Searchable **Platform catalog item** picker (e.g. typing `LFT` finds “Liver Function Panel | LFT”).
- Scope options to the active tab type (tests vs panels) and items **not yet offered** at the facility.
- When a searched item is already offered, show explicit feedback (disabled option, badge, or helper text) — do not allow duplicate enable.
- Support server-side search if needed (`searchFacilityLabCatalog` / `offered_only=false`) so large catalogs stay performant.

### 4. Unit price input

- Replace `AppTextField` price input with **`AppCurrencyAmountField`** (`app_currency_amount_field.dart`).
- Persist **amount and currency** together in the enable/configure payload (same pattern as billing, OPD, claims).
- Default currency from tenant/facility context where available.

### 5. Tenant & facility selectors — layout and gating

- Make selectors **full-width** and **responsive** (stack on narrow viewports; side-by-side on wide).
- **Disable** Facility context until a tenant is selected (multi-facility tenants).
- On hover/focus of disabled facility field, show tooltip: **“Select a tenant first.”**
- Clearing tenant clears facility and catalog state.

### 6. QC logs placement and clarity

- Either move **QC logs** out of Lab Configurations into the main lab workspace toolbar, **or**
- Keep it but add a short labeled section explaining purpose: *“Record quality-control runs for tests offered at this facility.”*
- QC logs must continue to use **offered tests only**.

## Key files

- `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart` — `_LabConfigurationsDialog`
- `frontend/lib/shared/lab_catalog/lab_catalog_dialogs.dart` — `LabEnableFacilityOfferingDialog`
- `frontend/lib/features/lab/presentation/controllers/lab_workspace_controller.dart` — `loadFacilityCatalogConfig`
- `frontend/lib/shared/components/app_currency_amount_field.dart`
- `frontend/lib/l10n/app_en.arb`
- `backend/src/modules/facility-lab-catalog/` — `offered_only` query support

## Acceptance criteria

- [ ] Empty-state copy updates as tenant/facility selection progresses.
- [ ] Tests/Panels tables show only offered items; no long list of “Not offered” rows.
- [ ] Enable dialog searches platform catalog; already-offered items are clearly indicated.
- [ ] Unit price uses `AppCurrencyAmountField` with amount + currency.
- [ ] Tenant/facility selectors span full width, respond to screen size, and facility is disabled until tenant is set.
- [ ] QC logs purpose is obvious or entry point is relocated.
- [ ] Existing lab configuration and catalog-scope tests updated; new behavior covered where practical.

## Out of scope

- Fixing malformed platform catalog seed data (e.g. corrupt test names).
- Super-admin cross-tenant login behavior.
