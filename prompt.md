# Fix Lab Configurations modal — scope, role UX, and catalog loading

## Problem

The **Lab Configurations** modal (`Lab Configurations` action on the Lab workspace) is implemented but broken in practice:

1. **Catalog never loads** — After selecting Tenant and Facility, the Tests and Panels tabs stay empty instead of showing the facility lab catalog.
2. **Misleading validation banner** — A red **“Check the details”** banner appears with:
   - Enter a valid Limit.
   - Enter a valid Tenant.
   - Enter a valid Facility.
   even though Tenant and Facility appear selected in the dropdowns.
3. **Misleading empty-state copy** — With Tenant selected but Facility still empty, the info banner still says *“Select a tenant and facility…”* instead of prompting only for the missing field.

## Expected behavior

### Role-based scope UI

| Role | Tenant field | Facility field | Scope resolution |
|------|--------------|----------------|------------------|
| Platform admin / super admin | Visible (required) | Visible (required) | User selects both; catalog loads when both are set |
| Tenant admin | **Hidden** | Visible (required) | Tenant auto-filled from session; user picks facility only |
| Facility admin | **Hidden** | **Hidden** | Tenant + facility auto-filled from session; catalog loads immediately on open |

For scoped roles, show a muted context line (e.g. *“Configuring lab catalog for {facilityName}.”*) instead of selectors.

### Catalog loading

Once scope is ready, load and display platform lab **Tests** and **Panels** for the selected facility (enable offerings, set prices, configure reference ranges / result options). Switching tabs or changing scope should reload appropriately.

### Empty / error states

- Tenant only → prompt to select a **facility** (not “tenant and facility”).
- Neither selected (platform admin) → prompt for both.
- API failure → show a clear, field-accurate error; do not show generic validation for fields that are visibly populated.

## Likely root causes (investigate first)

1. **Request validation mismatch** — `loadFacilityCatalogConfig` calls `listFacilityLabTests` / `listFacilityLabPanels` with `limit: 200`, but shared pagination validation caps `limit` at **100** (`MAX_PAGE_LIMIT`). This likely triggers *“Enter a valid Limit.”*
2. **Identifier format mismatch** — Lookup dropdown values may be human-friendly IDs, while `listFacilityLabCatalogQuerySchema` uses strict `uuidSchema` for `tenant_id` and `facility_id`. Align with `uuidOrFriendlyIdentifierSchema` (as other lab endpoints do) or ensure the frontend sends internal UUIDs.
3. **Scope not propagated** — Confirm `_LabConfigurationsDialog` passes the resolved `_tenantId` / `_facilityId` into `LabCatalogScope` and that `_catalogScope.isReady` matches what the API receives.

## Key files

- `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart` — `_LabConfigurationsDialog`, scope init, role-gated selectors
- `frontend/lib/features/lab/presentation/controllers/lab_workspace_controller.dart` — `loadFacilityCatalogConfig`
- `frontend/lib/features/lab/data/repositories/lab_repository_impl.dart` — facility catalog API params
- `frontend/lib/core/permissions/access_policy.dart` — `canManageTenant()`, `canManageFacility()`, session `tenantId` / `facilityId`
- `backend/src/modules/facility-lab-catalog/schemas/facility-lab-catalog.schema.js` — list query validation
- `frontend/lib/l10n/app_en.arb` — `labConfigurationsSelectFacilityBody` and related strings

## Acceptance criteria

- [ ] Platform admin can select tenant + facility and see populated Tests/Panels tables.
- [ ] Tenant admin sees only facility selector; tenant is implicit; catalog loads after facility selection.
- [ ] Facility admin sees no selectors; catalog loads on open using session scope.
- [ ] No spurious “valid Limit / Tenant / Facility” errors when scope is correctly set.
- [ ] Empty-state messaging reflects what is actually missing.
- [ ] Add or update tests covering scope resolution and catalog load request params (limit ≤ 100, valid identifiers).

## Verification

1. Open Lab workspace → **Lab Configurations**.
2. Repeat as platform admin, tenant admin, and facility admin (or simulate via session fixtures).
3. Confirm catalog rows appear on Tests and Panels tabs after scope is ready.
4. Confirm network calls to `/facility-lab-catalog/tests` and `/panels` return 200 with valid query params.
