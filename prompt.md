# Lab Configurations — scope selection UX

## Context

In the **Lab Configurations** modal (`_LabConfigurationsDialog` in `lab_workspace_page.dart`), elevated users who manage multiple tenants and facilities must choose a **Tenant** and **Facility context** before the lab catalog can load.

The dialog is opened from the Lab workspace and is used to enable platform tests/panels, set prices, and configure reference ranges for a specific facility.

## Problem

When the dialog opens and **no tenant is selected**, the **Facility context** field still appears interactive (see attached screenshot). This is confusing for users with cross-tenant access: they can attempt to pick a facility before a tenant is known, and the main content area can show catalog UI or empty states instead of a clear scope-selection prompt.

## Goal

Enforce a strict **tenant → facility** selection flow with clear, disabled UI and messaging until scope is complete.

## Requirements

### 1. Facility selector gating

- When `_showTenantSelector` is true and no tenant is selected:
  - Render the **Facility context** field as **disabled** (not merely empty).
  - Do **not** allow facility selection or clearing.
  - Show an inline helper message such as: *"Select a tenant first"* (reuse or extend `labConfigurationsSelectTenantFirstTooltip`).
- When a tenant **is** selected:
  - Enable the facility selector and populate it with `facilitiesForTenant(_tenantId)`.
  - Clear any previously selected facility when the tenant changes.

### 2. Scope-dependent content

- Until `LabCatalogScope.isReady` (both non-empty `tenantId` and `facilityId`):
  - **Hide** Tests/Panels toggle, search bar, catalog table, and enable actions.
  - **Show** `AppMessagePanel` with the appropriate scope prompt:
    - No tenant: `labConfigurationsSelectScopeBody` — *"Select a tenant and facility to load and configure the lab catalog."*
    - Tenant only: `labConfigurationsSelectFacilityOnlyBody(tenantName)` — *"Select a facility for {tenant} to load and configure the lab catalog."*
- Do **not** call `loadFacilityCatalogConfig` or show catalog empty states (e.g. *"No tests are offered at this facility"*) until scope is ready.

### 3. Visual affordance

- The disabled facility field must be visually distinct from an active empty dropdown (muted styling, no misleading clear/action controls).
- Optional: keep tooltip + tap-to-snackbar on the disabled field for accessibility.

## Files likely involved

- `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart` — `_LabConfigurationsDialog`, `_LabConfigurationsDisabledFacilityField`
- `frontend/lib/l10n/app_en.arb` — scope prompt / helper strings if new copy is needed
- `frontend/test/features/lab/...` — widget or controller tests for scope gating

## Acceptance criteria

- [ ] With tenant unselected, facility selector is disabled and shows a clear helper message.
- [ ] With tenant selected but facility unselected, facility selector is enabled; main area shows facility-only scope prompt.
- [ ] With both selected, catalog loads and Tests/Panels UI appears.
- [ ] Changing tenant resets facility and does not retain stale catalog data.
- [ ] No catalog empty/loading states appear before scope is ready.

## Reference

Existing partial implementation: `facilitySelectorEnabled`, `_LabConfigurationsDisabledFacilityField`, and `_scopePromptMessage` in `_LabConfigurationsDialogState`.
